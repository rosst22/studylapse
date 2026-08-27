import Foundation
import Observation
import Supabase
import os

/// Pushes local sessions to Supabase as a backup.
///
/// One-directional on purpose. SwiftData on the device stays the source of truth;
/// the server is a copy. Two-way merge is a genuinely hard problem and this app
/// does not need it yet -- a session is written once and never edited.
///
/// Videos are NOT uploaded. A backup that quietly consumed a user's data plan at
/// 26 MB per session would be a hostile default; that belongs with the v2 feed,
/// behind an explicit choice.
@MainActor
@Observable
final class SessionSync {

    enum State: Equatable {
        case idle
        case syncing(done: Int, total: Int)
        case failed(String)
        case synced(Date)
    }

    private(set) var state: State = .idle
    private let log = Logger(subsystem: "app.studylapse", category: "sync")

    /// One row per local session. Column names are snake_case to match Postgres.
    private struct RemoteSession: Encodable {
        let user_id: UUID
        let client_id: UUID
        let subject: String
        let started_at: Date
        let duration_seconds: Double
        let lapse_coverage_seconds: Double
        let frame_count: Int
        let byte_size: Int
        let gap_count: Int
    }

    func push(_ sessions: [StudySession], userID: UUID) async {
        guard let client = SupabaseService.shared.client, !sessions.isEmpty else {
            state = .synced(Date())
            return
        }

        let rows = sessions.map { session in
            RemoteSession(
                user_id: userID,
                client_id: session.id,
                subject: session.subject,
                started_at: session.startedAt,
                duration_seconds: session.duration,
                lapse_coverage_seconds: session.lapseCoverage,
                frame_count: session.frameCount,
                byte_size: session.byteSize,
                gap_count: session.gaps.count
            )
        }

        state = .syncing(done: 0, total: rows.count)
        do {
            // Upsert on (user_id, client_id): syncing the same session twice is a
            // no-op rather than a duplicate row.
            try await client
                .from("study_sessions")
                .upsert(rows, onConflict: "user_id,client_id")
                .execute()
            state = .synced(Date())
            log.info("pushed \(rows.count) sessions")
        } catch {
            log.error("sync failed: \(error.localizedDescription)")
            state = .failed(error.localizedDescription)
        }
    }
}
