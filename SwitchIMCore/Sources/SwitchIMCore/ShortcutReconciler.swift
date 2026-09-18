import Foundation

/// Pure reconciliation rules for the per-IME shortcut lifecycle against the
/// current input-source list. The app layer maps these onto KeyboardShortcuts
/// storage (enable/disable/setShortcut); the rules themselves stay
/// KeyboardShortcuts-free so they are unit-testable.
///
/// Behavior notes (see also SwitchIMCore/AGENTS.md):
/// - Removed sources keep their stored shortcut but have its hotkey
///   deactivated (retention).
/// - Re-added sources are re-enabled, and a re-added assignment that now
///   collides with another active source's shortcut is dropped.
/// - Shortcuts stored for sources that no longer exist (pre-launch orphans)
///   are deactivated once at startup.
public enum ShortcutReconciler {
    /// Stored shortcut names that belong to no active source.
    public static func orphanedNames(stored: Set<String>, active: Set<String>) -> Set<String> {
        stored.subtracting(active)
    }

    /// Re-added source IDs whose retained shortcut now collides with another
    /// active source's shortcut and must therefore be dropped. Collisions are
    /// resolved sequentially: once a re-added assignment is dropped it no
    /// longer conflicts with later re-added owners.
    public static func conflictedReaddedIDs<Shortcut: Hashable>(
        shortcutsByID: [String: Shortcut],
        readdedIDs: Set<String>
    ) -> Set<String> {
        var heldShortcuts = shortcutsByID
        var dropped = Set<String>()
        for id in readdedIDs {
            guard let shortcut = heldShortcuts[id] else { continue }
            let heldByOther = heldShortcuts.contains { otherID, otherShortcut in
                otherID != id && otherShortcut == shortcut
            }
            if heldByOther {
                heldShortcuts.removeValue(forKey: id)
                dropped.insert(id)
            }
        }
        return dropped
    }
}
