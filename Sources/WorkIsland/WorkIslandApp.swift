import AppKit
import SwiftUI

struct MainWindowLayout {
    static let defaultWidth: CGFloat = 960
    static let defaultHeight: CGFloat = 650
    static let minimumWidth: CGFloat = 840
    static let minimumHeight: CGFloat = 540
}

@main
struct WorkIslandApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("Work Island", id: "main") {
            RootView()
                .environmentObject(appDelegate.store)
                .environmentObject(appDelegate.preferences)
                .environmentObject(appDelegate.launchAtLogin)
                .background(
                    WindowReader { window in
                        appDelegate.registerMainWindow(window)
                    }
                )
        }
        .defaultSize(
            width: MainWindowLayout.defaultWidth,
            height: MainWindowLayout.defaultHeight
        )
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .importExport) {
                Button("Import…") {
                    appDelegate.importData()
                }
                Button("Export…") {
                    appDelegate.exportData()
                }
            }

            CommandGroup(after: .appInfo) {
                Button("Privacy…") {
                    appDelegate.showPrivacy()
                }
            }
        }

        Settings {
            SettingsView()
                .environmentObject(appDelegate.preferences)
                .environmentObject(appDelegate.launchAtLogin)
                .background(
                    WindowReader { window in
                        appDelegate.registerSettingsWindow(window)
                    }
                )
        }
    }
}

struct WindowReader: NSViewRepresentable {
    let onWindow: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            onWindow(view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            onWindow(nsView.window)
        }
    }
}
