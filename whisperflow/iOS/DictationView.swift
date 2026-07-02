import SwiftUI

/// The whole iOS UI: one big mic button, the transcript, and a Copy button.
/// iOS doesn't let normal apps type into other apps, so copy-paste (or the
/// share sheet) is the way to move the text where you need it.
struct DictationView: View {
    @StateObject private var engine = DictationEngine()

    var body: some View {
        VStack(spacing: 24) {
            Text("WhisperFlow")
                .font(.largeTitle.bold())

            Text(statusText)
                .foregroundStyle(.secondary)

            ScrollView {
                Text(engine.lastTranscript.isEmpty ? "Your words will appear here." : engine.lastTranscript)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))

            Button {
                engine.toggle()
            } label: {
                Image(systemName: engine.state == .recording ? "stop.circle.fill" : "mic.circle.fill")
                    .font(.system(size: 88))
                    .foregroundStyle(engine.state == .recording ? .red : .accentColor)
            }
            .disabled(engine.state == .transcribing || engine.state == .loadingModel)

            Button {
                UIPasteboard.general.string = engine.lastTranscript
            } label: {
                Label("Copy transcript", systemImage: "doc.on.doc")
            }
            .buttonStyle(.borderedProminent)
            .disabled(engine.lastTranscript.isEmpty)
        }
        .padding()
        .task { engine.prepare() }
    }

    private var statusText: String {
        switch engine.state {
        case .idle: "Tap the mic and start talking."
        case .loadingModel: "Downloading Whisper model (first launch only)…"
        case .recording: "Listening… tap to stop."
        case .transcribing: "Transcribing…"
        case .error(let message): message
        }
    }
}

#Preview {
    DictationView()
}
