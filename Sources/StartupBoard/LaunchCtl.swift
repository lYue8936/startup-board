import Foundation

enum LaunchCtl {
    static var guiDomain: String { "gui/\(getuid())" }

    // MARK: - 状态查询

    /// 当前用户会话中被禁用的服务标签
    /// 不同 macOS 版本的输出格式不同：`=> true` / `=> disabled`
    static func disabledLabels() -> Set<String> {
        let result = Shell.run("/bin/launchctl", ["print-disabled", guiDomain])
        guard let regex = try? NSRegularExpression(
            pattern: "\"([^\"]+)\"\\s*=>\\s*(?:true|disabled)"
        ) else { return [] }
        let range = NSRange(result.stdout.startIndex..., in: result.stdout)
        var labels = Set<String>()
        for match in regex.matches(in: result.stdout, options: [], range: range) {
            if let r = Range(match.range(at: 1), in: result.stdout) {
                labels.insert(String(result.stdout[r]))
            }
        }
        return labels
    }

    /// 当前用户会话中已加载（bootstrap）的服务标签
    /// 使用 `launchctl list` 的表格输出，格式比 `print` 稳定
    static func loadedLabels() -> Set<String> {
        let result = Shell.run("/bin/launchctl", ["list"])
        guard result.code == 0 else { return [] }

        var labels = Set<String>()
        for line in result.stdout.split(separator: "\n") {
            let parts = line.split(whereSeparator: { $0 == "\t" || $0 == " " })
            guard parts.count >= 3, parts[0] != "PID", let label = parts.last else { continue }
            labels.insert(String(label))
        }
        return labels
    }

    // MARK: - 运行时信息

    /// 读取单个服务的运行时状态；未加载时返回 nil
    static func runtime(label: String) -> ServiceRuntime? {
        let result = Shell.run("/bin/launchctl", ["print", "\(guiDomain)/\(label)"])
        guard result.code == 0 else { return nil }
        return parseRuntime(result.stdout)
    }

    private static func parseRuntime(_ text: String) -> ServiceRuntime {
        var runtime = ServiceRuntime()

        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("pid = ") {
                let value = Int(line.dropFirst("pid = ".count).trimmingCharacters(in: .whitespaces)) ?? 0
                runtime.pid = value > 0 ? value : nil
            } else if line.hasPrefix("runs = ") {
                runtime.runs = Int(line.dropFirst("runs = ".count).trimmingCharacters(in: .whitespaces))
            } else if line.hasPrefix("last exit code = ") {
                runtime.lastExitCode = Int(line.dropFirst("last exit code = ".count).trimmingCharacters(in: .whitespaces))
            } else if line.hasPrefix("state = ") {
                runtime.state = line.dropFirst("state = ".count).trimmingCharacters(in: .whitespaces)
            }
        }

        if let pid = runtime.pid {
            let sample = Shell.run("/bin/ps", ["-o", "pcpu=,rss=", "-p", "\(pid)"])
            let parts = sample.stdout.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\n" })
            if parts.count >= 2 {
                runtime.cpuPercent = Double(parts[0])
                if let rssKB = Double(parts[1]) {
                    runtime.memoryMB = rssKB / 1024
                }
            }
        }

        return runtime
    }

    // MARK: - 启用 / 停用

    static func enable(label: String, plistPath: String) {
        Shell.run("/bin/launchctl", ["enable", "\(guiDomain)/\(label)"])
        // 已加载时 bootstrap 会失败，属预期，可忽略
        Shell.run("/bin/launchctl", ["bootstrap", guiDomain, plistPath])
    }

    static func disable(label: String, plistPath: String) {
        Shell.run("/bin/launchctl", ["disable", "\(guiDomain)/\(label)"])
        // 未加载时 bootout 会失败，属预期，可忽略
        Shell.run("/bin/launchctl", ["bootout", "\(guiDomain)/\(label)"])
    }

    // MARK: - 运行控制

    /// 手动加载一个尚未 bootstrap 的服务
    static func bootstrap(label: String, plistPath: String) -> String? {
        _ = Shell.run("/bin/launchctl", ["enable", "\(guiDomain)/\(label)"])
        let result = Shell.run("/bin/launchctl", ["bootstrap", guiDomain, plistPath])
        guard result.code != 0 else { return nil }
        let message = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        return message.isEmpty ? "加载失败（退出码 \(result.code)）" : message
    }

    /// 立即启动服务；已运行时会失败（属预期）
    static func start(label: String) -> String? {
        run(["kickstart", "\(guiDomain)/\(label)"])
    }

    /// 重启服务：先终止当前实例再重新拉起
    static func restart(label: String) -> String? {
        run(["kickstart", "-k", "\(guiDomain)/\(label)"])
    }

    /// 向服务发送终止信号。KeepAlive 的服务会被 launchd 自动拉起。
    static func stop(label: String) -> String? {
        run(["kill", "SIGTERM", "\(guiDomain)/\(label)"])
    }

    private static func run(_ arguments: [String]) -> String? {
        let result = Shell.run("/bin/launchctl", arguments)
        guard result.code != 0 else { return nil }
        let message = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        return message.isEmpty ? "launchctl 执行失败（退出码 \(result.code)）" : message
    }
}
