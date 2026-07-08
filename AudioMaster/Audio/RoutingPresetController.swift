import Combine
import Foundation

/// Bridges routing presets to the live audio managers. Abstracted so preset
/// management can be tested without touching Core Audio.
@MainActor
protocol RoutingStatePort: AnyObject {
    /// Snapshot the current audio setup (output device, master volume,
    /// per-app volumes, global EQ).
    func captureSnapshot() -> RoutingSnapshot
    /// Restore a captured setup, skipping anything no longer available.
    func apply(_ snapshot: RoutingSnapshot)
}

/// Owns the user's saved routing presets: capture, apply, edit, and persistence.
@MainActor
final class RoutingPresetController: ObservableObject {
    @Published private(set) var presets: [RoutingPreset] = []

    private let port: RoutingStatePort
    private let defaults: UserDefaults
    private let storageKey = "com.audiomaster.routingPresets"

    init(port: RoutingStatePort, defaults: UserDefaults = .standard) {
        self.port = port
        self.defaults = defaults
        load()
    }

    /// Capture the current setup as a new preset.
    @discardableResult
    func saveCurrent(name: String) -> RoutingPreset {
        let preset = RoutingPreset(name: name, snapshot: port.captureSnapshot())
        presets.append(preset)
        persist()
        return preset
    }

    /// Restore a preset's captured setup.
    func apply(_ preset: RoutingPreset) {
        port.apply(preset.snapshot)
    }

    func rename(_ preset: RoutingPreset, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = indexOf(preset) else { return }
        presets[index].name = trimmed
        persist()
    }

    func delete(_ preset: RoutingPreset) {
        presets.removeAll { $0.id == preset.id }
        persist()
    }

    /// Re-capture the current setup into an existing preset, keeping its name.
    func updateSnapshot(_ preset: RoutingPreset) {
        guard let index = indexOf(preset) else { return }
        presets[index].snapshot = port.captureSnapshot()
        persist()
    }

    func move(fromOffsets: IndexSet, toOffset: Int) {
        presets.move(fromOffsets: fromOffsets, toOffset: toOffset)
        persist()
    }

    // MARK: - Helpers

    private func indexOf(_ preset: RoutingPreset) -> Int? {
        presets.firstIndex { $0.id == preset.id }
    }

    // MARK: - Persistence

    private func persist() {
        guard let data = try? JSONEncoder().encode(presets) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private func load() {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([RoutingPreset].self, from: data) else { return }
        presets = decoded
    }
}
