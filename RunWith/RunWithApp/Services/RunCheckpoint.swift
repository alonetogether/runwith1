import Foundation
import RunCore

/// Keeps an in-progress run on disk so a crash, a force-quit or iOS killing
/// the app cannot lose it (competitive doc §3.4). One file, rewritten every
/// 30 seconds while running and when the app goes to the background, deleted
/// once the finished run is saved.
///
/// Every operation runs on one serial queue, in the order it was asked for,
/// so a save that was already in flight when the run ended can never land
/// after the delete and bring a finished run back as "unfinished".
final class RunCheckpoint: @unchecked Sendable {
    struct Recovered {
        let builder: RunBuilder
        /// When the last checkpoint was written: everything up to here is kept.
        let savedAt: Date

        var startedAt: Date { builder.startedAt }
        var distanceM: Double { builder.distanceM }
        /// Offer to keep going only if the gap is short enough that the person
        /// is plausibly still out on the same run.
        var canContinue: Bool { Date().timeIntervalSince(savedAt) < 60 * 60 }
    }

    private let url: URL
    private let queue = DispatchQueue(label: "app.runwith.checkpoint", qos: .utility)
    private var isActive = false   // touched only on `queue`

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        url = docs.appendingPathComponent("in-progress-run.json")
    }

    /// The unfinished run left by a previous launch, if any. Synchronous: called
    /// once at launch, before any recording starts.
    func loadLeftover() -> Recovered? {
        queue.sync {
            guard let data = try? Data(contentsOf: url) else { return nil }
            guard let builder = try? JSONDecoder().decode(RunBuilder.self, from: data) else {
                // Written by an older build with a different layout: nothing usable.
                try? FileManager.default.removeItem(at: url)
                return nil
            }
            let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
            let savedAt = (attrs?[.modificationDate] as? Date) ?? builder.startedAt
            return Recovered(builder: builder, savedAt: savedAt)
        }
    }

    /// A run started or resumed: saves are accepted from now on.
    func open() {
        queue.async { self.isActive = true }
    }

    func save(_ builder: RunBuilder) {
        queue.async {
            guard self.isActive, let data = try? JSONEncoder().encode(builder) else { return }
            try? data.write(to: self.url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        }
    }

    /// The run was saved or discarded: stop accepting saves and remove the file.
    func close() {
        queue.async {
            self.isActive = false
            try? FileManager.default.removeItem(at: self.url)
        }
    }
}
