import Foundation

struct MediaAsset: Identifiable, Equatable {
    var id: UUID = UUID()
    var url: URL
    var createdAt: Date = Date()
    var duration: Double
    var displayName: String
    var relativePath: String

    var durationText: String { TimeFormat.hhmmss(duration) }
}
