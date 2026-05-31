import ComposableArchitecture
import Foundation
import Testing

@testable import Core

/// Unit tests for the live `UserDefaultsClient`, isolated to a throwaway suite so
/// they never touch `.standard`.
struct UserDefaultsClientTests {
    @Test
    func setGetRemoveRoundTrip() {
        let suite = "test.\(UUID().uuidString)"
        let client = UserDefaultsClient.live(suiteName: suite)
        defer { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }

        #expect(client.data("k") == nil)

        let payload = Data("hello".utf8)
        client.setData(payload, "k")
        #expect(client.data("k") == payload)

        client.remove("k")
        #expect(client.data("k") == nil)
    }

    @Test
    func persistsAcrossClientInstances() {
        let suite = "test.\(UUID().uuidString)"
        defer { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }

        let payload = Data([1, 2, 3])
        UserDefaultsClient.live(suiteName: suite).setData(payload, "k")

        // A fresh client over the same suite reads the persisted value (P1).
        #expect(UserDefaultsClient.live(suiteName: suite).data("k") == payload)
    }
}
