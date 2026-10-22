import SwiftUI
import AppKit

// MARK: - 待确认操作（防呆）

enum PendingAction {
    case disableApple(LaunchItem, enable: Bool)
    case deleteAgent(LaunchItem)
    case deleteLoginItem(LoginItem)
}

// MARK: - 主窗口

struct ManagerWindow: View {
    @EnvironmentObject private var store: ItemStore
    @Environment(\.openWindow) private var openWindow
    @State private var selection: String?
    @State private var showAddSheet = false
    @State private var pending: PendingAction?
    @State private var query = ""

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            detailPane
        }
        .frame(minWidth: Theme.windowMinWidth, minHeight: Theme.windowMinHeight)
        .background {
            VisualEffectView(material: .underWindowBackground, blending: .behindWindow)
                .ignoresSafeArea()
        }
        .background {
            WindowBackdropConfigurator().frame(width: 0, height: 0)
        }
        .sheet(isPresented: $showAddSheet) {
            AddItemSheet()
        }
        .confirmationDialog(
            pendingTitle,
            isPresented: Binding(
                get: { pending != nil },
                set: { if !$0 { pending = nil } }
            ),
            titleVisibility: .visible
        ) {
            confirmationButtons
        }
        .onAppear {
            WindowOpener.openManager = { openWindow(id: "manager") }
            if store.agents.isEmpty && store.loginItems.isEmpty { store.refresh() }
        }
    }

    // MARK: - 侧边栏

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: 34) // 让出窗口红绿灯位置

            sidebarHeader

            SearchField(text: $query)
                .padding(.horizontal, 12)
                .padding(.top, 12)

            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 3) {
                    SidebarRow(
                        symbol: "calendar.badge.clock",
                        tint: .orange,
                        title: "定时任务",
                        subtitle: "\(store.scheduledAgents.count + store.cronJobs.count) 个定时项",
                        selected: selection == "page|schedule",
                        statusColor: .orange
                    ) {
                        selection = "page|schedule"
                    }

                    SidebarRow(
                        symbol: "stethoscope",
                        tint: .green,
                        title: "启动项体检",
                        subtitle: healthSubtitle,
                        selected: selection == "page|health",
                        statusColor: store.health.isClean ? .green : (store.health.criticalCount > 0 ? .red : .orange)
                    ) {
                        selection = "page|health"
                    }

                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 1)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)

                    ForEach(agentGroups, id: \.title) { group in
                        groupHeader(group.title, count: group.items.count)
                        ForEach(group.items) { item in
                            SidebarRow(
                                symbol: ItemStyle.symbol(for: item),
                                tint: ItemStyle.color(for: item),
                                title: item.displayName,
                                subtitle: agentSubtitle(item),
                                selected: selection == item.id,
                                statusColor: item.isEffectivelyDisabled ? .secondary : ItemStyle.status(item).color
                            ) {
                                selection = item.id
                            }
                        }
                    }

                    if !filteredLoginItems.isEmpty {
                        groupHeader("登录时打开", count: filteredLoginItems.count)
                        ForEach(filteredLoginItems) { item in
                            SidebarRow(
                                symbol: "person.crop.circle.badge.checkmark",
                                tint: .teal,
                                title: item.name,
                                subtitle: loginSubtitle(item),
                                selected: selection == "login|" + item.id,
                                statusColor: .teal
                            ) {
                                selection = "login|" + item.id
                            }
                        }
                    }

                    if agentGroups.isEmpty && filteredLoginItems.isEmpty {
                        Text(query.isEmpty ? "未发现可管理的启动项" : "没有匹配的结果")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 22)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 6)
                .padding(.bottom, 10)
            }

            sidebarFooter
        }
        .frame(width: Theme.sidebarWidth)
        .background {
            VisualEffectView(material: .sidebar, blending: .behindWindow)
        }
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 1)
        }
    }

    private var sidebarHeader: some View {
        HStack(spacing: 10) {
            BrandMark(size: 34)

            VStack(alignment: .leading, spacing: 1) {
                Text("StartupBoard")
                    .font(.system(size: 14, weight: .bold))
                Text("启动项看板")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                showAddSheet = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Theme.brandGradient))
                    .shadow(color: Theme.brandStart.opacity(0.4), radius: 6, y: 2)
            }
            .buttonStyle(.plain)
            .help("添加自定义启动项")
        }
        .padding(.horizontal, 12)
        .padding(.top, 2)
    }

    private var sidebarFooter: some View {
        VStack(spacing: 8) {
            Divider().opacity(0.3)

            HStack(spacing: 10) {
                statBadge(count: enabledCount, label: "已启用", color: .green)
                statBadge(count: disabledCount, label: "已停用", color: .secondary)
                Spacer()
                Button {
                    store.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("重新扫描")
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
        }
    }

    private func statBadge(count: Int, label: String, color: Color) -> some View {
        HStack(spacing: 5) {
            StatusDot(color: color)
            Text("\(count)")
                .font(.system(size: 11, weight: .semibold))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }

    private func groupHeader(_ title: String, count: Int) -> some View {
        HStack(spacing: 5) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.4)
            Text("\(count)")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
                .padding(.vertical, 0.5)
                .background(Capsule().fill(Color.primary.opacity(0.07)))
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.top, 10)
        .padding(.bottom, 3)
    }

    private func agentSubtitle(_ item: LaunchItem) -> String {
        if item.isCustom { return "自定义启动项" }
        if item.displayName == item.label { return "后台服务 · \(item.scope.rawValue)" }
        return item.label
    }

    private func loginSubtitle(_ item: LoginItem) -> String {
        let fileName = (item.path as NSString).lastPathComponent
        return fileName.isEmpty ? "系统登录项" : fileName
    }

    private var healthSubtitle: String {
        if store.isLoading { return "正在扫描…" }
        if store.health.isClean { return "未发现问题" }
        return "\(store.health.issues.count) 个问题 · \(store.health.score) 分"
    }

    // MARK: - 数据分组

    private var filteredAgents: [LaunchItem] {
        guard !query.isEmpty else { return store.agents }
        return store.agents.filter {
            $0.displayName.localizedCaseInsensitiveContains(query)
                || $0.label.localizedCaseInsensitiveContains(query)
        }
    }

    private var filteredLoginItems: [LoginItem] {
        guard !query.isEmpty else { return store.loginItems }
        return store.loginItems.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    private var agentGroups: [(title: String, items: [LaunchItem])] {
        let agents = filteredAgents
        let custom = agents.filter(\.isCustom)
        let thirdParty = agents.filter { !$0.isCustom && !$0.isApple }
        let system = agents.filter(\.isApple)

        var groups: [(title: String, items: [LaunchItem])] = []
        if !custom.isEmpty { groups.append(("自定义", custom)) }
        if !thirdParty.isEmpty { groups.append(("第三方", thirdParty)) }
        if !system.isEmpty { groups.append(("系统自带", system)) }
        return groups
    }

    private var enabledCount: Int {
        store.agents.filter { !$0.isEffectivelyDisabled }.count
    }

    private var disabledCount: Int {
        store.agents.filter(\.isEffectivelyDisabled).count
    }

    // MARK: - 详情

    @ViewBuilder
    private var detailPane: some View {
        Group {
            if selection == "page|schedule" {
                SchedulePage(
                    onOpen: { selection = $0 },
                    onToggle: { item, enabled in requestToggle(item, enabled: enabled) }
                )
            } else if selection == "page|health" {
                HealthPage(
                    onOpen: { selection = $0 },
                    onDelete: { pending = .deleteAgent($0) }
                )
            } else if let item = store.agents.first(where: { $0.id == selection }) {
                AgentDetailCard(item: item, isOn: rowToggle(item)) {
                    pending = .deleteAgent(item)
                }
                .id(item.id)
            } else if let login = store.loginItems.first(where: { "login|" + $0.id == selection }) {
                LoginItemCard(item: login) {
                    pending = .deleteLoginItem(login)
                }
            } else {
                emptyState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            BrandMark(size: 68)
                .opacity(0.9)
            Text("选择一个启动项")
                .font(.system(size: 15, weight: .semibold))
            Text("在左侧列表中点击任意项目，查看并调整它的启动行为")
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)

            HStack(spacing: 8) {
                Button {
                    showAddSheet = true
                } label: {
                    Label("添加启动项", systemImage: "plus")
                }
                .buttonStyle(GradientButtonStyle(height: 29))

                Button {
                    store.refresh()
                } label: {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
                .buttonStyle(GlassButtonStyle(height: 29))
            }
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 确认弹窗

    private var pendingTitle: String {
        switch pending {
        case .disableApple(let item, _):
            return "「\(item.displayName)」是 macOS 系统自带启动项，停用后可能影响部分系统功能。确定要继续吗？"
        case .deleteAgent(let item):
            return "确定要删除「\(item.displayName)」吗？该操作不可撤销。"
        case .deleteLoginItem(let item):
            return "确定要从登录项中移除「\(item.name)」吗？"
        case nil:
            return ""
        }
    }

    @ViewBuilder
    private var confirmationButtons: some View {
        switch pending {
        case .disableApple(let item, let enable):
            Button(enable ? "仍然开启" : "仍然停用", role: .destructive) {
                store.setAgent(item, enabled: enable)
                pending = nil
            }
        case .deleteAgent(let item):
            Button("删除", role: .destructive) {
                if let error = store.deleteAgent(item) { store.lastError = error }
                pending = nil
            }
        case .deleteLoginItem(let item):
            Button("移除", role: .destructive) {
                if let error = store.removeLoginItem(item) { store.lastError = error }
                pending = nil
            }
        case nil:
            EmptyView()
        }
        Button("取消", role: .cancel) { pending = nil }
    }

    // MARK: - 行开关

    private func rowToggle(_ item: LaunchItem) -> Binding<Bool> {
        Binding(
            get: { !item.isEffectivelyDisabled },
            set: { requestToggle(item, enabled: $0) }
        )
    }

    private func requestToggle(_ item: LaunchItem, enabled: Bool) {
        // 系统自带项停用前需二次确认，防止误关
        if item.isApple && !enabled {
            pending = .disableApple(item, enable: enabled)
        } else {
            store.setAgent(item, enabled: enabled)
        }
    }
}

// MARK: - 侧边栏行

private struct SidebarRow: View {
    let symbol: String
    let tint: Color
    let title: String
    let subtitle: String
    let selected: Bool
    let statusColor: Color
    var trailing: String? = nil
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                IconTile(systemName: symbol, size: 26, tint: tint)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 9.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 4)

                if let trailing {
                    Text(trailing)
                        .font(.system(size: 9, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Capsule().fill(Color.primary.opacity(0.08)))
                } else {
                    StatusDot(color: statusColor)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(background)
                    .overlay {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(
                                Color.white.opacity(selected ? 0.28 : 0),
                                lineWidth: 0.8
                            )
                    }
            }
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }

    private var background: AnyShapeStyle {
        if selected {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Theme.brandStart.opacity(0.42), Theme.brandEnd.opacity(0.26)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        return AnyShapeStyle(Color.primary.opacity(hovering ? 0.06 : 0.0))
    }
}

// MARK: - 启动项详情

private struct AgentDetailCard: View {
    let item: LaunchItem
    let isOn: Binding<Bool>
    let onDelete: () -> Void

    @EnvironmentObject private var store: ItemStore

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 12) {
                header
                statsGrid
                runtimeCard
                scheduleCard
                programCard
                footprintCard
                dangerCard
            }
            .padding(.horizontal, 22)
            .padding(.top, 44)
            .padding(.bottom, 22)
        }
        .onAppear {
            store.loadRuntime(for: item)
        }
        .onChange(of: item.isEffectivelyDisabled) { _, _ in
            store.loadRuntime(for: item, force: true)
        }
    }

    private var status: (text: String, color: Color) { ItemStyle.status(item) }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            IconTile(systemName: ItemStyle.symbol(for: item), size: 54, tint: ItemStyle.color(for: item))

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(item.displayName)
                        .font(.system(size: 18, weight: .semibold))
                    if item.isApple { Pill(text: "系统", tint: .orange) }
                    if item.isCustom { Pill(text: "自定义", tint: Theme.brandStart) }
                }

                Text(item.displayName == item.label ? "\(item.scope.rawValue) · 后台服务" : item.label)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 7) {
                Toggle("", isOn: isOn)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.regular)
                HStack(spacing: 5) {
                    StatusDot(color: status.color)
                    Text(status.text)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .glassCard(padding: 18)
    }

    private var statsGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
            spacing: 12
        ) {
            statTile("范围", item.scope.rawValue, symbol: item.scope == .user ? "person.fill" : "person.2.fill")
            statTile("开机启动", item.runAtLoad ? "是" : "否", symbol: "power")
            statTile("常驻运行", item.keepAlive ? "是" : "否", symbol: "arrow.triangle.2.circlepath")
            statTile("当前状态", item.isLoaded ? "已加载" : "未加载", symbol: "bolt.fill")
        }
    }

    private func statTile(_ title: String, _ value: String, symbol: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.brandStart)
                .frame(width: 26, height: 26)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Theme.brandStart.opacity(0.12))
                }

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 12.5, weight: .medium))
            }
            Spacer(minLength: 0)
        }
        .glassCard(padding: 12)
    }

    // MARK: 运行状态

    private var runtimeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionLabel("运行状态", symbol: "waveform.path.ecg")
                Spacer()
                if !item.isEffectivelyDisabled {
                    Button("刷新") {
                        store.loadRuntime(for: item, force: true)
                    }
                    .buttonStyle(GlassButtonStyle(height: 24))
                }
            }

            if item.isEffectivelyDisabled {
                hintText("该项已停用，启用后可以查看进程状态并手动启动。")
            } else if let runtime = store.runtimeCache[item.id] {
                HStack(alignment: .center, spacing: 5) {
                    StatusDot(color: runtime.isRunning ? .green : .secondary)
                    Text(runtime.stateText)
                        .font(.system(size: 11, weight: .medium))
                    Spacer()
                }

                HStack(spacing: 8) {
                    metric("进程 PID", runtime.pid.map { String($0) } ?? "—")
                    metric("运行次数", runtime.runs.map { String($0) } ?? "—")
                    metric("上次退出码", runtime.lastExitCode.map { String($0) } ?? "—")
                    metric("CPU", runtime.cpuPercent.map { String(format: "%.1f%%", $0) } ?? "—")
                    metric("内存", runtime.memoryMB.map { String(format: "%.0f MB", $0) } ?? "—")
                }
                .padding(.vertical, 2)

                HStack(spacing: 8) {
                    Button("启动") { store.control(.start, for: item) }
                        .buttonStyle(GlassButtonStyle(height: 26))
                        .disabled(runtime.isRunning)

                    Button("重启") { store.control(.restart, for: item) }
                        .buttonStyle(GlassButtonStyle(height: 26))

                    if item.keepAlive {
                        Text("常驻服务停止后会被自动拉起，如需停用请关闭上方开关。")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Button("停止") { store.control(.stop, for: item) }
                            .buttonStyle(GlassButtonStyle(height: 26, tint: .red))
                            .disabled(!runtime.isRunning)
                    }

                    Spacer(minLength: 0)
                }

                if let error = store.lastError {
                    HStack(spacing: 5) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 9))
                        Text(error)
                            .font(.system(size: 10))
                            .lineLimit(2)
                    }
                    .foregroundStyle(.orange)
                }
            } else if store.isRuntimeLoading(item) {
                HStack(spacing: 7) {
                    ProgressView().controlSize(.small)
                    Text("正在读取运行状态…")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            } else {
                HStack(spacing: 10) {
                    hintText("服务当前未加载，可手动加载或等待触发条件满足。")
                    Spacer(minLength: 8)
                    Button("加载") { store.control(.load, for: item) }
                        .buttonStyle(GlassButtonStyle(height: 26))
                }
            }
        }
        .glassCard()
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 9.5))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .monospacedDigit()
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func hintText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: 定时配置

    @ViewBuilder
    private var scheduleCard: some View {
        if let summary = item.scheduleSummary {
            VStack(alignment: .leading, spacing: 8) {
                sectionLabel("定时触发", symbol: "calendar.badge.clock")

                HStack(spacing: 8) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                    Text(summary)
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                }

                Text("由 launchd 在指定时间自动拉起，触发时若服务未运行会重新启动。")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .glassCard()
        }
    }

    private var programCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("程序与参数", symbol: "terminal")
            Text(item.program.isEmpty ? "—" : item.program)
                .font(.system(size: 11, design: .monospaced))
                .textSelection(.enabled)
                .foregroundStyle(.primary.opacity(0.9))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(0.07))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.8)
                        }
                }
        }
        .glassCard()
    }

    private var footprintCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                sectionLabel("配置文件", symbol: "doc.text")
                Spacer()
                Button("复制路径") { copy(item.plistPath) }
                    .buttonStyle(GlassButtonStyle(height: 24))
                Button("在 Finder 中显示") {
                    NSWorkspace.shared.selectFile(
                        item.plistPath,
                        inFileViewerRootedAtPath: (item.plistPath as NSString).deletingLastPathComponent
                    )
                }
                .buttonStyle(GlassButtonStyle(height: 24))
            }

            Text(item.plistPath)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .lineLimit(2)
                .truncationMode(.middle)
        }
        .glassCard()
    }

    private var dangerCard: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.canDelete ? "删除启动项" : "受系统保护")
                    .font(.system(size: 12.5, weight: .semibold))
                Text(item.canDelete
                     ? "会先停用该服务，再删除对应的 plist 文件，操作不可撤销。"
                     : "此项目位于「所有用户」目录，仅支持停用，不支持删除。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            if item.canDelete {
                Button("删除…", action: onDelete)
                    .buttonStyle(GlassButtonStyle(height: 28, tint: .red))
            } else {
                Pill(text: "只读", tint: .secondary)
            }
        }
        .glassCard(tint: .red)
    }

    private func sectionLabel(_ text: String, symbol: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.4)
        }
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

// MARK: - 登录项详情

private struct LoginItemCard: View {
    let item: LoginItem
    let onRemove: () -> Void

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 14) {
                    IconTile(systemName: "person.crop.circle.badge.checkmark", size: 54, tint: .teal)

                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 6) {
                            Text(item.name)
                                .font(.system(size: 18, weight: .semibold))
                            Pill(text: "登录项", tint: .teal)
                        }
                        Text(item.path.isEmpty ? "系统托管的登录项" : (item.path as NSString).lastPathComponent)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 12)

                    HStack(spacing: 5) {
                        StatusDot(color: .teal)
                        Text("登录时打开")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .glassCard(padding: 18)

                VStack(alignment: .leading, spacing: 8) {
                    Text("应用路径")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.4)
                    Text(item.path.isEmpty ? "由系统（登录项框架）托管，未提供可读路径" : item.path)
                        .font(.system(size: 11, design: .monospaced))
                        .textSelection(.enabled)
                        .lineLimit(3)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.primary.opacity(0.07))
                        }
                }
                .glassCard()

                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("从登录项移除")
                            .font(.system(size: 12.5, weight: .semibold))
                        Text("移除后该应用不会再随登录自动打开，可随时在系统设置中重新添加。")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    Button("移除…", action: onRemove)
                        .buttonStyle(GlassButtonStyle(height: 28, tint: .red))
                }
                .glassCard(tint: .red)
            }
            .padding(.horizontal, 22)
            .padding(.top, 44)
            .padding(.bottom, 22)
        }
    }
}
