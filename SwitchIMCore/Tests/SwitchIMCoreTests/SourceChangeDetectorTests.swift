import Foundation
import SwitchIMCore
import Testing

@Suite("SourceChangeDetector")
struct SourceChangeDetectorTests {
    private func source(_ id: String, mode: String = "") -> InputSource {
        InputSource(
            sourceID: id,
            inputModeID: mode,
            name: id,
            isEnabled: true,
            isSelectCapable: true,
            languages: [],
            iconImageURL: nil
        )
    }

    @Test("Detects removed and added sources")
    func removesAndAdds() {
        let a = source("com.apple.inputmethod.Korean", mode: "2SetKorean")
        let b = source("org.youknowone.inputmethod.Gureum", mode: "han2")
        let c = source("dev.ensan.inputmethod.azooKeyMac", mode: "Japanese")
        let changes = SourceChangeDetector.changes(previous: [a, b], current: [b, c])
        #expect(changes.removed == [a.persistentIdentifier])
        #expect(changes.added == [c.persistentIdentifier])
    }

    @Test("No changes when lists match")
    func noChanges() {
        let a = source("org.youknowone.inputmethod.Gureum", mode: "han2")
        let b = source("org.youknowone.inputmethod.Gureum", mode: "system")
        let changes = SourceChangeDetector.changes(previous: [a, b], current: [b, a])
        #expect(changes.removed.isEmpty)
        #expect(changes.added.isEmpty)
    }
}

@Suite("ShortcutNaming persistent identifier")
struct ShortcutNamingPersistentTests {
    @Test("Persistent identifier maps back to the shortcut codename")
    func persistentToCodename() {
        #expect(
            ShortcutNaming.name(
                forPersistentIdentifier: "com.apple.inputmethod.Korean::com.apple.inputmethod.Korean.2SetKorean")
                == ShortcutKey.codename(
                    sourceID: "com.apple.inputmethod.Korean", inputModeID: "com.apple.inputmethod.Korean.2SetKorean")
        )
    }

    @Test("Empty modeID maps to dash")
    func emptyModeID() {
        #expect(
            ShortcutNaming.name(forPersistentIdentifier: "com.apple.keyboard.layout.ABC::")
                == ShortcutKey.codename(sourceID: "com.apple.keyboard.layout.ABC", inputModeID: nil)
        )
    }

    @Test("Malformed identifier returns nil")
    func malformed() {
        #expect(ShortcutNaming.name(forPersistentIdentifier: "") == nil)
    }
}
