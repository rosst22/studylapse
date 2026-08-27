import Foundation
import Supabase

/// Supabase connection details, injected at build time from Local.xcconfig.
///
/// Absent or placeholder values are not an error: the app is local-first, so it
/// simply runs with every account feature hidden. That also means anyone can
/// clone the public repo and build a working app without credentials.
struct SyncConfiguration: Sendable {
    let url: URL
    let anonKey: String

    static var current: SyncConfiguration? {
        guard
            let rawURL = Bundle.main.object(forInfoDictionaryKey: "SupabaseURL") as? String,
            let key = Bundle.main.object(forInfoDictionaryKey: "SupabaseAnonKey") as? String,
            !key.isEmpty,
            !rawURL.isEmpty,
            !rawURL.contains("PLACEHOLDER"),
            let url = URL(string: rawURL)
        else { return nil }
        return SyncConfiguration(url: url, anonKey: key)
    }
}

/// Single Supabase client for the process.
///
/// The anon key is meant to ship inside clients; Row Level Security on the
/// server is what actually stops one user reading another's sessions. It is kept
/// out of the public repo regardless.
final class SupabaseService: Sendable {
    static let shared = SupabaseService()
    let client: SupabaseClient?

    var isConfigured: Bool { client != nil }

    private init() {
        if let config = SyncConfiguration.current {
            client = SupabaseClient(supabaseURL: config.url, supabaseKey: config.anonKey)
        } else {
            client = nil
        }
    }
}
