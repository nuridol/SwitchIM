import Foundation

/// Language codes of the input methods that may ignore a background
/// `TISSelectInputSource` (returning `noErr` without switching) and therefore
/// qualify for the focus-pulse workaround after a failed read-back.
public enum CJKLanguageSet: Sendable {
    private static let codes: Set<String> = ["ja", "ko", "vi", "yue", "zh"]

    /// Whether any of the languages belongs to a CJK input method.
    /// Chinese variants that carry a region/script subtag (`zh-Hans`,
    /// `zh-Hant`, `zh-TW`, ...) match through the prefix rule.
    public static func contains(_ languages: [String]) -> Bool {
        languages.contains { language in
            codes.contains(language) || (language.hasPrefix("zh") && language.count > 2)
        }
    }
}
