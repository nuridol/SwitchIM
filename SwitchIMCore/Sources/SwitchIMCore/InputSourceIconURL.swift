import Foundation

/// Icon URL fallback helpers.
///
/// `kTISPropertyIconImageURL` is unreliable: Apple's Korean/Japanese IMEs point at
/// `.png` files that do not exist while the real files are `.tiff` (the legacy
/// SwitchIM 1.x code retried with `.tiff` for the same reason), and 3rd-party
/// IMEs may ship no per-layout icon at all (fall back to the app bundle icon).
public enum InputSourceIconURL {
    /// The icon URL with its extension replaced by `.tiff` (Apple IME fallback).
    public static func tiffFallbackURL(for url: URL) -> URL? {
        guard url.pathExtension.lowercased() != "tiff" else { return nil }
        let withoutExt = url.deletingPathExtension()
        return withoutExt.appendingPathExtension("tiff")
    }

    /// The nearest enclosing `.app` bundle directory for an icon URL, if any.
    /// (e.g. `.../Gureum.app/Contents/Resources/han2.png` → `.../Gureum.app`)
    public static func appBundleURL(from url: URL) -> URL? {
        var candidate: URL? = url.deletingLastPathComponent()
        while let current = candidate {
            if current.pathExtension.lowercased() == "app" {
                return current
            }
            candidate = current.deletingLastPathComponent()
        }
        return nil
    }

    /// The asset-catalog name for an icon URL's filename.
    /// (e.g. `han2.png` → `han2`) — used to look up the per-layout icon inside
    /// the IME bundle's `Assets.car` (multi-IME IMEs like Gureum bundle their
    /// layout icons there instead of at the `kTISPropertyIconImageURL` path).
    public static func assetName(from url: URL) -> String {
        url.deletingPathExtension().lastPathComponent
    }
}
