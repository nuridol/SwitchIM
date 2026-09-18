# AGENTS.md

Agent instructions for the `SwitchIMCore` package and its supporting test
harness. Repo-wide conventions, build commands, and the verification bar live
in the root `AGENTS.md`.

## Hardware-gated tests

Real-TIS tests (system input sources) run only when the marker file exists,
keeping CI safe:

```
touch /tmp/switchim_hw_tests && cd SwitchIMCore && swift test && rm /tmp/switchim_hw_tests
```

## Formatting & linting (auto-run on Xcode builds)

Both Xcode targets run swift-format and SwiftLint pre-build phases.
Layout rules belong to swift-format; SwiftLint enforces code style.
Run manually from the **repo root** (running inside `SwitchIMCore/` causes
relative path resolution errors in SwiftLint):

```
xcrun swift-format format --in-place --recursive SwitchIMApp SwitchIMCore/Sources SwitchIMCore/Tests
swiftlint
```

## Dead-code scanning (Periphery, auto-run on app builds)

App builds run Periphery warnings using the existing index store.
Run a full manual scan (indexes tests as well) from the **repo root**:

```
periphery scan
```

## Debug / test harness (`--mock-tis`)

Debug-only mock provider (`MockTISProvider`) replacing real TIS state for deterministic add/remove testing.
- **Why not real TIS?**: `TISEnableInputSource` is a no-op on modern macOS, making programmatic IME addition impossible.
- **Enable**: Run binary with `--mock-tis` or set `defaults write net.nuridol.mac.SwitchIM MockEnabled -bool YES`.
- **Control sources**: Write non-active mock source IDs to `MockSources` (picked up by 5s polling):
  ```
  defaults write net.nuridol.mac.SwitchIM MockSources -array "com.apple.inputmethod.Korean.3SetKorean"
  ```
- **Cleanup**: `defaults delete net.nuridol.mac.SwitchIM`

## Behavior notes

- **Removed-IME detection (TIS cache bug)**:
  - Behavior: Query enabled sources via child process (`EnabledSourcesProbe`) and filter via `SourceTruthResolver` (tested in `SourceTruthResolverTests.swift`). The `--mock-tis` harness skips the probe.
  - Why not in-process queries? macOS does not invalidate input-mode cache entries on IME removal until process exit (even after receiving change notifications); only a fresh process sees the true state. Additions do not need the probe as in-process cache updates correctly.
- **Shortcut retention on IME removal**:
  - Behavior: Disable hotkeys via `KeyboardShortcuts.disable` on removal; re-enable on re-add, dropping (`nil`) only on collision.
  - Why not delete immediately? Prevents accidental loss of user hotkey bindings during transient IME toggles or restarts.
- **Pre-launch orphans**:
  - Behavior: Reconcile once at startup (`reconcilePreLaunchOrphansIfNeeded`); strictly exclude `ToggleShortcut` chords. Core logic is in `ShortcutReconciler` (tested in `ShortcutReconcilerTests.swift`).
  - Why not scan on every refresh? Reading `KeyboardShortcuts.storedNames` is expensive.
  - Why not scan chords? Chords share the KeyboardShortcuts storage domain but are not per-IME shortcuts; scanning them would disable them in memory.