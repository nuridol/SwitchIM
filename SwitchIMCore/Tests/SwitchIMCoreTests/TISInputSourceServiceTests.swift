import Carbon
import Foundation
import Testing

@testable import SwitchIMCore

/// Real-TIS hardware tests. Skipped in normal CI; enable by creating the marker file:
///   touch /tmp/switchim_hw_tests
enum HardwareTests {
    static let enabled = FileManager.default.fileExists(atPath: "/tmp/switchim_hw_tests")
}

@Suite("TISInputSourceService (hardware, real system)")
struct TISInputSourceServiceTests {
    let service = TISInputSourceService()

    @Test(
        "Enumerated sources are non-empty and well-formed",
        .enabled(if: HardwareTests.enabled))
    func enumeratedSourcesAreWellFormed() {
        let sources = service.selectableInputSources()

        #expect(!sources.isEmpty)
        #expect(sources.allSatisfy { $0.isEnabled && $0.isSelectCapable })
        #expect(sources.allSatisfy { !$0.sourceID.isEmpty })
        // Deduplicated by persistent identifier.
        #expect(Set(sources.map(\.persistentIdentifier)).count == sources.count)
    }

    @Test(
        "The current source is enumerable and parses back into its parts",
        .enabled(if: HardwareTests.enabled))
    func currentSourceIsWellFormed() {
        guard let current = service.currentInputSource() else {
            #expect(Bool(false), "no current source")
            return
        }

        #expect(
            service.selectableInputSources().contains {
                $0.persistentIdentifier == current.persistentIdentifier
            })
        let parsed = InputSource.parsePersistentIdentifier(current.persistentIdentifier)
        #expect(parsed?.sourceID.isEmpty == false)
    }

    @Test(
        "Selecting the already-current source succeeds without switching",
        .enabled(if: HardwareTests.enabled))
    func selectingCurrentSourceIsANoOp() {
        guard let current = service.currentInputSource() else {
            #expect(Bool(false), "no current source")
            return
        }

        #expect(service.select(current))
        #expect(service.currentInputSource()?.persistentIdentifier == current.persistentIdentifier)
    }

    @Test(
        "Icon URL property reads as URL, string or nil",
        .enabled(if: HardwareTests.enabled))
    func iconURLPropertyReads() {
        for source in service.selectableInputSources() {
            // Just exercising the property plumbing on real TIS data — any of
            // URL, string-URL or nil is acceptable, but it must not trap.
            _ = source.iconImageURL
        }
    }
}
