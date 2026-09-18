import Foundation
import Testing

@testable import SwitchIMCore

/// Controllable provider for exercising the switcher's state machine.
final class MockInputSourceProvider: InputSourceAccess {
    var selectableSources: [InputSource]
    var current: InputSource?
    var selectResult: Bool = true
    /// The first N select calls simulate the system silently ignoring the switch
    /// (current stays wherever it was); later calls stick.
    var sticksAfterSelects = 0
    private(set) var selected: [InputSource] = []

    init(selectableSources: [InputSource], current: InputSource?) {
        self.selectableSources = selectableSources
        self.current = current
    }

    func selectableInputSources() -> [InputSource] { selectableSources }

    func currentInputSource() -> InputSource? { current }

    func select(_ source: InputSource) -> Bool {
        selected.append(source)
        if selectResult, selected.count > sticksAfterSelects {
            current = source
        }
        return selectResult
    }
}

@Suite("InputSourceSwitcher (switching contract)")
@MainActor
struct InputSourceSwitcherTests {
    private func makeSource(
        sourceID: String = "com.apple.inputmethod.Korean", modeID: String = "2Set", languages: [String] = ["ko"]
    ) -> InputSource {
        InputSource(
            sourceID: sourceID,
            inputModeID: modeID,
            name: sourceID,
            isEnabled: true,
            isSelectCapable: true,
            languages: languages,
            iconImageURL: nil
        )
    }

    @Test("Successful select returns true without pulsing")
    func successfulSelect() {
        let target = makeSource()
        let mock = MockInputSourceProvider(selectableSources: [target], current: nil)
        var pulsed = false
        let switcher = InputSourceSwitcher(access: mock) { pulsed = true }

        #expect(switcher.change(to: target) == true)
        #expect(mock.selected == [target])
        #expect(!pulsed)
    }

    @Test("Failed select returns false without nudging")
    func failedSelect() {
        let target = makeSource()
        let mock = MockInputSourceProvider(selectableSources: [target], current: nil)
        mock.selectResult = false
        var pulsed = false
        let switcher = InputSourceSwitcher(access: mock) { pulsed = true }

        #expect(switcher.change(to: target) == false)
        #expect(pulsed == false)
    }

    @Test("CJK source that does not stick pulses and re-selects")
    func cjkvNudgeRetry() {
        let target = makeSource(languages: ["ko"])
        let mock = MockInputSourceProvider(selectableSources: [target], current: target)
        mock.sticksAfterSelects = 1  // first select no-ops, re-select sticks
        mock.current = makeSource(sourceID: "com.apple.keyboard.layout.ABC", modeID: "", languages: ["en"])
        var pulsed = false
        let switcher = InputSourceSwitcher(access: mock) { pulsed = true }

        #expect(switcher.change(to: target) == true)
        #expect(pulsed == true)
        #expect(mock.selected.count == 2)
    }

    @Test("Non-CJK source that does not stick does not pulse")
    func nonCJKVNoNudge() {
        let target = makeSource(sourceID: "com.apple.keyboard.layout.ABC", modeID: "", languages: ["en"])
        let mock = MockInputSourceProvider(selectableSources: [target], current: target)
        mock.sticksAfterSelects = 1
        mock.current = makeSource(languages: ["ko"])
        var pulsed = false
        let switcher = InputSourceSwitcher(access: mock) { pulsed = true }

        #expect(switcher.change(to: target) == false)
        #expect(pulsed == false)
    }

    @Test("Pulsed retry that still fails returns false")
    func cjkvNudgeStillFails() {
        let target = makeSource(languages: ["ko"])
        let mock = MockInputSourceProvider(selectableSources: [target], current: target)
        mock.sticksAfterSelects = .max  // never sticks
        mock.current = makeSource(sourceID: "com.apple.keyboard.layout.ABC", modeID: "", languages: ["en"])
        var pulsed = false
        let switcher = InputSourceSwitcher(access: mock) { pulsed = true }

        #expect(switcher.change(to: target) == false)
        #expect(pulsed == true)
        #expect(mock.selected.count == 2)
    }
}
