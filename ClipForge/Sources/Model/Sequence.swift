import Foundation

struct Sequence: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var timebase: Timebase
    var tracks: [Track]
    var clips: [Clip]
    var globalFilter: EditorFilter? = nil

    static func makeDefault() -> Sequence {
        let videoTrack = Track(id: UUID(), kind: .video, index: 0, displayName: "Video 1")
        let audioTrack = Track(id: UUID(), kind: .audio, index: 0, displayName: "Audio 1")
        let titleTrack = Track(id: UUID(), kind: .title, index: 0, displayName: "Titles")
        return Sequence(
            id: UUID(),
            name: "Main",
            timebase: .init(frameRate: 30),
            tracks: [videoTrack, audioTrack, titleTrack],
            clips: []
        )
    }

    func activeClips(at time: Double) -> [Clip] {
        clips.filter { time >= $0.startTime && time < ($0.startTime + $0.duration) }
    }

    /// Topmost video clip (highest track index) at time
    func topVideoClip(at time: Double) -> Clip? {
        let active = activeClips(at: time).filter { $0.kind == .video }
        return active.sorted { $0.trackIndexHint < $1.trackIndexHint }.last
    }

    var duration: Double {
        max(0.01, clips.map { $0.startTime + $0.duration }.max() ?? 0.01)
    }
}

struct Timebase: Codable, Equatable {
    var frameRate: Int
}
