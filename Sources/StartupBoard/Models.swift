import Foundation

// MARK: - 登录时打开的应用（经典登录项）

struct LoginItem: Identifiable, Hashable {
    let name: String
    let path: String
    var id: String { name + "|" + path }
}

// MARK: - 定时触发

/// 对应 plist 中的 StartCalendarInterval 条目
struct CalendarTrigger: Hashable {
    var month: Int?
    var day: Int?
    var weekday: Int?
    var hour: Int?
    var minute: Int?

    var text: String { ScheduleText.calendar(self) }
}

// MARK: - LaunchAgent 后台启动项

struct LaunchItem: Identifiable, Hashable {
    enum Scope: String, Hashable {
        case user = "当前用户"
        case shared = "所有用户"
    }

    let label: String
    let plistPath: String
    let scope: Scope
    let displayName: String
    let program: String
    /// Program 或 ProgramArguments 的第一项，用于校验可执行文件是否存在
    let executablePath: String?
    let runAtLoad: Bool
    let keepAlive: Bool
    let plistDisabled: Bool
    let launchctlDisabled: Bool
    let isLoaded: Bool
    let calendarTriggers: [CalendarTrigger]
    let intervalSeconds: Int?

    var id: String { label }
    var isApple: Bool { label.hasPrefix("com.apple.") }
    var isCustom: Bool { UserAgentWriter.isManagedLabel(label) }
    var canDelete: Bool { scope == .user }
    var isEffectivelyDisabled: Bool { plistDisabled || launchctlDisabled }

    var isScheduled: Bool {
        !calendarTriggers.isEmpty || intervalSeconds != nil
    }

    /// 人类可读的定时描述；无定时任务时返回 nil
    var scheduleSummary: String? {
        if !calendarTriggers.isEmpty {
            return calendarTriggers.map(\.text).joined(separator: "、")
        }
        if let seconds = intervalSeconds {
            return ScheduleText.interval(seconds)
        }
        return nil
    }

    /// 判定触发器类型，用于列表分类
    var triggerKind: TriggerKind {
        if isScheduled { return .scheduled }
        if runAtLoad { return .login }
        if keepAlive { return .daemon }
        return .onDemand
    }
}

enum TriggerKind {
    case login      // 登录时启动
    case scheduled  // 定时 / 间隔
    case daemon     // 常驻守护
    case onDemand   // 按需加载

    var title: String {
        switch self {
        case .login: return "登录时启动"
        case .scheduled: return "定时触发"
        case .daemon: return "常驻运行"
        case .onDemand: return "按需加载"
        }
    }
}

// MARK: - 无法解析的 plist

struct UnreadablePlist: Identifiable, Hashable {
    let path: String
    let reason: String
    var id: String { path }
}

// MARK: - 服务运行状态

struct ServiceRuntime: Hashable {
    var pid: Int?
    var runs: Int?
    var lastExitCode: Int?
    var state: String?
    var cpuPercent: Double?
    var memoryMB: Double?

    var isRunning: Bool { (pid ?? 0) > 0 }

    var stateText: String {
        if isRunning { return "运行中" }
        if let state, state == "not running" { return "已加载 · 空闲" }
        return "未运行"
    }
}

// MARK: - 用户 crontab 中的定时任务（只读）

struct CronJob: Identifiable, Hashable {
    let id: String
    let schedule: String
    let command: String

    var summary: String { ScheduleText.cron(schedule) }
}

// MARK: - 启动项体检

enum HealthSeverity: Int, Comparable {
    case critical = 0
    case warning = 1
    case info = 2

    static func < (lhs: HealthSeverity, rhs: HealthSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var title: String {
        switch self {
        case .critical: return "需要处理"
        case .warning: return "建议关注"
        case .info: return "提示"
        }
    }

    var weight: Int {
        switch self {
        case .critical: return 14
        case .warning: return 7
        case .info: return 2
        }
    }
}

enum HealthFix {
    case locate(String)
    case delete(LaunchItem)
    case enable(LaunchItem)
    case disable(LaunchItem)
    case reveal(String)
}

struct HealthIssue: Identifiable {
    let id: String
    let severity: HealthSeverity
    let title: String
    let detail: String
    let fix: HealthFix?
}

struct HealthReport {
    var score: Int
    var issues: [HealthIssue]

    var criticalCount: Int { issues.filter { $0.severity == .critical }.count }
    var warningCount: Int { issues.filter { $0.severity == .warning }.count }
    var isClean: Bool { issues.isEmpty }

    var statusText: String {
        if isClean { return "一切正常" }
        if criticalCount > 0 { return "需要处理" }
        if warningCount > 0 { return "建议关注" }
        return "状态良好"
    }
}

// MARK: - 自定义启动项的触发方式

enum CustomTrigger {
    case login(delaySeconds: Int)
    case daily(hour: Int, minute: Int)
    case weekly(weekday: Int, hour: Int, minute: Int)
    case interval(seconds: Int)
}
