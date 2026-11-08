import Foundation
import Observation
import RunCore

/// Local persistence: one JSON file per Run under Documents/runs (brief §7).
/// The stored file IS the export; GPX is rendered on demand.
@MainActor
@Observable
final class RunStore {
    private(set) var runs: [Run] = []
    private(set) var lastError: String?

    private let directory: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        directory = docs.appendingPathComponent("runs", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        reload()
    }

    func reload() {
        let fm = FileManager.default
        let files = (try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        var loaded: [Run] = []
        for url in files where url.pathExtension == "json" {
            if let data = try? Data(contentsOf: url), let run = try? Run.fromJSON(data) {
                loaded.append(run)
            }
        }
        runs = loaded.sorted { $0.startedAt > $1.startedAt }
    }

    func save(_ run: Run) {
        do {
            let data = try run.jsonData()
            try data.write(to: jsonURL(for: run), options: .atomic)
            reload()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func delete(_ run: Run) {
        try? FileManager.default.removeItem(at: jsonURL(for: run))
        reload()
    }

    func jsonURL(for run: Run) -> URL {
        directory.appendingPathComponent("\(run.id.uuidString).json")
    }

    /// Writes a GPX rendering to a temp file named by date so it reads well in
    /// a share sheet, e.g. RunWith_2026-11-08_0931.gpx
    func gpxURL(for run: Run) throws -> URL {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd_HHmm"
        let name = "RunWith_\(f.string(from: run.startedAt))"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).gpx")
        try GPX.export(run, name: name).write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
