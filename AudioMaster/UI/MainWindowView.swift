import SwiftUI

enum SidebarTab: CaseIterable, Identifiable {
    case devices
    case apps
    case presets
    case preferences

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .devices: "Devices"
        case .apps: "Apps"
        case .presets: "Presets"
        case .preferences: "Preferences"
        }
    }

    var icon: String {
        switch self {
        case .devices: return "hifispeaker.2.fill"
        case .apps: return "square.grid.2x2.fill"
        case .presets: return "slider.horizontal.3"
        case .preferences: return "gearshape.fill"
        }
    }
}

struct MainWindowView: View {
    @ObservedObject var deviceManager: AudioDeviceManager
    @ObservedObject var bluetoothManager: BluetoothDeviceManager
    @ObservedObject var appVolumeController: AppVolumeController
    @ObservedObject var routingPresetController: RoutingPresetController
    @State private var selectedTab: SidebarTab = .devices

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            content
        }
        .frame(minWidth: 720, minHeight: 480)
        .background(AMBackground())
        .appAppearanceAware()
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            brandHeader
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 18)

            VStack(spacing: 1) {
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
            .padding(.horizontal, 10)

            Spacer()
        }
        .frame(width: 190)
        .background(AMTheme.surfaceElevated)
        .overlay(
            Rectangle()
                .fill(AMTheme.surfaceBorder)
                .frame(width: 1),
            alignment: .trailing
        )
    }

    private var brandHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(AMTheme.accent)

            Text("AudioMaster")
                .font(.system(size: 14, weight: .semibold))
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
            case .presets:
                PresetsTabView(routingPresetController: routingPresetController)
            case .preferences:
                PreferencesTabView(equalizerController: appVolumeController.equalizerController)
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
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(isSelected ? AMTheme.accent : .secondary)
                .frame(width: 20)

            Text(title)
                .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                .foregroundStyle(isSelected ? .primary : .secondary)

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 5)
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
            return AMTheme.accent.opacity(0.08)
        } else if isHovered {
            return Color.primary.opacity(0.03)
        }
        return .clear
    }
}
