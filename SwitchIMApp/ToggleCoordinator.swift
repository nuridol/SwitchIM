import AppKit
import KeyboardShortcuts
import SwitchIMCore

/// Drives the global input-source toggle:
///
///   KeyboardShortcuts.onKeyDown ─▶ InputSourceToggleEngine ─▶ overlay + AppState
///
/// The recorded chord is handled through KeyboardShortcuts (Carbon global
/// hotkeys), so it is entirely separate from the system's own input-source
/// shortcuts and needs no Accessibility permission. The Carbon API reports
/// key-downs only, so the commit — the chord's modifiers being released —
/// is detected by polling `NSEvent.modifierFlags` while the engine is active.
@MainActor
final class ToggleCoordinator: InputSourceToggleEngineDelegate {
    /// How often the chord's modifiers are checked while the engine is active.
    private static let modifierPollInterval: TimeInterval = 0.05

    private let state: AppState
    private lazy var engine: InputSourceToggleEngine = {
        let engine = InputSourceToggleEngine(
            sourcesProvider: { [weak state] in state?.sources ?? [] },
            currentIDProvider: { [weak state] in state?.currentSource?.persistentIdentifier },
            previousIDProvider: { [weak state] in state?.inputSourceHistory.previousID }
        )
        engine.delegate = self
        return engine
    }()
    private let overlay = ToggleOverlayPanel()
    private var modifierTimer: Timer?

    init(state: AppState) {
        self.state = state
    }

    func start() {
        ToggleShortcut.migrateLegacyStorageIfNeeded()
        KeyboardShortcuts.onKeyDown(for: ToggleShortcut.name) { [weak self] in
            guard let self else { return }
            engine.chordPressed()
            startModifierPollingIfNeeded()
        }
        KeyboardShortcuts.onKeyDown(for: ToggleShortcut.reverseName) { [weak self] in
            guard let self else { return }
            engine.reverseChordPressed()
            startModifierPollingIfNeeded()
        }
    }

    func stop() {
        stopModifierPolling()
        engine.cancel()
        overlay.dismiss()
    }

    // MARK: - Modifier polling

    private func startModifierPollingIfNeeded() {
        guard modifierTimer == nil else { return }
        let timer = Timer(timeInterval: Self.modifierPollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tickModifierPoll()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        modifierTimer = timer
    }

    private func stopModifierPolling() {
        modifierTimer?.invalidate()
        modifierTimer = nil
    }

    private func tickModifierPoll() {
        guard engine.mode != .idle else {
            stopModifierPolling()
            return
        }
        guard let base = ToggleShortcut.current() else {
            engine.cancel()
            stopModifierPolling()
            return
        }
        // Commit once any of the chord's modifiers is no longer held.
        let held = NSEvent.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let required = base.modifiers.intersection(.deviceIndependentFlagsMask)
        if !held.isSuperset(of: required) {
            engine.modifiersReleased()
            stopModifierPolling()
        }
    }

    // MARK: - InputSourceToggleEngineDelegate

    func engineRequestsQuickToggle() {
        guard
            let target = InputSourceToggleEngine.quickToggleTarget(
                sources: state.sources,
                currentID: state.currentSource?.persistentIdentifier,
                previousID: state.inputSourceHistory.previousID
            )
        else { return }
        state.select(target)
    }

    func engineDidPresentOverlay(sources: [InputSource], selectedIndex: Int) {
        overlay.present(
            sources: sources,
            names: sources.map { state.displayName(for: $0) },
            selectedIndex: selectedIndex
        )
    }

    func engineDidMoveSelection(toIndex index: Int) {
        overlay.setSelectedIndex(index)
    }

    func engineDidCommitOverlaySelection(_ source: InputSource?) {
        overlay.dismiss()
        guard let source,
            source.persistentIdentifier != state.currentSource?.persistentIdentifier
        else { return }
        state.select(source)
    }
}
