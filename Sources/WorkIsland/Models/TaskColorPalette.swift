import SwiftUI

enum TaskColorPalette {
    private static let colors: [Color] = [
        Color(red: 0.30, green: 0.56, blue: 0.98),
        Color(red: 0.46, green: 0.39, blue: 0.96),
        Color(red: 0.10, green: 0.70, blue: 0.66),
        Color(red: 0.98, green: 0.55, blue: 0.24),
        Color(red: 0.93, green: 0.34, blue: 0.55),
        Color(red: 0.24, green: 0.72, blue: 0.91),
        Color(red: 0.55, green: 0.76, blue: 0.24),
        Color(red: 0.73, green: 0.42, blue: 0.91),
        Color(red: 0.96, green: 0.72, blue: 0.20),
        Color(red: 0.20, green: 0.62, blue: 0.38)
    ]

    static func color(for taskID: UUID?, name: String) -> Color {
        colors[index(for: taskID, name: name)]
    }

    static func index(for taskID: UUID?, name: String) -> Int {
        let key = taskID?.uuidString.lowercased() ?? name.lowercased()
        var hash: UInt64 = 1_469_598_103_934_665_603

        for byte in key.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }

        return Int(hash % UInt64(colors.count))
    }
}
