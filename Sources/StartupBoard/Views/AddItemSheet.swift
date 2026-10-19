import SwiftUI
import AppKit

struct AddItemSheet: View {
    @EnvironmentObject private var store: ItemStore
    @Environment(\.dismiss) private var dismiss

    private enum TriggerMode: String, CaseIterable, Identifiable {
        case login = "登录时"
        case daily = "每天"
        case weekly = "每周"
        case interval = "间隔"

        var id: String { rawValue }
    }

    @State private var name = ""
    @State private var command = ""
    @State private var arguments = ""
    @State private var mode: TriggerMode = .login
    @State private var delay = 0.0
    @State private var hour = 9
    @State private var minute = 0
    @State private var weekday = 1
    @State private var intervalMinutes = 30.0
    @State private var errorText: String?

    private var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !command.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            field(
                title: "名称",
                placeholder: "显示用名称，如：我的备份脚本",
                symbol: "tag",
                text: $name
            )

            commandField

            field(
                title: "参数",
                placeholder: "可选，多个参数用空格分隔",
                symbol: "text.alignleft",
                text: $arguments
            )

            triggerCard

            footer
        }
        .padding(22)
        .frame(width: 520)
        .background {
            VisualEffectView(material: .hudWindow, blending: .withinWindow)
                .ignoresSafeArea()
        }
        .alert(
            "添加失败",
            isPresented: Binding(
                get: { errorText != nil },
                set: { if !$0 { errorText = nil } }
            )
        ) {
            Button("好", role: .cancel) {}
        } message: {
            Text(errorText ?? "")
        }
    }

    // MARK: - 组件

    private var header: some View {
        HStack(spacing: 12) {
            IconTile(systemName: "plus.circle.fill", size: 40, tint: Theme.brandStart)

            VStack(alignment: .leading, spacing: 2) {
                Text("添加自定义启动项")
                    .font(.system(size: 16, weight: .semibold))
                Text(triggerSummary)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.bottom, 2)
    }

    private var triggerSummary: String {
        switch mode {
        case .login:
            return delay <= 0
                ? "登录 macOS 时立即执行，写入 ~/Library/LaunchAgents"
                : "登录后等待 \(Int(delay)) 秒执行，写入 ~/Library/LaunchAgents"
        case .daily:
            return "每天 \(ScheduleText.hourMinuteText(hour: hour, minute: minute)) 自动执行"
        case .weekly:
            return "每\(ScheduleText.weekdayName(weekday)) \(ScheduleText.hourMinuteText(hour: hour, minute: minute)) 自动执行"
        case .interval:
            return "每 \(Int(intervalMinutes)) 分钟自动执行一次"
        }
    }

    private func field(
        title: String,
        placeholder: String,
        symbol: String,
        text: Binding<String>
    ) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.brandStart)
                .frame(width: 24, height: 24)
                .background {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Theme.brandStart.opacity(0.12))
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.4)
                TextField(placeholder, text: text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
            }
        }
        .glassCard(padding: 11)
    }

    private var commandField: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "app.badge.checkmark")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.brandStart)
                .frame(width: 24, height: 24)
                .background {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Theme.brandStart.opacity(0.12))
                }

            VStack(alignment: .leading, spacing: 2) {
                Text("命令或应用")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.4)
                TextField("完整路径，如 /Applications/App.app", text: $command)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
            }

            Button("浏览…") { chooseCommand() }
                .buttonStyle(GlassButtonStyle(height: 24))
        }
        .glassCard(padding: 11)
    }

    // MARK: - 触发方式

    private var triggerCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("触发方式")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.4)

            Picker("", selection: $mode) {
                ForEach(TriggerMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Divider().opacity(0.25)

            switch mode {
            case .login:
                delayRow
            case .daily:
                timeRow
            case .weekly:
                VStack(alignment: .leading, spacing: 10) {
                    weekdayRow
                    timeRow
                }
            case .interval:
                intervalRow
            }
        }
        .glassCard(padding: 12)
    }

    private var delayRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("延迟启动")
                    .font(.system(size: 11, weight: .medium))
                Spacer()
                Text(delay <= 0 ? "立即启动" : "\(Int(delay)) 秒后启动")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(delay <= 0 ? Color.secondary : Theme.brandStart)
                    .monospacedDigit()
            }

            Slider(value: $delay, in: 0...300, step: 5)
                .tint(Theme.brandStart)

            Text("等待系统登录完成后再启动，适合较重的后台程序。")
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
        }
    }

    private var timeRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.brandStart)
            Text("执行时间")
                .font(.system(size: 11, weight: .medium))

            Spacer()

            Picker("", selection: $hour) {
                ForEach(0..<24, id: \.self) { value in
                    Text(String(format: "%02d", value)).tag(value)
                }
            }
            .labelsHidden()
            .frame(width: 62)

            Text(":")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            Picker("", selection: $minute) {
                ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { value in
                    Text(String(format: "%02d", value)).tag(value)
                }
            }
            .labelsHidden()
            .frame(width: 62)
        }
    }

    private var weekdayRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.brandStart)
            Text("执行日")
                .font(.system(size: 11, weight: .medium))

            Spacer()

            Picker("", selection: $weekday) {
                Text("周一").tag(1)
                Text("周二").tag(2)
                Text("周三").tag(3)
                Text("周四").tag(4)
                Text("周五").tag(5)
                Text("周六").tag(6)
                Text("周日").tag(0)
            }
            .labelsHidden()
            .frame(width: 90)
        }
    }

    private var intervalRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("执行间隔")
                    .font(.system(size: 11, weight: .medium))
                Spacer()
                Text("每 \(Int(intervalMinutes)) 分钟")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.brandStart)
                    .monospacedDigit()
            }

            Slider(value: $intervalMinutes, in: 1...240, step: 1)
                .tint(Theme.brandStart)

            Text("系统会按固定间隔重复执行，最小 1 分钟。")
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Spacer()
            Button("取消") { dismiss() }
                .buttonStyle(GlassButtonStyle(height: 30))
                .keyboardShortcut(.cancelAction)
            Button("添加") { submit() }
                .buttonStyle(GradientButtonStyle(horizontalPadding: 18, height: 30))
                .keyboardShortcut(.defaultAction)
                .disabled(!canSubmit)
                .opacity(canSubmit ? 1 : 0.45)
        }
        .padding(.top, 2)
    }

    // MARK: - 操作

    private func chooseCommand() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            command = url.path
            if name.trimmingCharacters(in: .whitespaces).isEmpty {
                name = url.deletingPathExtension().lastPathComponent
            }
        }
    }

    private func submit() {
        let argList = arguments
            .trimmingCharacters(in: .whitespaces)
            .split(separator: " ")
            .map(String.init)

        let trigger: CustomTrigger
        switch mode {
        case .login:
            trigger = .login(delaySeconds: Int(delay))
        case .daily:
            trigger = .daily(hour: hour, minute: minute)
        case .weekly:
            trigger = .weekly(weekday: weekday, hour: hour, minute: minute)
        case .interval:
            trigger = .interval(seconds: Int(intervalMinutes) * 60)
        }

        if let error = store.addCustomItem(
            displayName: name,
            command: command,
            arguments: argList,
            trigger: trigger
        ) {
            errorText = error
        } else {
            dismiss()
        }
    }
}
