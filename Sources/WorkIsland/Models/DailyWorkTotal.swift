import Foundation

struct DailyWorkTotal: Identifiable, Equatable {
    let day: Date
    let duration: TimeInterval

    var id: Date { day }
}
