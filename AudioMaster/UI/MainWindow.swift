import AppKit
import SwiftUI

final class MainWindow: NSWindow {
    init(
        deviceManager: AudioDeviceManager,
        bluetoothManager: BluetoothDeviceManager,
        appVolumeController: AppVolumeController,
        routingPresetController: RoutingPresetController
    ) {
        let contentView = MainWindowView(
            deviceManager: deviceManager,
            bluetoothManager: bluetoothManager,
            appVolumeController: appVolumeController,
            routingPresetController: routingPresetController
        )
        let hostingController = NSHostingController(rootView: contentView)

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        contentViewController = hostingController
        title = "AudioMaster"
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        isReleasedWhenClosed = false
        delegate = self
        center()
        setFrameAutosaveName("AudioMasterMain")
        minSize = NSSize(width: 720, height: 480)
        backgroundColor = .windowBackgroundColor
    }
}

extension MainWindow: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Returning false cancels AppKit's close. Hide synchronously on the main
        // thread so the window disappears immediately; an async Task can leave it
        // visible if the hide work never runs (e.g. failed delegate cast).
        dispatchPrecondition(condition: .onQueue(.main))
        MainActor.assumeIsolated {
            if let appDelegate = AppDelegate.shared {
                appDelegate.hideMainWindow()
            } else {
                sender.orderOut(nil)
                NSApp.setActivationPolicy(.accessory)
            }
        }
        return false
    }
}
