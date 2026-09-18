import Foundation

/// Switching engine: TISSelectInputSource -> read-back verification -> (focus
/// pulse on failure for CJK sources).
/// Does NOT use the old hacks (synthetic mouse click / symbolichotkeys replay).
/// The pulse itself is app-layer UI plumbing (an off-screen NSWindow) and is
/// injected here so the core stays AppKit-free.
@MainActor
public final class InputSourceSwitcher {
    private let access: InputSourceAccess
    private let pulse: @MainActor () -> Void

    public init(
        access: InputSourceAccess = TISInputSourceService(),
        pulse: @escaping @MainActor () -> Void
    ) {
        self.access = access
        self.pulse = pulse
    }

    /// Switches to the source and verifies by reading back the current source.
    /// Returns true only when the system reports the target as current.
    @discardableResult
    public func change(to source: InputSource) -> Bool {
        let targetID = source.persistentIdentifier
        guard access.select(source) else { return false }

        if access.currentInputSource()?.persistentIdentifier != targetID {
            if CJKLanguageSet.contains(source.languages) {
                pulse()
                _ = access.select(source)
            }
        }
        return access.currentInputSource()?.persistentIdentifier == targetID
    }
}
