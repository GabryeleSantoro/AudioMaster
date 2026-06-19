import AppKit
import SwiftUI

@MainActor
final class MenuBarController: NSObject, ObservableObject {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var eventMonitor: Any?
    private var mainWindow: MainWindow?
    private let deviceManager: AudioDeviceManager
    private let appVolumeController: AppVolumeController

    init(deviceManager: AudioDeviceManager, appVolumeController: AppVolumeController) {
        self.deviceManager = deviceManager
        self.appVolumeController = appVolumeController
        super.init()
        setupStatusItem()
        setupPopover()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "speaker.wave.2.fill", accessibilityDescription: "AudioMaster")
            button.image?.size = NSSize(width: 16, height: 16)
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    private func setupPopover() {
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 340, height: 440)
        popover.behavior = .transient
        popover.animates = true

        let popoverView = PopoverView(
            deviceManager: deviceManager,
            appVolumeController: appVolumeController,
            menuBarController: self
        )
        popover.contentViewController = NSHostingController(rootView: popoverView)
        self.popover = popover
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button, let popover else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            setupEventMonitor()
        }
    }

    func closePopover() {
        popover?.performClose(nil)
        removeEventMonitor()
    }

    func openMainWindow() {
        closePopover()
        NSApp.activate(ignoringOtherApps: true)
        if let window = mainWindow {
            window.makeKeyAndOrderFront(nil)
        } else if let window = NSApp.windows.first(where: { $0.title == "AudioMaster" }) {
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

    private func setupEventMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePopover()
        }
    }

    private func removeEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}
