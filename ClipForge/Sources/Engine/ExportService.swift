import Foundation
import AVFoundation

enum ExportError: Error {
    case cannotCreateSession
}

final class ExportService {
    private let engine = EditorEngine()

    @MainActor
    func export(project: Project, sequence: Sequence) async throws -> URL {
        let build = try await engine.buildPlayableAsset(project: project, sequence: sequence)
        guard let comp = build.asset as? AVMutableComposition else {
            // In this starter engine returns a mutable composition, but keep safe:
            throw ExportError.cannotCreateSession
        }

        let outURL = AppPaths.uniqueFileURL(in: AppPaths.exportsDir, ext: "mp4")
        if FileManager.default.fileExists(atPath: outURL.path) {
            try? FileManager.default.removeItem(at: outURL)
        }

        guard let session = AVAssetExportSession(asset: comp, presetName: AVAssetExportPresetHighestQuality) else {
            throw ExportError.cannotCreateSession
        }

        session.outputURL = outURL
        session.outputFileType = .mp4
        session.shouldOptimizeForNetworkUse = true
        if let vc = build.videoComposition {
            session.videoComposition = vc
        }

        await session.exportAsync()

        if session.status != .completed {
            let msg = session.error?.localizedDescription ?? "Unknown export error"
            throw NSError(domain: "ClipForge.Export", code: 1, userInfo: [NSLocalizedDescriptionKey: msg])
        }

        return outURL
    }
}

extension AVAssetExportSession {
    func exportAsync() async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            exportAsynchronously {
                cont.resume(returning: ())
            }
        }
    }
}
