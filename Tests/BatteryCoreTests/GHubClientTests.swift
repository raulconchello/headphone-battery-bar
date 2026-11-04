import Foundation
import Testing

@testable import BatteryCore

struct GHubClientTests {
    private func data(_ text: String) -> Data { Data(text.utf8) }

    @Test func decodesLiveResponseShape() throws {
        let response = data(
            """
            {"path":"/battery/dev0/state","result":{"code":"SUCCESS"},"payload":{
              "@type":"type.googleapis.com/logi.protocol.wireless.Battery","deviceId":"dev0",
              "percentage":60,"mileage":24,"charging":false,"fullyCharged":false,
              "chargingError":false,"isBatteryRemoved":false
            }}
            """)
        let reading = try #require(
            try GHubClient.decodeResponse(response, path: "/battery/dev0/state", as: BatteryReading.self)
        )
        #expect(reading.percent == 60)
        #expect(!reading.isCharging)
        #expect(reading.description == "60% · On battery")
    }

    @Test func ignoresGreetingAndOtherPaths() throws {
        let greeting = data("{\"path\":\"/\",\"verb\":\"OPTIONS\",\"origin\":\"backend\"}")
        #expect(try GHubClient.decodeResponse(greeting, path: "/devices/list", as: DeviceList.self) == nil)
        let other = data("{\"path\":\"/battery/other/state\",\"result\":{\"code\":\"SUCCESS\"}}")
        #expect(try GHubClient.decodeResponse(other, path: "/devices/list", as: DeviceList.self) == nil)
    }

    @Test func rejectsErrorsAndMissingPayloads() {
        for response in [
            "{\"path\":\"/devices/list\",\"result\":{\"code\":\"FAILURE\"}}",
            "{\"path\":\"/devices/list\",\"result\":{\"code\":\"SUCCESS\"}}",
            "{\"path\":\"/devices/list\",\"payload\":{\"deviceInfos\":[]}}",
        ] {
            #expect(throws: (any Error).self) {
                try GHubClient.decodeResponse(data(response), path: "/devices/list", as: DeviceList.self)
            }
        }
    }

    @Test func doesNotSelectOtherHeadsetsOrMice() throws {
        let list = try JSONDecoder().decode(
            DeviceList.self,
            from: data(
                """
                {"deviceInfos":[
                  {"id":"mouse","state":"ACTIVE","deviceType":"MOUSE","displayName":"G522"},
                  {"id":"other","state":"ACTIVE","deviceType":"HEADSET","displayName":"G733"},
                  {"id":"inactive","state":"INACTIVE","deviceType":"HEADSET","deviceBaseModel":"g522"},
                  {"id":"active","state":"ACTIVE","deviceType":"HEADSET","deviceModel":"g522_white",
                   "extendedDisplayName":"G522 Gaming Headset"}
                ]}
                """))
        #expect(list.headset?.id == "active")
        #expect(list.headset?.name == "G522 Gaming Headset")
    }

    @Test func inactiveHeadsetIsNotActiveAndEmptyInventoryIsValid() throws {
        let inactive = try JSONDecoder().decode(
            DeviceList.self,
            from: data(
                """
                {"deviceInfos":[{"id":"off","state":"INACTIVE","deviceType":"HEADSET","deviceBaseModel":"g522"}]}
                """))
        #expect(inactive.headset?.isActive == false)
        let empty = try JSONDecoder().decode(DeviceList.self, from: data("{\"deviceInfos\":[]}"))
        #expect(empty.headset == nil)
    }

    @Test func validatesPercentageAndMissingBattery() throws {
        for percent in [-1, 101] {
            #expect(throws: (any Error).self) {
                try JSONDecoder().decode(
                    BatteryReading.self, from: data("{\"deviceId\":\"dev0\",\"percentage\":\(percent)}")
                )
            }
        }
        for payload in [
            "{\"deviceId\":\"dev0\"}",
            "{\"deviceId\":\"dev0\",\"percentage\":null}",
            "{\"deviceId\":\"dev0\",\"percentage\":60,\"isBatteryRemoved\":true}",
        ] {
            #expect(throws: (any Error).self) {
                try JSONDecoder().decode(BatteryReading.self, from: data(payload))
            }
        }
        for percent in [0, 100] {
            let reading = try JSONDecoder().decode(
                BatteryReading.self, from: data("{\"deviceId\":\"dev0\",\"percentage\":\(percent)}")
            )
            #expect(reading.percent == percent)
        }
    }

    @Test func chargingFlagsAndRounding() throws {
        let reading = try JSONDecoder().decode(
            BatteryReading.self, from: data("{\"deviceId\":\"dev0\",\"percentage\":59.6,\"charging\":true}")
        )
        #expect(reading.percent == 60)
        #expect(reading.isCharging)
        let full = try JSONDecoder().decode(
            BatteryReading.self,
            from: data(
                """
                {"deviceId":"dev0","percentage":100,"charging":true,"fullyCharged":true}
                """))
        #expect(!full.isCharging)
        #expect(full.description == "100% · Fully charged")
        let error = try JSONDecoder().decode(
            BatteryReading.self,
            from: data(
                """
                {"deviceId":"dev0","percentage":30,"charging":true,"chargingError":true}
                """))
        #expect(!error.isCharging)
        #expect(error.description == "30% · Charging problem")
    }

    @Test func unavailableSnapshotsCannotKeepAnOldPercentage() throws {
        let reading = try JSONDecoder().decode(
            BatteryReading.self, from: data("{\"deviceId\":\"dev0\",\"percentage\":60}")
        )
        for state: HeadsetSnapshot.State in [.connecting, .disconnected, .unavailable] {
            let snapshot = HeadsetSnapshot(state: state, reading: reading)
            #expect(snapshot.reading == nil)
            #expect(snapshot.percentText == "—")
        }
        #expect(HeadsetSnapshot(state: .available, reading: reading).percentText == "60%")
    }
}
