import AppKit
import SwiftUI

final class MainWindow: NSWindow {
    init(deviceManager: AudioDeviceManager, appVolumeController: AppVolumeController) {
        let contentView = MainWindowView(
            deviceManager: deviceManager,
            appVolumeController: appVolumeController
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
        center()
        setFrameAutosaveName("AudioMasterMain")
        minSize = NSSize(width: 720, height: 480)
        backgroundColor = .windowBackgroundColor
    }
}
