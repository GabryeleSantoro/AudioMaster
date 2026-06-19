<p align="center">
  <img src="AudioMaster/Resources/Assets.xcassets/AppIcon.appiconset/icon_256.png" width="128" alt="AudioMaster Icon"/>
</p>

<h1 align="center">AudioMaster</h1>

<p align="center">
  <strong>The free, open-source audio control center for macOS.</strong><br/>
  Per-app volume · Device switching · Menu bar control
</p>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#installation">Installation</a> •
  <a href="#how-it-works">How It Works</a> •
  <a href="#roadmap">Roadmap</a> •
  <a href="#support">Support</a>
</p>

---

## Features

### Per-App Volume Control

Control the volume of every app independently. Lower Slack notifications while keeping Spotify loud, mute a browser tab without affecting anything else — all from one place.

- Individual volume slider for each running app
- One-click mute per app
- Remembers your volume preferences across restarts
- Real-time detection of audio-playing apps

### Audio Device Management

See all your connected audio devices at a glance and switch between them instantly.

- View all output and input devices in one unified list
- One-click device switching (no more digging into System Settings)
- Collapsible Output / Input sections to keep things tidy
- Device details: type, manufacturer, channels, sample rate
- Automatic detection when devices are plugged in or removed

### Menu Bar Control

AudioMaster lives in your menu bar — always accessible, never in the way.

- Quick popover with app volumes and device switching
- Master volume control
- Compact view of currently playing apps
- Click the menu bar icon to access everything without opening a window

### Lightweight & Non-Intrusive

- Launches as a **menu bar icon only** — no Dock clutter, no window popping up
- First launch guides you through setup with an onboarding sequence
- Optionally open the full window on launch (configurable in Preferences)
- Click the Dock icon or use the popover to open the full window when needed

### Preferences

- Launch at login
- Show/hide menu bar icon
- Open window on launch (off by default)
- Remember app volumes across sessions
- Configurable volume curve (linear or logarithmic)
- dB display option
- Notification controls for device switches, app detection, and Bluetooth disconnects

---

## Installation

### Requirements

- macOS 12.0 (Monterey) or later
- Universal binary: runs natively on Apple Silicon and Intel

### Download

Download the latest `.dmg` from [GitHub Releases](https://github.com/GabryeleSantoro/AudioMaster/releases).

### Build from Source

```bash
git clone https://github.com/GabryeleSantoro/AudioMaster.git
cd AudioMaster
open AudioMaster.xcodeproj
```

Build and run with Xcode 15+.

---

## How It Works

1. **Launch** — AudioMaster starts as a menu bar icon. On first launch, you'll be guided through a quick setup.
2. **Control volumes** — Click the menu bar icon to see all apps playing audio. Drag sliders to adjust individual volumes.
3. **Switch devices** — Expand the Output section in the popover or open the full window to switch your audio device instantly.
4. **Forget about it** — AudioMaster remembers your preferences. It stays out of the way until you need it.

---

## Roadmap

| Status | Feature                                            |
| ------ | -------------------------------------------------- |
| ✅     | Per-app volume control                             |
| ✅     | Audio device switching (output & input)            |
| ✅     | Menu bar popover with quick controls               |
| ✅     | Device hot-plug detection                          |
| ✅     | Volume persistence across restarts                 |
| 🔜     | Bluetooth device management & battery display      |
| 🔜     | Audio routing presets (Work, Gaming, Music)        |
| 🔜     | Global keyboard shortcuts                          |
| 🔜     | Audio normalization (loudness equalization)        |
| 📋     | Per-app EQ and audio effects                       |
| 📋     | Multi-output routing (one app to multiple devices) |
| 📋     | iCloud sync for presets                            |

---

## Support

AudioMaster is **100% free** and open source. If you find it useful, consider buying me a coffee to support ongoing development.

<p align="center">
  <a href="https://www.buymeacoffee.com/gabrielesantoro">
    <img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" width="200"/>
  </a>
</p>

---

## License

This project is open source. See [LICENSE](LICENSE) for details.

---

<p align="center">
  Made with ❤️ for the Mac community
</p>
