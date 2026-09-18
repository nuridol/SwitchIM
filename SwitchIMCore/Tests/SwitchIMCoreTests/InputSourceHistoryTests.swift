import Testing

@testable import SwitchIMCore

@Suite("InputSourceHistory (MRU tracking)")
@MainActor
struct InputSourceHistoryTests {
    @Test("Records shift the previous entry down")
    func shiftsPrevious() {
        let history = InputSourceHistory()

        history.recordCurrent("A")
        #expect(history.currentID == "A")
        #expect(history.previousID == nil)

        history.recordCurrent("B")
        #expect(history.currentID == "B")
        #expect(history.previousID == "A")

        history.recordCurrent("C")
        #expect(history.currentID == "C")
        #expect(history.previousID == "B")
    }

    @Test("Same-ID and nil records are no-ops")
    func deduplicates() {
        let history = InputSourceHistory(currentID: "A")
        history.recordCurrent("B")

        history.recordCurrent("B")
        #expect(history.previousID == "A")

        history.recordCurrent(nil)
        #expect(history.currentID == "B")
        #expect(history.previousID == "A")
    }
}
