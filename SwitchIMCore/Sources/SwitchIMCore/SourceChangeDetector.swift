import Foundation

/// Computes which input sources disappeared / reappeared between two
/// enumerations, so removed sources' shortcuts can be deactivated (retained but
/// invalid) and re-added ones reactivated with conflict resolution.
public enum SourceChangeDetector {
    public static func changes(
        previous: [InputSource],
        current: [InputSource]
    ) -> (removed: Set<String>, added: Set<String>) {
        let previousIDs = Set(previous.map(\.persistentIdentifier))
        let currentIDs = Set(current.map(\.persistentIdentifier))
        return (previousIDs.subtracting(currentIDs), currentIDs.subtracting(previousIDs))
    }
}
