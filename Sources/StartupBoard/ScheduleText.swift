import Foundation

/// 把 launchd 的日历 / 间隔配置以及 cron 表达式翻译成中文描述
enum ScheduleText {

    // MARK: - 日历触发

    static func calendar(_ trigger: CalendarTrigger) -> String {
        datePrefix(trigger) + timeSuffix(trigger)
    }

    private static func datePrefix(_ trigger: CalendarTrigger) -> String {
        if let weekday = trigger.weekday {
            return "每" + weekdayName(weekday)
        }
        if let month = trigger.month, let day = trigger.day {
            return "每年 \(month) 月 \(day) 日"
        }
        if let day = trigger.day {
            return "每月 \(day) 日"
        }
        if let month = trigger.month {
            return "每年 \(month) 月"
        }
        return "每天"
    }

    private static func timeSuffix(_ trigger: CalendarTrigger) -> String {
        switch (trigger.hour, trigger.minute) {
        case let (hour?, minute?):
            return String(format: " %02d:%02d", hour, minute)
        case let (hour?, nil):
            return " \(hour) 点的每分钟"
        case let (nil, minute?):
            return "每小时第 \(minute) 分"
        case (nil, nil):
            return " 每分钟"
        }
    }

    /// launchd 中 Weekday：0 与 7 为周日，1 为周一
    static func weekdayName(_ weekday: Int) -> String {
        switch weekday {
        case 0, 7: return "周日"
        case 1: return "周一"
        case 2: return "周二"
        case 3: return "周三"
        case 4: return "周四"
        case 5: return "周五"
        case 6: return "周六"
        default: return "周\(weekday)"
        }
    }

    // MARK: - 间隔触发

    static func interval(_ seconds: Int) -> String {
        guard seconds > 0 else { return "间隔未设置" }
        if seconds % 3600 == 0 {
            return "每 \(seconds / 3600) 小时"
        }
        if seconds % 60 == 0 {
            return "每 \(seconds / 60) 分钟"
        }
        return "每 \(seconds) 秒"
    }

    // MARK: - cron 表达式（5 段）

    static func cron(_ expression: String) -> String {
        let fields = expression.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
        guard fields.count == 5 else { return expression }

        let minute = fields[0], hour = fields[1], day = fields[2], month = fields[3], weekday = fields[4]
        let dateWildcard = day == "*" && month == "*" && weekday == "*"

        if minute == "*", hour == "*", dateWildcard {
            return "每分钟"
        }

        // 每 N 分钟
        if minutesStep(minute) != nil, hour == "*", dateWildcard {
            return "每 \(minutesStep(minute)!) 分钟"
        }

        // 每小时
        if hour == "*", dateWildcard, let minuteValue = Int(minute) {
            return "每小时第 \(minuteValue) 分"
        }

        // 固定时分
        if let minuteValue = Int(minute), let hourValue = Int(hour) {
            let time = String(format: "%02d:%02d", hourValue, minuteValue)
            let prefix = datePrefix(day: day, month: month, weekday: weekday)
            return prefix.isEmpty ? "每天 \(time)" : "\(prefix) \(time)"
        }

        return "\(expression)"
    }

    private static func minutesStep(_ field: String) -> Int? {
        guard field.hasPrefix("*/"), let step = Int(field.dropFirst(2)), step > 0 else { return nil }
        return step
    }

    private static func datePrefix(day: String, month: String, weekday: String) -> String {
        if weekday != "*" {
            if let range = weekdayRange(weekday) {
                return range
            }
            if let value = Int(weekday), (0...7).contains(value) {
                return "每" + weekdayName(value)
            }
        }
        if day != "*", month != "*" {
            return "每年 \(month) 月 \(day) 日"
        }
        if day != "*" {
            return "每月 \(day) 日"
        }
        return ""
    }

    /// 形如 1-5 的工作日区间
    private static func weekdayRange(_ field: String) -> String? {
        let parts = field.split(separator: "-")
        guard parts.count == 2,
              let start = Int(parts[0]),
              let end = Int(parts[1]) else { return nil }
        if start == 1 && end == 5 { return "工作日" }
        guard (0...7).contains(start), (0...7).contains(end) else { return nil }
        return "每" + weekdayName(start) + "至" + weekdayName(end)
    }

    // MARK: - 触发器编辑辅助

    static func hourMinuteText(hour: Int, minute: Int) -> String {
        String(format: "%02d:%02d", hour, minute)
    }
}
