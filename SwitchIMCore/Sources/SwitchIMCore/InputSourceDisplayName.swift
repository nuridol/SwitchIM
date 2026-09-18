import Foundation

/// Display-name disambiguation for input sources.
///
/// Multiple IMEs localize the same layout name identically (e.g. Apple Korean and
/// Gureum both show "두벌식" in the Korean locale). When such a collision exists,
/// append a vendor label derived from the bundle ID so each entry stays
/// distinguishable (method 4 from the reference investigation).
public enum InputSourceDisplayName {
    /// A short vendor label for a bundle ID.
    /// - `com.apple.*` → "Apple"
    /// - otherwise → the last DNS component, with a trailing "Mac" cleaned
    ///   (`dev.ensan.inputmethod.azooKeyMac` → "azooKey").
    public static func vendorName(bundleID: String) -> String {
        let last = bundleID.split(separator: ".").last.map(String.init) ?? bundleID
        if bundleID.hasPrefix("com.apple") {
            return "Apple"
        }
        if last.hasSuffix("Mac") {
            return String(last.dropLast(3))
        }
        return last
    }

    /// The name to display for a source within a list.
    ///
    /// Returns the plain localized name, or `"name (vendor)"` when another source
    /// in the list shares the same localized name.
    public static func displayName(for source: InputSource, in sources: [InputSource]) -> String {
        let colliding = sources.filter {
            $0.name == source.name && $0.persistentIdentifier != source.persistentIdentifier
        }
        guard !colliding.isEmpty else {
            return source.name
        }
        let vendor = source.bundleID.map(vendorName) ?? source.name
        return "\(source.name) (\(vendor))"
    }
}
