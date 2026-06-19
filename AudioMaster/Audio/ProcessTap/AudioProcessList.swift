import AppKit
import CoreAudio
import Foundation

struct AudioProcessInfo: Identifiable, Equatable {
    var id: pid_t { pid }

    let audioObjectID: AudioObjectID
    let pid: pid_t
    let bundleID: String?
    let executable: String?
    let isRunning: Bool

    var displayName: String {
        if let app = NSRunningApplication(processIdentifier: pid),
           let name = app.localizedName, !name.isEmpty {
            return name
        }
        if let bundleID, !bundleID.isEmpty { return bundleID }
        if let executable, !executable.isEmpty { return executable }
        return "pid \(pid)"
    }

    var icon: NSImage? {
        NSRunningApplication(processIdentifier: pid)?.icon
    }
}

enum AudioProcessList {
    static func all() throws -> [AudioProcessInfo] {
        let ids = try processTapGetArray(
            AudioObjectID(kAudioObjectSystemObject),
            kAudioHardwarePropertyProcessObjectList
        )
        return ids.map { id in
            let pid: pid_t = (try? processTapGet(id, kAudioProcessPropertyPID, as: pid_t.self)) ?? -1
            let bundle: String? = try? processTapGetString(id, kAudioProcessPropertyBundleID)
            let running: UInt32 = (try? processTapGet(id, kAudioProcessPropertyIsRunning, as: UInt32.self)) ?? 0
            return AudioProcessInfo(
                audioObjectID: id,
                pid: pid,
                bundleID: (bundle?.isEmpty == false) ? bundle : nil,
                executable: executableName(for: pid),
                isRunning: running != 0
            )
        }
    }

    static func audioObjectID(forPID pid: pid_t) throws -> AudioObjectID? {
        try all().first { $0.pid == pid }?.audioObjectID
    }

    private static func executableName(for pid: pid_t) -> String? {
        guard pid > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: 2048)
        let length = proc_name(pid, &buffer, UInt32(buffer.count))
        if length > 0 { return String(cString: buffer) }
        return nil
    }
}
