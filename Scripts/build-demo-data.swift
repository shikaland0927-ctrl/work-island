import Foundation

struct WorkTask: Codable {
    let id: UUID
    var name: String
    let createdAt: Date
    var isArchived: Bool
}

struct WorkSegment: Codable {
    let startedAt: Date
    let endedAt: Date
}

struct WorkSession: Codable {
    let id: UUID
    var taskID: UUID?
    var subject: String
    var note: String
    let startedAt: Date
    let endedAt: Date
    let segments: [WorkSegment]
}

struct ActiveWork: Codable {
    let id: UUID
    var taskID: UUID?
    var subject: String
    var note: String
    let startedAt: Date
    var completedSegments: [WorkSegment]
    var runningSince: Date?
}

struct PersistedState: Codable {
    let schemaVersion: Int
    var sessions: [WorkSession]
    let tasks: [WorkTask]
    let selectedTaskID: UUID?
    let activeWork: ActiveWork?
    let draftSubject: String
    let draftNote: String
}

struct DemoSession {
    let number: Int
    let task: String
    let startedAt: String
    let minutes: Int
    let note: String
}

let demoSessions: [DemoSession] = [
    .init(number: 1, task: "App Development", startedAt: "2026-08-02T22:30:00Z", minutes: 90, note: "Polished the dashboard layout"),
    .init(number: 2, task: "Thesis", startedAt: "2026-08-03T01:00:00Z", minutes: 45, note: "Reviewed related work"),
    .init(number: 3, task: "Math", startedAt: "2026-08-03T02:30:00Z", minutes: 60, note: "Solved differential equations"),
    .init(number: 4, task: "Planning", startedAt: "2026-08-03T05:00:00Z", minutes: 30, note: "Outlined the next milestone"),
    .init(number: 5, task: "App Development", startedAt: "2026-08-01T23:30:00Z", minutes: 120, note: "Implemented the main interaction flow"),
    .init(number: 6, task: "Math", startedAt: "2026-08-02T03:30:00Z", minutes: 60, note: "Practiced linear algebra"),
    .init(number: 7, task: "Thesis", startedAt: "2026-08-02T06:00:00Z", minutes: 75, note: "Refined the literature review"),
    .init(number: 8, task: "App Development", startedAt: "2026-08-01T00:00:00Z", minutes: 90, note: "Improved local persistence"),
    .init(number: 9, task: "Planning", startedAt: "2026-08-01T02:00:00Z", minutes: 45, note: "Prioritized the release checklist"),
    .init(number: 10, task: "Math", startedAt: "2026-08-01T04:00:00Z", minutes: 75, note: "Reviewed probability exercises"),
    .init(number: 11, task: "Thesis", startedAt: "2026-07-30T23:00:00Z", minutes: 90, note: "Drafted the methodology section"),
    .init(number: 12, task: "Math", startedAt: "2026-07-31T01:30:00Z", minutes: 60, note: "Checked proof details"),
    .init(number: 13, task: "App Development", startedAt: "2026-07-31T04:00:00Z", minutes: 120, note: "Built and verified analytics views"),
    .init(number: 14, task: "App Development", startedAt: "2026-07-30T00:00:00Z", minutes: 75, note: "Improved History details"),
    .init(number: 15, task: "Thesis", startedAt: "2026-07-30T05:00:00Z", minutes: 45, note: "Organized research notes"),
    .init(number: 16, task: "Math", startedAt: "2026-07-29T01:00:00Z", minutes: 90, note: "Practiced numerical methods"),
    .init(number: 17, task: "Planning", startedAt: "2026-07-29T04:00:00Z", minutes: 30, note: "Planned the rest of the week"),
    .init(number: 18, task: "Thesis", startedAt: "2026-07-28T05:00:00Z", minutes: 60, note: "Reviewed source material"),
    .init(number: 19, task: "Math", startedAt: "2026-07-28T06:30:00Z", minutes: 45, note: "Worked through calculus problems"),
    .init(number: 20, task: "Planning", startedAt: "2026-07-27T00:30:00Z", minutes: 45, note: "Defined the weekly priorities"),
    .init(number: 21, task: "Math", startedAt: "2026-07-26T00:30:00Z", minutes: 90, note: "Reviewed key formulas"),
    .init(number: 22, task: "App Development", startedAt: "2026-07-25T01:00:00Z", minutes: 120, note: "Completed the task library update"),
    .init(number: 23, task: "Math", startedAt: "2026-07-22T02:00:00Z", minutes: 60, note: "Solved a practice set"),
    .init(number: 24, task: "Thesis", startedAt: "2026-07-22T23:30:00Z", minutes: 90, note: "Compared reference frameworks"),
    .init(number: 25, task: "App Development", startedAt: "2026-07-20T04:00:00Z", minutes: 135, note: "Stabilized notch hover behavior"),
    .init(number: 26, task: "Planning", startedAt: "2026-07-18T01:00:00Z", minutes: 60, note: "Organized release milestones"),
    .init(number: 27, task: "Math", startedAt: "2026-07-17T00:00:00Z", minutes: 75, note: "Reviewed linear algebra notes"),
    .init(number: 28, task: "Thesis", startedAt: "2026-07-16T05:00:00Z", minutes: 120, note: "Revised the discussion outline"),
    .init(number: 29, task: "App Development", startedAt: "2026-07-14T00:00:00Z", minutes: 90, note: "Added backup import and export"),
    .init(number: 30, task: "Planning", startedAt: "2026-07-11T02:00:00Z", minutes: 75, note: "Planned the first public release"),
    .init(number: 31, task: "Math", startedAt: "2026-07-10T04:00:00Z", minutes: 90, note: "Summarized the chapter"),
    .init(number: 32, task: "App Development", startedAt: "2026-07-08T23:00:00Z", minutes: 120, note: "Improved launch reliability"),
    .init(number: 33, task: "Thesis", startedAt: "2026-07-06T04:00:00Z", minutes: 90, note: "Synthesized research findings"),
    .init(number: 34, task: "App Development", startedAt: "2026-06-30T01:00:00Z", minutes: 90, note: "Focused development session"),
    .init(number: 35, task: "Thesis", startedAt: "2026-06-27T03:00:00Z", minutes: 75, note: "Reviewed thesis material"),
    .init(number: 36, task: "Math", startedAt: "2026-06-24T00:30:00Z", minutes: 60, note: "Practice and review"),
    .init(number: 37, task: "Planning", startedAt: "2026-06-20T02:00:00Z", minutes: 45, note: "Weekly planning"),
    .init(number: 38, task: "App Development", startedAt: "2026-06-17T04:00:00Z", minutes: 105, note: "Focused development session"),
    .init(number: 39, task: "Thesis", startedAt: "2026-06-13T01:00:00Z", minutes: 90, note: "Reviewed thesis material"),
    .init(number: 40, task: "Math", startedAt: "2026-06-10T05:00:00Z", minutes: 75, note: "Practice and review"),
    .init(number: 41, task: "Planning", startedAt: "2026-06-06T02:30:00Z", minutes: 60, note: "Weekly planning"),
    .init(number: 42, task: "App Development", startedAt: "2026-06-03T00:00:00Z", minutes: 120, note: "Focused development session"),
    .init(number: 43, task: "Thesis", startedAt: "2026-05-29T03:00:00Z", minutes: 80, note: "Reviewed thesis material"),
    .init(number: 44, task: "Math", startedAt: "2026-05-25T01:00:00Z", minutes: 60, note: "Practice and review"),
    .init(number: 45, task: "Planning", startedAt: "2026-05-21T04:00:00Z", minutes: 45, note: "Weekly planning"),
    .init(number: 46, task: "App Development", startedAt: "2026-05-16T00:30:00Z", minutes: 100, note: "Focused development session"),
    .init(number: 47, task: "Thesis", startedAt: "2026-05-12T05:00:00Z", minutes: 90, note: "Reviewed thesis material"),
    .init(number: 48, task: "Math", startedAt: "2026-05-07T02:00:00Z", minutes: 75, note: "Practice and review"),
    .init(number: 49, task: "Planning", startedAt: "2026-05-02T01:00:00Z", minutes: 60, note: "Weekly planning"),
    .init(number: 50, task: "App Development", startedAt: "2026-04-27T03:30:00Z", minutes: 90, note: "Focused development session"),
    .init(number: 51, task: "Thesis", startedAt: "2026-04-21T00:00:00Z", minutes: 105, note: "Reviewed thesis material"),
    .init(number: 52, task: "Math", startedAt: "2026-04-15T04:00:00Z", minutes: 60, note: "Practice and review"),
    .init(number: 53, task: "Planning", startedAt: "2026-04-09T01:30:00Z", minutes: 45, note: "Weekly planning"),
    .init(number: 54, task: "App Development", startedAt: "2026-04-03T02:00:00Z", minutes: 120, note: "Focused development session"),
    .init(number: 55, task: "Thesis", startedAt: "2026-03-28T05:00:00Z", minutes: 90, note: "Reviewed thesis material"),
    .init(number: 56, task: "Math", startedAt: "2026-03-22T01:00:00Z", minutes: 75, note: "Practice and review"),
    .init(number: 57, task: "Planning", startedAt: "2026-03-16T03:00:00Z", minutes: 60, note: "Weekly planning"),
    .init(number: 58, task: "App Development", startedAt: "2026-03-10T00:30:00Z", minutes: 105, note: "Focused development session"),
    .init(number: 59, task: "Thesis", startedAt: "2026-03-04T04:00:00Z", minutes: 90, note: "Reviewed thesis material")
]

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("Demo data error: \(message)\n".utf8))
    exit(1)
}

guard CommandLine.arguments.count == 3 else {
    fail("usage: swift Scripts/build-demo-data.swift <input.json> <output.json>")
}

let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
let decoder = JSONDecoder()
decoder.dateDecodingStrategy = .iso8601

var state: PersistedState
do {
    state = try decoder.decode(PersistedState.self, from: Data(contentsOf: inputURL))
} catch {
    fail("could not decode input: \(error.localizedDescription)")
}

let taskByName = Dictionary(
    uniqueKeysWithValues: state.tasks.map { ($0.name.lowercased(), $0) }
)
let requiredTasks = Set(demoSessions.map { $0.task.lowercased() })
let missingTasks = requiredTasks.subtracting(taskByName.keys).sorted()
guard missingTasks.isEmpty else {
    fail("missing tasks: \(missingTasks.joined(separator: ", "))")
}

let formatter = ISO8601DateFormatter()
let demoIDs = Set(demoSessions.compactMap {
    UUID(uuidString: String(format: "D3A00000-0000-4000-8000-%012d", $0.number))
})
state.sessions.removeAll { demoIDs.contains($0.id) }

for spec in demoSessions {
    guard let task = taskByName[spec.task.lowercased()] else {
        fail("task disappeared while building data: \(spec.task)")
    }
    guard let id = UUID(
        uuidString: String(format: "D3A00000-0000-4000-8000-%012d", spec.number)
    ) else {
        fail("invalid UUID for demo session \(spec.number)")
    }
    guard let startedAt = formatter.date(from: spec.startedAt) else {
        fail("invalid date for demo session \(spec.number): \(spec.startedAt)")
    }

    let endedAt = startedAt.addingTimeInterval(TimeInterval(spec.minutes * 60))
    state.sessions.append(
        WorkSession(
            id: id,
            taskID: task.id,
            subject: task.name,
            note: spec.note,
            startedAt: startedAt,
            endedAt: endedAt,
            segments: [WorkSegment(startedAt: startedAt, endedAt: endedAt)]
        )
    )
}

state.sessions.sort { $0.endedAt > $1.endedAt }

do {
    try FileManager.default.createDirectory(
        at: outputURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(state).write(to: outputURL, options: .atomic)
    print("Prepared \(state.sessions.count) records at \(outputURL.path)")
} catch {
    fail("could not write output: \(error.localizedDescription)")
}
