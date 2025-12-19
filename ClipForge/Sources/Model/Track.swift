import Foundation

struct Track: Codable, Identifiable, Equatable {
    enum Kind: String, Codable {
        case video, audio, title, sticker
    }

    var id: UUID
    var kind: Kind
    var index: Int
    var displayName: String

    var kindLabel: String {
        switch kind {
        case .video: return "Video"
        case .audio: return "Audio"
        case .title: return "Title"
        case .sticker: return "Sticker"
        }
    }
}
