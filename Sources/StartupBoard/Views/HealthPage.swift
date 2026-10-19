import SwiftUI
import AppKit

private struct SeverityGroup: Identifiable {
    let severity: HealthSeverity
    let issues: [HealthIssue]

    var id: HealthSeverity { severity }
}

/// 启动项体检：零权限的本地静态检查，给出评分与可操作建议
struct HealthPage: View {
    @EnvironmentObject private var store: ItemStore

    var onOpen: (String) -> Void
    var onDelete: (LaunchItem) -> Void

    private var report: HealthReport { store.health }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 12) {
                summaryCard

                if report.isClean {
                    cleanCard
                } else {
                    ForEach(grouped) { group in
                        sectionLabel(group.severity, count: group.issues.count)
                        ForEach(group.issues) { issue in
                            issueCard(issue)
                        }
                    }
                }

                Text("体检只读取本地的启动项配置与程序路径，不会修改任何项目。")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 2)
            }
            .padding(.horizontal, 22)
            .padding(.top, 44)
            .padding(.bottom, 22)
        }
    }

    // MARK: - 概览

    private var summaryCard: some View {
        HStack(alignment: .center, spacing: 20) {
            scoreRing

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    Text("启动项体检")
                        .font(.system(size: 18, weight: .semibold))
                    Pill(text: report.statusText, tint: scoreColor)
                }

                Text("已扫描 \(store.agents.count) 个后台项、\(store.loginItems.count) 个登录项")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    counter("\(report.criticalCount)", label: "需处理", color: .red)
                    counter("\(report.warningCount)", label: "建议关注", color: .orange)
                    counter("\(report.issues.count - report.criticalCount - report.warningCount)", label: "提示", color: .blue)
                }
                .padding(.top, 2)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 8) {
                Button {
                    store.refresh()
                } label: {
                    Label("重新扫描", systemImage: "arrow.clockwise")
                }
                .buttonStyle(GradientButtonStyle(height: 29))

                Text(lastScanText)
                    .font(.system(size: 9.5))
                    .foregroundStyle(.tertiary)
            }
        }
        .glassCard(padding: 20)
    }

    private var scoreRing: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: 9)
            Circle()
                .trim(from: 0, to: CGFloat(report.score) / 100)
                .stroke(
                    scoreColor,
                    style: StrokeStyle(lineWidth: 9, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.35), value: report.score)

            VStack(spacing: -1) {
                Text("\(report.score)")
                    .font(.system(size: 29, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("分")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 100, height: 100)
    }

    private var scoreColor: Color {
        if report.score >= 85 { return .green }
        if report.score >= 60 { return .orange }
        return .red
    }

    private var lastScanText: String {
        guard let date = store.lastScan else { return "尚未扫描" }
        if Date().timeIntervalSince(date) < 60 { return "上次扫描：刚刚" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "上次扫描：" + formatter.string(from: date)
    }

    private func counter(_ value: String, label: String, color: Color) -> some View {
        HStack(spacing: 5) {
            StatusDot(color: color)
            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }

    private var cleanCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 26))
                .foregroundStyle(.green)
            Text("没有发现异常")
                .font(.system(size: 14, weight: .semibold))
            Text("所有启动项的可执行文件都存在，也没有标签冲突或损坏的配置文件。")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .glassCard()
    }

    // MARK: - 问题列表

    private var grouped: [SeverityGroup] {
        [HealthSeverity.critical, .warning, .info].compactMap { severity in
            let list = report.issues.filter { $0.severity == severity }
            return list.isEmpty ? nil : SeverityGroup(severity: severity, issues: list)
        }
    }

    private func sectionLabel(_ severity: HealthSeverity, count: Int) -> some View {
        HStack(spacing: 6) {
            Text(severity.title)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(tint(for: severity))
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
        .padding(.top, 4)
    }

    private func issueCard(_ issue: HealthIssue) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol(for: issue.severity))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint(for: issue.severity))
                .frame(width: 26, height: 26)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(tint(for: issue.severity).opacity(0.12))
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(issue.title)
                    .font(.system(size: 12.5, weight: .semibold))
                Text(issue.detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }

            Spacer(minLength: 8)

            if let fix = issue.fix {
                Button(actionTitle(for: fix)) { apply(fix) }
                    .buttonStyle(GlassButtonStyle(
                        height: 26,
                        tint: isDestructive(fix) ? .red : .primary
                    ))
            }
        }
        .glassCard(padding: 13)
    }

    // MARK: - 操作

    private func apply(_ fix: HealthFix) {
        switch fix {
        case .locate(let id):
            onOpen(id)
        case .delete(let item):
            onDelete(item)
        case .enable(let item):
            store.setAgent(item, enabled: true)
        case .disable(let item):
            store.setAgent(item, enabled: false)
        case .reveal(let path):
            NSWorkspace.shared.selectFile(
                path,
                inFileViewerRootedAtPath: (path as NSString).deletingLastPathComponent
            )
        }
    }

    private func actionTitle(for fix: HealthFix) -> String {
        switch fix {
        case .locate: return "查看"
        case .delete: return "删除…"
        case .enable: return "重新启用"
        case .disable: return "停用…"
        case .reveal: return "显示文件"
        }
    }

    private func isDestructive(_ fix: HealthFix) -> Bool {
        switch fix {
        case .delete, .disable: return true
        default: return false
        }
    }

    private func tint(for severity: HealthSeverity) -> Color {
        switch severity {
        case .critical: return .red
        case .warning: return .orange
        case .info: return .blue
        }
    }

    private func symbol(for severity: HealthSeverity) -> String {
        switch severity {
        case .critical: return "exclamationmark.octagon.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }
}
