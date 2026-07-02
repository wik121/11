import AppKit

/// Watches the keyboard system-wide for the push-to-talk key: **right Option (⌥)**.
/// Hold it to record, release it to transcribe — no matter which app is in front.
/// Requires the Accessibility permission the app requests on first launch.
final class HotkeyMonitor {
    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var isHeld = false

    private let pushToTalkKeyCode: UInt16 = 61 // right Option

    func start() {
        let handler: (NSEvent) -> Void = { [weak self] event in
            self?.handle(event)
        }
        // Global monitor sees key events while *other* apps are focused;
        // the local one covers our own windows.
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: handler)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            handler(event)
            return event
        }
    }

    func stop() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
    }

    private func handle(_ event: NSEvent) {
        guard event.keyCode == pushToTalkKeyCode else { return }
        let pressed = event.modifierFlags.contains(.option)
        if pressed && !isHeld {
            isHeld = true
            onPress?()
        } else if !pressed && isHeld {
            isHeld = false
            onRelease?()
        }
    }
}
