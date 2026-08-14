import AppKit
import Combine
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

enum ApplicationVisibilityPolicy {
    static func activationPolicy(
        mainWindowVisible: Bool
    ) -> NSApplication.ActivationPolicy {
        mainWindowVisible ? .regular : .accessory
    }
}

enum ApplicationQAConfiguration {
    static var showsGlassRefractionFixture: Bool {
        Bundle.main.object(
            forInfoDictionaryKey: "WorkIslandGlassRefractionFixture"
        ) as? Bool == true
    }
}

enum LaunchAtLoginPolicy {
    static func canManage(bundleURL: URL) -> Bool {
        bundleURL
            .deletingLastPathComponent()
            .standardizedFileURL
            .path == "/Applications"
    }
}

final class LaunchAtLoginController: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var requiresApproval = false
    @Published private(set) var errorMessage: String?

    let bundleURL: URL

    var canManage: Bool {
        LaunchAtLoginPolicy.canManage(bundleURL: bundleURL)
    }

    init(bundleURL: URL = Bundle.main.bundleURL) {
        self.bundleURL = bundleURL
        refresh()
    }

    func refresh() {
        guard canManage else {
            isEnabled = false
            requiresApproval = false
            return
        }

        let status = SMAppService.mainApp.status
        isEnabled = status == .enabled
        requiresApproval = status == .requiresApproval
    }

    @discardableResult
    func setEnabled(_ enabled: Bool) -> Bool {
        errorMessage = nil

        guard canManage else {
            errorMessage = "Move Work Island to Applications to change this setting."
            refresh()
            return false
        }

        let service = SMAppService.mainApp

        do {
            if enabled {
                switch service.status {
                case .enabled:
                    break
                case .notRegistered:
                    try service.register()
                case .requiresApproval:
                    errorMessage = "Allow Work Island in System Settings > General > Login Items."
                case .notFound:
                    errorMessage = "Launch at Login is not available for this copy."
                @unknown default:
                    errorMessage = "Launch at Login is not available right now."
                }
            } else if service.status == .enabled
                        || service.status == .requiresApproval {
                try service.unregister()
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        refresh()
        return enabled == isEnabled
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    typealias IslandPanelFactory = (
        WorkTimerStore,
        AppPreferences,
        @escaping () -> Void
    ) -> IslandPanelPresenting
    typealias MainWindowFactory = (
        WorkTimerStore,
        AppPreferences,
        LaunchAtLoginController
    ) -> NSWindow?

    let store: WorkTimerStore
    let preferences: AppPreferences
    let launchAtLogin: LaunchAtLoginController

    private let makeIslandPanel: IslandPanelFactory
    private let makeMainWindow: MainWindowFactory
    private var panelController: IslandPanelPresenting?
    private var mainWindow: NSWindow?
    private var mainWindowObservers: [NSObjectProtocol] = []
    private weak var settingsWindow: NSWindow?
    private var settingsWindowObservers: [NSObjectProtocol] = []
    private var glassRefractionBackdropWindow: NSWindow?

    override init() {
        store = WorkTimerStore()
        preferences = AppPreferences()
        launchAtLogin = LaunchAtLoginController()
        makeIslandPanel = Self.defaultIslandPanel
        makeMainWindow = Self.defaultMainWindow
        super.init()
    }

    init(
        store: WorkTimerStore,
        preferences: AppPreferences,
        launchAtLogin: LaunchAtLoginController,
        makeIslandPanel: @escaping IslandPanelFactory,
        makeMainWindow: @escaping MainWindowFactory = { _, _, _ in nil }
    ) {
        self.store = store
        self.preferences = preferences
        self.launchAtLogin = launchAtLogin
        self.makeIslandPanel = makeIslandPanel
        self.makeMainWindow = makeMainWindow
        super.init()
    }

    deinit {
        removeMainWindowObservers()
        removeSettingsWindowObservers()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        ProcessInfo.processInfo.disableAutomaticTermination(
            "Work Island keeps its timer and notch available in the background."
        )

        preferences.prepareForLaunch(
            hadExistingData: store.startedWithExistingData
        )

        if panelController == nil {
            let controller = makeIslandPanel(
                store,
                preferences
            ) { [weak self] in
                self?.showMainWindow()
            }
            panelController = controller
            controller.show()
        }
    }

    func registerMainWindow(_ window: NSWindow?) {
        guard let window, !(window is NSPanel) else {
            return
        }

        if mainWindow !== window {
            removeMainWindowObservers()
            mainWindow = window
            observeMainWindow(window)
        }

        window.isReleasedWhenClosed = false
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        if ApplicationQAConfiguration.showsGlassRefractionFixture {
            configureGlassRefractionFixture(window: window)
        }
        updateApplicationVisibility()
    }

    func registerSettingsWindow(_ window: NSWindow?) {
        guard let window,
              !(window is NSPanel),
              window !== mainWindow else {
            return
        }

        if settingsWindow !== window {
            removeSettingsWindowObservers()
            settingsWindow = window
            observeSettingsWindow(window)
        }

        updateApplicationVisibility()
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        showMainWindow()
        return false
    }

    func applicationShouldTerminateAfterLastWindowClosed(
        _ sender: NSApplication
    ) -> Bool {
        false
    }

    func importData() {
        guard store.activeWork == nil else {
            showAlert(
                title: "Timer Active",
                message: "Finish or discard the current timer before importing."
            )
            return
        }

        let panel = NSOpenPanel()
        panel.title = "Import"
        panel.prompt = "Import"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        let confirmation = NSAlert()
        confirmation.alertStyle = .warning
        confirmation.messageText = "Replace current data?"
        confirmation.informativeText = "Importing replaces the current activities and records. Work Island saves a local backup first."
        confirmation.addButton(withTitle: "Import")
        confirmation.addButton(withTitle: "Cancel")

        guard confirmation.runModal() == .alertFirstButtonReturn else {
            return
        }

        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            try store.importData(from: url)
            showAlert(
                title: "Imported",
                message: "Activities and records were restored. The previous data is saved as \(store.importBackupURL.lastPathComponent)."
            )
        } catch {
            showAlert(title: "Import Failed", message: error.localizedDescription)
        }
    }

    func exportData() {
        let panel = NSSavePanel()
        panel.title = "Export"
        panel.prompt = "Export"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "Work Island Backup \(Self.backupDateString()).json"

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            try store.exportData(to: url)
        } catch {
            showAlert(title: "Export Failed", message: error.localizedDescription)
        }
    }

    func showPrivacy() {
        showAlert(
            title: "Privacy",
            message: "Work Island stores activities, notes, and work records only on this Mac. It does not collect, transmit, track, or share personal data. There are no accounts, analytics, ads, or third-party SDKs. Import and Export access only files you choose."
        )
    }

    private func showMainWindow() {
        if mainWindow == nil,
           let window = makeMainWindow(
               store,
               preferences,
               launchAtLogin
           ) {
            registerMainWindow(window)
        }

        guard let mainWindow else {
            return
        }

        updateApplicationVisibility(mainWindowVisible: true)
        NSApp.activate(ignoringOtherApps: true)
        mainWindow.makeKeyAndOrderFront(nil)
    }

    private func observeMainWindow(_ window: NSWindow) {
        let center = NotificationCenter.default

        mainWindowObservers = [
            center.addObserver(
                forName: NSWindow.didBecomeMainNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                self?.updateApplicationVisibility(mainWindowVisible: true)
            },
            center.addObserver(
                forName: NSWindow.willCloseNotification,
                object: window,
                queue: .main
            ) { [weak self, weak window] _ in
                DispatchQueue.main.async {
                    guard let self, self.mainWindow === window else {
                        return
                    }
                    self.updateApplicationVisibility()
                }
            }
        ]
    }

    private func observeSettingsWindow(_ window: NSWindow) {
        let center = NotificationCenter.default

        settingsWindowObservers = [
            center.addObserver(
                forName: NSWindow.didBecomeMainNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                self?.updateApplicationVisibility(mainWindowVisible: true)
            },
            center.addObserver(
                forName: NSWindow.willCloseNotification,
                object: window,
                queue: .main
            ) { [weak self, weak window] _ in
                DispatchQueue.main.async {
                    guard let self, self.settingsWindow === window else {
                        return
                    }
                    self.updateApplicationVisibility()
                }
            }
        ]
    }

    private func removeMainWindowObservers() {
        let center = NotificationCenter.default
        mainWindowObservers.forEach(center.removeObserver)
        mainWindowObservers.removeAll()
    }

    private func removeSettingsWindowObservers() {
        let center = NotificationCenter.default
        settingsWindowObservers.forEach(center.removeObserver)
        settingsWindowObservers.removeAll()
    }

    private func configureGlassRefractionFixture(window: NSWindow) {
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false

        guard glassRefractionBackdropWindow == nil else {
            return
        }

        let backdrop = NSWindow(
            contentRect: window.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        backdrop.isOpaque = true
        backdrop.backgroundColor = .white
        backdrop.hasShadow = false
        backdrop.ignoresMouseEvents = true
        backdrop.isReleasedWhenClosed = false
        backdrop.contentView = NSHostingView(
            rootView: IslandRefractionBackdropFixtureView()
        )
        backdrop.setFrame(window.frame, display: true)
        glassRefractionBackdropWindow = backdrop
        window.addChildWindow(backdrop, ordered: .below)
        backdrop.orderFront(nil)
        window.orderFront(nil)
    }

    private func updateApplicationVisibility() {
        updateApplicationVisibility(
            mainWindowVisible: mainWindow?.isVisible == true
                || settingsWindow?.isVisible == true
        )
    }

    private func updateApplicationVisibility(mainWindowVisible: Bool) {
        let policy = ApplicationVisibilityPolicy.activationPolicy(
            mainWindowVisible: mainWindowVisible
        )

        guard NSApp.activationPolicy() != policy else {
            return
        }

        NSApp.setActivationPolicy(policy)
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private static func backupDateString() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private static func defaultIslandPanel(
        store: WorkTimerStore,
        preferences: AppPreferences,
        openMainWindow: @escaping () -> Void
    ) -> IslandPanelPresenting {
        IslandPanelController(
            store: store,
            preferences: preferences,
            openMainWindow: openMainWindow
        )
    }

    private static func defaultMainWindow(
        store: WorkTimerStore,
        preferences: AppPreferences,
        launchAtLogin: LaunchAtLoginController
    ) -> NSWindow? {
        let rootView: AnyView
        if ApplicationQAConfiguration.showsGlassRefractionFixture {
            rootView = AnyView(IslandRefractionFixtureView())
        } else {
            rootView = AnyView(
                RootView()
                    .environmentObject(store)
                    .environmentObject(preferences)
                    .environmentObject(launchAtLogin)
            )
        }
        let hostingController = NSHostingController(rootView: rootView)
        let isFixture = ApplicationQAConfiguration.showsGlassRefractionFixture
        let window = NSWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: isFixture ? 620 : MainWindowLayout.defaultWidth,
                height: isFixture ? 610 : MainWindowLayout.defaultHeight
            ),
            styleMask: [
                .titled,
                .closable,
                .miniaturizable,
                .resizable,
                .fullSizeContentView
            ],
            backing: .buffered,
            defer: false
        )

        window.title = isFixture ? "Glass Refraction QA" : "Work Island"
        window.contentViewController = hostingController
        window.minSize = NSSize(
            width: MainWindowLayout.minimumWidth,
            height: MainWindowLayout.minimumHeight
        )
        window.isReleasedWhenClosed = false

        if isFixture || !window.setFrameUsingName("main") {
            window.center()
        }
        window.setFrameAutosaveName("main")
        return window
    }
}
