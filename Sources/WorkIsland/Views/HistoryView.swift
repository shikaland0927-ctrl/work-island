import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var store: WorkTimerStore

    var body: some View {
        MainPageScrollContainer(
            maximumContentWidth: MainPageLayout.standardMaximumContentWidth
        ) {
            LazyVStack(alignment: .leading, spacing: 14) {
                summary

                if store.sessions.isEmpty {
                    EmptyHistoryCard(
                        systemImage: "clock.badge.questionmark",
                        message: "Finished work records will appear here."
                    )
                } else {
                    ForEach(store.sessions) { session in
                        HistorySessionCard(session: session)
                            .environmentObject(store)
                    }
                }
            }
        }
        .navigationTitle("History")
    }

    private var summary: some View {
        let completedDuration = store.sessions.reduce(0) { $0 + $1.totalDuration }

        return HStack {
            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(store.sessions.count) \(store.sessions.count == 1 ? "record" : "records")")
                    .font(.subheadline.weight(.semibold))
                Text(WorkFormatting.readable(completedDuration))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.bottom, 6)
    }
}

private struct HistorySessionCard: View {
    @EnvironmentObject private var store: WorkTimerStore
    let session: WorkSession

    @State private var isEditing = false
    @State private var draftNote: String
    @State private var editAnchor: SessionTimeAnchor
    @State private var editTimestamp: Date
    @State private var editHours: Int
    @State private var editMinutes: Int
    @State private var editMessage: String?
    @State private var isConfirmingDelete = false

    init(session: WorkSession) {
        let durationFields = Self.durationFields(for: session.totalDuration)

        self.session = session
        _draftNote = State(initialValue: session.note)
        _editAnchor = State(initialValue: .end)
        _editTimestamp = State(
            initialValue: SessionInputTime.minutePrecision(session.endedAt)
        )
        _editHours = State(initialValue: durationFields.hours)
        _editMinutes = State(initialValue: durationFields.minutes)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(
                        TaskColorPalette.color(
                            for: session.taskID,
                            name: session.subject
                        )
                    )
                    .frame(width: 6, height: itemTitle == nil ? 44 : 60)

                VStack(alignment: .leading, spacing: 4) {
                    Text(session.subject)
                        .font(.headline)
                        .lineLimit(1)

                    if let itemTitle {
                        Label(itemTitle, systemImage: itemKind?.systemImage ?? "checkmark.circle")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Text(timeRange)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(dateLabel)
                        .font(.subheadline.weight(.medium))
                    Text(WorkFormatting.readable(session.totalDuration))
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        Button {
                            resetEditor(using: session)
                            isEditing = true
                        } label: {
                            Label("Edit", systemImage: "square.and.pencil")
                                .labelStyle(.iconOnly)
                        }
                        .buttonStyle(.borderless)
                        .disabled(isEditing)
                        .hoverHelp("Edit")

                        Button(role: .destructive) {
                            isConfirmingDelete = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                                .labelStyle(.iconOnly)
                        }
                        .buttonStyle(.borderless)
                        .hoverHelp("Delete")
                    }
                }
            }

            if isEditing {
                Divider()
                editor
            } else if !session.note.isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: 5) {
                    Text("NOTE")
                        .font(.caption2.weight(.bold))
                        .tracking(0.5)
                        .foregroundStyle(.secondary)

                    Text(session.note)
                        .font(.subheadline)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(18)
        .workCard()
        .onChange(of: session) { updatedSession in
            if !isEditing {
                resetEditor(using: updatedSession)
            }
        }
        .confirmationDialog(
            "Delete this work record?",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete Record", role: .destructive) {
                store.deleteSession(id: session.id)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Note")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                TextEditor(text: $draftNote)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(minHeight: 92)
                    .background(
                        Color(nsColor: .textBackgroundColor),
                        in: RoundedRectangle(cornerRadius: 9)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 9)
                            .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                    }
            }

            Divider()

            SessionInputControls(
                timestamp: $editTimestamp,
                anchor: $editAnchor,
                hours: $editHours,
                minutes: $editMinutes
            )
            .onChange(of: editTimestamp) { _ in
                editMessage = nil
            }
            .onChange(of: editAnchor) { _ in
                editMessage = nil
            }
            .onChange(of: editHours) { _ in
                editMessage = nil
            }
            .onChange(of: editMinutes) { _ in
                editMessage = nil
            }

            if let editMessage {
                Text(editMessage)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.red)
            }

            HStack(spacing: 8) {
                Spacer()

                Button("Cancel") {
                    resetEditor(using: session)
                    isEditing = false
                }
                .workGlassSecondaryButtonStyle()

                Button("Save") {
                    saveEdits()
                }
                .workProminentButtonStyle()
                .tint(.indigo)
                .disabled(hasTimingChanges && editDuration <= 0)
            }
        }
    }

    private var editDuration: TimeInterval {
        ManualDurationOptions.duration(
            hours: editHours,
            minutes: editMinutes
        )
    }

    private var itemTitle: String? {
        session.activityItemTitle
            ?? session.activityItemID.flatMap { store.activityItem(id: $0)?.title }
    }

    private var itemKind: ActivityItemKind? {
        session.activityItemKind
            ?? session.activityItemID.flatMap { store.activityItem(id: $0)?.kind }
    }

    private var hasTimingChanges: Bool {
        let originalFields = Self.durationFields(for: session.totalDuration)
        let originalDuration = ManualDurationOptions.duration(
            hours: originalFields.hours,
            minutes: originalFields.minutes
        )

        return editAnchor != .end
            || editTimestamp != SessionInputTime.minutePrecision(session.endedAt)
            || editDuration != originalDuration
    }

    private func saveEdits() {
        let didSave: Bool

        if hasTimingChanges {
            didSave = store.updateSession(
                id: session.id,
                note: draftNote,
                anchorDate: editTimestamp,
                duration: editDuration,
                anchor: editAnchor
            )
        } else {
            didSave = store.updateSession(id: session.id, note: draftNote)
        }

        if didSave {
            editMessage = nil
            isEditing = false
        } else {
            editMessage = "Not saved"
        }
    }

    private func resetEditor(using source: WorkSession) {
        let durationFields = Self.durationFields(for: source.totalDuration)

        draftNote = source.note
        editAnchor = .end
        editTimestamp = SessionInputTime.minutePrecision(source.endedAt)
        editHours = durationFields.hours
        editMinutes = durationFields.minutes
        editMessage = nil
    }

    private static func durationFields(
        for duration: TimeInterval
    ) -> (hours: Int, minutes: Int) {
        let maximumHours = ManualDurationOptions.hours.last ?? 24
        let maximumMinutes = (maximumHours * 60) + 59
        let roundedMinutes = Int((duration / 60).rounded())
        let totalMinutes = min(maximumMinutes, max(1, roundedMinutes))

        if totalMinutes > maximumHours * 60 {
            return (maximumHours, totalMinutes - (maximumHours * 60))
        }

        return (totalMinutes / 60, totalMinutes % 60)
    }

    private var dateLabel: String {
        WorkFormatting.compactDate(session.endedAt)
    }

    private var timeRange: String {
        "\(WorkFormatting.time(session.startedAt)) – \(WorkFormatting.time(session.endedAt))"
    }
}

struct HistoryMetricCard: View {
    let title: String
    let value: String
    let detail: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .lineLimit(1)

            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
        .workCard()
    }
}

struct EmptyHistoryCard: View {
    let systemImage: String
    let message: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(22)
        .frame(maxWidth: .infinity, minHeight: 86, alignment: .leading)
        .workCard()
    }
}
