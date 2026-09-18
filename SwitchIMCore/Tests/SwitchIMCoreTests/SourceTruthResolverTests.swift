import Foundation
import SwitchIMCore
import Testing

@Suite("SourceTruthResolver")
struct SourceTruthResolverTests {
    private let gureum = "org.youknowone.inputmethod.Gureum.han2::org.youknowone.inputmethod.Gureum.han2"
    private let kanaMode = "com.apple.inputmethod.Kotoeri.KanaTyping.Japanese::com.apple.inputmethod.Japanese"

    @Test("Marks visible IDs the truth set dropped as stale")
    func removalBecomesStale() {
        let stale = SourceTruthResolver.staleIDs(
            visibleIDs: [gureum, kanaMode],
            truthIDs: [gureum],
            previousStaleIDs: []
        )
        #expect(stale == [kanaMode])
    }

    @Test("Revives re-added IDs previously marked stale")
    func readdRevives() {
        let stale = SourceTruthResolver.staleIDs(
            visibleIDs: [gureum, kanaMode],
            truthIDs: [gureum, kanaMode],
            previousStaleIDs: [kanaMode]
        )
        #expect(stale.isEmpty)
    }

    @Test("Keeps stale IDs across probes while the truth set omits them")
    func stalePersists() {
        let stale = SourceTruthResolver.staleIDs(
            visibleIDs: [gureum, kanaMode],
            truthIDs: [gureum],
            previousStaleIDs: [kanaMode]
        )
        #expect(stale == [kanaMode])
    }

    @Test("Remembers stale IDs even after they vanish from the in-process views")
    func remembersInvisibleStale() {
        // The stale cache can resurface removed entries — keep hiding them
        // until the truth set re-lists them.
        let stale = SourceTruthResolver.staleIDs(
            visibleIDs: [gureum],
            truthIDs: [gureum],
            previousStaleIDs: [kanaMode]
        )
        #expect(stale == [kanaMode])
    }

    @Test("Empty truth set makes every visible ID stale")
    func emptyTruth() {
        let stale = SourceTruthResolver.staleIDs(
            visibleIDs: [gureum, kanaMode],
            truthIDs: [],
            previousStaleIDs: []
        )
        #expect(stale == [gureum, kanaMode])
    }
}
