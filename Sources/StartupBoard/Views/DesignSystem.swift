import SwiftUI
import AppKit

// MARK: - 设计令牌

enum Theme {
    /// 品牌渐变：靛紫 → 青蓝（与应用图标一致）
    static let brandStart = Color(red: 0.482, green: 0.357, blue: 1.0)
    static let brandEnd = Color(red: 0.133, green: 0.827, blue: 0.933)

    static let brandGradient = LinearGradient(
        colors: [brandStart, brandEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardRadius: CGFloat = 14
    static let sidebarWidth: CGFloat = 296
    static let windowMinWidth: CGFloat = 880
    static let windowMinHeight: CGFloat = 560
}

// MARK: - 系统毛玻璃

/// 桥接 NSVisualEffectView，用于真正的系统毛玻璃效果
struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .underWindowBackground
    var blending: NSVisualEffectView.BlendingMode = .behindWindow
    var emphasized: Bool = false
    var state: NSVisualEffectView.State = .followsWindowActiveState

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blending
        view.state = state
        view.isEmphasized = emphasized
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blending
        view.state = state
        view.isEmphasized = emphasized
    }
}

/// 让承载窗口透明，毛玻璃才能真正透出桌面内容
struct WindowBackdropConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.isOpaque = false
            window.backgroundColor = .clear
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.styleMask.insert(.fullSizeContentView)
            window.isMovableByWindowBackground = true
            if window.contentView?.wantsLayer != true {
                window.contentView?.wantsLayer = true
            }
            window.contentView?.layer?.cornerRadius = 12
            window.contentView?.layer?.masksToBounds = true
        }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {}
}

// MARK: - 玻璃卡片

struct GlassCardModifier: ViewModifier {
    var padding: CGFloat = 16
    var radius: CGFloat = Theme.cardRadius
    var tint: Color = .clear

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.20), Color.white.opacity(0.02)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(tint.opacity(tint == .clear ? 0 : 0.06))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.45), Color.white.opacity(0.06)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
            }
            .shadow(color: Color.black.opacity(0.10), radius: 12, x: 0, y: 6)
    }
}

extension View {
    /// 统一的玻璃卡片外观
    func glassCard(padding: CGFloat = 16, radius: CGFloat = Theme.cardRadius, tint: Color = .clear) -> some View {
        modifier(GlassCardModifier(padding: padding, radius: radius, tint: tint))
    }
}

// MARK: - 小组件

/// 胶囊标签（系统 / 自定义 / 停用状态等）
struct Pill: View {
    let text: String
    var tint: Color = .secondary
    var filled: Bool = false

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.2)
            .foregroundStyle(filled ? Color.white : tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 2.5)
            .background {
                Capsule().fill(filled ? AnyShapeStyle(tint) : AnyShapeStyle(tint.opacity(0.14)))
            }
            .overlay {
                Capsule().strokeBorder(tint.opacity(filled ? 0.0 : 0.28), lineWidth: 0.6)
            }
    }
}

/// 状态圆点
struct StatusDot: View {
    let color: Color
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
            .overlay {
                Circle().strokeBorder(Color.white.opacity(0.5), lineWidth: 0.5)
            }
            .shadow(color: color.opacity(0.6), radius: 3)
    }
}

/// 圆角图标底座
struct IconTile: View {
    let systemName: String
    var size: CGFloat = 34
    var tint: Color = .accentColor

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [tint.opacity(0.34), tint.opacity(0.12)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.30), lineWidth: 0.8)
            }
            .overlay {
                Image(systemName: systemName)
                    .font(.system(size: size * 0.44, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: size, height: size)
    }
}

/// 品牌图标：优先使用应用自身图标（打包后的 .icns）
struct BrandMark: View {
    var size: CGFloat = 28

    var body: some View {
        Group {
            if let icon = NSApp.applicationIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
            } else {
                Image(systemName: "bolt.horizontal.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Theme.brandGradient)
                    .padding(size * 0.18)
            }
        }
        .frame(width: size, height: size)
    }
}

/// 主按钮：品牌渐变填充
struct GradientButtonStyle: ButtonStyle {
    var horizontalPadding: CGFloat = 14
    var height: CGFloat = 30

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, horizontalPadding)
            .frame(height: height)
            .background {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Theme.brandGradient)
                    .opacity(configuration.isPressed ? 0.82 : 1)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.28), lineWidth: 0.8)
            }
            .shadow(color: Theme.brandStart.opacity(0.35), radius: 8, x: 0, y: 3)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// 次级按钮：玻璃胶囊
struct GlassButtonStyle: ButtonStyle {
    var height: CGFloat = 28
    var tint: Color = .primary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .frame(height: height)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.thinMaterial)
                    .opacity(configuration.isPressed ? 0.7 : 1)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(
                        tint == .red ? Color.red.opacity(0.45) : Color.white.opacity(0.22),
                        lineWidth: 0.8
                    )
            }
    }
}

/// 搜索框
struct SearchField: View {
    var placeholder: String = "搜索启动项"
    @Binding var text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 9)
        .frame(height: 28)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(0.07))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.8)
                }
        }
    }
}

// MARK: - 文案与配色

enum ItemStyle {
    static func color(for item: LaunchItem) -> Color {
        if item.isCustom { return Theme.brandStart }
        if item.isApple { return .orange }
        return .blue
    }

    static func symbol(for item: LaunchItem) -> String {
        if item.isCustom { return "sparkles" }
        if item.isApple { return "apple.logo" }
        if item.keepAlive { return "arrow.triangle.2.circlepath" }
        return "gearshape.2.fill"
    }

    static func status(_ item: LaunchItem) -> (text: String, color: Color) {
        if item.isEffectivelyDisabled { return ("已停用", .secondary) }
        if item.isLoaded { return ("运行中", .green) }
        return ("已启用", .blue)
    }
}
