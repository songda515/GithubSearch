import ComposableArchitecture
import Foundation

/// Generic key/value persistence wrapped around `UserDefaults`. Features encode
/// their own models (e.g. JSON) and store the resulting `Data` — Core stays
/// screen-agnostic and never knows feature policy.
@DependencyClient
public struct UserDefaultsClient: Sendable {
    /// Read raw data for a key.
    public var data: @Sendable (_ key: String) -> Data?
    /// Write (or clear, when `nil`) raw data for a key.
    public var setData: @Sendable (_ data: Data?, _ key: String) -> Void
    /// Remove the value for a key.
    public var remove: @Sendable (_ key: String) -> Void
}

extension UserDefaultsClient: DependencyKey {
    /// Build a client backed by `UserDefaults`. `suiteName == nil` → `.standard`.
    /// Only the `Sendable` `suiteName` is captured; the `UserDefaults` instance is
    /// created inside each closure (Swift 6 strict-concurrency safe).
    public static func live(suiteName: String? = nil) -> UserDefaultsClient {
        @Sendable func defaults() -> UserDefaults {
            suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
        }
        return Self(
            data: { defaults().data(forKey: $0) },
            setData: { defaults().set($0, forKey: $1) },
            remove: { defaults().removeObject(forKey: $0) }
        )
    }

    public static let liveValue = UserDefaultsClient.live()

    /// In-memory, deterministic stub for previews (and a safe default).
    public static var previewValue: UserDefaultsClient {
        let storage = LockIsolated<[String: Data]>([:])
        return Self(
            data: { storage.value[$0] },
            setData: { data, key in storage.withValue { $0[key] = data } },
            remove: { key in storage.withValue { $0[key] = nil } }
        )
    }
    // testValue is auto-synthesized as "unimplemented" by @DependencyClient.
}

public extension DependencyValues {
    var userDefaults: UserDefaultsClient {
        get { self[UserDefaultsClient.self] }
        set { self[UserDefaultsClient.self] = newValue }
    }
}
