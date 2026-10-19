import Foundation

@MainActor
final class ItemStore: ObservableObject {
    @Published var agents: [LaunchItem] = []
    @Published var loginItems: [LoginItem] = []
    @Published var unreadable: [UnreadablePlist] = []
    @Published var cronJobs: [CronJob] = []
    @Published var health = HealthReport(score: 100, issues: [])
    @Published var runtimeCache: [String: ServiceRuntime] = [:]
    @Published var isLoading = true
    @Published var lastError: String?
    @Published var lastScan: Date?

    private var runtimeLoading: Set<String> = []

    init() {
        refresh()
    }

    // MARK: - 刷新

    func refresh() {
        Task.detached(priority: .userInitiated) { [weak self] in
            let scan = LaunchAgentScanner.scan()
            let login = LoginItemsBridge.list()
            let cron = CronScanner.jobs()
            let report = HealthCheck.evaluate(items: scan.items, unreadable: scan.unreadable)
            let error = login.error

            await MainActor.run { [weak self] in
                guard let self else { return }
                self.agents = scan.items
                self.unreadable = scan.unreadable
                self.loginItems = login.items
                self.cronJobs = cron
                self.health = report
                self.lastError = error
                self.isLoading = false
                self.lastScan = Date()

                // 清理已被删除项目的运行时缓存
                let alive = Set(scan.items.map(\.id))
                self.runtimeCache = self.runtimeCache.filter { alive.contains($0.key) }
            }
        }
    }

    // MARK: - 启用 / 停用

    @discardableResult
    func setAgent(_ item: LaunchItem, enabled: Bool) -> String? {
        if enabled {
            LaunchCtl.enable(label: item.label, plistPath: item.plistPath)
        } else {
            LaunchCtl.disable(label: item.label, plistPath: item.plistPath)
        }
        runtimeCache[item.id] = nil
        refresh()
        return nil
    }

    // MARK: - 运行状态

    /// 按需加载单个服务的运行时信息（详情页出现时调用）
    func loadRuntime(for item: LaunchItem, force: Bool = false) {
        if !force {
            guard runtimeCache[item.id] == nil else { return }
        }
        guard !runtimeLoading.contains(item.id) else { return }
        runtimeLoading.insert(item.id)

        Task.detached(priority: .userInitiated) { [weak self] in
            let runtime = LaunchCtl.runtime(label: item.label)
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.runtimeCache[item.id] = runtime
                self.runtimeLoading.remove(item.id)
            }
        }
    }

    func isRuntimeLoading(_ item: LaunchItem) -> Bool {
        runtimeLoading.contains(item.id)
    }

    /// 启动 / 重启 / 停止，并在短暂等待后刷新该服务的运行时状态
    func control(_ action: ControlAction, for item: LaunchItem) {
        Task.detached(priority: .userInitiated) { [weak self] in
            let error: String?
            switch action {
            case .load: error = LaunchCtl.bootstrap(label: item.label, plistPath: item.plistPath)
            case .start: error = LaunchCtl.start(label: item.label)
            case .restart: error = LaunchCtl.restart(label: item.label)
            case .stop: error = LaunchCtl.stop(label: item.label)
            }

            try? await Task.sleep(nanoseconds: 500_000_000)
            let runtime = LaunchCtl.runtime(label: item.label)

            await MainActor.run { [weak self] in
                guard let self else { return }
                self.runtimeCache[item.id] = runtime
                if let error { self.lastError = error }
            }
        }
    }

    enum ControlAction {
        case load
        case start
        case restart
        case stop
    }

    // MARK: - 删除

    @discardableResult
    func deleteAgent(_ item: LaunchItem) -> String? {
        guard item.canDelete else {
            return "仅支持删除「当前用户」目录下的启动项"
        }
        LaunchCtl.disable(label: item.label, plistPath: item.plistPath)
        try? FileManager.default.removeItem(atPath: item.plistPath)
        runtimeCache[item.id] = nil
        refresh()
        return nil
    }

    @discardableResult
    func removeLoginItem(_ item: LoginItem) -> String? {
        if let error = LoginItemsBridge.remove(name: item.name) {
            return error
        }
        refresh()
        return nil
    }

    // MARK: - 添加自定义启动项

    @discardableResult
    func addCustomItem(
        displayName: String,
        command: String,
        arguments: [String],
        trigger: CustomTrigger
    ) -> String? {
        do {
            let label = try UserAgentWriter.add(
                displayName: displayName,
                command: command,
                arguments: arguments,
                trigger: trigger
            )
            LaunchCtl.enable(
                label: label,
                plistPath: LaunchAgentScanner.userDirectory + "/" + label + ".plist"
            )
            refresh()
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    // MARK: - 统计

    var scheduledAgents: [LaunchItem] {
        agents.filter(\.isScheduled)
    }
}
