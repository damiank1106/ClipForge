import Foundation
import Speech
import AVFoundation

enum CaptionError: Error {
    case notAuthorized
    case recognitionFailed
    case audioExportFailed
}

final class CaptionService {
    @MainActor
    func transcribeToSRT(url: URL) async throws -> String {
        let auth = await SFSpeechRecognizer.requestAuthorizationAsync()
        guard auth == .authorized else { throw CaptionError.notAuthorized }

        // Extract audio to M4A for recognition (more reliable)
        let audioURL = try await exportAudio(from: url)

        guard let recognizer = SFSpeechRecognizer() else {
            throw CaptionError.recognitionFailed
        }

        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = false

        let result = try await recognizer.recognitionAsync(request: request)
        let segments = result.bestTranscription.segments

        // Convert segments to a simple SRT (one line per ~3 seconds)
        return SRTWriter.makeSRT(from: segments)
    }

    private func exportAudio(from videoURL: URL) async throws -> URL {
        let asset = AVAsset(url: videoURL)
        let outURL = AppPaths.uniqueFileURL(in: AppPaths.exportsDir, ext: "m4a")
        if FileManager.default.fileExists(atPath: outURL.path) {
            try? FileManager.default.removeItem(at: outURL)
        }

        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw CaptionError.audioExportFailed
        }
        session.outputURL = outURL
        session.outputFileType = .m4a

        try await session.exportAsync()
        if session.status != .completed {
            throw CaptionError.audioExportFailed
        }
        return outURL
    }
}

extension SFSpeechRecognizer {
    func recognitionAsync(request: SFSpeechRecognitionRequest) async throws -> SFSpeechRecognitionResult {
        try await withCheckedThrowingContinuation { cont in
            self.recognitionTask(with: request) { result, error in
                if let error = error {
                    cont.resume(throwing: error)
                    return
                }
                if let result = result, result.isFinal {
                    cont.resume(returning: result)
                }
            }
        }
    }
}

extension SFSpeechRecognizerAuthorizationStatus {
    var isAuthorized: Bool { self == .authorized }
}

extension SFSpeechRecognizer {
    static func requestAuthorizationAsync() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status)
            }
        }
    }
}

enum SRTWriter {
    static func makeSRT(from segments: [SFTranscriptionSegment]) -> String {
        // Group segments into ~3s chunks
        let chunkSeconds: Double = 3.0
        var blocks: [(start: Double, end: Double, text: String)] = []
        var currentStart: Double?
        var currentEnd: Double = 0
        var words: [String] = []

        func flush() {
            guard let s = currentStart, !words.isEmpty else { return }
            blocks.append((s, currentEnd, words.joined(separator: " ")))
            currentStart = nil
            currentEnd = 0
            words.removeAll()
        }

        for seg in segments {
            if currentStart == nil { currentStart = seg.timestamp }
            currentEnd = seg.timestamp + seg.duration
            words.append(seg.substring)

            if let s = currentStart, (currentEnd - s) >= chunkSeconds {
                flush()
            }
        }
        flush()

        var out: [String] = []
        for (i, b) in blocks.enumerated() {
            out.append(String(i + 1))
            out.append("\(timecode(b.start)) --> \(timecode(b.end))")
            out.append(b.text)
            out.append("")
        }
        return out.joined(separator: "\n")
    }

    private static func timecode(_ seconds: Double) -> String {
        let msTotal = max(0, Int((seconds * 1000).rounded()))
        let ms = msTotal % 1000
        let total = msTotal / 1000
        let s = total % 60
        let m = (total / 60) % 60
        let h = total / 3600
        return String(format: "%02d:%02d:%02d,%03d", h, m, s, ms)
    }
}
