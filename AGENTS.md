# SwitchIM

macOS menu bar app that switches input sources (IMEs): per-IME global shortcuts
plus a tap/hold toggle chord. `SwitchIMApp/` is the app target; `SwitchIMCore/`
is the local Swift package holding the testable engine. The Xcode project is
generated from `project.yml`.

## Verify a change

```
xcodegen generate
xcodebuild -project SwitchIM.xcodeproj -scheme SwitchIM -configuration Debug -derivedDataPath .build/DerivedData build
cd SwitchIMCore && swift test
```

Rerun `xcodegen generate` after adding or removing any file — a stale file
reference fails the build. Run verification, fix any build, test, or lint
failures caused by the change, and rerun without asking for approval at each
step. Done means: the app target builds, core tests pass, and any new
user-facing strings exist across all four localization files.

## Conventions

- Source code and comments in English.
- User-facing strings: SwiftUI `Text("…")` literals and `String(localized:)`
  arguments are the localization keys. Add each new one to all four
  `SwitchIMApp/Resources/*.lproj/Localizable.strings` (en, ko, ja, zh-Hans);
  no dead keys remain.
- Swift 6 concurrency in the app target: when an API demands a `@Sendable`
  closure, hop back to the main actor with `Task { @MainActor in … }`
  (`AppState.startPolling`); bridge CF types with `unsafeDowncast`: a
  conditional `as?` downcast to a CF type is a compile error.
- Keep switching and toggle logic in the core as UI-framework-free pure types
  (`InputSourceToggleEngine`, `ShortcutReconciler`, `InputSourceSwitcher`);
  KeyboardShortcuts handling, overlay and settings plumbing stay in the app
  layer.

## SwitchIMCore/AGENTS.md

Consult `SwitchIMCore/AGENTS.md` when modifying `SwitchIMCore/`, running manual
lint/format/scan commands, or using the `--mock-tis` debug harness.
