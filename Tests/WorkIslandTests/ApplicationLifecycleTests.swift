import AppKit
import XCTest
@testable import WorkIsland

final class ApplicationLifecycleTests: XCTestCase {
    func testClosingLastWindowDoesNotTerminateApplication() throws {
        let delegate = try makeDelegate()

        XCTAssertFalse(
            delegate.applicationShouldTerminateAfterLastWindowClosed(NSApplication.shared)
        )
    }

    func testMainWindowVisibilityControlsApplicationActivationPolicy() {
        XCTAssertEqual(
            ApplicationVisibilityPolicy.activationPolicy(mainWindowVisible: true),
            .regular
        )
        XCTAssertEqual(
            ApplicationVisibilityPolicy.activationPolicy(mainWindowVisible: false),
            .accessory
        )
    }

    func testInstalledApplicationCanManageLaunchAtLogin() {
        XCTAssertTrue(
            LaunchAtLoginPolicy.canManage(
                bundleURL: URL(fileURLWithPath: "/Applications/Work Island.app")
            )
        )
    }

    func testDevelopmentBundleCannotManageLaunchAtLogin() {
        XCTAssertFalse(
            LaunchAtLoginPolicy.canManage(
                bundleURL: URL(fileURLWithPath: "/tmp/Work Island.app")
            )
        )
    }

    func testQABundleRequiresAbsoluteIsolatedStorageAndPreferences() throws {
        let storageURL = URL(fileURLWithPath: "/tmp/work-island-layout-qa.json")
        let suiteName = "local.shikazeriku.work-island.qa.layout.preferences"

        let configuration = try XCTUnwrap(
            ApplicationQAIsolationConfiguration.resolve(
                bundleIdentifier: "local.shikazeriku.work-island.qa.layout",
                infoDictionary: [
                    ApplicationQAIsolationConfiguration.storagePathInfoKey:
                        storageURL.path,
                    ApplicationQAIsolationConfiguration.defaultsSuiteInfoKey:
                        suiteName,
                    ApplicationQAIsolationConfiguration.keepsNotchExpandedInfoKey:
                        true
                ]
            )
        )

        XCTAssertEqual(configuration.storageURL, storageURL)
        XCTAssertEqual(configuration.defaultsSuiteName, suiteName)
        XCTAssertTrue(configuration.keepsNotchExpanded)
    }

    func testProductionBundleIgnoresQAIsolationMetadata() {
        XCTAssertNil(
            ApplicationQAIsolationConfiguration.resolve(
                bundleIdentifier: "local.shikazeriku.work-island",
                infoDictionary: [
                    ApplicationQAIsolationConfiguration.storagePathInfoKey:
                        "/tmp/work-island-layout-qa.json",
                    ApplicationQAIsolationConfiguration.defaultsSuiteInfoKey:
                        "local.shikazeriku.work-island.qa.layout.preferences"
                ]
            )
        )
    }

    func testQABundleRejectsRelativeStoragePath() {
        XCTAssertNil(
            ApplicationQAIsolationConfiguration.resolve(
                bundleIdentifier: "local.shikazeriku.work-island.qa.layout",
                infoDictionary: [
                    ApplicationQAIsolationConfiguration.storagePathInfoKey:
                        "work-data.json",
                    ApplicationQAIsolationConfiguration.defaultsSuiteInfoKey:
                        "local.shikazeriku.work-island.qa.layout.preferences"
                ]
            )
        )
    }

    func testDidFinishLaunchingBuildsAndShowsNotchWithoutMainWindow() throws {
        let panel = TestIslandPanel()
        let delegate = try makeDelegate(
            makeIslandPanel: { _, _, _ in panel }
        )

        delegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )

        XCTAssertTrue(panel.didShow)
        XCTAssertTrue(delegate.preferences.isPrepared)
    }

    func testReopenCreatesMissingMainWindowAndHandlesEventInternally() throws {
        var didRequestWindow = false
        let delegate = try makeDelegate(
            makeMainWindow: { _, _, _ in
                didRequestWindow = true
                return nil
            }
        )

        let shouldContinueDefaultHandling = delegate.applicationShouldHandleReopen(
            NSApplication.shared,
            hasVisibleWindows: false
        )

        XCTAssertTrue(didRequestWindow)
        XCTAssertFalse(shouldContinueDefaultHandling)
    }

    private func makeDelegate(
        makeIslandPanel: @escaping AppDelegate.IslandPanelFactory = {
            _, _, _ in TestIslandPanel()
        },
        makeMainWindow: @escaping AppDelegate.MainWindowFactory = {
            _, _, _ in nil
        }
    ) throws -> AppDelegate {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
        }

        let suiteName = "WorkIslandLifecycleTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
        }

        return AppDelegate(
            store: WorkTimerStore(
                storageURL: root.appendingPathComponent("work-data.json")
            ),
            preferences: AppPreferences(defaults: defaults),
            launchAtLogin: LaunchAtLoginController(
                bundleURL: root.appendingPathComponent("Work Island.app")
            ),
            makeIslandPanel: makeIslandPanel,
            makeMainWindow: makeMainWindow
        )
    }
}

private final class TestIslandPanel: IslandPanelPresenting {
    private(set) var didShow = false

    func show() {
        didShow = true
    }
}
