import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    static private(set) weak var shared: AppDelegate?

    private var deviceManager: AudioDeviceManager?
    private var bluetoothManager: BluetoothDeviceManager?
    private var appVolumeController: AppVolumeController?
    private var normalizationController: NormalizationController?
    private var routingPresetController: RoutingPresetController?
    private var activityCoordinator: ResourceActivityCoordinator?
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

    private static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        AppAppearance.current.applyToApplication()

        let needsOnboarding = !AppDelegate.hasCompletedOnboarding
        let shouldShowWindow = needsOnboarding || AppDelegate.openWindowOnLaunch

        NSApp.setActivationPolicy(shouldShowWindow ? .regular : .accessory)

        Task { @MainActor in
            let manager = AudioDeviceManager()
            let bluetooth = BluetoothDeviceManager()
            let equalizerController = EqualizerController()
            let volumeController = AppVolumeController(equalizerController: equalizerController)
            let coordinator = ResourceActivityCoordinator()
            volumeController.bind(activityCoordinator: coordinator)
            let normalization = NormalizationController()
            let routingPort = LiveRoutingStatePort(
                deviceManager: manager,
                appVolumeController: volumeController,
                equalizerController: equalizerController,
                normalizationController: normalization
            )
            deviceManager = manager
            bluetoothManager = bluetooth
            appVolumeController = volumeController
            normalizationController = normalization
            routingPresetController = RoutingPresetController(port: routingPort)
            activityCoordinator = coordinator

            manager.onDevicesUpdated = { [weak bluetooth] devices in
                Task { @MainActor in
                    bluetooth?.updateAudioDeviceContext(from: devices)
                }
            }

            do {
                let cached = try PersistenceController.shared.fetchDevices()
                print("[AudioMaster] Loaded \(cached.count) cached device(s) from Core Data")
            } catch {
                print("[AudioMaster] Failed to load cached devices: \(error.localizedDescription)")
            }

            manager.refreshDevices()
            manager.startMonitoring()
            if !Self.isRunningTests {
                bluetooth.startMonitoring()
            }
            volumeController.startMonitoring()

            menuBarController = MenuBarController(
                deviceManager: manager,
                bluetoothManager: bluetooth,
                appVolumeController: volumeController,
                activityCoordinator: coordinator
            )

            setupVolumeShortcutMonitor()

            if shouldShowWindow {
                showMainWindow()
            }

            if !Self.isRunningTests {
                UpdateScheduler.shared.start()
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
            bluetoothManager?.stopMonitoring()
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
        guard let deviceManager, let bluetoothManager, let appVolumeController, let routingPresetController else { return }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        if let window = mainWindow {
            window.makeKeyAndOrderFront(nil)
        } else {
            let window = MainWindow(
                deviceManager: deviceManager,
                bluetoothManager: bluetoothManager,
                appVolumeController: appVolumeController,
                routingPresetController: routingPresetController
            )
            mainWindow = window
            window.makeKeyAndOrderFront(nil)
        }
        activityCoordinator?.setUIVisibility(.mainWindowVisible)
    }

    @MainActor
    func hideToMenuBar() {
        menuBarController?.closePopover()
        mainWindow?.orderOut(nil)
        if ResourceActivityPolicy.shouldUseAccessoryActivationPolicyAfterHidingMainWindow(
            openWindowOnLaunch: AppDelegate.openWindowOnLaunch
        ) {
            NSApp.setActivationPolicy(.accessory)
        }
        activityCoordinator?.setUIVisibility(.hidden)
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
        bluetoothManager?.stopMonitoring()
        appVolumeController?.stopMonitoring()
        UpdateScheduler.shared.stop()
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
    @AppStorage(AppPreferences.Keys.volumeShortcutsEnabled) private var volumeShortcutsEnabled = true

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
                .disabled(!volumeShortcutsEnabled)

                Button("Decrease Volume of Last App") {
                    Task { @MainActor in
                        (NSApp.delegate as? AppDelegate)?.volumeController?.decreaseLastModifiedVolume()
                    }
                }
                .keyboardShortcut(.downArrow, modifiers: [.command, .option])
                .disabled(!volumeShortcutsEnabled)
            }
        }
    }
}
