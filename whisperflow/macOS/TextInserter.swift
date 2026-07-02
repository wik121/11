import AppKit
import Carbon.HIToolbox

/// Puts the transcript into whatever app you were using, Wispr Flow-style:
/// saves the clipboard, copies the text, simulates ⌘V, then restores the clipboard.
/// Requires Accessibility permission (System Settings → Privacy & Security → Accessibility).
enum TextInserter {
    static func insert(_ text: String) {
        let pasteboard = NSPasteboard.general
        let savedClipboard = pasteboard.string(forType: .string)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        pressCommandV()

        // Give the paste a moment to land before restoring the old clipboard.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            pasteboard.clearContents()
            if let savedClipboard {
                pasteboard.setString(savedClipboard, forType: .string)
            }
        }
    }

    /// Shows the system Accessibility prompt if permission hasn't been granted yet.
    static func ensureAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    private static func pressCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey = CGKeyCode(kVK_ANSI_V)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
