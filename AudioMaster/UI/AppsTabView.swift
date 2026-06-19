import SwiftUI

struct AppsTabView: View {
    @ObservedObject var deviceManager: AudioDeviceManager
    @ObservedObject var appVolumeController: AppVolumeController
    @State private var searchText: String = ""
    @State private var hoveredPID: pid_t?

    private var filteredApps: [AppVolumeEntry] {
        if searchText.isEmpty { return appVolumeController.apps }
        return appVolumeController.apps.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 36)

            headerSection
                .padding(.horizontal, 28)

            if !appVolumeController.isProcessTapAvailable {
                unavailableBanner
                    .padding(.horizontal, 28)
                    .padding(.top, 16)
            }

            Spacer().frame(height: 16)

            searchBar
                .padding(.horizontal, 28)

            Spacer().frame(height: 16)

            if filteredApps.isEmpty {
                emptyState
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 2) {
                        ForEach(filteredApps) { app in
                            AppVolumeRow(
                                app: app,
                                volume: appVolumeController.sliderValue(for: app.pid),
                                isMuted: appVolumeController.isMuted(pid: app.pid),
                                isActive: appVolumeController.isActive(pid: app.pid),
                                isHovered: hoveredPID == app.pid,
                                errorMessage: appVolumeController.errors[app.pid],
                                onVolumeChange: { newVolume in
                                    appVolumeController.setGain(pid: app.pid, gain: Float(newVolume))
                                },
                                onMuteToggle: {
                                    appVolumeController.toggleMute(pid: app.pid)
                                }
                            )
                            .onHover { hovered in
                                withAnimation(.easeInOut(duration: 0.1)) {
                                    hoveredPID = hovered ? app.pid : nil
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 24)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            appVolumeController.refresh()
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("App Volumes")
                .font(.system(size: 26, weight: .bold, design: .rounded))

            let playing = appVolumeController.apps.filter(\.isPlayingAudio).count
            let total = appVolumeController.apps.count
            if playing > 0 {
                Text("\(playing) playing · \(total) apps open")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            } else {
                Text("\(total) apps open")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var unavailableBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text("Per-app volume requires macOS 14.2 or later.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .amGlassCard(cornerRadius: 10)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "speaker.slash")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text("No apps running")
                .font(.system(size: 14, weight: .medium))
            Text("Open an app to control its volume here.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 80)
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
    let app: AppVolumeEntry
    let volume: Double
    let isMuted: Bool
    let isActive: Bool
    let isHovered: Bool
    let errorMessage: String?
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
        .overlay(alignment: .bottomLeading) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 9))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 2)
            }
        }
        .onAppear { localVolume = volume }
        .onChange(of: volume) { newValue in localVolume = newValue }
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
            Text(app.displayName)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)

            Text(volumeLabel)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(isActive ? AMTheme.accent : Color.secondary)
        }
        .frame(width: 120, alignment: .leading)
    }

    private var volumeSlider: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.06))
                    .frame(height: 4)

                Capsule()
                    .fill(
                        isMuted
                            ? AnyShapeStyle(Color.white.opacity(0.12))
                            : AnyShapeStyle(AMTheme.accentGradient)
                    )
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
            Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .font(.system(size: 11))
                .foregroundStyle(isMuted ? .primary : .tertiary)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
    }

    private var volumeLabel: String {
        if isMuted { return "Muted" }
        if isActive || app.isPlayingAudio { return "\(Int(localVolume * 100))%" }
        return "Ready"
    }
}
