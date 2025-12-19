import Foundation
import CoreGraphics

struct Clip: Codable, Identifiable, Equatable {
    enum Kind: String, Codable { case video, audio, title, sticker }

    var id: UUID
    var kind: Kind
    var trackID: UUID
    var name: String

    // Timeline
    var startTime: Double
    var duration: Double

    // Source trimming (time inside the original media)
    var sourceStart: Double
    var sourceDuration: Double

    // Media reference (local file inside Documents/Media)
    var mediaRelativePath: String?

    // Basic visual params (scaffold for keyframes)
    var opacity: Double = 1.0
    var transform: CGAffineTransformCodable = .identity

    // Effects (simple "primary filter" for now)
    var primaryFilter: EditorFilter? = nil

    // Keyframes (scaffold)
    var opacityKeyframes: KeyframedDouble? = nil
    var transformKeyframes: KeyframedTransform? = nil

    static func makeFromMedia(asset: MediaAsset, trackID: UUID, startTime: Double) -> Clip {
        Clip(
            id: UUID(),
            kind: .video,
            trackID: trackID,
            name: asset.displayName,
            startTime: startTime,
            duration: asset.duration,
            sourceStart: 0,
            sourceDuration: asset.duration,
            mediaRelativePath: asset.relativePath,
            opacity: 1.0,
            transform: .identity,
            primaryFilter: nil,
            opacityKeyframes: nil,
            transformKeyframes: nil
        )
    }

    var mediaURL: URL? {
        guard let rel = mediaRelativePath else { return nil }
        return AppPaths.mediaDir.appendingPathComponent(rel)
    }

    // Hint: used to compute topmost clip ordering when compositing.
    // This demo uses track ordering from Sequence.tracks; if unavailable, 0.
    var trackIndexHint: Int = 0
}
