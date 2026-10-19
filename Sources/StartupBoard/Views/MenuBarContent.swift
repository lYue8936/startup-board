import SwiftUI
import AppKit

// MARK: - 菜单栏面板（毛玻璃浮层）

struct MenuBarPanel: View {
    @EnvironmentObject private var store: ItemStore
    @Environment(\.openWindow) private var openWindow
    @State private var query = ""

    private var visibleAgents: [LaunchItem] {
        let agents = store.agents.filter { !$0.isApple }
        guard !query.isEmpty else { return agents }
        return agents.filter {
            $0.displayName.localizedCaseInsensitiveContains(query)
                || $0.label.localizedCaseInsensitiveContains(query)
        }
    }

    private var disabledCount: Int {
        store.agents.filter(\.isEffectivelyDisabled).count
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.35)

            VStack(spacing: 10) {
                SearchField(text: $query)
                list
                footer
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 12)
        }
        .frame(width: 348)
        .background {
            VisualEffectView(material: .popover, blending: .behindWindow)
                .ignoresSafeArea()
        }
        .onAppear { store.refresh() }
    }

    // MARK: 头部

    private var header: some View {
        HStack(spacing: 9) {
            BrandMark(size: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text("StartupBoard")
                    .font(.system(size: 12.5, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                store.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(Color.primary.opacity(0.07)))
            }
            .buttonStyle(.plain)
            .help("重新扫描启动项")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    private var subtitle: String {
        if store.isLoading { return "正在扫描…" }
        let total = store.agents.count + store.loginItems.count
        return "\(total) 个启动项 · \(disabledCount) 个已停用"
    }

    // MARK: 列表

    @ViewBuilder
    private var list: some View {
        if store.isLoading {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("正在扫描启动项…")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 26)
        } else if visibleAgents.isEmpty {
            VStack(spacing: 6) {
                Image(systemName: "checkmark.seal")
                    .font(.system(size: 18, weight: .light))
                    .foregroundStyle(.secondary)
                Text(query.isEmpty ? "没有可管理的后台启动项" : "没有匹配的结果")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        } else {
            ScrollView(.vertical) {
                VStack(spacing: 4) {
                    ForEach(visibleAgents) { item in
                        MenuItemRow(item: item, isOn: toggleBinding(item))
                    }
                }
                .padding(.vertical, 1)
            }
            .frame(maxHeight: 300)
        }
    }

    // MARK: 底部操作

    private var footer: some View {
        VStack(spacing: 8) {
            Divider().opacity(0.35)

            Button {
                openWindow(id: "manager")
                DispatchQueue.main.async {
                    NSApp.activate(ignoringOtherApps: true)
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 10.5, weight: .semibold))
                    Text("打开管理窗口")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(GradientButtonStyle(horizontalPadding: 0, height: 30))
            .keyboardShortcut("m")

            HStack(spacing: 6) {
                if let error = store.lastError {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer()
                } else {
                    Spacer()
                }

                Button("退出") { NSApp.terminate(nil) }
                    .buttonStyle(.plain)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .keyboardShortcut("q")
            }
            .padding(.top, 1)
        }
    }

    private func toggleBinding(_ item: LaunchItem) -> Binding<Bool> {
        Binding(
            get: { !item.isEffectivelyDisabled },
            set: { store.setAgent(item, enabled: $0) }
        )
    }
}

// MARK: - 菜单栏单行

private struct MenuItemRow: View {
    let item: LaunchItem
    let isOn: Binding<Bool>
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 9) {
            IconTile(systemName: ItemStyle.symbol(for: item), size: 26, tint: ItemStyle.color(for: item))

            VStack(alignment: .leading, spacing: 1) {
                Text(item.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Text(subtitleText)
                    .font(.system(size: 9.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(hovering ? 0.07 : 0))
        }
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onHover { hovering = $0 }
    }

    private var subtitleText: String {
        if item.isCustom { return "自定义启动项" }
        if item.displayName == item.label { return "后台服务 · \(item.scope.rawValue)" }
        return item.label
    }
}
