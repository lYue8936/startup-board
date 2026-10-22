import SwiftUI
import AppKit

@main
struct StartupBoardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = ItemStore()

    var body: some Scene {
        Window("启动项看板", id: "manager") {
            ManagerWindow()
                .environmentObject(store)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1000, height: 640)
        .windowResizability(.contentMinSize)
    }
}

/// 记录「打开管理窗口」的动作，供 AppDelegate 在点击 Dock 图标时复用。
enum WindowOpener {
    static var openManager: (() -> Void)?
}
