import Foundation

final class ProjectStorage {
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    func save(project: Project) {
        var p = project
        p.touch()
        let url = AppPaths.projectsDir.appendingPathComponent("\(p.id.uuidString).json")
        do {
            let data = try encoder.encode(p)
            try data.write(to: url, options: [.atomic])
            Log.info("Saved project: \(url.lastPathComponent)")
        } catch {
            Log.error("Save failed: \(error)")
        }
    }

    func loadMostRecentProject() -> Project? {
        let dir = AppPaths.projectsDir
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) else {
            return nil
        }
        let jsons = files.filter { $0.pathExtension.lowercased() == "json" }
        let sorted = jsons.sorted { (a, b) -> Bool in
            let da = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let db = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return da > db
        }
        guard let latest = sorted.first else { return nil }
        return load(url: latest)
    }

    func load(url: URL) -> Project? {
        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(Project.self, from: data)
        } catch {
            Log.error("Load failed: \(error)")
            return nil
        }
    }
}
