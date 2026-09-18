import AppKit
import KeyboardShortcuts

/// KeyboardShortcuts storage for the global input-source toggle: a base chord
/// recorded by the user, plus the same chord with Shift registered
/// programmatically for reverse navigation while the picker overlay is held
/// open.
@MainActor
enum ToggleShortcut {
    static let name = KeyboardShortcuts.Name("SwitchIMInputSourceToggle")
    static let reverseName = KeyboardShortcuts.Name("SwitchIMInputSourceToggleReverse")

    /// The recorded base chord, if any.
    static func current() -> KeyboardShortcuts.Shortcut? {
        KeyboardShortcuts.getShortcut(for: name)
    }

    /// The reverse chord (base plus Shift), if recorded.
    static func reverse() -> KeyboardShortcuts.Shortcut? {
        KeyboardShortcuts.getShortcut(for: reverseName)
    }

    /// Mirrors the currently recorded base chord (plus Shift) as the reverse
    /// chord, or clears it when no base chord is recorded.
    static func syncReverseChord() {
        syncReverseChord(base: current())
    }

    /// Same as `syncReverseChord()` for an explicitly given base chord — used
    /// from the recorder callback, which passes the just-captured value.
    static func syncReverseChord(base: KeyboardShortcuts.Shortcut?) {
        guard let base, let key = base.key else {
            KeyboardShortcuts.setShortcut(nil, for: reverseName)
            return
        }
        KeyboardShortcuts.setShortcut(
            KeyboardShortcuts.Shortcut(key, modifiers: base.modifiers.union(.shift)),
            for: reverseName
        )
    }

    /// One-time migration from the pre-rewrite storage (a custom JSON blob
    /// under "ToggleHotkeyBinding") into KeyboardShortcuts storage.
    static func migrateLegacyStorageIfNeeded() {
        let legacyKey = "ToggleHotkeyBinding"
        guard let data = UserDefaults.standard.data(forKey: legacyKey) else { return }
        // Consume the legacy key either way; only migrate into empty storage.
        defer { UserDefaults.standard.removeObject(forKey: legacyKey) }
        guard current() == nil else { return }

        struct LegacyBinding: Decodable {
            let modifiersRaw: UInt64
            let keyCode: UInt16
        }
        guard let legacy = try? JSONDecoder().decode(LegacyBinding.self, from: data) else { return }
        let shortcut = KeyboardShortcuts.Shortcut(
            KeyboardShortcuts.Key(rawValue: Int(legacy.keyCode)),
            modifiers: NSEvent.ModifierFlags(rawValue: UInt(legacy.modifiersRaw))
        )
        KeyboardShortcuts.setShortcut(shortcut, for: name)
        syncReverseChord()
    }
}
