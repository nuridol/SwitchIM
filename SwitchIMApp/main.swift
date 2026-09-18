import AppKit
import SwitchIMCore

// Truth-probe child (see EnabledSourcesProbe): prints one persistent
// identifier per line, before any NSApplication setup.
if CommandLine.arguments.contains("--print-enabled-sources") {
    for identifier in TISInputSourceService().selectableInputSources().map(\.persistentIdentifier) {
        print(identifier)
    }
    fflush(stdout)
    exit(0)
}

// Pure AppKit bootstrap: SwitchIM is an LSUIElement menu bar app whose windows
// (settings, toggle overlay) are all controller-presented, so there is no
// SwiftUI scene to declare — the SwiftUI `Settings` scene never attached to a
// screen in accessory apps, which is why settings go through
// SettingsWindowController instead.
let app = NSApplication.shared
let delegate = AppDelegate()

app.delegate = delegate
app.run()
