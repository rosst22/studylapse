import SwiftData
import SwiftUI

/// Account is entirely optional. Everything in StudyLapse works signed out; this
/// screen exists to back sessions up, and to let an account be deleted.
struct AccountView: View {
    @Environment(AuthController.self) private var auth
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \StudySession.startedAt, order: .reverse) private var sessions: [StudySession]

    @State private var sync = SessionSync()
    @State private var email = ""
    @State private var code = ""
    @State private var confirmingDelete = false

    var body: some View {
        NavigationStack {
            Form {
                switch auth.state {
                case .signedOut, .sendingCode:
                    signedOutSection
                case .awaitingCode, .verifying:
                    codeSection
                case .signedIn(let address):
                    signedInSection(address)
                }

                if let message = auth.errorMessage {
                    Section { Text(message).font(.footnote).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }

    // MARK: - Signed out

    private var signedOutSection: some View {
        Group {
            Section {
                Text("StudyLapse works fully without an account. Sign in only if you "
                     + "want your session history backed up in case you lose your phone.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section {
                TextField("you@example.com", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button {
                    Task { await auth.sendCode(to: email) }
                } label: {
                    if auth.state == .sendingCode {
                        ProgressView()
                    } else {
                        Text("Email me a code")
                    }
                }
                .disabled(email.isEmpty || auth.state == .sendingCode)
            } header: {
                Text("Sign in")
            } footer: {
                Text("We store your email address and your session statistics. "
                     + "Videos are never uploaded.")
            }
        }
    }

    // MARK: - Code entry

    private var codeSection: some View {
        Section("Enter the code") {
            TextField("123456", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .font(.title2.monospacedDigit())
            Button {
                Task { await auth.verify(code: code) }
            } label: {
                if auth.state == .verifying { ProgressView() } else { Text("Verify") }
            }
            .disabled(code.count < 6 || auth.state == .verifying)
            Button("Use a different email") {
                code = ""
                auth.cancelCodeEntry()
            }
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Signed in

    private func signedInSection(_ address: String) -> some View {
        Group {
            Section("Signed in as") {
                Text(address).foregroundStyle(.secondary)
            }

            Section {
                Button {
                    guard let id = auth.currentUserID else { return }
                    Task { await sync.push(sessions, userID: id) }
                } label: {
                    switch sync.state {
                    case .syncing(let done, let total):
                        HStack { ProgressView(); Text("Backing up \(done)/\(total)…") }
                    default:
                        Label("Back up \(sessions.count) session\(sessions.count == 1 ? "" : "s")",
                              systemImage: "arrow.up.to.line")
                    }
                }
                .disabled(isSyncing)

                switch sync.state {
                case .synced(let when):
                    Text("Last backed up \(when.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption).foregroundStyle(.secondary)
                case .failed(let message):
                    Text(message).font(.caption).foregroundStyle(.red)
                default:
                    EmptyView()
                }
            } header: {
                Text("Backup")
            } footer: {
                Text("Session times and subjects only. Your time-lapse videos stay "
                     + "on this device.")
            }

            Section {
                Button("Sign out") { Task { await auth.signOut() } }
                Button("Delete account", role: .destructive) { confirmingDelete = true }
                    .disabled(auth.isDeleting)
            } footer: {
                Text("Deleting your account permanently removes it and every session "
                     + "backed up from it. Sessions on this phone are not affected.")
            }
            .confirmationDialog("Delete your account?", isPresented: $confirmingDelete,
                                titleVisibility: .visible) {
                Button("Delete permanently", role: .destructive) {
                    Task { if await auth.deleteAccount() { dismiss() } }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This cannot be undone. Your account and all backed-up sessions "
                     + "will be erased. The sessions stored on this phone stay put.")
            }
        }
    }

    private var isSyncing: Bool {
        if case .syncing = sync.state { return true }
        return false
    }
}
