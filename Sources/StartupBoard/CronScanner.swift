import Foundation

/// 读取当前用户的 crontab（只读展示，避免误改系统或第三方任务）
enum CronScanner {
    static func jobs() -> [CronJob] {
        let result = Shell.run("/usr/bin/crontab", ["-l"])
        guard result.code == 0 else { return [] }

        var jobs: [CronJob] = []
        for rawLine in result.stdout.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }

            // 跳过 NAME=value 形式的环境变量
            if line.contains("=") && !line.hasPrefix("@") && !line.hasPrefix("*") {
                continue
            }

            if let job = parseSpecial(line) ?? parseStandard(line) {
                jobs.append(job)
            }
        }
        return jobs
    }

    // MARK: - 解析

    /// @reboot / @daily 等快捷写法
    private static func parseSpecial(_ line: String) -> CronJob? {
        guard line.hasPrefix("@") else { return nil }
        let parts = line.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard parts.count == 2 else { return nil }
        let keyword = String(parts[0])
        let command = String(parts[1]).trimmingCharacters(in: .whitespaces)
        guard !command.isEmpty else { return nil }

        let schedule: String
        switch keyword {
        case "@reboot": schedule = "登录时"
        case "@yearly", "@annually": schedule = "每年一次"
        case "@monthly": schedule = "每月一次"
        case "@weekly": schedule = "每周一次"
        case "@daily", "@midnight": schedule = "每天一次"
        case "@hourly": schedule = "每小时一次"
        default: return nil
        }

        return CronJob(id: "cron:" + line, schedule: schedule, command: command)
    }

    /// 标准 5 段表达式
    private static func parseStandard(_ line: String) -> CronJob? {
        var fields: [String] = []
        var remainder = Substring(line)

        while fields.count < 5 {
            remainder = remainder.drop(while: { $0 == " " || $0 == "\t" })
            guard let end = remainder.firstIndex(where: { $0 == " " || $0 == "\t" }) else { return nil }
            fields.append(String(remainder[remainder.startIndex..<end]))
            remainder = remainder[end...]
        }

        let command = remainder.trimmingCharacters(in: .whitespaces)
        guard !command.isEmpty else { return nil }

        let expression = fields.joined(separator: " ")
        return CronJob(id: "cron:" + line, schedule: expression, command: command)
    }
}
