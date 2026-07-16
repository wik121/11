import AppKit
import SwiftUI

@main
struct AdvanceFlowSecureMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(engine: appDelegate.engine, hotkey: appDelegate.hotkey)
        } label: {
            MenuBarIcon(engine: appDelegate.engine)
        }
        .menuBarExtraStyle(.window)
    }
}

/// Wires everything together at launch:
/// hotkey pressed → record, hotkey released → transcribe → paste into the active app.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    let engine = DictationEngine()
    let hotkey = HotkeyMonitor()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Triggers the Accessibility prompt on first launch. Without this permission
        // the app can neither see the global hotkey nor paste text for you.
        TextInserter.ensureAccessibilityPermission()

        engine.onTranscript = { text in
            TextInserter.insert(text)
        }
        engine.prepare()

        hotkey.onPress = { [weak self] in self?.engine.startRecording() }
        hotkey.onRelease = { [weak self] in self?.engine.stopAndTranscribe() }
        hotkey.start()
    }
}

/// The little icon in the menu bar; switches to a waveform while listening.
struct MenuBarIcon: View {
    @ObservedObject var engine: DictationEngine

    var body: some View {
        Image(systemName: engine.state == .recording ? "waveform.circle.fill" : "mic.fill")
    }
}
