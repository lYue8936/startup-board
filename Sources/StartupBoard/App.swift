import SwiftUI

@main
struct StartupBoardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = ItemStore()

    var body: some Scene {
        MenuBarExtra {
            MenuBarPanel()
                .environmentObject(store)
        } label: {
            Image(systemName: "bolt.horizontal.fill")
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
