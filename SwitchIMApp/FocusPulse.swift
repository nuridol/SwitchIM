import AppKit

/// Workaround for a TIS quirk: a background `TISSelectInputSource` into a CJK
/// input method can return `noErr` without taking effect. Briefly making a
/// tiny invisible window key forces the system to process a focus change, so
/// a retry can stick. The window is held for 80 ms so the focus change
/// registers before it closes.
@MainActor
enum FocusPulse {
    private static let hold = Duration.milliseconds(80)

    static func flash() {
        let window = NSWindow(
            contentRect: .zero,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.setFrame(NSRect(x: -300, y: -300, width: 3, height: 3), display: false)
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle]
        window.alphaValue = 0.02
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        Task { [window] in
            try? await Task.sleep(for: hold)
            window.orderOut(nil)
        }
    }
}
