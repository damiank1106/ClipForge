import Foundation

enum EditorFilter: String, Codable, CaseIterable, Identifiable {
    case none
    case noir
    case chrome
    case instant
    case sepia
    case bloom
    case vivid
    case mono

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "None"
        case .noir: return "Noir"
        case .chrome: return "Chrome"
        case .instant: return "Instant"
        case .sepia: return "Sepia"
        case .bloom: return "Bloom"
        case .vivid: return "Vivid"
        case .mono: return "Mono"
        }
    }
}
