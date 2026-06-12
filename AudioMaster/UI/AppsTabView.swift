import SwiftUI

struct AppAudioItem: Identifiable {
    let id = UUID()
    let name: String
    let bundleID: String
    var volume: Double
    var isMuted: Bool
    let icon: NSImage?
}

struct AppsTabView: View {
    @ObservedObject var deviceManager: AudioDeviceManager
    @State private var searchText: String = ""
    @State private var apps: [AppAudioItem] = AppAudioItem.sampleApps()
    @State private var hoveredAppID: UUID?

    private var filteredApps: [AppAudioItem] {
        if searchText.isEmpty { return apps }
        return apps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 40)

            headerSection
                .padding(.horizontal, 32)

            Spacer().frame(height: 16)

            searchBar
                .padding(.horizontal, 32)

            Spacer().frame(height: 16)

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 2) {
                    ForEach(Array(filteredApps.enumerated()), id: \.element.id) { index, app in
                        AppVolumeRow(
                            app: app,
                            isHovered: hoveredAppID == app.id,
                            onVolumeChange: { newVolume in
                                apps[index].volume = newVolume
                            },
                            onMuteToggle: {
                                apps[index].isMuted.toggle()
                            }
                        )
                        .onHover { hovered in
                            withAnimation(.easeInOut(duration: 0.1)) {
                                hoveredAppID = hovered ? app.id : nil
                            }
                        }
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("App Volumes")
                .font(.system(size: 22, weight: .semibold))

            Text("\(apps.count) apps detected")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)

            TextField("Filter apps...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
        )
    }
}

// MARK: - App Volume Row

struct AppVolumeRow: View {
    let app: AppAudioItem
    let isHovered: Bool
    let onVolumeChange: (Double) -> Void
    let onMuteToggle: () -> Void

    @State private var localVolume: Double = 0

    var body: some View {
        HStack(spacing: 12) {
            appIcon
            appName
            Spacer()
            volumeSlider
            muteButton
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color.primary.opacity(0.03) : Color.clear)
        )
        .onAppear { localVolume = app.volume }
        .onChange(of: app.volume) { newValue in localVolume = newValue }
    }

    private var appIcon: some View {
        Group {
            if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 28, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(0.06))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: "app.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.tertiary)
                    )
            }
        }
    }

    private var appName: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(app.name)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)

            Text(volumeLabel)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .frame(width: 100, alignment: .leading)
    }

    private var volumeSlider: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.06))
                    .frame(height: 4)

                Capsule()
                    .fill(app.isMuted ? Color.primary.opacity(0.15) : Color.primary.opacity(0.45))
                    .frame(width: max(0, geometry.size.width * localVolume), height: 4)

                Circle()
                    .fill(Color.primary.opacity(0.8))
                    .frame(width: 10, height: 10)
                    .offset(x: max(0, geometry.size.width * localVolume - 5))
                    .opacity(isHovered ? 1 : 0)
            }
            .frame(maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let newVolume = max(0, min(1, value.location.x / geometry.size.width))
                        localVolume = newVolume
                        onVolumeChange(newVolume)
                    }
            )
        }
        .frame(width: 140, height: 24)
    }

    private var muteButton: some View {
        Button(action: onMuteToggle) {
            Image(systemName: app.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .font(.system(size: 11))
                .foregroundStyle(app.isMuted ? .primary : .tertiary)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
    }

    private var volumeLabel: String {
        if app.isMuted { return "Muted" }
        return "\(Int(localVolume * 100))%"
    }
}

// MARK: - Sample Data

extension AppAudioItem {
    static func sampleApps() -> [AppAudioItem] {
        let workspace = NSWorkspace.shared
        let runningApps = workspace.runningApplications.filter { app in
            app.activationPolicy == .regular && app.bundleIdentifier != nil
        }

        return runningApps.prefix(12).map { app in
            AppAudioItem(
                name: app.localizedName ?? "Unknown",
                bundleID: app.bundleIdentifier ?? "",
                volume: Double.random(in: 0.4...1.0),
                isMuted: false,
                icon: app.icon
            )
        }
    }
}
