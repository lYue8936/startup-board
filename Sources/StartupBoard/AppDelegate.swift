import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// 启动时是否已尝试打开管理窗口，避免菜单栏图标重建时重复打开
    static var didAutoOpenManager = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 菜单栏常驻应用：不占用 Dock 图标
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
