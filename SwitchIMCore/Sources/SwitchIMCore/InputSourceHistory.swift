import Foundation

/// Tracks the most-recently-used keyboard input source so the toggle hotkey
/// can ping-pong between the current and previous source (⌘Tab style) rather
/// than blindly advancing through the list.
///
/// The owner records every current-source change — including switches made
/// outside this app (system menu, globe key, other apps) — so history stays
/// accurate regardless of how the switch was triggered.
@MainActor
public final class InputSourceHistory {
    public private(set) var currentID: String?
    public private(set) var previousID: String?

    public init(currentID: String? = nil) {
        self.currentID = currentID
    }

    /// Records a current-source change. Same-ID (or nil) calls are no-ops.
    public func recordCurrent(_ id: String?) {
        guard let id, id != currentID else { return }
        previousID = currentID
        currentID = id
    }
}
