import Foundation

/// Value-type input source model. Extracts only the needed properties from
/// TISInputSource so it can be Sendable and safely used in menus, settings and tests.
public struct InputSource: Identifiable, Equatable, Hashable, Sendable {
    public var id: String { persistentIdentifier }

    public let sourceID: String
    public let inputModeID: String
    public let name: String
    public let bundleID: String?
    public let isEnabled: Bool
    public let isSelectCapable: Bool
    public let languages: [String]
    public let iconImageURL: URL?

    public init(
        sourceID: String,
        inputModeID: String,
        name: String,
        bundleID: String? = nil,
        isEnabled: Bool,
        isSelectCapable: Bool,
        languages: [String],
        iconImageURL: URL?
    ) {
        self.sourceID = sourceID
        self.inputModeID = inputModeID
        self.name = name
        self.bundleID = bundleID
        self.isEnabled = isEnabled
        self.isSelectCapable = isSelectCapable
        self.languages = languages
        self.iconImageURL = iconImageURL
    }

    /// Since a single TIS source can expose multiple modes (e.g. Korean 2Set/3Set),
    /// `sourceID::inputModeID` is used as the persistent identifier.
    public var persistentIdentifier: String {
        sourceID + "::" + inputModeID
    }

    /// The (source, mode) pair parsed back from a persistent identifier.
    /// The mode ID is empty when the identifier carries none. Returns nil when
    /// no source ID is present.
    public static func parsePersistentIdentifier(_ identifier: String) -> (sourceID: String, inputModeID: String)? {
        let parts = identifier.split(separator: "::", maxSplits: 1).map(String.init)
        guard let sourceID = parts.first else { return nil }
        return (sourceID, parts.count > 1 ? parts[1] : "")
    }
}

extension Array where Element == InputSource {
    /// Removes input sources that share the same `persistentIdentifier`,
    /// keeping the first occurrence and preserving order — TIS can return
    /// multiple distinct objects with the same logical identity.
    public func uniquedByPersistentIdentifier() -> [InputSource] {
        var seen = Set<String>()
        return filter { seen.insert($0.persistentIdentifier).inserted }
    }
}
