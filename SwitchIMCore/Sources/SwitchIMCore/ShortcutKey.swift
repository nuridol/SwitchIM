import Foundation

/// Legacy per-IME UserDefaults key format from SwitchIM 1.x.
///
/// Old implementation (SwitchIM.swift `shortcutCodename`):
/// `(sourceID + "#" + modeID).replacingOccurrences(of: ".", with: "_")`,
/// where a nil modeID is represented as "-".
///
/// This must stay byte-compatible with SwitchIM 1.x so existing user
/// shortcut settings can be migrated to the new storage.
public enum ShortcutKey {
    public static func codename(sourceID: String, inputModeID: String?) -> String {
        let modeID = inputModeID ?? "-"
        return (sourceID + "#" + modeID).replacingOccurrences(of: ".", with: "_")
    }
}
