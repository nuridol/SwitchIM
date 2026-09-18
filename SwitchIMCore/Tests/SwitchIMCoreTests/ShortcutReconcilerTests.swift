import SwitchIMCore
import Testing

@Suite("ShortcutReconciler")
struct ShortcutReconcilerTests {
    @Test("Stored names without an active source are orphaned")
    func orphans() {
        let orphaned = ShortcutReconciler.orphanedNames(
            stored: ["a", "b", "c"],
            active: ["a", "b"]
        )
        #expect(orphaned == ["c"])
    }

    @Test("Nothing stored is orphaned when every name is active")
    func noOrphans() {
        let orphaned = ShortcutReconciler.orphanedNames(
            stored: ["a", "b"],
            active: ["a", "b", "c"]
        )
        #expect(orphaned.isEmpty)
    }

    @Test("Re-added shortcut colliding with a retained owner is dropped")
    func collisionWithRetainedOwner() {
        let dropped = ShortcutReconciler.conflictedReaddedIDs(
            shortcutsByID: ["a": "F5", "b": "F5", "c": "F6"],
            readdedIDs: ["b"]
        )
        #expect(dropped == ["b"])
    }

    @Test("Re-added shortcut without collision is kept")
    func noCollision() {
        let dropped = ShortcutReconciler.conflictedReaddedIDs(
            shortcutsByID: ["a": "F5", "b": "F6"],
            readdedIDs: ["b"]
        )
        #expect(dropped.isEmpty)
    }

    @Test("Two re-added owners sharing one shortcut resolve to a single drop")
    func twoReaddedOwnersShareOneShortcut() {
        let dropped = ShortcutReconciler.conflictedReaddedIDs(
            shortcutsByID: ["a": "F5", "b": "F5"],
            readdedIDs: ["a", "b"]
        )
        #expect(dropped.count == 1)
    }

    @Test("Re-added owner without a stored shortcut is never dropped")
    func readdedWithoutShortcut() {
        let dropped = ShortcutReconciler.conflictedReaddedIDs(
            shortcutsByID: ["a": "F5"],
            readdedIDs: ["b"]
        )
        #expect(dropped.isEmpty)
    }

    @Test("Collision check is shortcut-equality based, not owner-based")
    func distinctShortcutsDoNotConflict() {
        let dropped = ShortcutReconciler.conflictedReaddedIDs(
            shortcutsByID: ["a": "F5", "b": "F6", "c": "F7"],
            readdedIDs: ["b", "c"]
        )
        #expect(dropped.isEmpty)
    }
}
