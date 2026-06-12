import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var deviceManager: AudioDeviceManager?
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            let manager = AudioDeviceManager()
            deviceManager = manager

            do {
                let cached = try PersistenceController.shared.fetchDevices()
                print("[AudioMaster] Loaded \(cached.count) cached device(s) from Core Data")
            } catch {
                print("[AudioMaster] Failed to load cached devices: \(error.localizedDescription)")
            }

            manager.refreshDevices()
            manager.startMonitoring()

            menuBarController = MenuBarController(deviceManager: manager)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        Task { @MainActor in
            deviceManager?.stopMonitoring()
        }
    }
}

@main
struct AudioMasterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .appSettings) {}
        }
    }
}
