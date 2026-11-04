# Headphone Battery Bar

A **vibe-coded project**, built and iterated with AI to keep my headphones' battery level visible in the macOS menu bar. I wanted to check the battery at a glance without opening Logitech G HUB.

The app is written in Swift and AppKit for the **Logitech G522 LIGHTSPEED**. A circular battery gauge surrounds a headphone icon, with the percentage beside it.

- **Charging:** the icon, circle, and percentage turn green. An optional animation fills only the gap from the current charge toward 100%, then pauses before repeating. The actual battery arc and number stay steady.
- **Low battery:** below 15% when unplugged, the icon, circle, and percentage turn red.
- **Disconnected or unavailable:** the percentage becomes a dash, with details in the menu.

Battery readings refresh every 30 seconds and after waking from sleep.

## Requirements

- macOS 14 or newer.
- Xcode or Xcode Command Line Tools with **Swift 6.1 or newer**.
- [Logitech G HUB](https://www.logitechg.com/en-us/software/ghub), running in the background.
- A G522 connected through its LIGHTSPEED receiver or USB. Bluetooth-only use is not supported.

## Install and use

Clone the repository and run the installer:

```bash
git clone https://github.com/raulconchello/headphone-battery-bar.git
cd headphone-battery-bar
./Scripts/install.sh
```

The installer builds and locally signs **Headphone Battery Bar.app**, installs it in `/Applications` (or `~/Applications` if needed), and launches it. The battery indicator appears in the menu bar. It enables **Launch at Login** on first launch; macOS may require approval in System Settings.

Click the indicator to refresh the reading, open G HUB, toggle **Charging Animation** or **Launch at Login**, or quit. Animation follows macOS Reduce Motion until you explicitly turn it on or off in the app's menu. G HUB needs to stay running for battery readings to work.

To update later, run these commands from the repository folder:

```bash
git pull --ff-only
./Scripts/install.sh
```

To uninstall, turn off **Launch at Login**, quit the app, and remove **Headphone Battery Bar.app** from Applications.

## How it reads the battery

Each refresh opens a short-lived WebSocket connection to G HUB's local agent at `ws://127.0.0.1:9010`, using the `json` subprotocol. It makes two read-only `GET` requests:

1. `/devices/list` — discover the G522 and check that its state is `ACTIVE`.
2. `/battery/<deviceId>/state` — read the percentage and charging flags.

The device ID is discovered afresh every time; G HUB's transient IDs are never saved. The connection closes after each refresh, with an eight-second deadline. Requests stay on the Mac. The app has no third-party dependencies and does not read G HUB's database, change headphone settings, or collect analytics.

This is an undocumented Logitech interface, also used by [LGBattery](https://github.com/bmrussell/LGBattery) and [LogiBAT](https://github.com/someweirdhuman/LogiBAT). A future G HUB update may require an adjustment. Readings have the same accuracy and freshness as those reported by G HUB; the app cannot independently measure the battery. The app creates its own menu-bar item; G HUB's existing item is managed separately.

## Development

```bash
swift test --jobs 2
swift run --jobs 2 HeadphoneBatteryBar
./Scripts/build-app.sh
```

Print a live, read-only diagnostic snapshot without creating a menu-bar item:

```bash
swift run --jobs 2 HeadphoneBatteryBar --print-battery
```

The diagnostic exits with status 1 if G HUB cannot be read. Disconnection is a valid snapshot and exits with status 0.

`Sources/BatteryCore` contains discovery, response validation, and the local client. `Sources/HeadphoneBatteryBar` contains the AppKit interface and launch-at-login support. Tests use synthetic responses and require no connected hardware.

## License

[MIT](LICENSE) — Copyright © 2026 Raul Conchello.
