import SwiftUI
import AppKit

/// 定时任务面板：聚合 LaunchAgent 的日历 / 间隔触发，以及只读的用户 crontab
struct SchedulePage: View {
    @EnvironmentObject private var store: ItemStore

    var onOpen: (String) -> Void
    var onToggle: (LaunchItem, Bool) -> Void

    private var scheduledAgents: [LaunchItem] {
        store.agents
            .filter(\.isScheduled)
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 12) {
                header

                if scheduledAgents.isEmpty && store.cronJobs.isEmpty {
                    emptyState
                } else {
                    if !scheduledAgents.isEmpty {
                        sectionLabel("LaunchAgent 定时项", count: scheduledAgents.count)
                        ForEach(scheduledAgents) { item in
                            agentCard(item)
                        }
                    }

                    if !store.cronJobs.isEmpty {
                        sectionLabel("用户 crontab（只读）", count: store.cronJobs.count)
                        ForEach(store.cronJobs) { job in
                            cronCard(job)
                        }
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 44)
            .padding(.bottom, 22)
        }
    }

    // MARK: - 头部

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            IconTile(systemName: "calendar.badge.clock", size: 54, tint: .orange)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text("定时任务")
                        .font(.system(size: 18, weight: .semibold))
                    Pill(text: "\(scheduledAgents.count + store.cronJobs.count) 项", tint: .orange)
                }
                Text("按日 / 周 / 间隔自动执行的任务，含 launchd 与 crontab")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Button {
                store.refresh()
            } label: {
                Label("刷新", systemImage: "arrow.clockwise")
            }
            .buttonStyle(GlassButtonStyle(height: 28))
        }
        .glassCard(padding: 18)
    }

    // MARK: - 行

    private func agentCard(_ item: LaunchItem) -> some View {
        HStack(spacing: 12) {
            IconTile(systemName: "clock.fill", size: 34, tint: item.isEffectivelyDisabled ? .secondary : .orange)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.displayName)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    if item.isApple { Pill(text: "系统", tint: .orange) }
                    if item.isEffectivelyDisabled { Pill(text: "已停用", tint: .secondary) }
                }

                Text(item.scheduleSummary ?? "")
                    .font(.system(size: 11))
                    .foregroundStyle(item.isEffectivelyDisabled ? Color.secondary : Color.orange)

                Text(item.label)
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)

            Button("详情") { onOpen(item.id) }
                .buttonStyle(GlassButtonStyle(height: 26))

            Toggle("", isOn: Binding(
                get: { !item.isEffectivelyDisabled },
                set: { onToggle(item, $0) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.mini)
        }
        .glassCard(padding: 13)
    }

    private func cronCard(_ job: CronJob) -> some View {
        HStack(alignment: .top, spacing: 12) {
            IconTile(systemName: "terminal", size: 34, tint: .teal)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(job.summary)
                        .font(.system(size: 13, weight: .medium))
                    Pill(text: "crontab", tint: .teal)
                }

                Text(job.command)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)

            Button("复制") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(job.command, forType: .string)
            }
            .buttonStyle(GlassButtonStyle(height: 26))
        }
        .glassCard(padding: 13)
    }

    // MARK: - 其它

    private func sectionLabel(_ title: String, count: Int) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 10.5, weight: .semibold))
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
        .padding(.top, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(.secondary)
            Text("还没有定时任务")
                .font(.system(size: 13, weight: .semibold))
            Text("点击左上角「+」添加定时启动项，或在使用 crontab 后重新扫描")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
