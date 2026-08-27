import Foundation
import Observation
import Supabase
import os

/// Optional sign-in via a six-digit email code.
///
/// Email OTP rather than Sign in with Apple, deliberately: Sign in with Apple
/// needs a paid-membership entitlement, and Guideline 4.8 (which requires an
/// equivalent privacy-preserving option) only applies when an app uses
/// *third-party* login services. Plain email uses none, so it does not apply.
///
/// Nothing in the app requires being signed in. Signing in adds backup, and in a
/// later version, sharing.
@MainActor
@Observable
final class AuthController {

    enum State: Equatable {
        case signedOut
        case sendingCode
        case awaitingCode(email: String)
        case verifying
        case signedIn(email: String)
    }

    private(set) var state: State = .signedOut
    private(set) var errorMessage: String?
    private(set) var isDeleting = false

    var isAvailable: Bool { SupabaseService.shared.isConfigured }
    var isSignedIn: Bool { if case .signedIn = state { true } else { false } }

    var currentUserID: UUID? {
        SupabaseService.shared.client?.auth.currentUser?.id
    }

    private let log = Logger(subsystem: "app.studylapse", category: "auth")

    /// Restore a session saved in the keychain by the SDK.
    func restore() async {
        guard let client = SupabaseService.shared.client else { return }
        do {
            let session = try await client.auth.session
            if let email = session.user.email {
                state = .signedIn(email: email)
            }
        } catch {
            state = .signedOut
        }
    }

    func sendCode(to email: String) async {
        guard let client = SupabaseService.shared.client else { return }
        let address = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard address.contains("@") else {
            errorMessage = "That doesn't look like an email address."
            return
        }
        errorMessage = nil
        state = .sendingCode
        do {
            try await client.auth.signInWithOTP(email: address, shouldCreateUser: true)
            state = .awaitingCode(email: address)
        } catch {
            log.error("sendCode failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            state = .signedOut
        }
    }

    func verify(code: String) async {
        guard let client = SupabaseService.shared.client,
              case .awaitingCode(let email) = state else { return }
        errorMessage = nil
        state = .verifying
        do {
            try await client.auth.verifyOTP(email: email, token: code, type: .email)
            state = .signedIn(email: email)
        } catch {
            log.error("verify failed: \(error.localizedDescription)")
            errorMessage = "That code didn't work. Check it and try again."
            state = .awaitingCode(email: email)
        }
    }

    func cancelCodeEntry() {
        errorMessage = nil
        state = .signedOut
    }

    func signOut() async {
        guard let client = SupabaseService.shared.client else { return }
        try? await client.auth.signOut()
        state = .signedOut
    }

    /// Required by App Store Guideline 5.1.1(v).
    ///
    /// Deletion runs in an Edge Function because removing an auth user needs the
    /// service role key, which must never be inside an app binary. The function
    /// identifies the caller from their own access token, so this request can
    /// only ever delete the account making it.
    func deleteAccount() async -> Bool {
        guard let client = SupabaseService.shared.client else { return false }
        isDeleting = true
        defer { isDeleting = false }
        do {
            try await client.functions.invoke("delete-account")
            try? await client.auth.signOut()
            state = .signedOut
            return true
        } catch {
            log.error("account deletion failed: \(error.localizedDescription)")
            errorMessage = "Could not delete the account: \(error.localizedDescription)"
            return false
        }
    }
}
