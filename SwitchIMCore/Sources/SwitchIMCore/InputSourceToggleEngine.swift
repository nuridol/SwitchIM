import Foundation

/// Tap/hold state machine for the global input-source toggle.
///
/// The toggle is a single recorded chord handled through KeyboardShortcuts.
/// A quick tap of the chord ping-pongs to the most-recently-used source;
/// holding it past `holdThreshold` opens the picker overlay, where a
/// repeated press of the chord advances the selection and the same press
/// with Shift added retreats. Releasing the chord's modifiers commits.
///
///   idle ── chordPressed ──▶ pendingTap
///   pendingTap ── (holdThreshold elapses) ──▶ holdActive (overlay shown)
///   pendingTap ── modifiersReleased ──▶ quick toggle to the MRU source
///   pendingTap/holdActive ── chordPressed ──▶ holdActive, selection advances
///   holdActive ── reverseChordPressed ──▶ selection retreats
///   holdActive ── modifiersReleased ──▶ commits the highlighted source
@MainActor
public final class InputSourceToggleEngine {
    /// How long the chord can be held before a tap becomes a hold.
    public static let holdThreshold: TimeInterval = 0.2
    /// Repeated chord presses closer together than this are ignored, so a
    /// possible auto-repeat of the chord key cannot spin the selection.
    public static let minimumRepeatInterval: TimeInterval = 0.12

    public enum Mode: Equatable {
        case idle
        case pendingTap
        case holdActive
    }

    public private(set) var mode: Mode = .idle

    /// Schedules `fire` on the main queue after `delay` seconds; the returned
    /// closure cancels it.
    public typealias Scheduler =
        @MainActor (_ delay: TimeInterval, _ fire: @escaping @MainActor () -> Void) -> @MainActor () -> Void

    private let sourcesProvider: () -> [InputSource]
    private let currentIDProvider: () -> String?
    private let previousIDProvider: () -> String?
    private let schedule: Scheduler
    private let clock: () -> Date

    public weak var delegate: InputSourceToggleEngineDelegate?

    private var sources: [InputSource] = []
    private var selectedIndex = 0
    private var cancelScheduledHold: (() -> Void)?
    private var lastPressAt: Date?

    public init(
        sourcesProvider: @escaping () -> [InputSource],
        currentIDProvider: @escaping () -> String?,
        previousIDProvider: @escaping () -> String?,
        scheduler: @escaping Scheduler = InputSourceToggleEngine.dispatchScheduler,
        clock: @escaping () -> Date = Date.init
    ) {
        self.sourcesProvider = sourcesProvider
        self.currentIDProvider = currentIDProvider
        self.previousIDProvider = previousIDProvider
        self.schedule = scheduler
        self.clock = clock
    }

    /// Default main-queue scheduler built on a cancellable DispatchWorkItem.
    @MainActor
    public static func dispatchScheduler(
        delay: TimeInterval,
        fire: @escaping @MainActor () -> Void
    ) -> @MainActor () -> Void {
        let work = DispatchWorkItem { MainActor.assumeIsolated { fire() } }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        return { work.cancel() }
    }

    // MARK: - Chord events

    /// The toggle chord was pressed. The first press arms the tap/hold timer;
    /// a repeat while already active advances the picker selection.
    public func chordPressed() {
        guard mode == .idle else {
            pressWhileActive()
            return
        }
        loadSources()
        guard sources.count > 1 else { return }
        mode = .pendingTap
        lastPressAt = clock()
        cancelScheduledHold = schedule(Self.holdThreshold) { [weak self] in
            guard let self, self.mode == .pendingTap else { return }
            self.transitionToHold()
        }
    }

    /// The chord plus Shift was pressed: retreat the picker selection.
    public func reverseChordPressed() {
        guard mode != .idle else { return }
        forceHoldMode()
        moveSelection(by: -1)
    }

    /// The chord's modifiers are no longer held: commit.
    public func modifiersReleased() {
        cancelScheduledHoldTimer()
        defer { mode = .idle }

        switch mode {
        case .pendingTap:
            // Released within the threshold with a single press — jump to
            // the most-recently-used source (⌘Tab-style ping-pong).
            delegate?.engineRequestsQuickToggle()
        case .holdActive:
            let chosen = sources.isEmpty ? nil : sources[selectedIndex]
            delegate?.engineDidCommitOverlaySelection(chosen)
        case .idle:
            break
        }
    }

    public func cancel() {
        cancelScheduledHoldTimer()
        mode = .idle
    }

    // MARK: - Target resolution (pure)

    /// The source a quick toggle should activate: the most-recently-used other
    /// source when one is recorded, otherwise the next source in the list.
    public static func quickToggleTarget(
        sources: [InputSource],
        currentID: String?,
        previousID: String?
    ) -> InputSource? {
        guard sources.count > 1 else { return nil }
        if let previousID,
            previousID != currentID,
            let target = sources.first(where: { $0.persistentIdentifier == previousID })
        {
            return target
        }
        return nextSource(sources: sources, currentID: currentID)
    }

    /// The source after the current one in TIS order, wrapping around.
    public static func nextSource(sources: [InputSource], currentID: String?) -> InputSource? {
        guard !sources.isEmpty else { return nil }
        let currentIndex = sources.firstIndex { $0.persistentIdentifier == currentID } ?? 0
        let nextIndex = wrap(currentIndex + 1, count: sources.count)
        return sources[nextIndex]
    }

    static func wrap(_ index: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return ((index % count) + count) % count
    }

    // MARK: - Internals

    /// A repeat of the chord while the engine is active forces the picker
    /// early (if still pending) and moves the selection forward.
    private func pressWhileActive() {
        let pressedAt = clock()
        if let lastPressAt, pressedAt.timeIntervalSince(lastPressAt) < Self.minimumRepeatInterval {
            return
        }
        lastPressAt = pressedAt
        forceHoldMode()
        moveSelection(by: +1)
    }

    /// Loads the picker list in the provider's (TIS registration) order and
    /// pre-selects the quick-toggle target — the most-recently-used source,
    /// falling back to the next source in the list. The stable order keeps
    /// positions learnable across activations, while the pre-selection keeps
    /// hold-release committing the same source a quick tap would.
    private func loadSources() {
        sources = sourcesProvider()
        let target = Self.quickToggleTarget(
            sources: sources,
            currentID: currentIDProvider(),
            previousID: previousIDProvider()
        )
        selectedIndex = sources.firstIndex { $0.persistentIdentifier == target?.persistentIdentifier } ?? 0
    }

    /// Cancels the pending hold-threshold timer, if one is armed.
    private func cancelScheduledHoldTimer() {
        cancelScheduledHold?()
        cancelScheduledHold = nil
    }

    private func transitionToHold() {
        mode = .holdActive
        guard sources.count > 1 else { return }
        delegate?.engineDidPresentOverlay(sources: sources, selectedIndex: selectedIndex)
    }

    private func forceHoldMode() {
        guard mode == .pendingTap else { return }
        cancelScheduledHoldTimer()
        transitionToHold()
    }

    private func moveSelection(by delta: Int) {
        guard !sources.isEmpty else { return }
        selectedIndex = Self.wrap(selectedIndex + delta, count: sources.count)
        delegate?.engineDidMoveSelection(toIndex: selectedIndex)
    }
}

@MainActor
public protocol InputSourceToggleEngineDelegate: AnyObject {
    /// A quick tap: switch to the MRU target (resolved via
    /// `InputSourceToggleEngine.quickToggleTarget`).
    func engineRequestsQuickToggle()

    /// The hold threshold elapsed: present the picker with the full source
    /// list (TIS registration order, quick-toggle target pre-selected).
    func engineDidPresentOverlay(sources: [InputSource], selectedIndex: Int)

    /// The highlight moved (a chord repeat while held; Shift + chord goes back).
    func engineDidMoveSelection(toIndex index: Int)

    /// The modifiers were released after a hold: commit the highlighted source
    /// (nil when the list was empty) and dismiss the picker.
    func engineDidCommitOverlaySelection(_ source: InputSource?)
}
