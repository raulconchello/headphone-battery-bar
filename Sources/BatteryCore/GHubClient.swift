import Foundation

public enum HubError: Error, LocalizedError, Sendable {
    case rejected
    case invalidResponse
    case invalidBattery
    case wrongDevice

    public var errorDescription: String? {
        switch self {
        case .rejected: "G HUB could not read the battery."
        case .invalidResponse, .invalidBattery, .wrongDevice: "G HUB returned an invalid battery reading."
        }
    }
}

private struct HubHeader: Decodable {
    struct Result: Decodable { let code: String }
    let path: String
    let result: Result?
}

private struct HubResponse<Payload: Decodable>: Decodable {
    let payload: Payload
}

private struct HubRequest: Encodable {
    let msgId = UUID().uuidString
    let path: String
    let verb = "GET"
}

public struct GHubClient: Sendable {
    public init() {}

    /// A short-lived, read-only connection. No device settings or G HUB files are written.
    public func fetch() async throws -> HeadsetSnapshot {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 10
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.connectionProxyDictionary = [:]
        let session = URLSession(configuration: configuration)
        let socket = session.webSocketTask(with: URL(string: "ws://127.0.0.1:9010")!, protocols: ["json"])

        // URLSession's receive() can otherwise wait indefinitely on an idle connection.
        let deadline = Task {
            try await Task.sleep(for: .seconds(8))
            socket.cancel(with: .goingAway, reason: nil)
        }
        defer {
            deadline.cancel()
            socket.cancel(with: .normalClosure, reason: nil)
            session.invalidateAndCancel()
        }

        return try await withTaskCancellationHandler {
            socket.resume()
            let devices: DeviceList = try await request("/devices/list", on: socket)
            guard let device = devices.headset else {
                return HeadsetSnapshot(state: .disconnected, checkedAt: Date())
            }
            guard device.isActive else {
                return HeadsetSnapshot(state: .disconnected, deviceName: device.name, checkedAt: Date())
            }
            let battery: BatteryReading = try await request("/battery/\(device.id)/state", on: socket)
            guard battery.deviceId == device.id else { throw HubError.wrongDevice }
            return HeadsetSnapshot(
                state: .available, deviceName: device.name, reading: battery, checkedAt: Date()
            )
        } onCancel: {
            socket.cancel(with: .goingAway, reason: nil)
        }
    }

    private func request<Payload: Decodable>(
        _ path: String, on socket: URLSessionWebSocketTask
    ) async throws -> Payload {
        let data = try JSONEncoder().encode(HubRequest(path: path))
        try await socket.send(.string(String(decoding: data, as: UTF8.self)))
        while !Task.isCancelled {
            let data: Data
            switch try await socket.receive() {
            case .data(let bytes): data = bytes
            case .string(let text): data = Data(text.utf8)
            @unknown default: throw HubError.invalidResponse
            }
            if let payload = try Self.decodeResponse(data, path: path, as: Payload.self) {
                return payload
            }
        }
        throw CancellationError()
    }

    /// Ignore the unsolicited OPTIONS greeting and messages for other paths.
    public static func decodeResponse<Payload: Decodable>(
        _ data: Data, path: String, as type: Payload.Type
    ) throws -> Payload? {
        let decoder = JSONDecoder()
        let header = try decoder.decode(HubHeader.self, from: data)
        guard header.path == path else { return nil }
        guard let result = header.result else { throw HubError.invalidResponse }
        guard result.code == "SUCCESS" else { throw HubError.rejected }
        return try decoder.decode(HubResponse<Payload>.self, from: data).payload
    }
}
