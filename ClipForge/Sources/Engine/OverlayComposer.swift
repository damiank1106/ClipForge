import Foundation
import AVFoundation
import UIKit

/// Overlays (titles, stickers, captions) for export.
/// Starter: demonstrates where overlays go; production requires timeline-sync + animations.
final class OverlayComposer {

    struct OverlayItem {
        var start: Double
        var duration: Double
        var kind: String // "text", "image"
        var text: String?
    }

    func makeCoreAnimationTool(renderSize: CGSize, overlays: [OverlayItem]) -> AVVideoCompositionCoreAnimationTool {
        let parent = CALayer()
        parent.frame = CGRect(origin: .zero, size: renderSize)

        let videoLayer = CALayer()
        videoLayer.frame = parent.frame
        parent.addSublayer(videoLayer)

        let overlayLayer = CALayer()
        overlayLayer.frame = parent.frame
        parent.addSublayer(overlayLayer)

        // Example: static watermark (replace with timeline-driven overlays)
        let label = CATextLayer()
        label.string = "ClipForge"
        label.fontSize = 32
        label.opacity = 0.35
        label.alignmentMode = .right
        label.frame = CGRect(x: 0, y: 20, width: renderSize.width - 20, height: 44)
        overlayLayer.addSublayer(label)

        return AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: parent)
    }
}
