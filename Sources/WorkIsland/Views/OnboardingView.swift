import AppKit
import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var store: WorkTimerStore
    @EnvironmentObject private var preferences: AppPreferences
    @EnvironmentObject private var launchAtLogin: LaunchAtLoginController

    @State private var activityName = "Work"
    @State private var opensAtLogin = true

    var body: some View {
        VStack(spacing: 24) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 78, height: 78)
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text("Set Up Work Island")
                    .font(.title2.weight(.semibold))
                Text("Track time from your Mac's notch.")
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("First Activity")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    TextField("e.g. Study, Thesis, Client work", text: $activityName)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(complete)
                }

                Toggle("Launch at Login", isOn: $opensAtLogin)

                Text("You can change these anytime in Settings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 360)

            Button(action: complete) {
                Text("Continue")
                    .frame(minWidth: 96)
            }
            .workProminentButtonStyle()
            .controlSize(.large)
            .tint(.indigo)
            .disabled(cleanedActivityName.isEmpty)
            .keyboardShortcut(.defaultAction)
        }
        .padding(34)
        .frame(width: 480)
        .interactiveDismissDisabled()
        .onAppear {
            activityName = store.selectedTask?.name ?? "Work"
            opensAtLogin = launchAtLogin.isEnabled || !store.startedWithExistingData
        }
    }

    private var cleanedActivityName: String {
        activityName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func complete() {
        guard !cleanedActivityName.isEmpty else {
            return
        }

        if let selectedTaskID = store.selectedTaskID {
            if !store.renameTask(id: selectedTaskID, to: cleanedActivityName) {
                _ = store.addTask(named: cleanedActivityName)
            }
        } else {
            _ = store.addTask(named: cleanedActivityName)
        }

        _ = launchAtLogin.setEnabled(opensAtLogin)
        preferences.completeOnboarding()
    }
}
