import SwiftUI
import AppKit

@main
struct StartupBoardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = ItemStore()

    var body: some Scene {
        MenuBarExtra {
            MenuBarPanel()
                .environmentObject(store)
        } label: {
            MenuBarIcon()
        }
        .menuBarExtraStyle(.window)

        Window("启动项看板", id: "manager") {
            ManagerWindow()
                .environmentObject(store)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1000, height: 640)
        .windowResizability(.contentMinSize)
    }
}

/// 菜单栏图标。`MenuBarExtra` 是首个 Scene，SwiftUI 不会自动打开管理窗口，
/// 因此借图标首次出现时主动打开一次。
private struct MenuBarIcon: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Image(systemName: "bolt.horizontal.fill")
            .onAppear {
                guard !AppDelegate.didAutoOpenManager else { return }
                AppDelegate.didAutoOpenManager = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    openWindow(id: "manager")
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
    }
}
