import Foundation

enum HealthExportLoaderError: LocalizedError {
    case folderMissing(URL)
    case exportMissing(URL)
    case unreadable(URL)

    var errorDescription: String? {
        switch self {
        case .folderMissing(let url):
            return "Health Export folder not found at \(url.path)."
        case .exportMissing(let url):
            return "No HealthAutoExport-*.json file was found in \(url.path)."
        case .unreadable(let url):
            return "The newest Health Export file could not be read: \(url.lastPathComponent)."
        }
    }
}

struct HealthExportLoader {
    static var healthExportDirectory: URL {
        let documents = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents")
        let candidates = [
            documents.appendingPathComponent("Health Export"),
            documents.appendingPathComponent("health export")
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0.path) } ?? candidates[0]
    }

    func load() -> Result<DailyCoach, Error> {
        let directory = Self.healthExportDirectory
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return .failure(HealthExportLoaderError.folderMissing(directory))
        }

        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        let candidates = files.filter {
            $0.pathExtension.lowercased() == "json"
                && ($0.lastPathComponent.hasPrefix("HealthAutoExport-") || $0.lastPathComponent == "HealthAutoExport.json")
        }

        guard let newest = candidates.max(by: {
            ($0.modificationDate ?? .distantPast) < ($1.modificationDate ?? .distantPast)
        }) else {
            return .failure(HealthExportLoaderError.exportMissing(directory))
        }

        guard let data = try? Data(contentsOf: newest),
              let export = try? JSONDecoder().decode(HealthAutoExport.self, from: data) else {
            return .failure(HealthExportLoaderError.unreadable(newest))
        }

        return .success(DailyCoachBuilder(export: export, sourceURL: newest).build())
    }
}
