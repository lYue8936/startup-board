import Foundation

/// 通过 AppleScript「系统事件」桥接经典登录项（登录时打开的应用）
enum LoginItemsBridge {
    struct Result {
        let items: [LoginItem]
        let error: String?
    }

    // MARK: - AppleScript 执行

    private static func runAppleScript(_ source: String) -> (output: String, error: String?) {
        let output = Shell.run("/usr/bin/osascript", ["-e", source])
        if output.code == 0 { return (output.stdout, nil) }
        return ("", output.stderr.isEmpty ? "执行 AppleScript 失败" : output.stderr)
    }

    private static func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    // MARK: - 列表

    static func list() -> Result {
        let script = """
        tell application "System Events"
        set output to ""
        repeat with anItem in (get every login item)
        set output to output & (name of anItem) & tab & (path of anItem) & linefeed
        end repeat
        return output
        end tell
        """
        let (output, error) = runAppleScript(script)
        guard error == nil else { return Result(items: [], error: error) }

        var items: [LoginItem] = []
        for line in output.split(whereSeparator: { $0 == "\n" }) where !line.isEmpty {
            let parts = line.split(separator: "\t")
            guard let name = parts.first, !name.isEmpty else { continue }
            // 部分登录项（SMAppService 托管的）没有可读路径，AppleScript 会返回 "missing value"
            var path = parts.count > 1 ? String(parts[1]) : ""
            if path == "missing value" { path = "" }
            items.append(LoginItem(name: String(name), path: path))
        }
        return Result(items: items, error: nil)
    }

    // MARK: - 移除

    static func remove(name: String) -> String? {
        let script = "tell application \"System Events\" to delete login item \"\(escape(name))\""
        let (_, error) = runAppleScript(script)
        return error
    }
}
