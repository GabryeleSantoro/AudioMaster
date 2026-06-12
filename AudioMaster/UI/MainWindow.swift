import AppKit
import SwiftUI

final class MainWindow: NSWindow {
    init(deviceManager: AudioDeviceManager) {
        let contentView = MainWindowView(deviceManager: deviceManager)
        let hostingController = NSHostingController(rootView: contentView)

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        contentViewController = hostingController
        title = "AudioMaster"
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        isReleasedWhenClosed = false
        center()
        setFrameAutosaveName("AudioMasterMain")
        minSize = NSSize(width: 580, height: 420)
        backgroundColor = .windowBackgroundColor
    }
}
