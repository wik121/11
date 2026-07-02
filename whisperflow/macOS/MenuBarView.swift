import SwiftUI

/// The popover shown when you click the menu-bar icon: current status,
/// a hint how to use the app, and the last transcript.
struct MenuBarView: View {
    @ObservedObject var engine: DictationEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(statusText, systemImage: statusIcon)
                .font(.headline)

            Text("Hold **right ⌥ Option** in any app, speak, then let go — the text is typed for you.")
                .font(.callout)
                .foregroundStyle(.secondary)

            Picker("Language", selection: $engine.language) {
                ForEach(DictationLanguage.allCases) { language in
                    Text(language.label).tag(language)
                }
            }
            .pickerStyle(.menu)

            if !engine.lastTranscript.isEmpty {
                Divider()
                Text(engine.lastTranscript)
                    .font(.callout)
                    .lineLimit(4)
            }

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
        .frame(width: 300)
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
