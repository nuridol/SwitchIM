import SwitchIMCore
import Testing

@Suite("CJKLanguageSet")
struct CJKLanguageSetTests {
    @Test("CJK language codes are members")
    func cjkMembers() {
        #expect(CJKLanguageSet.contains(["ko"]))
        #expect(CJKLanguageSet.contains(["ja"]))
        #expect(CJKLanguageSet.contains(["zh-Hans"]))
        #expect(CJKLanguageSet.contains(["zh-Hant"]))
        #expect(CJKLanguageSet.contains(["vi"]))
        #expect(CJKLanguageSet.contains(["yue"]))
    }

    @Test("Non-CJK languages are not members")
    func nonCJK() {
        #expect(!CJKLanguageSet.contains(["en"]))
        #expect(!CJKLanguageSet.contains(["ru"]))
        #expect(!CJKLanguageSet.contains(["fr"]))
        #expect(!CJKLanguageSet.contains(["de"]))
    }

    @Test("Empty language list is not CJK")
    func empty() {
        #expect(!CJKLanguageSet.contains([]))
    }

    @Test("Exact zh and zh-prefixed variants are members")
    func zhVariants() {
        #expect(CJKLanguageSet.contains(["zh"]))
        #expect(CJKLanguageSet.contains(["zh-TW"]))
        #expect(CJKLanguageSet.contains(["zh-CN"]))
    }
}

@Suite("InputSource persistent identifier")
struct InputSourceIdentifierTests {
    @Test("sourceID::inputModeID combination")
    func persistentIdentifier() {
        let source = InputSource(
            sourceID: "com.apple.inputmethod.Korean", inputModeID: "2Set", name: "", isEnabled: true,
            isSelectCapable: true, languages: ["ko"], iconImageURL: nil)
        #expect(source.persistentIdentifier == "com.apple.inputmethod.Korean::2Set")
        #expect(source.id == source.persistentIdentifier)
    }

    @Test("Duplicate sources are deduplicated")
    func dedup() {
        let a = InputSource(
            sourceID: "com.example.ime", inputModeID: "modeA", name: "", isEnabled: true, isSelectCapable: true,
            languages: [], iconImageURL: nil)
        let b = InputSource(
            sourceID: "com.example.ime", inputModeID: "modeA", name: "", isEnabled: true, isSelectCapable: true,
            languages: [], iconImageURL: nil)
        let c = InputSource(
            sourceID: "com.example.ime", inputModeID: "modeB", name: "", isEnabled: true, isSelectCapable: true,
            languages: [], iconImageURL: nil)
        #expect([a, b, c].uniquedByPersistentIdentifier().count == 2)
    }
}
