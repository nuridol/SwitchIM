import Foundation

/// Stable, dot-free shortcut name per input source.
///
/// KeyboardShortcuts.Name forbids dots in names (Name.swift) and stores them under
/// `KeyboardShortcuts_<name>` in UserDefaults. We reuse the legacy SwitchIM 1.x
/// codename format so migration from the old MASShortcut storage maps 1:1.
public enum ShortcutNaming {
    public static func name(for source: InputSource) -> String {
        ShortcutKey.codename(
            sourceID: source.sourceID,
            inputModeID: source.inputModeID.isEmpty ? nil : source.inputModeID
        )
    }

    /// The shortcut name rawValue for a persistent identifier
    /// (`sourceID::inputModeID`), even when the source is no longer present.
    public static func name(forPersistentIdentifier id: String) -> String? {
        InputSource.parsePersistentIdentifier(id).map {
            ShortcutKey.codename(
                sourceID: $0.sourceID,
                inputModeID: $0.inputModeID.isEmpty ? nil : $0.inputModeID
            )
        }
    }
}
