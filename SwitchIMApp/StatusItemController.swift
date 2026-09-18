import AppKit
import Combine
import SwitchIMCore

/// Menu bar controller. Kept on AppKit (NSStatusItem/NSMenu) because live
/// IME list updates, checkmarks and shortcut mirroring are most reliable there.
/// The settings window itself is SwiftUI.
///
/// Mutating an `NSMenu` while it is being tracked (open in the menu bar) leaves
/// the menu window with a stale height, rendering blank space below the last
/// item. Opening the settings window activates the app, which re-triggers
/// input-source change notifications → `refresh()` → `rebuildMenu()`; if that
/// lands while the menu is open, the whitespace appears. Rebuilds and button-
/// icon updates are therefore deferred until `menuDidClose`, and the layout is
/// forced with `menu.update()` when the menu opens.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let state: AppState
    private let settingsController: SettingsWindowController
    private var statusItem: NSStatusItem?
    private var cancellables: Set<AnyCancellable> = []
    private let menu = NSMenu()
    private var menuIsOpen = false
    private var needsMenuRebuild = false
    private var needsIconUpdate = false
    /// Cached per-source icons so repeated updates don't re-load TIS icon files.
    private var iconCache: [String: NSImage] = [:]

    init(state: AppState) {
        self.state = state
        self.settingsController = SettingsWindowController(state: state)
        super.init()
    }

    func start() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.menu = menu
        statusItem = item
        menu.delegate = self

        updateButtonIcon(mode: state.menuBarIconMode)

        state.$sourceRevision
            .sink { [weak self] _ in
                guard let self else { return }
                self.rebuildMenu()
                self.updateButtonIcon(mode: self.state.menuBarIconMode)
            }
            .store(in: &cancellables)

        state.$shortcutRevision
            .sink { [weak self] _ in
                self?.rebuildMenu()
            }
            .store(in: &cancellables)

        state.$menuBarIconMode
            .sink { [weak self] mode in
                self?.updateButtonIcon(mode: mode)
            }
            .store(in: &cancellables)
    }

    func stop() {
        cancellables.removeAll()
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        statusItem = nil
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        menuIsOpen = true
        menu.update()  // force correct layout before display
    }

    func menuDidClose(_ menu: NSMenu) {
        menuIsOpen = false
        if needsMenuRebuild {
            needsMenuRebuild = false
            rebuildMenu()
        }
        if needsIconUpdate {
            needsIconUpdate = false
            updateButtonIcon(mode: state.menuBarIconMode)
        }
    }

    private func rebuildMenu() {
        guard !menuIsOpen else {
            needsMenuRebuild = true
            return
        }

        menu.removeAllItems()

        for source in state.sources {
            let item = NSMenuItem(
                title: state.displayName(for: source), action: #selector(selectSource(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = source.persistentIdentifier
            item.state = state.currentSource?.persistentIdentifier == source.persistentIdentifier ? .on : .off
            item.setShortcut(for: state.shortcutName(for: source))
            menu.addItem(item)
        }

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: String(localized: "Settings…"), action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let aboutItem = NSMenuItem(
            title: String(localized: "About SwitchIM"), action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        let quitItem = NSMenuItem(
            title: String(localized: "Quit SwitchIM"), action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q")
        quitItem.target = NSApp
        menu.addItem(quitItem)

        menu.update()
    }

    /// Sets the menu bar button image based on the icon mode setting and the
    /// current input source (legacy SwitchIM behavior).
    private func updateButtonIcon(mode: MenuBarIconMode) {
        guard !menuIsOpen else {
            needsIconUpdate = true
            return
        }
        guard let button = statusItem?.button else { return }

        switch mode {
        case .app:
            let image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "SwitchIM")
            image?.isTemplate = true
            button.image = image
        case .inputSource:
            guard let current = state.currentSource else {
                button.image = nil
                return
            }
            if let cached = iconCache[current.persistentIdentifier] {
                button.image = cached
                return
            }
            guard let icon = IconLoader.icon(for: current) else {
                button.image = nil
                return
            }
            iconCache[current.persistentIdentifier] = icon
            button.image = icon
        }
    }

    @objc private func selectSource(_ sender: NSMenuItem) {
        guard let identifier = sender.representedObject as? String,
            let source = state.sources.first(where: { $0.persistentIdentifier == identifier })
        else { return }
        state.select(source)
    }

    @objc private func openSettings() {
        settingsController.show()
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }
}
