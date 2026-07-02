import SwiftUI
import UIKit

/// The whole iOS UI: one big mic button, the transcript, settings toggles and a
/// history sheet. iOS doesn't let normal apps type into other apps, so copy-paste
/// (or the share sheet) is the way to move the text where you need it.
struct DictationView: View {
    @StateObject private var engine = DictationEngine()
    @State private var showHistory = false

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("WhisperFlow")
                    .font(.largeTitle.bold())
                Spacer()
                Button {
                    showHistory = true
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.title3)
                }
                .accessibilityLabel("History")
            }

            Text(statusText)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Picker("Language", selection: $engine.language) {
                ForEach(DictationLanguage.allCases) { language in
                    Text(language.label).tag(language)
                }
            }
            .pickerStyle(.segmented)

            Toggle("Clean up text (remove filler words)", isOn: $engine.cleanupEnabled)
            Toggle("Auto-stop after silence", isOn: $engine.autoStopEnabled)

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
        .overlay(alignment: .bottomTrailing) {
            WatermarkView().padding(8)
        }
        .sheet(isPresented: $showHistory) {
            HistoryView(history: engine.history)
        }
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

/// Past dictations — tap one to copy it. Stored only on this device.
struct HistoryView: View {
    @ObservedObject var history: TranscriptHistory
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(history.entries) { entry in
                Button {
                    UIPasteboard.general.string = entry.text
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.text)
                            .lineLimit(3)
                            .foregroundStyle(.primary)
                        Text(entry.date, style: .relative)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .overlay {
                if history.entries.isEmpty {
                    ContentUnavailableView("No dictations yet", systemImage: "clock")
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button("Clear") { history.clear() }
                        .disabled(history.entries.isEmpty)
                }
            }
        }
    }
}

#Preview {
    DictationView()
}
