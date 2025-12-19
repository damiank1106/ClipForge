import Foundation
import AVFoundation
import CoreImage

enum EngineError: Error {
    case missingMedia
    case noVideo
}

struct PlayableBuild {
    let asset: AVAsset
    let videoComposition: AVVideoComposition?
}

@MainActor
final class EditorEngine {
    private let ciContext = CIContext(options: nil)

    func buildPlayableAsset(project: Project, sequence: Sequence) async throws -> PlayableBuild {
        let builder = CompositionBuilder()
        let built = try builder.buildComposition(sequence: sequence)

        // If there is NO video track, don't attach a videoComposition (prevents renderSize crash).
        if built.composition.tracks(withMediaType: .video).isEmpty {
            return PlayableBuild(asset: built.composition, videoComposition: nil)
        }

        let vc = try await makeFilterVideoComposition(asset: built.composition, sequence: sequence)

        // Safety: only use it if it has a valid size
        if vc.renderSize.width <= 0 || vc.renderSize.height <= 0 {
            return PlayableBuild(asset: built.composition, videoComposition: nil)
        }

        return PlayableBuild(asset: built.composition, videoComposition: vc)
    }

    private func makeFilterVideoComposition(asset: AVAsset, sequence: Sequence) async throws -> AVVideoComposition {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<AVVideoComposition, Error>) in
            AVVideoComposition.videoComposition(
                with: asset,
                applyingCIFiltersWithHandler: { [ciContext] request in
                    let t = request.compositionTime.seconds
                    let img = request.sourceImage.clampedToExtent()

                    let activeFilter = sequence.topVideoClip(at: t)?.primaryFilter ?? sequence.globalFilter
                    let out = VideoEffects.apply(filter: activeFilter, to: img) ?? img

                    request.finish(with: out.cropped(to: request.sourceImage.extent), context: ciContext)
                },
                completionHandler: { videoComposition, error in
                    if let videoComposition {
                        continuation.resume(returning: videoComposition)
                    } else {
                        continuation.resume(throwing: error ?? EngineError.noVideo)
                    }
                }
            )
        }
    }
}

