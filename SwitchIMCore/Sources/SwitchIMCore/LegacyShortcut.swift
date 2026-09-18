import Foundation

/// A shortcut as stored by the legacy MASShortcut 2.x library.
///
/// MASShortcut persisted its `MASShortcut` object via the
/// `NSKeyedArchiveFromData` value transformer into UserDefaults. `MASShortcut`'s
/// `encodeWithCoder:` writes two integers (MASShortcut.m:221-224):
///   - `KeyCode` (virtual key code; `NSNotFound` encoded as -1)
///   - `ModifierFlags` (Cocoa `NSEventModifierFlags`)
///
/// The archive is a keyed-archive property list whose root container holds those
/// values. We cannot decode it with `NSKeyedUnarchiver` because the legacy
/// `MASShortcut` class is not present at runtime, so we parse the plist directly.
public struct LegacyShortcut: Equatable, Sendable {
    public let keyCode: Int
    public let modifierFlags: Int

    public init(keyCode: Int, modifierFlags: Int) {
        self.keyCode = keyCode
        self.modifierFlags = modifierFlags
    }

    public static func decodeMASShortcutData(_ data: Data) -> LegacyShortcut? {
        guard
            let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
            let dict = plist as? [String: Any],
            let objects = dict["$objects"] as? [Any]
        else {
            return nil
        }

        // Resolve the root object referenced by `$top` -> `root`, falling back
        // to scanning `$objects` for the first container with the two keys.
        let rootIndex: Int?
        if let top = dict["$top"] as? [String: Any],
            let index = uidValue(top["root"])
        {
            rootIndex = index
        } else {
            rootIndex = objects.firstIndex {
                guard let container = $0 as? [String: Any] else { return false }
                return container["KeyCode"] != nil && container["ModifierFlags"] != nil
            }
        }

        guard
            let rootIndex,
            objects.indices.contains(rootIndex),
            let root = objects[rootIndex] as? [String: Any],
            let keyCode = (root["KeyCode"] as? NSNumber)?.intValue,
            let modifierFlags = (root["ModifierFlags"] as? NSNumber)?.intValue
        else {
            return nil
        }

        return LegacyShortcut(keyCode: keyCode, modifierFlags: modifierFlags)
    }

    /// Extracts the integer from a `CFKeyedArchiverUID` printed as
    /// `<CFKeyedArchiverUID 0x...>{value = N}`.
    private static func uidValue(_ object: Any?) -> Int? {
        guard let object else { return nil }
        let description = String(describing: object)
        guard
            let match = description.range(of: "value = \\d+", options: .regularExpression)
        else {
            return nil
        }
        return Int(description[match].replacingOccurrences(of: "value = ", with: ""))
    }
}
