import AppKit
import BatteryCore
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let batteryIcon = BatteryIconView(frame: .zero)
    private let client = GHubClient()
    private var snapshot = HeadsetSnapshot(state: .connecting)
    private var refreshTask: Task<Void, Never>?
    private var timer: Timer?
    private var generation = 0
    private var launchAtLoginError: String?
    private let animationPreferenceKey = "chargingAnimationEnabled"

    private var chargingAnimationEnabled: Bool {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: animationPreferenceKey) != nil {
            return defaults.bool(forKey: animationPreferenceKey)
        }
        return !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItem.button?.imagePosition = .imageOnly
        if let button = statusItem.button {
            batteryIcon.frame = button.bounds
            batteryIcon.autoresizingMask = [.width, .height]
            button.addSubview(batteryIcon)
        }
        configureLaunchAtLoginOnce()
        render()
        refresh()
        let timer = Timer(timeInterval: 30, target: self, selector: #selector(refresh), userInfo: nil, repeats: true)
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        let notifications = NSWorkspace.shared.notificationCenter
        notifications.addObserver(
            self, selector: #selector(didWake), name: NSWorkspace.didWakeNotification, object: nil)
        notifications.addObserver(
            self, selector: #selector(willSleep), name: NSWorkspace.willSleepNotification, object: nil)
        notifications.addObserver(
            self, selector: #selector(accessibilityOptionsChanged),
            name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        refreshTask?.cancel()
        timer?.invalidate()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    @objc private func refresh() {
        guard refreshTask == nil else { return }
        let currentGeneration = generation
        refreshTask = Task { [weak self] in
            guard let self else { return }
            let updated: HeadsetSnapshot
            do {
                updated = try await client.fetch()
            } catch {
                guard !Task.isCancelled else { return }
                let message = error is HubError ? "Battery data unavailable" : "G HUB unavailable"
                updated = HeadsetSnapshot(state: .unavailable, message: message)
            }
            guard !Task.isCancelled, currentGeneration == generation else { return }
            snapshot = updated
            refreshTask = nil
            render()
        }
        rebuildMenu()
    }

    @objc private func willSleep() {
        generation += 1
        refreshTask?.cancel()
        refreshTask = nil
        snapshot = HeadsetSnapshot(state: .connecting)
        render()
    }

    @objc private func didWake() {
        willSleep()
        refresh()
    }

    private func render() {
        statusItem.button?.image = StatusItemRenderer.image(for: snapshot)
        updateBatteryIcon()
        let description = "\(snapshot.deviceName): \(snapshot.statusText)"
        statusItem.button?.toolTip = description
        statusItem.button?.setAccessibilityLabel(description)
        rebuildMenu()
    }

    @objc private func updateBatteryIcon() {
        batteryIcon.update(
            reading: snapshot.reading,
            imageWidth: statusItem.button?.image?.size.width ?? 0,
            animateCharging: chargingAnimationEnabled
        )
    }

    @objc private func accessibilityOptionsChanged() {
        updateBatteryIcon()
        rebuildMenu()
    }

    @objc private func toggleChargingAnimation() {
        UserDefaults.standard.set(!chargingAnimationEnabled, forKey: animationPreferenceKey)
        updateBatteryIcon()
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        menu.addItem(label(snapshot.deviceName))
        menu.addItem(label(snapshot.statusText))
        if snapshot.state == .unavailable {
            menu.addItem(label("Open G HUB to check the connection."))
        } else if snapshot.state == .disconnected {
            menu.addItem(label("Turn on your headset and connect its receiver."))
        }
        if let date = snapshot.checkedAt {
            menu.addItem(label("Checked \(date.formatted(date: .omitted, time: .shortened))"))
        }
        menu.addItem(.separator())
        let refreshItem = action("Refresh Now", selector: #selector(refresh), key: "r")
        refreshItem.isEnabled = refreshTask == nil
        menu.addItem(refreshItem)
        menu.addItem(action("Open G HUB", selector: #selector(openGHub)))
        let animation = action("Charging Animation", selector: #selector(toggleChargingAnimation))
        animation.state = chargingAnimationEnabled ? .on : .off
        menu.addItem(animation)
        let login = action(
            SMAppService.mainApp.status == .requiresApproval ? "Allow Launch at Login…" : "Launch at Login",
            selector: #selector(toggleLaunchAtLogin)
        )
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        if let launchAtLoginError { menu.addItem(label(launchAtLoginError)) }
        menu.addItem(.separator())
        menu.addItem(action("Quit Headphone Battery Bar", selector: #selector(quit), key: "q"))
        statusItem.menu = menu
    }

    private func label(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func action(_ title: String, selector: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func openGHub() {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.logi.ghub") {
            NSWorkspace.shared.openApplication(at: url, configuration: .init())
        }
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            switch SMAppService.mainApp.status {
            case .enabled: try SMAppService.mainApp.unregister()
            case .requiresApproval: SMAppService.openSystemSettingsLoginItems()
            case .notFound, .notRegistered: try SMAppService.mainApp.register()
            @unknown default: break
            }
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = "Could not change Launch at Login."
        }
        rebuildMenu()
    }

    private func configureLaunchAtLoginOnce() {
        guard Bundle.main.bundleURL.pathExtension == "app" else { return }
        let defaults = UserDefaults.standard
        let key = "didConfigureLaunchAtLoginV1"
        guard !defaults.bool(forKey: key) else { return }
        do {
            if SMAppService.mainApp.status == .notRegistered {
                try SMAppService.mainApp.register()
            }
            defaults.set(true, forKey: key)
        } catch {
            launchAtLoginError = "Enable Launch at Login from the menu."
        }
    }

    @objc private func quit() { NSApp.terminate(nil) }
}
