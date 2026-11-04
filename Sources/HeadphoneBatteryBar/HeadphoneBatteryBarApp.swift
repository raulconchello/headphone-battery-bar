import AppKit
import BatteryCore
import Darwin
import Foundation

@main
enum HeadphoneBatteryBarApp {
    @MainActor
    static func main() async {
        if CommandLine.arguments.contains("--print-battery") {
            let snapshot: HeadsetSnapshot
            do {
                snapshot = try await GHubClient().fetch()
            } catch {
                snapshot = HeadsetSnapshot(state: .unavailable, message: error.localizedDescription)
            }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            if let data = try? encoder.encode(snapshot) {
                print(String(decoding: data, as: UTF8.self))
            }
            if snapshot.state == .unavailable { exit(EXIT_FAILURE) }
            return
        }

        if let identifier = Bundle.main.bundleIdentifier,
            NSRunningApplication.runningApplications(withBundleIdentifier: identifier).contains(where: {
                $0.processIdentifier != ProcessInfo.processInfo.processIdentifier
                    && !$0.isTerminated && kill($0.processIdentifier, 0) == 0
            })
        {
            return
        }

        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.run()
    }
}
