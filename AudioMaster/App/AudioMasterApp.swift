import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var deviceManager: AudioDeviceManager?
    private var appVolumeController: AppVolumeController?
    private var menuBarController: MenuBarController?
    private var mainWindow: MainWindow?

    static var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") }
        set { UserDefaults.standard.set(newValue, forKey: "hasCompletedOnboarding") }
    }

    static var openWindowOnLaunch: Bool {
        get { UserDefaults.standard.bool(forKey: "openWindowOnLaunch") }
        set { UserDefaults.standard.set(newValue, forKey: "openWindowOnLaunch") }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let needsOnboarding = !AppDelegate.hasCompletedOnboarding
        let shouldShowWindow = needsOnboarding || AppDelegate.openWindowOnLaunch

        NSApp.setActivationPolicy(shouldShowWindow ? .regular : .accessory)

        Task { @MainActor in
            let manager = AudioDeviceManager()
            let volumeController = AppVolumeController()
            deviceManager = manager
            appVolumeController = volumeController

            do {
                let cached = try PersistenceController.shared.fetchDevices()
                print("[AudioMaster] Loaded \(cached.count) cached device(s) from Core Data")
            } catch {
                print("[AudioMaster] Failed to load cached devices: \(error.localizedDescription)")
            }

            manager.refreshDevices()
            manager.startMonitoring()
            volumeController.startMonitoring()

            menuBarController = MenuBarController(
                deviceManager: manager,
                appVolumeController: volumeController
            )

            if shouldShowWindow {
                showMainWindow()
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showMainWindow()
        }
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        Task { @MainActor in
            deviceManager?.stopMonitoring()
            appVolumeController?.stopMonitoring()
        }
    }

    @MainActor
    func showMainWindow() {
        guard let deviceManager, let appVolumeController else { return }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        if let window = mainWindow {
            window.makeKeyAndOrderFront(nil)
        } else {
            let window = MainWindow(
                deviceManager: deviceManager,
                appVolumeController: appVolumeController
            )
            mainWindow = window
            window.makeKeyAndOrderFront(nil)
        }
    }

    @MainActor
    func hideMainWindow() {
        mainWindow?.orderOut(nil)
        mainWindow = nil
        if !AppDelegate.openWindowOnLaunch {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    @MainActor
    func completeOnboarding() {
        AppDelegate.hasCompletedOnboarding = true
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
