import Foundation
import AVFoundation
import Accelerate

/// Generates waveforms for audio clips.
/// Starter: produces downsampled RMS buckets.
/// For production: caching, multichannel, zoom-level pyramids, beat detection.
final class WaveformService {
    struct Waveform {
        var samples: [Float] // 0...1
    }

    func makeWaveform(url: URL, buckets: Int = 800) async throws -> Waveform {
        let asset = AVAsset(url: url)
        guard let track = asset.tracks(withMediaType: .audio).first else {
            return Waveform(samples: [])
        }

        let reader = try AVAssetReader(asset: asset)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsNonInterleaved: false
        ]
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
        reader.add(output)
        reader.startReading()

        var floats: [Float] = []
        while reader.status == .reading, let sampleBuffer = output.copyNextSampleBuffer(),
              let block = CMSampleBufferGetDataBuffer(sampleBuffer) {
            var length = 0
            var dataPointer: UnsafeMutablePointer<Int8>?
            CMBlockBufferGetDataPointer(block, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &dataPointer)
            if let dataPointer {
                let count = length / MemoryLayout<Float>.size
                let ptr = dataPointer.withMemoryRebound(to: Float.self, capacity: count) { $0 }
                floats.append(contentsOf: UnsafeBufferPointer(start: ptr, count: count))
            }
            CMSampleBufferInvalidate(sampleBuffer)
        }

        if floats.isEmpty { return Waveform(samples: []) }

        let absVals = floats.map { abs($0) }
        let step = max(1, absVals.count / buckets)
        var out: [Float] = []
        out.reserveCapacity(buckets)

        for i in stride(from: 0, to: absVals.count, by: step) {
            let end = min(absVals.count, i + step)
            let slice = absVals[i..<end]
            var rms: Float = 0
            vDSP_rmsqv(Array(slice), 1, &rms, vDSP_Length(slice.count))
            out.append(min(1, rms))
        }

        // Normalize
        if let maxV = out.max(), maxV > 0 {
            out = out.map { $0 / maxV }
        }

        return Waveform(samples: out)
    }
}
