import Carbon
import Foundation

/// Read/switch access to the system's input sources.
public protocol InputSourceAccess {
    func selectableInputSources() -> [InputSource]
    func currentInputSource() -> InputSource?
    func select(_ source: InputSource) -> Bool
}

/// `InputSourceAccess` backed by the Carbon Text Input Sources (TIS) API.
///
/// Queries everything with `TISCreateInputSourceList(nil, false)` and filters
/// in Swift instead of leaning on over-restrictive API-level filters
/// (IsSelectCapable, type allow-lists, parent-regex) — the key to detecting
/// 3rd-party IMEs like Keyman (Issue #5).
public final class TISInputSourceService: InputSourceAccess {
    public init() {}

    // MARK: - InputSourceAccess

    public func selectableInputSources() -> [InputSource] {
        Self.installedSources()
            .filter { Self.stringProperty($0, kTISPropertyInputSourceCategory) == Self.keyboardCategory }
            .compactMap(Self.inputSource(from:))
            .filter { $0.isEnabled && $0.isSelectCapable }
            .uniquedByPersistentIdentifier()
    }

    public func currentInputSource() -> InputSource? {
        guard let current = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return nil }
        return Self.inputSource(from: current)
    }

    @discardableResult
    public func select(_ source: InputSource) -> Bool {
        guard let tis = Self.tisSource(matching: source.persistentIdentifier) else { return false }
        if TISSelectInputSource(tis) == noErr { return true }
        // A disabled source cannot be selected; enable it and retry once
        // (modernization plan §3.1).
        TISEnableInputSource(tis)
        return TISSelectInputSource(tis) == noErr
    }

    // MARK: - TIS plumbing

    private static let keyboardCategory = kTISCategoryKeyboardInputSource as String

    /// Every input source installed on the system, enabled or not.
    static func installedSources() -> [TISInputSource] {
        let list = TISCreateInputSourceList(nil, false)
        return (list?.takeRetainedValue() as? [TISInputSource]) ?? []
    }

    /// The TIS object for a persistent identifier (`sourceID::inputModeID`),
    /// preferring the exact mode match and falling back to the bare source.
    static func tisSource(matching persistentIdentifier: String) -> TISInputSource? {
        guard let parsed = InputSource.parsePersistentIdentifier(persistentIdentifier) else { return nil }

        let filter = NSDictionary(dictionary: [kTISPropertyInputSourceID as String: parsed.sourceID])
        guard
            let matches = TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource]
        else {
            return nil
        }
        if parsed.inputModeID.isEmpty {
            return matches.first
        }
        return matches.first {
            Self.stringProperty($0, kTISPropertyInputModeID) == parsed.inputModeID
        } ?? matches.first
    }

    /// The value-type model for a TIS object.
    static func inputSource(from source: TISInputSource) -> InputSource? {
        guard let sourceID = stringProperty(source, kTISPropertyInputSourceID) else { return nil }
        return InputSource(
            sourceID: sourceID,
            inputModeID: stringProperty(source, kTISPropertyInputModeID) ?? "",
            name: stringProperty(source, kTISPropertyLocalizedName) ?? sourceID,
            bundleID: stringProperty(source, kTISPropertyBundleID),
            isEnabled: boolProperty(source, kTISPropertyInputSourceIsEnabled),
            isSelectCapable: boolProperty(source, kTISPropertyInputSourceIsSelectCapable),
            languages: languageList(source),
            iconImageURL: urlProperty(source, kTISPropertyIconImageURL)
        )
    }

    static func stringProperty(_ source: TISInputSource, _ key: CFString) -> String? {
        guard let ptr = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<AnyObject>.fromOpaque(ptr).takeUnretainedValue() as? String
    }

    static func boolProperty(_ source: TISInputSource, _ key: CFString) -> Bool {
        guard let ptr = TISGetInputSourceProperty(source, key) else { return false }
        let value = Unmanaged<AnyObject>.fromOpaque(ptr).takeUnretainedValue()
        if let bool = value as? Bool { return bool }
        return (value as? NSNumber)?.boolValue ?? false
    }

    static func languageList(_ source: TISInputSource) -> [String] {
        guard let ptr = TISGetInputSourceProperty(source, kTISPropertyInputSourceLanguages) else {
            return []
        }
        return (Unmanaged<AnyObject>.fromOpaque(ptr).takeUnretainedValue() as? [String]) ?? []
    }

    static func urlProperty(_ source: TISInputSource, _ key: CFString) -> URL? {
        guard let ptr = TISGetInputSourceProperty(source, key) else { return nil }
        let value = Unmanaged<AnyObject>.fromOpaque(ptr).takeUnretainedValue()
        if let url = value as? URL { return url }
        return (value as? String).flatMap { URL(string: $0) }
    }
}
