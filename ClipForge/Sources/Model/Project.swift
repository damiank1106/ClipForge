import Foundation

struct Project: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date
    var sequences: [Sequence]

    static func makeNew(name: String) -> Project {
        let seq = Sequence.makeDefault()
        return Project(
            id: UUID(),
            name: name,
            createdAt: Date(),
            updatedAt: Date(),
            sequences: [seq]
        )
    }

    mutating func touch() { updatedAt = Date() }
}
