import Foundation

/// Reads the enabled-source truth by spawning a fresh child process
/// (`--print-enabled-sources`): only a process started after an IME removal
/// enumerates the true set — see `SourceTruthResolver` for why the running
/// process cannot see it.
enum EnabledSourcesProbe {
    /// nil on any failure (spawn error, non-zero exit, empty output).
    ///
    /// Async only so the blocking read runs off the main actor. The child is
    /// this binary running a ~1ms query and exiting, so no read timeout —
    /// the backstop timer schedules another probe regardless.
    static func enabledSourceIDs() async -> [String]? {
        guard let executableURL = Bundle.main.executableURL else { return nil }
        let process = Process()
        process.executableURL = executableURL
        process.arguments = ["--print-enabled-sources"]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return nil
        }

        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        let text = String(data: data, encoding: .utf8) ?? ""
        let ids =
            text
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        // Empty output = child failure, not "no sources" — as truth it
        // would wipe the menu.
        guard !ids.isEmpty else { return nil }
        return ids
    }
}
