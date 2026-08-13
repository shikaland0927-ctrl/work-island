import Foundation

struct WorkTask: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    let createdAt: Date
    var isArchived: Bool
    var sortOrder: Int?

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        isArchived: Bool = false,
        sortOrder: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.isArchived = isArchived
        self.sortOrder = sortOrder
    }
}
