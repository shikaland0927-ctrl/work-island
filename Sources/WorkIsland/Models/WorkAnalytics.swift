import Foundation

struct DailyTaskWorkTotal: Identifiable, Equatable {
    struct ID: Hashable {
        let day: Date
        let taskID: UUID
    }

    let day: Date
    let taskID: UUID
    let taskName: String
    let duration: TimeInterval

    var id: ID {
        ID(day: day, taskID: taskID)
    }
}

struct TaskWorkTotal: Identifiable, Equatable {
    let taskID: UUID
    let taskName: String
    let duration: TimeInterval

    var id: UUID { taskID }
}

struct DashboardStats: Equatable {
    let currentStreak: Int
    let longestStreak: Int
    let bestDay: Date?
    let bestDayDuration: TimeInterval
}
