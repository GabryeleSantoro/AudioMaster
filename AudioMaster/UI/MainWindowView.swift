import SwiftUI

enum SidebarTab: CaseIterable, Identifiable {
    case devices
    case apps
    case preferences

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .devices: "Devices"
        case .apps: "Apps"
        case .preferences: "Preferences"
        }
    }

    var icon: String {
        switch self {
        case .devices: return "hifispeaker.2.fill"
        case .apps: return "square.grid.2x2.fill"
        case .preferences: return "gearshape.fill"
        }
    }
}

struct MainWindowView: View {
    @ObservedObject var deviceManager: AudioDeviceManager
    @ObservedObject var bluetoothManager: BluetoothDeviceManager
    @ObservedObject var appVolumeController: AppVolumeController
    @State private var selectedTab: SidebarTab = .devices

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            content
        }
        .frame(minWidth: 720, minHeight: 480)
        .background(AMBackground())
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            brandHeader
                .padding(.horizontal, 20)
                .padding(.top, 28)
                .padding(.bottom, 24)

            VStack(spacing: 2) {
                ForEach(SidebarTab.allCases) { tab in
                    SidebarItem(
                        title: tab.title,
                        icon: tab.icon,
                        isSelected: selectedTab == tab
                    )
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = tab
                        }
                    }
                }
            }
            .padding(.horizontal, 14)

            Spacer()
        }
        .frame(width: 210)
        .background(AMTheme.surfaceElevated)
        .overlay(
            Rectangle()
                .fill(AMTheme.surfaceBorder)
                .frame(width: 1),
            alignment: .trailing
        )
    }

    private var brandHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(AMTheme.accent)

            VStack(alignment: .leading, spacing: 1) {
                Text("AudioMaster")
                    .font(.system(size: 14, weight: .semibold))
                Text("Sound control")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            WaveformView(barCount: 4)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        Group {
            switch selectedTab {
            case .devices:
                DevicesTabView(
                    deviceManager: deviceManager,
                    bluetoothManager: bluetoothManager
                )
            case .apps:
                AppsTabView(
                    deviceManager: deviceManager,
                    appVolumeController: appVolumeController
                )
            case .preferences:
                PreferencesTabView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.15), value: selectedTab)
    }
}

// MARK: - Sidebar Item

struct SidebarItem: View {
    let title: LocalizedStringKey
    let icon: String
    let isSelected: Bool

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(isSelected ? AMTheme.accent : .secondary)
                .frame(width: 22)

            Text(title)
                .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                .foregroundStyle(isSelected ? .primary : .secondary)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(backgroundColor)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
        .contentShape(Rectangle())
    }

    private var backgroundColor: Color {
        if isSelected {
            return AMTheme.accent.opacity(0.1)
        } else if isHovered {
            return Color.primary.opacity(0.04)
        }
        return .clear
    }
}
