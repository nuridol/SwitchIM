import AppKit
import SwiftUI

/// Manages the settings window as a regular AppKit window hosting the SwiftUI
/// settings view. The SwiftUI `Settings` scene is unreliable in accessory
/// (LSUIElement) apps — `showSettingsWindow:` creates windows that never attach
/// to a screen — so the menu bar app presents settings through this controller
/// instead.
@MainActor
final class SettingsWindowController {
    private let state: AppState
    private var window: NSWindow?

    init(state: AppState) {
        self.state = state
    }

    func show() {
        let window = self.window ?? makeWindow()
        if !window.isVisible {
            window.center()
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let content = NSHostingController(rootView: SettingsView().environmentObject(state))
        // Keep the window sized to the content: it grows/shrinks with the number
        // of input source rows and the presence of conflict warnings.
        content.sizingOptions = [.preferredContentSize]
        let window = NSWindow(contentViewController: content)
        window.title = String(localized: "SwitchIM Settings")
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        // Retained by the controller (isReleasedWhenClosed = false) for instant reuse.
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(width: 400, height: 160)
        self.window = window
        return window
    }
}
