# Headphone Battery Bar

A small native macOS menu-bar app for the Logitech G522 LIGHTSPEED. A thin circular battery gauge surrounds a headphone symbol, followed by the remaining percentage. It uses the same sizes, type, and gauge style as [AI Usage Bar](https://github.com/raulconchello/ai-usage-bar). While charging, the headphones, circle, and percentage turn green. Only the unfilled portion of the ring animates: it grows from the current battery level toward 100% over 1.4 seconds, fades out, then rests for 2.2 seconds before repeating. The actual battery arc and percentage stay steady throughout. When unplugged with a displayed battery level below 15%, the icon, circle, and percentage turn red without animation. Charging takes priority over the low-battery color. Other states use the normal menu-bar tint. The animation uses Core Animation and stops when charging ends or the data becomes unavailable.

The **Charging Animation** menu item turns the motion on or off for this app. Until you choose a preference, it follows macOS Reduce Motion. An explicit choice overrides that default without changing any system setting.

Click the item to see battery and charging details, refresh, open G HUB, change Launch at Login, or quit. The app refreshes every 30 seconds and immediately after waking from sleep. If the headset disconnects or G HUB becomes unavailable, the percentage becomes a dash and the menu explains the status. It automatically recovers on the next refresh.

## Install

Requirements: macOS 14 or newer, Xcode (or its command-line tools with Swift 6.1+), and Logitech G HUB running with the G522 connected through its LIGHTSPEED receiver or USB. Bluetooth-only use is not supported by this app.

```bash
./Scripts/install.sh
```

The script builds an ad-hoc signed app, installs it in `/Applications` (or `~/Applications` if needed), and launches it. On first launch from the app bundle it enables Launch at Login, which can be turned off in the menu. macOS may require approval in System Settings. Installation preserves the previous app if replacement fails.

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
