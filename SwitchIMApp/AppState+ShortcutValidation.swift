import AppKit
import KeyboardShortcuts
import SwitchIMCore

/// Recorder-validation API used by the settings window: conflict reporting
/// for a source's current shortcut and validation rules that block recording
/// a shortcut already assigned to another source or to the toggle chord.
extension AppState {
    /// A shortcut assignment conflict for a source's recorder row.
    enum ShortcutConflict {
        case duplicate(source: InputSource)
        case takenBySystem
    }

    /// The conflict for a source's current shortcut, if any.
    func shortcutConflict(for source: InputSource) -> ShortcutConflict? {
        let name = shortcutName(for: source)
        guard let shortcut = KeyboardShortcuts.getShortcut(for: name) else { return nil }

        if shortcut.isTakenBySystem {
            return .takenBySystem
        }
        if let other = otherSource(assigned: shortcut, excludingID: source.persistentIdentifier) {
            return .duplicate(source: other)
        }
        return nil
    }

    /// Blocks recording a shortcut that is already assigned to another source.
    /// The KeyboardShortcuts recorder itself already warns about system and main
    /// menu conflicts; this covers conflicts between our own per-IME shortcuts
    /// and the global toggle chord.
    func shortcutValidationResult(for source: InputSource, shortcut: KeyboardShortcuts.Shortcut)
        -> KeyboardShortcuts.ValidationResult
    {
        if let other = otherSource(assigned: shortcut, excludingID: source.persistentIdentifier) {
            return .disallow(reason: String(localized: "This shortcut is already assigned to “\(other.name)”."))
        }
        if let toggle = ToggleShortcut.current(), shortcut == toggle {
            return .disallow(
                reason: String(localized: "This shortcut is used by the input source toggle.")
            )
        }
        if let reverse = ToggleShortcut.reverse(), shortcut == reverse {
            return .disallow(
                reason: String(localized: "This shortcut is used by the input source toggle.")
            )
        }
        return .allow
    }

    /// Validation for the toggle chord recorder: the chord needs at least one
    /// of ⌃ ⌥ ⌘ (⇧ is reserved for reverse navigation) and must not collide
    /// with a per-IME shortcut.
    func toggleValidationResult(for shortcut: KeyboardShortcuts.Shortcut) -> KeyboardShortcuts.ValidationResult {
        let pressed = shortcut.modifiers.intersection(.deviceIndependentFlagsMask)
        let trigger: NSEvent.ModifierFlags = [.control, .option, .command]
        guard !pressed.isDisjoint(with: trigger) else {
            return .disallow(reason: String(localized: "The toggle shortcut needs at least one of ⌃ ⌥ ⌘."))
        }
        guard !pressed.contains(.shift) else {
            return .disallow(
                reason: String(localized: "The toggle shortcut cannot use ⇧ — it is reserved for reverse navigation.")
            )
        }
        if let other = sourceAssigned(to: shortcut) {
            return .disallow(reason: String(localized: "This shortcut is already assigned to “\(other.name)”."))
        }
        return .allow
    }

    /// The source whose per-IME shortcut matches the toggle chord, if any —
    /// used to keep the toggle from shadowing (or being shadowed by) a
    /// per-source shortcut.
    func sourceAssigned(to shortcut: KeyboardShortcuts.Shortcut) -> InputSource? {
        for source in sources {
            if let recorded = KeyboardShortcuts.getShortcut(for: shortcutName(for: source)),
                recorded == shortcut
            {
                return source
            }
        }
        return nil
    }

    /// The first other active source assigned the given shortcut, if any.
    private func otherSource(assigned shortcut: KeyboardShortcuts.Shortcut, excludingID: String) -> InputSource? {
        for other in sources where other.persistentIdentifier != excludingID {
            if KeyboardShortcuts.getShortcut(for: shortcutName(for: other)) == shortcut {
                return other
            }
        }
        return nil
    }
}
