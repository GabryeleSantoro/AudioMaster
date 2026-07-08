import SwiftUI

struct PresetsTabView: View {
    @ObservedObject var routingPresetController: RoutingPresetController

    @State private var isCreating = false
    @State private var newName = ""
    @State private var editingID: UUID?
    @State private var editingName = ""

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                Spacer().frame(height: 24)

                headerSection
                    .padding(.horizontal, 24)

                createSection
                    .padding(.horizontal, 24)

                if routingPresetController.presets.isEmpty {
                    emptyState
                        .padding(.horizontal, 24)
                } else {
                    presetList
                        .padding(.horizontal, 24)
                }

                Spacer(minLength: 20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Presets")
                .font(.system(size: 18, weight: .semibold))

            Text("Save your current output device, app volumes, and equalizer, then restore the whole setup in one click.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Create

    private var createSection: some View {
        Group {
            if isCreating {
                HStack(spacing: 8) {
                    TextField("Preset name", text: $newName)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 240)
                        .onSubmit(commitCreate)

                    Button("Save", action: commitCreate)
                        .buttonStyle(.borderedProminent)
                        .disabled(trimmed(newName).isEmpty)

                    Button("Cancel", action: cancelCreate)

                    Spacer()
                }
            } else {
                Button(action: startCreate) {
                    Label("Save current setup…", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    // MARK: - List

    private var presetList: some View {
        VStack(spacing: 8) {
            ForEach(routingPresetController.presets) { preset in
                presetRow(preset)
            }
        }
    }

    private func presetRow(_ preset: RoutingPreset) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 14))
                .foregroundStyle(AMTheme.accent)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 3) {
                if editingID == preset.id {
                    TextField("Preset name", text: $editingName)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 220)
                        .onSubmit { commitRename(preset) }
                } else {
                    Text(preset.name)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                }

                Text(summary(for: preset))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if editingID == preset.id {
                Button("Done") { commitRename(preset) }
            } else {
                Button("Apply") { routingPresetController.apply(preset) }
                    .buttonStyle(.bordered)

                Menu {
                    Button("Rename") { startRename(preset) }
                    Button("Update to current setup") { routingPresetController.updateSnapshot(preset) }
                    Divider()
                    Button("Delete", role: .destructive) { routingPresetController.delete(preset) }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 14))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .frame(width: 28)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .amGlassCard()
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No presets yet")
                .font(.system(size: 13, weight: .medium))
            Text("Set up your devices and volumes how you like them, then choose “Save current setup” to create a preset like Work, Gaming, or Music.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .amGlassCard()
    }

    // MARK: - Actions

    private func startCreate() {
        newName = ""
        isCreating = true
    }

    private func commitCreate() {
        let name = trimmed(newName)
        guard !name.isEmpty else { return }
        routingPresetController.saveCurrent(name: name)
        newName = ""
        isCreating = false
    }

    private func cancelCreate() {
        newName = ""
        isCreating = false
    }

    private func startRename(_ preset: RoutingPreset) {
        editingName = preset.name
        editingID = preset.id
    }

    private func commitRename(_ preset: RoutingPreset) {
        routingPresetController.rename(preset, to: editingName)
        editingID = nil
        editingName = ""
    }

    // MARK: - Helpers

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func summary(for preset: RoutingPreset) -> String {
        let snapshot = preset.snapshot
        var parts: [String] = []

        if let device = snapshot.outputDeviceName {
            parts.append(device)
        }
        if let master = snapshot.masterVolume {
            parts.append("Master \(Int((master * 100).rounded()))%")
        }
        if !snapshot.appVolumes.isEmpty {
            let count = snapshot.appVolumes.count
            parts.append("\(count) app\(count == 1 ? "" : "s")")
        }
        if let equalizer = snapshot.equalizer, equalizer.enabled, !equalizer.bands.isFlat {
            parts.append("EQ")
        }

        return parts.isEmpty ? "Empty preset" : parts.joined(separator: " · ")
    }
}
