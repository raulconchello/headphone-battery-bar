import Foundation

public struct DeviceInfo: Decodable, Sendable {
    public let id: String
    public let state: String
    public let deviceType: String
    public let deviceBaseModel: String?
    public let deviceModel: String?
    public let displayName: String?
    public let extendedDisplayName: String?

    public var name: String {
        [extendedDisplayName, displayName].compactMap { $0 }.first { !$0.isEmpty } ?? "G522"
    }

    public var isTargetHeadset: Bool {
        guard deviceType == "HEADSET" else { return false }
        return deviceBaseModel == "g522"
            || deviceModel?.hasPrefix("g522_") == true
            || displayName == "G522"
    }

    public var isActive: Bool { state == "ACTIVE" }
}

public struct DeviceList: Decodable, Sendable {
    public let deviceInfos: [DeviceInfo]

    public var headset: DeviceInfo? {
        let matching = deviceInfos.filter(\.isTargetHeadset)
        return matching.first(where: \.isActive) ?? matching.first
    }
}

public struct BatteryReading: Decodable, Encodable, Equatable, Sendable {
    public let deviceId: String
    public let percentage: Double
    public let charging: Bool
    public let fullyCharged: Bool
    public let chargingError: Bool
    public let isBatteryRemoved: Bool

    public var percent: Int { Int(percentage.rounded()) }
    public var isCharging: Bool { charging && !fullyCharged && !chargingError }

    enum CodingKeys: String, CodingKey {
        case deviceId, percentage, charging, fullyCharged, chargingError, isBatteryRemoved
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        deviceId = try values.decode(String.self, forKey: .deviceId)
        percentage = try values.decode(Double.self, forKey: .percentage)
        guard percentage.isFinite, (0...100).contains(percentage) else {
            throw HubError.invalidBattery
        }
        charging = try values.decodeIfPresent(Bool.self, forKey: .charging) ?? false
        fullyCharged = try values.decodeIfPresent(Bool.self, forKey: .fullyCharged) ?? false
        chargingError = try values.decodeIfPresent(Bool.self, forKey: .chargingError) ?? false
        isBatteryRemoved = try values.decodeIfPresent(Bool.self, forKey: .isBatteryRemoved) ?? false
        guard !isBatteryRemoved else { throw HubError.invalidBattery }
    }

    public var description: String {
        if chargingError { return "\(percent)% · Charging problem" }
        if fullyCharged { return "\(percent)% · Fully charged" }
        return "\(percent)% · \(isCharging ? "Charging" : "On battery")"
    }
}

public struct HeadsetSnapshot: Encodable, Sendable {
    public enum State: String, Encodable, Sendable {
        case connecting, available, disconnected, unavailable
    }

    public let state: State
    public let deviceName: String
    public let reading: BatteryReading?
    public let checkedAt: Date?
    public let message: String?

    public init(
        state: State,
        deviceName: String = "G522 Gaming Headset",
        reading: BatteryReading? = nil,
        checkedAt: Date? = nil,
        message: String? = nil
    ) {
        self.state = state
        self.deviceName = deviceName
        // A failed or disconnected refresh must never display a previous battery level.
        self.reading = state == .available ? reading : nil
        self.checkedAt = checkedAt
        self.message = message
    }

    public var percentText: String { reading.map { "\($0.percent)%" } ?? "—" }

    public var statusText: String {
        switch state {
        case .connecting: "Checking battery…"
        case .available: reading?.description ?? "Battery unavailable"
        case .disconnected: "Headphones disconnected"
        case .unavailable: message ?? "G HUB unavailable"
        }
    }
}
