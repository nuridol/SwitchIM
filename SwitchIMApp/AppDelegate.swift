import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let state: AppState
    private var statusItemController: StatusItemController?
    private var toggleCoordinator: ToggleCoordinator?

    override init() {
        #if DEBUG
            if CommandLine.arguments.contains("--mock-tis") || UserDefaults.standard.bool(forKey: "MockEnabled") {
                // Debug/test harness — see MockTISProvider.
                state = AppState(provider: MockTISProvider())
            } else {
                state = AppState()
            }
        #else
            state = AppState()
        #endif
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        state.start()
        statusItemController = StatusItemController(state: state)
        statusItemController?.start()

        let coordinator = ToggleCoordinator(state: state)
        coordinator.start()
        toggleCoordinator = coordinator
    }

    func applicationWillTerminate(_ notification: Notification) {
        toggleCoordinator?.stop()
        statusItemController?.stop()
        state.stop()
    }
}
