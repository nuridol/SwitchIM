import Foundation
import Testing

@testable import SwitchIMCore

@Suite("ShortcutNaming (legacy-compatible names)")
struct ShortcutNamingTests {
    private func makeSource(sourceID: String, modeID: String) -> InputSource {
        InputSource(
            sourceID: sourceID,
            inputModeID: modeID,
            name: sourceID,
            isEnabled: true,
            isSelectCapable: true,
            languages: [],
            iconImageURL: nil
        )
    }

    @Test("Name matches the legacy codename exactly")
    func matchesLegacyCodename() {
        let source = makeSource(sourceID: "com.apple.inputmethod.Korean", modeID: "2Set")
        #expect(
            ShortcutNaming.name(for: source)
                == ShortcutKey.codename(sourceID: "com.apple.inputmethod.Korean", inputModeID: "2Set")
        )
    }

    @Test("Empty modeID maps to dash, matching the legacy nil-modeID behavior")
    func emptyModeIDBecomesDash() {
        let source = makeSource(sourceID: "com.apple.keyboard.layout.ABC", modeID: "")
        #expect(ShortcutNaming.name(for: source) == "com_apple_keyboard_layout_ABC#-")
    }

    @Test("Name contains no dots (required by KeyboardShortcuts.Name)")
    func noDots() {
        let source = makeSource(sourceID: "org.youknowone.inputmethod.Gureum", modeID: "layout")
        #expect(!ShortcutNaming.name(for: source).contains("."))
    }
}

@Suite("LegacyShortcut (MASShortcut data migration)")
struct LegacyShortcutTests {
    /// Reproduces the exact encoding of the legacy MASShortcut object
    /// (MASShortcut.m `encodeWithCoder:` — keys `KeyCode` and `ModifierFlags`).
    @objc(MASShortcutStub)
    private final class MASShortcutStub: NSObject, NSCoding {
        let keyCode: Int
        let modifierFlags: Int

        init(keyCode: Int, modifierFlags: Int) {
            self.keyCode = keyCode
            self.modifierFlags = modifierFlags
        }

        func encode(with coder: NSCoder) {
            coder.encode(keyCode, forKey: "KeyCode")
            coder.encode(modifierFlags, forKey: "ModifierFlags")
        }

        required init?(coder: NSCoder) {
            nil
        }
    }

    private func legacyData(keyCode: Int, modifierFlags: Int) throws -> Data {
        try NSKeyedArchiver.archivedData(
            withRootObject: MASShortcutStub(keyCode: keyCode, modifierFlags: modifierFlags),
            requiringSecureCoding: false
        )
    }

    @Test("Decodes keyCode and modifierFlags from a legacy archive")
    func decodesShortcut() throws {
        let data = try legacyData(keyCode: 0x31, modifierFlags: 0x100000)  // Space + Command
        let decoded = LegacyShortcut.decodeMASShortcutData(data)
        #expect(decoded == LegacyShortcut(keyCode: 0x31, modifierFlags: 0x100000))
    }

    @Test("Decodes zero modifier flags")
    func decodesNoModifiers() throws {
        let data = try legacyData(keyCode: 0x24, modifierFlags: 0)  // Return
        let decoded = LegacyShortcut.decodeMASShortcutData(data)
        #expect(decoded == LegacyShortcut(keyCode: 0x24, modifierFlags: 0))
    }

    @Test("Invalid data returns nil")
    func invalidData() {
        #expect(LegacyShortcut.decodeMASShortcutData(Data()) == nil)
        #expect(LegacyShortcut.decodeMASShortcutData(Data("not an archive".utf8)) == nil)
    }
}
