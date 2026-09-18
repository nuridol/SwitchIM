import Foundation
import Testing

@testable import SwitchIMCore

/// Manual scheduler for exercising the engine's tap/hold threshold
/// deterministically: recorded blocks fire when `advance` passes their delay.
@MainActor
private final class ManualScheduler {
    private struct Scheduled {
        let deadline: TimeInterval
        let fire: () -> Void
    }

    private var scheduled: [Scheduled] = []
    private var elapsed: TimeInterval = 0
    /// Fired scheduled blocks in (delay, fire) order for assertions.
    private(set) var firedDelays: [TimeInterval] = []

    var scheduler: InputSourceToggleEngine.Scheduler {
        { [weak self] delay, fire in
            let box = Box(fire)
            self?.scheduled.append(Scheduled(deadline: (self?.elapsed ?? 0) + delay) { box.call() })
            return { [weak box] in box?.cancelled = true }
        }
    }

    func advance(by time: TimeInterval) {
        elapsed += time
        let now = elapsed
        let due = scheduled.filter { $0.deadline <= now }
        scheduled.removeAll { $0.deadline <= now }
        for item in due {
            firedDelays.append(item.deadline)
            item.fire()
        }
    }

    private final class Box {
        var cancelled = false
        private let fire: () -> Void

        init(_ fire: @escaping () -> Void) { self.fire = fire }

        func call() {
            guard !cancelled else { return }
            fire()
        }
    }
}

@MainActor
private final class MockEngineDelegate: InputSourceToggleEngineDelegate {
    private(set) var quickToggleCount = 0
    private(set) var presented: [(sources: [InputSource], selectedIndex: Int)] = []
    private(set) var selectedIndexes: [Int] = []
    private(set) var committed: [InputSource?] = []

    func engineRequestsQuickToggle() {
        quickToggleCount += 1
    }

    func engineDidPresentOverlay(sources: [InputSource], selectedIndex: Int) {
        presented.append((sources, selectedIndex))
    }

    func engineDidMoveSelection(toIndex index: Int) {
        selectedIndexes.append(index)
    }

    func engineDidCommitOverlaySelection(_ source: InputSource?) {
        committed.append(source)
    }
}

@Suite("InputSourceToggleEngine (tap/hold state machine)")
@MainActor
struct InputSourceToggleEngineTests {
    /// `InputSource.persistentIdentifier` is `sourceID + "::" + inputModeID`
    /// and the engine works with these full identifiers.
    private func pid(_ id: String) -> String { id + "::" }

    private func makeSource(_ id: String) -> InputSource {
        InputSource(
            sourceID: id,
            inputModeID: "",
            name: id,
            isEnabled: true,
            isSelectCapable: true,
            languages: [],
            iconImageURL: nil
        )
    }

    private func makeEngine(
        sources: [InputSource],
        currentID: String?,
        previousID: String?,
        clock: ManualScheduler,
        now: @escaping () -> Date = Date.init
    ) -> (engine: InputSourceToggleEngine, delegate: MockEngineDelegate) {
        let delegate = MockEngineDelegate()
        let engine = InputSourceToggleEngine(
            sourcesProvider: { sources },
            currentIDProvider: { currentID },
            previousIDProvider: { previousID },
            scheduler: clock.scheduler,
            clock: now
        )
        engine.delegate = delegate
        return (engine, delegate)
    }

    // MARK: - Quick tap

    @Test("Tap below threshold quick-toggles without any overlay")
    func quickTap() {
        let a = makeSource("A")
        let b = makeSource("B")
        let clock = ManualScheduler()
        let (engine, delegate) = makeEngine(sources: [a, b], currentID: pid("A"), previousID: nil, clock: clock)

        engine.chordPressed()
        clock.advance(by: 0.1)
        engine.modifiersReleased()

        #expect(delegate.quickToggleCount == 1)
        #expect(delegate.presented.isEmpty)
        #expect(engine.mode == .idle)
    }

    @Test("Hold past the threshold presents the overlay")
    func holdPresentsOverlay() {
        let a = makeSource("A")
        let b = makeSource("B")
        let clock = ManualScheduler()
        let (engine, delegate) = makeEngine(sources: [a, b], currentID: pid("A"), previousID: nil, clock: clock)

        engine.chordPressed()
        clock.advance(by: InputSourceToggleEngine.holdThreshold + 0.01)

        #expect(delegate.presented.count == 1)
        // TIS order [A, B] with the quick-toggle target (B) pre-selected.
        #expect(delegate.presented[0].selectedIndex == 1)
        #expect(engine.mode == .holdActive)
    }

    @Test("Commit after hold selects the highlighted source")
    func commitAfterHold() {
        let a = makeSource("A")
        let b = makeSource("B")
        let clock = ManualScheduler()
        let (engine, delegate) = makeEngine(sources: [a, b], currentID: pid("A"), previousID: nil, clock: clock)

        engine.chordPressed()
        clock.advance(by: 0.3)
        engine.modifiersReleased()

        #expect(delegate.committed.count == 1)
        #expect(delegate.committed[0] == b)  // the pre-selected quick-toggle target
        #expect(engine.mode == .idle)
    }

    @Test("Repeated press before the threshold forces hold and advances")
    func repeatPressForcesHoldAndAdvances() {
        let a = makeSource("A")
        let b = makeSource("B")
        let c = makeSource("C")
        let clock = ManualScheduler()
        var current = Date(timeIntervalSince1970: 0)
        let (engine, delegate) = makeEngine(
            sources: [a, b, c], currentID: pid("A"), previousID: nil, clock: clock,
            now: { current }
        )

        engine.chordPressed()
        clock.advance(by: 0.05)
        current = Date(timeIntervalSince1970: 0.3)  // past the repeat interval
        engine.chordPressed()

        #expect(delegate.presented.count == 1)
        #expect(delegate.selectedIndexes == [2])  // pre-selected B, advance → C
        #expect(engine.mode == .holdActive)

        // The forced transition cancels the pending timer — no double present.
        clock.advance(by: 0.3)
        #expect(delegate.presented.count == 1)

        engine.modifiersReleased()
        #expect(delegate.committed.last??.persistentIdentifier == pid("C"))
    }

    @Test("Repeated press within the repeat interval is ignored")
    func repeatWithinIntervalIsIgnored() {
        let a = makeSource("A")
        let b = makeSource("B")
        let c = makeSource("C")
        let clock = ManualScheduler()
        var current = Date(timeIntervalSince1970: 0)
        let (engine, delegate) = makeEngine(
            sources: [a, b, c], currentID: pid("A"), previousID: nil, clock: clock,
            now: { current }
        )

        engine.chordPressed()
        current = Date(timeIntervalSince1970: 0.02)  // 20 ms later — throttled
        engine.chordPressed()

        #expect(delegate.presented.isEmpty)
        #expect(delegate.selectedIndexes.isEmpty)

        current = Date(timeIntervalSince1970: 0.3)  // past the interval — accepted
        engine.chordPressed()
        #expect(delegate.selectedIndexes == [2])
    }

    @Test("Retreat moves the highlight backwards and wraps")
    func retreatWraps() {
        let a = makeSource("A")
        let b = makeSource("B")
        let c = makeSource("C")
        let clock = ManualScheduler()
        let (engine, delegate) = makeEngine(sources: [a, b, c], currentID: pid("A"), previousID: nil, clock: clock)

        engine.chordPressed()
        clock.advance(by: 0.3)
        engine.reverseChordPressed()
        engine.reverseChordPressed()

        // TIS order [A, B, C] pre-selected at B (1): retreat → A (0), wrap → C (2).
        #expect(delegate.selectedIndexes == [0, 2])
    }

    @Test("Single source is a no-op")
    func singleSourceIsNoOp() {
        let a = makeSource("A")
        let clock = ManualScheduler()
        let (engine, delegate) = makeEngine(sources: [a], currentID: pid("A"), previousID: nil, clock: clock)

        engine.chordPressed()
        clock.advance(by: 0.3)
        engine.modifiersReleased()

        #expect(delegate.quickToggleCount == 0)
        #expect(delegate.presented.isEmpty)
        #expect(delegate.committed.isEmpty)
        #expect(engine.mode == .idle)
    }

    @Test("Reverse chord while idle is ignored")
    func reverseWhileIdleIsIgnored() {
        let a = makeSource("A")
        let b = makeSource("B")
        let clock = ManualScheduler()
        let (engine, delegate) = makeEngine(sources: [a, b], currentID: pid("A"), previousID: nil, clock: clock)

        engine.reverseChordPressed()

        #expect(delegate.presented.isEmpty)
        #expect(delegate.selectedIndexes.isEmpty)
        #expect(engine.mode == .idle)
    }

    // MARK: - Target resolution

    @Test("Quick toggle prefers the MRU source and falls back to next")
    func quickToggleTarget() {
        let a = makeSource("A")
        let b = makeSource("B")
        let c = makeSource("C")
        let sources = [a, b, c]

        // Previous recorded and still valid → ping-pong back to it.
        #expect(
            InputSourceToggleEngine.quickToggleTarget(sources: sources, currentID: pid("B"), previousID: pid("A"))
                == a
        )

        // No history yet → advance to the next source in TIS order (wraps).
        #expect(
            InputSourceToggleEngine.quickToggleTarget(sources: sources, currentID: pid("C"), previousID: nil)
                == a
        )

        // Previous no longer selectable → fall back to next.
        #expect(
            InputSourceToggleEngine.quickToggleTarget(sources: sources, currentID: pid("A"), previousID: "gone")
                == b
        )

        // Not enough sources → nil.
        #expect(
            InputSourceToggleEngine.quickToggleTarget(sources: [a], currentID: pid("A"), previousID: nil)
                == nil
        )
    }

    @Test("Overlay keeps TIS order; the MRU target is pre-selected")
    func overlayOrdering() {
        let a = makeSource("A")
        let b = makeSource("B")
        let c = makeSource("C")
        let clock = ManualScheduler()

        // MRU recorded → the list stays in TIS order with the MRU source highlighted.
        let (engine, delegate) = makeEngine(
            sources: [a, b, c], currentID: pid("A"), previousID: pid("C"), clock: clock)
        engine.chordPressed()
        clock.advance(by: 0.3)
        #expect(delegate.presented.last?.sources.map(\.persistentIdentifier) == [pid("A"), pid("B"), pid("C")])
        #expect(delegate.presented.last?.selectedIndex == 2)

        // No history → the next source in TIS order is pre-selected.
        let (engine2, delegate2) = makeEngine(sources: [a, b, c], currentID: pid("A"), previousID: nil, clock: clock)
        engine2.chordPressed()
        clock.advance(by: 0.3)
        #expect(delegate2.presented.last?.sources.map(\.persistentIdentifier) == [pid("A"), pid("B"), pid("C")])
        #expect(delegate2.presented.last?.selectedIndex == 1)
    }
}
