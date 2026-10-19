import Foundation

/// 本地静态体检：只读文件系统，不执行、不修改任何启动项
enum HealthCheck {
    /// 启用的第三方后台项超过该数量时给出提示
    private static let crowdedThreshold = 18

    static func evaluate(items: [LaunchItem], unreadable: [UnreadablePlist]) -> HealthReport {
        var issues: [HealthIssue] = []

        // 1. 无法解析的配置文件
        for file in unreadable {
            issues.append(
                HealthIssue(
                    id: "unreadable:" + file.path,
                    severity: .warning,
                    title: "配置文件无法解析",
                    detail: "\(file.path)\n\(file.reason)",
                    fix: .reveal(file.path)
                )
            )
        }

        // 2. 缺少可执行文件
        for item in items {
            guard let path = item.executablePath, !path.isEmpty, path.hasPrefix("/") else {
                if item.executablePath == nil || item.executablePath?.isEmpty == true {
                    issues.append(
                        HealthIssue(
                            id: "noprogram:" + item.id,
                            severity: .warning,
                            title: "未声明启动程序",
                            detail: "「\(item.displayName)」既没有 Program 也没有 ProgramArguments，可能无法被正常拉起。",
                            fix: .locate(item.id)
                        )
                    )
                }
                continue
            }

            guard !FileManager.default.fileExists(atPath: path) else { continue }

            let severity: HealthSeverity = item.isApple ? .info : .critical
            issues.append(
                HealthIssue(
                    id: "missing:" + item.id,
                    severity: severity,
                    title: "启动程序已不存在",
                    detail: "「\(item.displayName)」指向的 \(path) 已被删除或移动，每次触发都会失败。",
                    fix: item.canDelete ? .delete(item) : .reveal(item.plistPath)
                )
            )
        }

        // 3. 标签重复（用户级与系统级同名会互相覆盖启停状态）
        var grouped: [String: [LaunchItem]] = [:]
        for item in items {
            grouped[item.label, default: []].append(item)
        }
        for (label, group) in grouped.sorted(by: { $0.key < $1.key }) {
            guard group.count > 1,
                  Set(group.map(\.scope)).count > 1 else { continue }
            issues.append(
                HealthIssue(
                    id: "duplicate:" + label,
                    severity: .warning,
                    title: "启动项标签重复",
                    detail: "「\(label)」同时存在于当前用户与所有用户目录，两边的启停状态可能相互覆盖。",
                    fix: .locate(group[0].id)
                )
            )
        }

        // 4. 第三方后台项过多
        let activeThirdParty = items.filter { !$0.isApple && !$0.isEffectivelyDisabled }
        if activeThirdParty.count > crowdedThreshold {
            issues.append(
                HealthIssue(
                    id: "crowded",
                    severity: .info,
                    title: "启用的后台项偏多",
                    detail: "当前已启用 \(activeThirdParty.count) 个第三方后台项，可能拖慢登录速度并占用内存。",
                    fix: nil
                )
            )
        }

        // 5. 程序位于临时目录，重启后可能失效
        for item in items where !item.isApple {
            guard let path = item.executablePath else { continue }
            if path.hasPrefix("/tmp/") || path.hasPrefix("/private/tmp/") || path.hasPrefix("/Volumes/") {
                issues.append(
                    HealthIssue(
                        id: "volatile:" + item.id,
                        severity: .warning,
                        title: "程序位于临时位置",
                        detail: "「\(item.displayName)」的可执行文件位于 \(path)，重启或卸载磁盘后会失效。",
                        fix: .locate(item.id)
                    )
                )
            }
        }

        issues.sort {
            if $0.severity != $1.severity { return $0.severity < $1.severity }
            return $0.title < $1.title
        }

        let deduction = issues.reduce(0) { $0 + $1.severity.weight }
        return HealthReport(score: max(0, 100 - deduction), issues: issues)
    }
}
