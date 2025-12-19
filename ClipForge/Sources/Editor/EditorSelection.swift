import Foundation

struct EditorSelection: Equatable, Codable {
    var selectedClipID: UUID? = nil

    mutating func select(clip: Clip) { selectedClipID = clip.id }
    mutating func clear() { selectedClipID = nil }
}
