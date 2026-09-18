import KeyboardShortcuts
import ServiceManagement
import SwiftUI
import SwitchIMCore

struct SettingsView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        Form {
            Section("Startup") {
                Toggle(
                    "Launch at Login",
                    isOn: Binding(
                        get: { state.launchAtLogin },
                        set: { state.setLaunchAtLogin($0) }
                    ))
                if state.launchAtLoginNeedsApproval {
                    HStack {
                        Text("Enable in System Settings › General › Login Items")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button {
                            SMAppService.openSystemSettingsLoginItems()
                        } label: {
                            Text("Open System Settings")
                        }
                        .controlSize(.small)
                    }
                }
            }

            Section("Menu Bar Icon") {
                Picker("Menu Bar Icon", selection: $state.menuBarIconMode) {
                    Text("App icon").tag(MenuBarIconMode.app)
                    Text("Input method icon").tag(MenuBarIconMode.inputSource)
                }
                .pickerStyle(.radioGroup)
            }

            Section("Input Sources") {
                if state.sources.isEmpty {
                    Text("No input sources found.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(state.sources) { source in
                        sourceRow(source)
                    }
                }
            }

            ToggleShortcutSection()
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .navigationTitle("SwitchIM Settings")
    }

    private func sourceRow(_ source: InputSource) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label {
                    Text(state.displayName(for: source))
                } icon: {
                    if let icon = IconLoader.icon(for: source) {
                        Image(nsImage: icon)
                    } else if state.currentSource?.persistentIdentifier == source.persistentIdentifier {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.tint)
                    } else {
                        Image(systemName: "circle")
                    }
                }
                Spacer()
                KeyboardShortcuts.Recorder(for: state.shortcutName(for: source)) { _ in
                    state.shortcutDidChange()
                }
                .shortcutValidation { shortcut in
                    state.shortcutValidationResult(for: source, shortcut: shortcut)
                }
            }

            if let conflict = state.shortcutConflict(for: source) {
                Label {
                    Text(conflictMessage(conflict))
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                }
                .font(.caption)
                .foregroundStyle(.red)
                .padding(.leading, 4)
            }
        }
    }

    private func conflictMessage(_ conflict: AppState.ShortcutConflict) -> LocalizedStringKey {
        switch conflict {
        case .duplicate(let other):
            return "Conflicts with “\(other.name)”"
        case .takenBySystem:
            return "Already used by a system shortcut"
        }
    }
}

/// Global input-source toggle: one recorded chord — tap it to ping-pong
/// between the two most recent sources, hold it to pick from the overlay.
private struct ToggleShortcutSection: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        Section("Input Source Toggle") {
            HStack {
                Text("Toggle Shortcut")
                Spacer()
                KeyboardShortcuts.Recorder(for: ToggleShortcut.name) { shortcut in
                    ToggleShortcut.syncReverseChord(base: shortcut)
                }
                .shortcutValidation { shortcut in
                    state.toggleValidationResult(for: shortcut)
                }
            }

            Text("ToggleShortcutHint")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let conflictSource {
                Label {
                    Text("Already assigned to “\(conflictSource.name)”")
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                }
                .font(.caption)
                .foregroundStyle(.red)
            }
        }
    }

    /// The per-IME source whose shortcut matches the toggle chord, if any.
    private var conflictSource: InputSource? {
        guard let toggle = ToggleShortcut.current() else { return nil }
        return state.sourceAssigned(to: toggle)
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
}
