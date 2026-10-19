import Foundation

/// 将自定义启动项写入 ~/Library/LaunchAgents
enum UserAgentWriter {
    static let labelPrefix = "app.startupboard.custom."
    /// 兼容历史版本（LaunchDeck / 启动项管理）生成的项目：仅识别与管理，不改写旧文件
    static let legacyLabelPrefixes = [
        "app.launchdeck.custom.",
        "local.startup-manager.custom.",
    ]
    static let displayNameKey = "StartupBoardDisplayName"
    static let legacyDisplayNameKeys = [
        "LaunchDeckDisplayName",
        "StartupManagerDisplayName",
    ]

    /// 是否为本应用（含历史版本）创建的自定义启动项
    static func isManagedLabel(_ label: String) -> Bool {
        if label.hasPrefix(labelPrefix) { return true }
        return legacyLabelPrefixes.contains { label.hasPrefix($0) }
    }

    /// 读取 plist 中的显示名称（兼容旧键名）
    static func displayName(in dict: [String: Any]) -> String? {
        if let value = dict[displayNameKey] as? String { return value }
        for key in legacyDisplayNameKeys {
            if let value = dict[key] as? String { return value }
        }
        return nil
    }

    enum WriteError: LocalizedError {
        case invalidName
        case invalidCommand

        var errorDescription: String? {
            switch self {
            case .invalidName: return "请填写启动项名称"
            case .invalidCommand: return "请填写要启动的命令或脚本路径"
            }
        }
    }

    /// 添加自定义启动项，返回生成的 LaunchAgent 标签
    static func add(
        displayName: String,
        command: String,
        arguments: [String],
        trigger: CustomTrigger
    ) throws -> String {
        let name = displayName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { throw WriteError.invalidName }
        let commandPath = command.trimmingCharacters(in: .whitespaces)
        guard !commandPath.isEmpty else { throw WriteError.invalidCommand }

        // 生成标签：名称 slug + 短 UUID，避免重名
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-")
        var slug = ""
        for scalar in name.lowercased().unicodeScalars where allowed.contains(scalar) {
            slug.unicodeScalars.append(scalar)
        }
        if slug.isEmpty { slug = "item" }
        let label = labelPrefix + slug + "-" + UUID().uuidString.prefix(8).lowercased()

        var plist: [String: Any] = [
            "Label": label,
            displayNameKey: name,
        ]

        switch trigger {
        case .login(let delaySeconds):
            if delaySeconds > 0 {
                // 延迟启动：通过 sh -c "sleep N; exec ..." 实现
                let quoted = ([commandPath] + arguments).map(shellQuote).joined(separator: " ")
                plist["ProgramArguments"] = ["/bin/sh", "-c", "sleep \(delaySeconds)\nexec \(quoted)"]
            } else {
                // 直接以参数数组形式传递，路径含空格也无需转义
                plist["ProgramArguments"] = [commandPath] + arguments
            }
            plist["RunAtLoad"] = true

        case .daily(let hour, let minute):
            plist["ProgramArguments"] = [commandPath] + arguments
            plist["StartCalendarInterval"] = ["Hour": hour, "Minute": minute]

        case .weekly(let weekday, let hour, let minute):
            plist["ProgramArguments"] = [commandPath] + arguments
            plist["StartCalendarInterval"] = [
                "Weekday": weekday,
                "Hour": hour,
                "Minute": minute,
            ]

        case .interval(let seconds):
            plist["ProgramArguments"] = [commandPath] + arguments
            plist["StartInterval"] = max(60, seconds)
        }

        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        let directory = URL(fileURLWithPath: LaunchAgentScanner.userDirectory, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent(label + ".plist")
        try data.write(to: fileURL)
        return label
    }

    /// 拼接进 sh -c 时的单引号转义
    private static func shellQuote(_ text: String) -> String {
        "'" + text.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
