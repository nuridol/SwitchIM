#if DEBUG
    import Foundation
    import SwitchIMCore

    /// DEBUG / test-only input source provider.
    ///
    /// Presents a controllable set of "enabled" sources instead of real TIS state,
    /// enabling deterministic add/remove → shortcut disable/enable/conflict-drop
    /// testing without touching the user's input sources. It is never compiled into
    /// release builds.
    ///
    /// Activation (either works):
    /// - run the binary with `--mock-tis`, or
    /// - set the `MockEnabled` UserDefaults flag, e.g.:
    ///   `defaults write net.nuridol.mac.SwitchIM MockEnabled -bool YES`
    ///
    /// The active source list is read live from the `MockSources` UserDefaults key
    /// (array of source IDs); the app's 5s polling picks up changes:
    ///
    /// ```
    /// defaults write net.nuridol.mac.SwitchIM MockSources -array \
    ///   "com.apple.inputmethod.Korean.3SetKorean" \
    ///   "com.apple.inputmethod.Korean.390Sebulshik"
    /// ```
    final class MockTISProvider: InputSourceAccess {
        func selectableInputSources() -> [InputSource] {
            (UserDefaults.standard.stringArray(forKey: "MockSources") ?? []).map(makeSource)
        }

        func currentInputSource() -> InputSource? {
            selectableInputSources().first
        }

        func select(_ source: InputSource) -> Bool {
            true
        }

        private func makeSource(id: String) -> InputSource {
            InputSource(
                sourceID: id,
                inputModeID: id,
                name: id,
                bundleID: id.hasPrefix("com.apple.") ? "com.apple.inputmethod.Korean" : nil,
                isEnabled: true,
                isSelectCapable: true,
                languages: [],
                iconImageURL: nil
            )
        }
    }
#endif
