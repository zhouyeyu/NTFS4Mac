import SwiftUI
import AppKit

@main
struct NTFS4MacApp: App {
    @State private var deviceService = DeviceService()
    @State private var mountService = MountService()
    @State private var watcher = DeviceWatcher()

    var body: some Scene {
        WindowGroup {
            DeviceListView()
                .environment(deviceService)
                .environment(mountService)
                .onAppear {
                    watcher.onDeviceChange = {
                        Task { @MainActor in
                            await deviceService.refresh()
                        }
                    }
                    watcher.start()
                    Task { await deviceService.refresh() }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 600, height: 400)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
