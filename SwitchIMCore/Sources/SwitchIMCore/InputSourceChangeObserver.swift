import Carbon
import Foundation

/// Observes input source changes via distributed notifications, reporting
/// which kind changed.
@MainActor
public final class InputSourceChangeObserver {
    public enum Event: Equatable {
        /// `kTISNotifySelectedKeyboardInputSourceChanged` — the user switched IMEs.
        case selectedChanged
        /// `kTISNotifyEnabledKeyboardInputSourcesChanged` — the enabled set
        /// changed (IME added or removed).
        case enabledChanged
    }

    private var onChange: ((Event) -> Void)?
    private var eventByName: [Notification.Name: Event] = [:]

    public init(onChange: ((Event) -> Void)? = nil) {
        self.onChange = onChange
    }

    public func start() {
        let center = DistributedNotificationCenter.default()
        let names: [(Notification.Name, Event)] = [
            (Notification.Name(rawValue: kTISNotifySelectedKeyboardInputSourceChanged as String), .selectedChanged),
            (Notification.Name(rawValue: kTISNotifyEnabledKeyboardInputSourcesChanged as String), .enabledChanged),
        ]
        for (name, event) in names {
            center.addObserver(
                self,
                selector: #selector(inputSourcesDidChange(_:)),
                name: name,
                object: nil
            )
            eventByName[name] = event
        }
    }

    public func stop() {
        DistributedNotificationCenter.default().removeObserver(self)
    }

    @objc private func inputSourcesDidChange(_ notification: Notification) {
        onChange?(eventByName[notification.name] ?? .selectedChanged)
    }
}
