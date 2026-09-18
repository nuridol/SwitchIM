import Foundation

/// The macOS TIS cache is only partially invalidated on IME removal: in a
/// running process the parent source disappears but its input-mode entries
/// stay enumerated until the process exits, and every in-process query
/// serves that stale view. Only a process started after the change sees the
/// true enabled set, so the app reconciles its list against a child-process
/// truth set and hides the IDs resolved here.
public enum SourceTruthResolver {
    /// IDs to hide from the in-process enumeration. Stale IDs persist while
    /// the truth set omits them — the stale cache can resurface them at any
    /// time — and revive automatically once the truth set lists them again
    /// (a re-added source).
    public static func staleIDs(
        visibleIDs: Set<String>,
        truthIDs: Set<String>,
        previousStaleIDs: Set<String>
    ) -> Set<String> {
        previousStaleIDs
            .subtracting(truthIDs)
            .union(visibleIDs.subtracting(truthIDs))
    }
}
