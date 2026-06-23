import AppKit

struct AppVolumeEntry: Identifiable, Equatable {
    var id: pid_t { pid }

    let pid: pid_t
    let bundleID: String?
    let name: String
    /// Whether Core Audio reports this process is currently producing output.
    let isPlayingAudio: Bool

    var displayName: String { name }
    var icon: NSImage? { Self.icon(for: pid) }

    static func icon(for pid: pid_t) -> NSImage? {
        NSRunningApplication(processIdentifier: pid)?.icon
    }
}
