import AppKit

/// The keys you can hold to dictate. All are "modifier-style" keys that arrive
/// as `.flagsChanged` events, which is what makes hold-to-talk reliable.
enum PushToTalkKey: String, CaseIterable, Identifiable {
    case rightOption
    case rightCommand
    case rightControl
    case function

    var id: String { rawValue }

    var keyCode: UInt16 {
        switch self {
        case .rightOption: 61
        case .rightCommand: 54
        case .rightControl: 62
        case .function: 63
        }
    }

    var flag: NSEvent.ModifierFlags {
        switch self {
        case .rightOption: .option
        case .rightCommand: .command
        case .rightControl: .control
        case .function: .function
        }
    }

    var label: String {
        switch self {
        case .rightOption: "Right ⌥ Option"
        case .rightCommand: "Right ⌘ Command"
        case .rightControl: "Right ⌃ Control"
        case .function: "🌐 Fn / Globe"
        }
    }
}

/// Watches the keyboard system-wide for the push-to-talk key.
/// Hold it to record, release it to transcribe — no matter which app is in front.
/// Requires the Accessibility permission the app requests on first launch.
@MainActor
final class HotkeyMonitor: ObservableObject {
    /// User-selectable in the menu-bar popover, remembered across launches.
    @Published var key: PushToTalkKey {
        didSet { UserDefaults.standard.set(key.rawValue, forKey: Self.keyDefaultsKey) }
    }

    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?

    private static let keyDefaultsKey = "hotkey.pushToTalkKey"
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var isHeld = false

    init() {
        let saved = UserDefaults.standard.string(forKey: Self.keyDefaultsKey) ?? ""
        key = PushToTalkKey(rawValue: saved) ?? .rightOption
    }

    func start() {
        // Global monitor sees key events while *other* apps are focused;
        // the local one covers our own windows. NSEvent isn't Sendable, so only
        // the two values we need cross over to the main actor.
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            let keyCode = event.keyCode
            let flags = event.modifierFlags
            Task { @MainActor in self?.handle(keyCode: keyCode, flags: flags) }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            let keyCode = event.keyCode
            let flags = event.modifierFlags
            Task { @MainActor in self?.handle(keyCode: keyCode, flags: flags) }
            return event
        }
    }

    func stop() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
    }

    private func handle(keyCode: UInt16, flags: NSEvent.ModifierFlags) {
        guard keyCode == key.keyCode else { return }
        let pressed = flags.contains(key.flag)
        if pressed && !isHeld {
            isHeld = true
            onPress?()
        } else if !pressed && isHeld {
            isHeld = false
            onRelease?()
        }
    }
}
