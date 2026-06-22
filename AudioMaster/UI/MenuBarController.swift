import AppKit
import SwiftUI

@MainActor
final class MenuBarController: NSObject, ObservableObject {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var eventMonitor: Any?
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
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.image = Self.menuBarIcon()
            button.image?.accessibilityDescription = String(localized: "AudioMaster")
            button.action = #selector(statusItemClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    private static func menuBarIcon() -> NSImage? {
        guard let source = NSApp.applicationIconImage ?? NSImage(named: "AppIcon") else {
            return NSImage(systemSymbolName: "waveform.circle.fill", accessibilityDescription: String(localized: "AudioMaster"))
        }

        let icon = (source.copy() as? NSImage) ?? source
        icon.size = NSSize(width: 18, height: 18)
        icon.isTemplate = false
        return icon
    }

    private func setupPopover() {
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 340, height: 480)
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

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            buildContextMenu().popUp(
                positioning: nil,
                at: NSPoint(x: 0, y: sender.bounds.height + 4),
                in: sender
            )
        } else {
            togglePopover()
        }
    }

    private func buildContextMenu() -> NSMenu {
        let menu = NSMenu()

        let openItem = NSMenuItem(
            title: String(localized: "Open AudioMaster"),
            action: #selector(openMainWindowFromMenu),
            keyEquivalent: ""
        )
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: String(localized: "Quit AudioMaster"),
            action: #selector(quitFromMenu),
            keyEquivalent: ""
        )
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    @objc private func openMainWindowFromMenu() {
        openMainWindow()
    }

    @objc private func quitFromMenu() {
        guard let appDelegate = NSApp.delegate as? AppDelegate else { return }
        appDelegate.quitApplication()
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
        guard let appDelegate = NSApp.delegate as? AppDelegate else { return }
        appDelegate.showMainWindow()
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
