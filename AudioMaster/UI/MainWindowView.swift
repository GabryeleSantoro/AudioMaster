import SwiftUI

enum SidebarTab: String, CaseIterable, Identifiable {
    case devices = "Devices"
    case apps = "Apps"
    case preferences = "Preferences"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .devices: return "hifispeaker.2"
        case .apps: return "square.grid.2x2"
        case .preferences: return "gearshape"
        }
    }
}

struct MainWindowView: View {
    @ObservedObject var deviceManager: AudioDeviceManager
    @State private var selectedTab: SidebarTab = .devices

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider().opacity(0.4)
            content
        }
        .frame(minWidth: 580, minHeight: 420)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 52)

            VStack(spacing: 2) {
                ForEach(SidebarTab.allCases) { tab in
                    SidebarItem(
                        title: tab.rawValue,
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
            .padding(.horizontal, 12)

            Spacer()

            VStack(spacing: 4) {
                if let device = deviceManager.defaultOutputDevice {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.green.opacity(0.8))
                            .frame(width: 6, height: 6)
                        Text(device.name)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Text("v1.0")
                    .font(.system(size: 10, weight: .light, design: .monospaced))
                    .foregroundStyle(.quaternary)
            }
            .padding(.bottom, 16)
        }
        .frame(width: 180)
        .background(Color.primary.opacity(0.02))
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case .devices:
            DevicesTabView(deviceManager: deviceManager)
        case .apps:
            AppsTabView(deviceManager: deviceManager)
        case .preferences:
            PreferencesTabView()
        }
    }
}

// MARK: - Sidebar Item

struct SidebarItem: View {
    let title: String
    let icon: String
    let isSelected: Bool

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(isSelected ? .primary : .secondary)
                .frame(width: 20)

            Text(title)
                .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                .foregroundStyle(isSelected ? .primary : .secondary)

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(backgroundColor)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
        .contentShape(Rectangle())
    }

    private var backgroundColor: Color {
        if isSelected {
            return Color.primary.opacity(0.08)
        } else if isHovered {
            return Color.primary.opacity(0.04)
        }
        return .clear
    }
}
