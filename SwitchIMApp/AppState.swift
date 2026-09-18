import AppKit
import Combine
import Foundation
import KeyboardShortcuts
import ServiceManagement
import SwitchIMCore

/// What the menu bar icon shows.
enum MenuBarIconMode: String {
    /// The SwitchIM app icon (keyboard symbol), template-marked.
    case app
    /// The current input source's own icon, updating as the IME changes
    /// (restores the legacy SwitchIM "Menu Bar Icon: Language" behavior).
    case inputSource
}

/// Shared app state, owned by AppDelegate and injected into both the status item
/// and the SwiftUI settings view via environmentObject.
@MainActor
final class AppState: ObservableObject {
    @Published private(set) var sources: [InputSource] = []
    @Published private(set) var currentSource: InputSource?
    /// Bumped once per `refresh()` that actually changed the source list or the
    /// current source — a single publication so the menu bar rebuilds once.
    @Published private(set) var sourceRevision = 0
    /// Bumped whenever a shortcut is recorded/removed so the menu bar re-mirrors it.
    @Published private(set) var shortcutRevision = 0
    @Published var menuBarIconMode: MenuBarIconMode {
        didSet {
            UserDefaults.standard.set(menuBarIconMode.rawValue, forKey: Self.menuBarIconModeKey)
        }
    }
    /// Whether SwitchIM is registered as a login item (`SMAppService.mainApp`).
    @Published private(set) var launchAtLogin = false
    /// True when the login item needs approval in System Settings.
    @Published private(set) var launchAtLoginNeedsApproval = false

    private let provider: InputSourceAccess
    private let switcher: InputSourceSwitcher
    private var observer: InputSourceChangeObserver?
    /// The probe child reads real TIS even in mock mode, so probing is
    /// skipped there — the two views would disagree.
    private let usesRealTIS: Bool
    /// MRU tracking for the global input-source toggle (⌘Tab-style ping-pong).
    let inputSourceHistory = InputSourceHistory()
    /// Cached KeyboardShortcuts.Name per rawValue — creating a Name spawns a
    /// Task on every init (Name.swift), so reuse them instead of rebuilding on
    /// every refresh (which fires on each IME switch notification).
    private var shortcutNames: [String: KeyboardShortcuts.Name] = [:]
    /// Names that already have a global hotkey handler registered. `onKeyUp`
    /// appends to the handler list, so each name must be registered at most once.
    private var registeredHandlerNames: Set<String> = []
    /// Marks whether the legacy MASShortcut migration pass has completed.
    /// Persisted in UserDefaults so it runs exactly once ever, not once per launch.
    private var legacyMigrationCompleted: Bool

    private static let legacyMigrationCompletedKey = "LegacyShortcutMigrationCompleted"
    private static let menuBarIconModeKey = "MenuBarIconMode"

    init(provider: InputSourceAccess = TISInputSourceService()) {
        self.provider = provider
        self.switcher = InputSourceSwitcher(access: provider, pulse: FocusPulse.flash)
        self.usesRealTIS = provider is TISInputSourceService
        self.legacyMigrationCompleted = UserDefaults.standard.bool(forKey: Self.legacyMigrationCompletedKey)
        self.menuBarIconMode =
            MenuBarIconMode(
                rawValue: UserDefaults.standard.string(forKey: Self.menuBarIconModeKey) ?? ""
            ) ?? .app
    }

    func start() {
        refresh()
        refreshLaunchAtLoginStatus()
        observer = InputSourceChangeObserver { [weak self] event in
            self?.handleSourceChange(event)
        }
        observer?.start()
        startPolling()
        if usesRealTIS {
            truthMonitor.onTruth = { [weak self] truthIDs in
                self?.applyTruth(truthIDs)
            }
            truthMonitor.start()
        }
    }

    /// Toggles the login item. Reads the status back so the UI reflects the
    /// actual result (e.g. `.requiresApproval` on unsandboxed Debug builds).
    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Registration can fail (e.g. app not in /Applications); keep the
            // reported status as-is.
        }
        refreshLaunchAtLoginStatus()
    }

    private func refreshLaunchAtLoginStatus() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
        launchAtLoginNeedsApproval = SMAppService.mainApp.status == .requiresApproval
    }

    func stop() {
        observer?.stop()
        observer = nil
        pollTimer?.invalidate()
        pollTimer = nil
        truthMonitor.stop()
    }

    func select(_ source: InputSource) {
        _ = switcher.change(to: source)
        refresh()
    }

    func refresh() {
        // The in-process enumeration keeps removed IMEs' input-mode entries
        // (see applyTruth) — filter out the IDs the truth probe tombstoned.
        let enumerated = provider.selectableInputSources()
        let newSources = enumerated.filter { !staleInputIDs.contains($0.persistentIdentifier) }
        applySources(newSources, current: provider.currentInputSource())
    }

    private func applySources(_ newSources: [InputSource], current newCurrent: InputSource?) {
        let changes = SourceChangeDetector.changes(previous: sources, current: newSources)

        // Publish only when something actually changed, so redundant refresh()
        // calls (duplicate notifications, poll + notification, select echo) do
        // not re-trigger menu rebuilds or icon updates.
        let sourceChanged = sources.map(\.persistentIdentifier) != newSources.map(\.persistentIdentifier)
        let currentChanged = currentSource?.persistentIdentifier != newCurrent?.persistentIdentifier
        if currentChanged {
            currentSource = newCurrent
            inputSourceHistory.recordCurrent(newCurrent?.persistentIdentifier)
        }
        if sourceChanged {
            sources = newSources
        }
        if sourceChanged || currentChanged {
            sourceRevision += 1
        }

        deactivateShortcuts(forRemoved: changes.removed)
        activateShortcuts(forAdded: changes.added)
        reconcilePreLaunchOrphansIfNeeded()
        registerShortcuts(for: sources)
        migrateLegacyShortcutsIfNeeded(for: sources)
    }

    /// Removals are invisible to in-process TIS queries, so an enabled-set
    /// change additionally schedules a truth probe.
    private func handleSourceChange(_ event: InputSourceChangeObserver.Event) {
        refresh()
        if event == .enabledChanged, usesRealTIS {
            truthMonitor.probeAfterEnabledSetChange()
        }
    }

    /// A failed probe (nil) keeps the current state unchanged.
    private func applyTruth(_ truthIDs: [String]?) {
        guard let truthIDs else { return }
        let visibleIDs = Set(sources.map(\.persistentIdentifier))
            .union(provider.selectableInputSources().map(\.persistentIdentifier))
        staleInputIDs = SourceTruthResolver.staleIDs(
            visibleIDs: visibleIDs,
            truthIDs: Set(truthIDs),
            previousStaleIDs: staleInputIDs
        )
        refresh()
    }

    /// A removed source's shortcut is retained in storage but its global hotkey
    /// is deactivated (`KeyboardShortcuts.disable`) so the key can be reassigned
    /// to another IME while the source is gone.
    private func deactivateShortcuts(forRemoved removedIDs: Set<String>) {
        for id in removedIDs {
            guard let name = shortcutName(forPersistentIdentifier: id),
                KeyboardShortcuts.getShortcut(for: name) != nil
            else { continue }
            KeyboardShortcuts.disable(name)
        }
    }

    /// Reactivates a re-added source's retained shortcut. If that shortcut now
    /// collides with a currently valid shortcut (the key was reassigned while
    /// the source was removed), the re-added shortcut is dropped instead —
    /// the drop set comes from the core `ShortcutReconciler` rules.
    private func activateShortcuts(forAdded addedIDs: Set<String>) {
        let conflictedIDs = ShortcutReconciler.conflictedReaddedIDs(
            shortcutsByID: activeShortcutsByID(),
            readdedIDs: addedIDs
        )
        for id in addedIDs {
            guard let name = shortcutName(forPersistentIdentifier: id),
                KeyboardShortcuts.getShortcut(for: name) != nil
            else { continue }
            KeyboardShortcuts.enable(name)
            if conflictedIDs.contains(id) {
                KeyboardShortcuts.setShortcut(nil, for: name)
            }
        }
    }

    /// The current shortcut assignment per active source ID (sources without
    /// a stored shortcut are absent).
    private func activeShortcutsByID() -> [String: KeyboardShortcuts.Shortcut] {
        var byID: [String: KeyboardShortcuts.Shortcut] = [:]
        for source in sources {
            if let shortcut = KeyboardShortcuts.getShortcut(for: shortcutName(for: source)) {
                byID[source.persistentIdentifier] = shortcut
            }
        }
        return byID
    }

    /// On first launch, deactivate shortcuts for sources that were removed while
    /// the app was not running (`storedNames` scans all defaults, so run once).
    /// The orphan set itself comes from the core `ShortcutReconciler` rules.
    private func reconcilePreLaunchOrphansIfNeeded() {
        guard !hasReconciledOrphans else { return }
        hasReconciledOrphans = true
        let activeNames = Set(sources.map { ShortcutNaming.name(for: $0) })
        // The toggle chords share the KeyboardShortcuts storage domain but are
        // not per-IME shortcuts. Treating them as orphans would disable them
        // in memory on every launch — the chord would stop firing even though
        // the recorder still shows it as recorded — so they are excluded here.
        let toggleNames: Set<String> = [
            ToggleShortcut.name.rawValue,
            ToggleShortcut.reverseName.rawValue,
        ]
        let storedNames = Set(KeyboardShortcuts.storedNames.map(\.rawValue)).subtracting(toggleNames)
        let orphaned = ShortcutReconciler.orphanedNames(stored: storedNames, active: activeNames)
        for name in KeyboardShortcuts.storedNames where orphaned.contains(name.rawValue) {
            KeyboardShortcuts.disable(name)
        }
    }

    private func shortcutName(forPersistentIdentifier id: String) -> KeyboardShortcuts.Name? {
        guard let rawValue = ShortcutNaming.name(forPersistentIdentifier: id) else { return nil }
        return cachedName(forRawValue: rawValue)
    }

    /// Stable dot-free KeyboardShortcuts.Name for a source. Cached.
    func shortcutName(for source: InputSource) -> KeyboardShortcuts.Name {
        cachedName(forRawValue: ShortcutNaming.name(for: source))
    }

    /// Returns the cached Name for a rawValue, creating and caching it on first use
    /// (creating a Name spawns a Task per init, so reuse them).
    private func cachedName(forRawValue rawValue: String) -> KeyboardShortcuts.Name {
        if let cached = shortcutNames[rawValue] {
            return cached
        }
        let name = KeyboardShortcuts.Name(rawValue)
        shortcutNames[rawValue] = name
        return name
    }

    // MARK: - Polling

    private var pollTimer: Timer?
    /// Truth-dropped IDs still enumerated in-process (removed IMEs' entries).
    private var staleInputIDs: Set<String> = []
    private let truthMonitor = SourceTruthMonitor()
    private var hasReconciledOrphans = false

    private func startPolling() {
        pollTimer?.invalidate()
        // Poll backstop for missed notifications: catches additions and
        // current-source switches (removals need the truth monitor — they
        // are invisible to in-process queries).
        let timer = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollInputSources()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    private func pollInputSources() {
        let enabledIDs = provider.selectableInputSources()
            .filter { !staleInputIDs.contains($0.persistentIdentifier) }
            .map(\.persistentIdentifier)
        let currentID = provider.currentInputSource()?.persistentIdentifier
        let knownIDs = sources.map(\.persistentIdentifier)
        let knownCurrentID = currentSource?.persistentIdentifier
        guard enabledIDs != knownIDs || currentID != knownCurrentID else { return }
        refresh()
    }

    /// The name to show in the settings list and menu bar — disambiguated with a
    /// vendor label when two IMEs share the same localized name (e.g. "두벌식").
    func displayName(for source: InputSource) -> String {
        InputSourceDisplayName.displayName(for: source, in: sources)
    }

    /// Called from the SwiftUI recorder when the user records/removes a shortcut.
    func shortcutDidChange() {
        shortcutRevision += 1
    }

    // MARK: - Shortcuts

    private func registerShortcuts(for sources: [InputSource]) {
        for source in sources {
            let name = shortcutName(for: source)
            guard registeredHandlerNames.insert(name.rawValue).inserted else { continue }
            KeyboardShortcuts.onKeyUp(for: name) { [weak self] in
                self?.select(source)
            }
        }
    }

    private func migrateLegacyShortcutsIfNeeded(for sources: [InputSource]) {
        guard !legacyMigrationCompleted else { return }
        // An empty source list means TIS is not queryable yet (first-launch
        // timing, provider hiccup); marking the pass complete now would
        // permanently consume it and silently lose the user's 1.x shortcuts.
        // Retry on the next refresh instead.
        guard !sources.isEmpty else { return }
        // The migration pass runs exactly once ever; no new legacy keys can
        // appear after the first run.
        legacyMigrationCompleted = true
        UserDefaults.standard.set(true, forKey: Self.legacyMigrationCompletedKey)

        let defaults = UserDefaults.standard
        for source in sources {
            let name = shortcutName(for: source)
            guard KeyboardShortcuts.getShortcut(for: name) == nil else { continue }

            let legacyKey = ShortcutNaming.name(for: source)
            guard
                let data = defaults.data(forKey: legacyKey),
                let legacy = LegacyShortcut.decodeMASShortcutData(data),
                legacy.keyCode >= 0  // NSNotFound is encoded as -1 (unset)
            else {
                continue
            }

            let shortcut = KeyboardShortcuts.Shortcut(
                KeyboardShortcuts.Key(rawValue: legacy.keyCode),
                modifiers: NSEvent.ModifierFlags(rawValue: UInt(legacy.modifierFlags))
            )
            KeyboardShortcuts.setShortcut(shortcut, for: name)
            defaults.removeObject(forKey: legacyKey)
        }
    }
}
