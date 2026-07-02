import AppKit
import SwiftUI

/// The popover shown when you click the menu-bar icon: current status, settings
/// (language, push-to-talk key, cleanup, auto-stop) and recent transcripts.
struct MenuBarView: View {
    @ObservedObject var engine: DictationEngine
    @ObservedObject var hotkey: HotkeyMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(statusText, systemImage: statusIcon)
                .font(.headline)

            Text("Hold **\(hotkey.key.label)** in any app, speak, then let go — the text is typed for you.")
                .font(.callout)
                .foregroundStyle(.secondary)

            Divider()

            Picker("Language", selection: $engine.language) {
                ForEach(DictationLanguage.allCases) { language in
                    Text(language.label).tag(language)
                }
            }

            Picker("Push-to-talk key", selection: $hotkey.key) {
                ForEach(PushToTalkKey.allCases) { key in
                    Text(key.label).tag(key)
                }
            }

            Toggle("Clean up text (remove filler words)", isOn: $engine.cleanupEnabled)

            Toggle("Auto-stop after silence", isOn: $engine.autoStopEnabled)

            HistorySection(history: engine.history)

            Divider()

            HStack {
                Button("Quit WhisperFlow") {
                    NSApplication.shared.terminate(nil)
                }
                Spacer()
                WatermarkView()
            }
        }
        .padding(16)
        .frame(width: 320)
    }

    private var statusText: String {
        switch engine.state {
        case .idle: "Ready"
        case .loadingModel: "Downloading Whisper model…"
        case .recording: "Listening…"
        case .transcribing: "Transcribing…"
        case .error(let message): message
        }
    }

    private var statusIcon: String {
        switch engine.state {
        case .recording: "waveform"
        case .transcribing: "hourglass"
        case .error: "exclamationmark.triangle"
        default: "mic"
        }
    }
}

/// The last few dictations — click one to copy it back to the clipboard.
private struct HistorySection: View {
    @ObservedObject var history: TranscriptHistory

    var body: some View {
        if !history.entries.isEmpty {
            Divider()

            HStack {
                Text("Recent")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Clear") { history.clear() }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }

            ForEach(history.entries.prefix(5)) { entry in
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(entry.text, forType: .string)
                } label: {
                    HStack {
                        Text(entry.text)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "doc.on.doc")
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Click to copy")
            }
        }
    }
}
