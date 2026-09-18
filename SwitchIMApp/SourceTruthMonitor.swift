import Foundation

/// Schedules enabled-source truth probes (see `EnabledSourcesProbe`): one
/// debounced probe per enabled-set change, plus a slow backstop for missed
/// notifications.
@MainActor
final class SourceTruthMonitor {
    private static let backstopInterval: TimeInterval = 60
    /// Rapid successive edits (add, then remove) collapse into one child spawn.
    private static let changeDebounce: Duration = .seconds(1)

    private var backstopTimer: Timer?
    private var probeTask: Task<Void, Never>?

    /// nil = failed probe.
    var onTruth: (([String]?) -> Void)?

    func start() {
        backstopTimer?.invalidate()
        let timer = Timer(timeInterval: Self.backstopInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.probe(after: .zero)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        backstopTimer = timer
    }

    func stop() {
        backstopTimer?.invalidate()
        backstopTimer = nil
        probeTask?.cancel()
        probeTask = nil
    }

    func probe(after delay: Duration) {
        probeTask?.cancel()
        probeTask = Task {
            if delay > .zero {
                try? await Task.sleep(for: delay)
                guard !Task.isCancelled else { return }
            }
            let truthIDs = await EnabledSourcesProbe.enabledSourceIDs()
            guard !Task.isCancelled else { return }
            onTruth?(truthIDs)
        }
    }

    func probeAfterEnabledSetChange() {
        probe(after: Self.changeDebounce)
    }
}
