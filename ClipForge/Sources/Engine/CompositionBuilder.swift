import Foundation
import AVFoundation
import UIKit

struct CompositionBuild {
    let composition: AVMutableComposition
    let renderSize: CGSize
}

final class CompositionBuilder {

    func buildComposition(sequence: Sequence) throws -> CompositionBuild {
        let composition = AVMutableComposition()

        // Build composition tracks per timeline track
        var videoTrackMap: [UUID: AVMutableCompositionTrack] = [:]
        var audioTrackMap: [UUID: AVMutableCompositionTrack] = [:]

        for track in sequence.tracks {
            switch track.kind {
            case .video:
                if let t = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) {
                    videoTrackMap[track.id] = t
                }
            case .audio:
                if let t = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
                    audioTrackMap[track.id] = t
                }
            default:
                break
            }
        }

        var firstVideoNatural: CGSize?
        var firstVideoTransform: CGAffineTransform = .identity

        // Insert clips
        let clips = sequence.clips.sorted { $0.startTime < $1.startTime }
        for clip in clips {
            guard let url = clip.mediaURL else { continue }
            let asset = AVAsset(url: url)

            let insertAt = CMTime(seconds: clip.startTime, preferredTimescale: 600)
            let srcStart = CMTime(seconds: clip.sourceStart, preferredTimescale: 600)
            let srcDur = CMTime(seconds: min(clip.duration, clip.sourceDuration), preferredTimescale: 600)
            let srcRange = CMTimeRange(start: srcStart, duration: srcDur)

            switch clip.kind {
            case .video:
                guard let srcV = asset.tracks(withMediaType: .video).first else { continue }
                // capture render size from first video
                if firstVideoNatural == nil {
                    firstVideoTransform = srcV.preferredTransform
                    firstVideoNatural = srcV.naturalSize
                }
                guard let dst = videoTrackMap[clip.trackID] else { continue }
                try? dst.insertTimeRange(srcRange, of: srcV, at: insertAt)

                // also include audio if present and user didn’t add separate audio clip
                if let srcA = asset.tracks(withMediaType: .audio).first,
                   let audioDst = audioTrackMap.first?.value {
                    try? audioDst.insertTimeRange(srcRange, of: srcA, at: insertAt)
                }

            case .audio:
                guard let srcA = asset.tracks(withMediaType: .audio).first else { continue }
                guard let dst = audioTrackMap[clip.trackID] else { continue }
                try? dst.insertTimeRange(srcRange, of: srcA, at: insertAt)

            default:
                break
            }
        }

        let renderSize = computeRenderSize(natural: firstVideoNatural ?? CGSize(width: 1920, height: 1080),
                                          preferredTransform: firstVideoTransform)

        return CompositionBuild(composition: composition, renderSize: renderSize)
    }

    private func computeRenderSize(natural: CGSize, preferredTransform: CGAffineTransform) -> CGSize {
        // Basic orientation fix: if rotated 90°, swap width/height
        let isPortrait = abs(preferredTransform.b) == 1 && abs(preferredTransform.c) == 1
        if isPortrait {
            return CGSize(width: natural.height, height: natural.width)
        }
        return natural
    }
}
