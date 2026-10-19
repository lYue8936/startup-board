import Foundation

enum LaunchAgentScanner {
    static let userDirectory: String = NSHomeDirectory() + "/Library/LaunchAgents"
    static let sharedDirectory = "/Library/LaunchAgents"

    struct ScanResult {
        var items: [LaunchItem] = []
        var unreadable: [UnreadablePlist] = []
    }

    /// 扫描用户级与所有用户级 LaunchAgents，返回排序后的列表与无法解析的文件
    static func scan() -> ScanResult {
        let disabled = LaunchCtl.disabledLabels()
        let loaded = LaunchCtl.loadedLabels()
        var result = ScanResult()

        for (directory, scope) in [(userDirectory, LaunchItem.Scope.user), (sharedDirectory, LaunchItem.Scope.shared)] {
            let partial = contentsOf(directory: directory, scope: scope, disabled: disabled, loaded: loaded)
            result.items += partial.items
            result.unreadable += partial.unreadable
        }

        // 自定义项排最前，其余按名称排序
        result.items.sort { a, b in
            if a.isCustom != b.isCustom { return a.isCustom }
            return a.displayName.localizedCaseInsensitiveCompare(b.displayName) == .orderedAscending
        }
        return result
    }

    private static func contentsOf(
        directory: String,
        scope: LaunchItem.Scope,
        disabled: Set<String>,
        loaded: Set<String>
    ) -> ScanResult {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: directory),
              let files = try? fileManager.contentsOfDirectory(atPath: directory) else {
            return ScanResult()
        }

        var result = ScanResult()
        for fileName in files.sorted() where fileName.hasSuffix(".plist") {
            let path = directory + "/" + fileName
            let parsed = loadPlist(at: path, scope: scope, disabled: disabled, loaded: loaded)
            if let item = parsed.item {
                result.items.append(item)
            } else {
                result.unreadable.append(
                    UnreadablePlist(path: path, reason: parsed.reason ?? "无法解析该 plist")
                )
            }
        }
        return result
    }

    private static func loadPlist(
        at path: String,
        scope: LaunchItem.Scope,
        disabled: Set<String>,
        loaded: Set<String>
    ) -> (item: LaunchItem?, reason: String?) {
        guard let data = FileManager.default.contents(atPath: path) else {
            return (nil, "文件不可读")
        }
        guard let dict = (try? PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
        )) as? [String: Any] else {
            return (nil, "plist 格式无效")
        }
        guard let label = dict["Label"] as? String, !label.isEmpty else {
            return (nil, "缺少 Label 字段")
        }

        let arguments = (dict["ProgramArguments"] as? [Any])?.compactMap { $0 as? String } ?? []
        let program = (dict["Program"] as? String) ?? arguments.joined(separator: " ")
        let executablePath = (dict["Program"] as? String) ?? arguments.first

        let item = LaunchItem(
            label: label,
            plistPath: path,
            scope: scope,
            displayName: UserAgentWriter.displayName(in: dict) ?? label,
            program: program,
            executablePath: executablePath,
            runAtLoad: dict["RunAtLoad"] as? Bool ?? false,
            keepAlive: dict["KeepAlive"] != nil,
            plistDisabled: dict["Disabled"] as? Bool ?? false,
            launchctlDisabled: disabled.contains(label),
            isLoaded: loaded.contains(label),
            calendarTriggers: calendarTriggers(from: dict["StartCalendarInterval"]),
            intervalSeconds: (dict["StartInterval"] as? NSNumber)?.intValue
        )
        return (item, nil)
    }

    // MARK: - 定时配置解析

    private static func calendarTriggers(from value: Any?) -> [CalendarTrigger] {
        if let array = value as? [[String: Any]] {
            return array.map(makeTrigger)
        }
        if let dict = value as? [String: Any] {
            return [makeTrigger(dict)]
        }
        return []
    }

    private static func makeTrigger(_ dict: [String: Any]) -> CalendarTrigger {
        func intValue(_ key: String) -> Int? {
            (dict[key] as? NSNumber)?.intValue
        }
        return CalendarTrigger(
            month: intValue("Month"),
            day: intValue("Day"),
            weekday: intValue("Weekday"),
            hour: intValue("Hour"),
            minute: intValue("Minute")
        )
    }
}
