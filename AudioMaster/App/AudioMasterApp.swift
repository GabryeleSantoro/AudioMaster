import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var deviceManager: AudioDeviceManager?
    private var appVolumeController: AppVolumeController?
    private var menuBarController: MenuBarController?
    private var mainWindow: MainWindow?
    private var volumeShortcutMonitor: Any?
    private var isQuittingForReal = false

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

            setupVolumeShortcutMonitor()

            if shouldShowWindow {
                showMainWindow()
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if isQuittingForReal {
            return .terminateNow
        }

        DispatchQueue.main.async { [weak self] in
            Task { @MainActor in
                self?.hideToMenuBar()
            }
        }
        return .terminateCancel
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showMainWindow()
        }
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let volumeShortcutMonitor {
            NSEvent.removeMonitor(volumeShortcutMonitor)
        }
        Task { @MainActor in
            deviceManager?.stopMonitoring()
            appVolumeController?.stopMonitoring()
        }
    }

    @MainActor
    var volumeController: AppVolumeController? {
        appVolumeController
    }

    private func setupVolumeShortcutMonitor() {
        volumeShortcutMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard AppPreferences.volumeShortcutsEnabled else { return event }
            guard
                event.modifierFlags.contains(.command),
                event.modifierFlags.contains(.option)
            else {
                return event
            }

            let handled: Bool
            switch event.keyCode {
            case 126:
                Task { @MainActor in self?.appVolumeController?.increaseLastModifiedVolume() }
                handled = true
            case 125:
                Task { @MainActor in self?.appVolumeController?.decreaseLastModifiedVolume() }
                handled = true
            default:
                handled = false
            }

            return handled ? nil : event
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
    func hideToMenuBar() {
        menuBarController?.closePopover()
        mainWindow?.orderOut(nil)
        NSApp.setActivationPolicy(.accessory)
    }

    @MainActor
    func hideMainWindow() {
        hideToMenuBar()
    }

    @MainActor
    func quitApplication() {
        isQuittingForReal = true
        menuBarController?.closePopover()
        deviceManager?.stopMonitoring()
        appVolumeController?.stopMonitoring()
        NSApp.terminate(nil)
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
            CommandGroup(replacing: .appTermination) {
                Button("Hide AudioMaster") {
                    Task { @MainActor in
                        (NSApp.delegate as? AppDelegate)?.hideToMenuBar()
                    }
                }
                .keyboardShortcut("q", modifiers: .command)
            }
            CommandMenu("Volume") {
                Button("Increase Volume of Last App") {
                    Task { @MainActor in
                        (NSApp.delegate as? AppDelegate)?.volumeController?.increaseLastModifiedVolume()
                    }
                }
                .keyboardShortcut(.upArrow, modifiers: [.command, .option])
                .disabled(!AppPreferences.volumeShortcutsEnabled)

                Button("Decrease Volume of Last App") {
                    Task { @MainActor in
                        (NSApp.delegate as? AppDelegate)?.volumeController?.decreaseLastModifiedVolume()
                    }
                }
                .keyboardShortcut(.downArrow, modifiers: [.command, .option])
                .disabled(!AppPreferences.volumeShortcutsEnabled)
            }
        }
    }
}
