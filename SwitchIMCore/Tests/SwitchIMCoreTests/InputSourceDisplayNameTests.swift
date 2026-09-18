import Foundation
import SwitchIMCore
import Testing

@Suite("InputSourceDisplayName (collision disambiguation)")
struct InputSourceDisplayNameTests {
    private func makeSource(name: String, bundleID: String?, sourceID: String) -> InputSource {
        InputSource(
            sourceID: sourceID,
            inputModeID: "",
            name: name,
            bundleID: bundleID,
            isEnabled: true,
            isSelectCapable: true,
            languages: ["ko"],
            iconImageURL: nil
        )
    }

    @Test("Apple bundle IDs map to Apple")
    func appleVendor() {
        #expect(InputSourceDisplayName.vendorName(bundleID: "com.apple.inputmethod.Korean") == "Apple")
    }

    @Test("Reverse-DNS product becomes the vendor label")
    func dnsVendor() {
        #expect(InputSourceDisplayName.vendorName(bundleID: "org.youknowone.inputmethod.Gureum") == "Gureum")
    }

    @Test("Trailing Mac suffix is cleaned")
    func macSuffixCleaned() {
        #expect(InputSourceDisplayName.vendorName(bundleID: "dev.ensan.inputmethod.azooKeyMac") == "azooKey")
    }

    @Test("Plain name when there is no collision")
    func noCollision() {
        let gureum = makeSource(
            name: "두벌식", bundleID: "org.youknowone.inputmethod.Gureum",
            sourceID: "org.youknowone.inputmethod.Gureum.han2")
        let list = [gureum]
        #expect(InputSourceDisplayName.displayName(for: gureum, in: list) == "두벌식")
    }

    @Test("Vendor label appended on collision")
    func collisionAppendsVendor() {
        let apple = makeSource(
            name: "두벌식", bundleID: "com.apple.inputmethod.Korean", sourceID: "com.apple.inputmethod.Korean.2SetKorean")
        let gureum = makeSource(
            name: "두벌식", bundleID: "org.youknowone.inputmethod.Gureum",
            sourceID: "org.youknowone.inputmethod.Gureum.han2")
        let list = [apple, gureum]
        #expect(InputSourceDisplayName.displayName(for: apple, in: list) == "두벌식 (Apple)")
        #expect(InputSourceDisplayName.displayName(for: gureum, in: list) == "두벌식 (Gureum)")
    }

    @Test("Distinct names never get a vendor suffix")
    func distinctNamesStayPlain() {
        let roman = makeSource(
            name: "Roman", bundleID: "org.youknowone.inputmethod.Gureum",
            sourceID: "org.youknowone.inputmethod.Gureum.system")
        let azoo = makeSource(
            name: "azooKey (日本語)", bundleID: "dev.ensan.inputmethod.azooKeyMac",
            sourceID: "dev.ensan.inputmethod.azooKeyMac.Japanese")
        let list = [roman, azoo]
        #expect(InputSourceDisplayName.displayName(for: roman, in: list) == "Roman")
        #expect(InputSourceDisplayName.displayName(for: azoo, in: list) == "azooKey (日本語)")
    }
}

@Suite("InputSourceIconURL fallbacks")
struct InputSourceIconURLTests {
    @Test("Tiff fallback swaps png extension")
    func tiffFallback() throws {
        let url = try #require(
            URL(
                string:
                    "file:///System/Library/Input%20Methods/KoreanIM.app/Contents/PlugIns/KIM_Extension"
                    + ".appex/Contents/Resources/2SetKorean.png"
            ))
        let tiff = InputSourceIconURL.tiffFallbackURL(for: url)
        #expect(tiff?.pathExtension == "tiff")
        #expect(tiff?.deletingPathExtension() == url.deletingPathExtension())
    }

    @Test("No fallback for an existing tiff URL")
    func noTiffForTiff() throws {
        let url = try #require(
            URL(string: "file:///Library/Input%20Methods/azooKeyMac.app/Contents/Resources/main.tiff"))
        #expect(InputSourceIconURL.tiffFallbackURL(for: url) == nil)
    }

    @Test("Finds the enclosing .app bundle")
    func appBundle() throws {
        let url = try #require(URL(string: "file:///Library/Input%20Methods/Gureum.app/Contents/Resources/han2.png"))
        let app = InputSourceIconURL.appBundleURL(from: url)
        #expect(app?.lastPathComponent == "Gureum.app")
    }

    @Test("Finds .app through an appex plug-in path")
    func appBundleThroughAppex() throws {
        let url = try #require(
            URL(
                string:
                    "file:///System/Library/Input%20Methods/KoreanIM.app/Contents/PlugIns/KIM_Extension"
                    + ".appex/Contents/Resources/2SetKorean.png"
            ))
        let app = InputSourceIconURL.appBundleURL(from: url)
        #expect(app?.lastPathComponent == "KoreanIM.app")
    }

    @Test("Asset name is the filename without extension")
    func assetName() throws {
        let url = try #require(URL(string: "file:///Library/Input%20Methods/Gureum.app/Contents/Resources/han2.png"))
        #expect(InputSourceIconURL.assetName(from: url) == "han2")
    }
}
