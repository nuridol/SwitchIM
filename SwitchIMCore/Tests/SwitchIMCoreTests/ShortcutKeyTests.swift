import SwitchIMCore
import Testing

@Suite("ShortcutKey (legacy SwitchIM 1.x compatibility)")
struct ShortcutKeyTests {
    @Test("Dots in source ID are replaced with underscores")
    func dotsReplaced() {
        #expect(
            ShortcutKey.codename(sourceID: "com.apple.inputmethod.Korean", inputModeID: "2Set")
                == "com_apple_inputmethod_Korean#2Set"
        )
    }

    @Test("Nil modeID is represented as dash, matching legacy behavior")
    func nilModeIDUsesDash() {
        #expect(
            ShortcutKey.codename(sourceID: "com.apple.keyboard.layout.ABC", inputModeID: nil)
                == "com_apple_keyboard_layout_ABC#-"
        )
    }

    @Test("Explicit dash modeID is preserved")
    func explicitDashModeID() {
        #expect(
            ShortcutKey.codename(sourceID: "com.apple.keyboard.layout.ABC", inputModeID: "-")
                == "com_apple_keyboard_layout_ABC#-"
        )
    }

    @Test("Source ID without dots is unchanged except for the mode suffix")
    func noDots() {
        #expect(ShortcutKey.codename(sourceID: "ABC", inputModeID: "2Set") == "ABC#2Set")
    }

    @Test("Empty modeID string is kept as-is (not replaced by dash)")
    func emptyModeID() {
        #expect(ShortcutKey.codename(sourceID: "com.example.ime", inputModeID: "") == "com_example_ime#")
    }

    @Test("Gureum source ID round-trips to the legacy key")
    func gureum() {
        #expect(
            ShortcutKey.codename(sourceID: "org.youknowone.inputmethod.Gureum", inputModeID: "layout")
                == "org_youknowone_inputmethod_Gureum#layout"
        )
    }
}
