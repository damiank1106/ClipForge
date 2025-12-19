import Foundation
import AVFoundation

final class ProxyService {
    /// Create a smaller proxy for smoother editing. (Starter implementation)
    func createProxyIfNeeded(for mediaURL: URL) async throws -> URL {
        // For a real editor: store proxies in a cache folder, map originals→proxy, validate.
        let outURL = AppPaths.uniqueFileURL(in: AppPaths.mediaDir, ext: "proxy.mp4")

        let asset = AVAsset(url: mediaURL)
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPreset1280x720) else {
            return mediaURL
        }
        session.outputURL = outURL
        session.outputFileType = .mp4
        session.shouldOptimizeForNetworkUse = true

        try await session.export()
        if session.status == .completed {
            return outURL
        }
        return mediaURL
    }
}
