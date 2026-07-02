import Foundation
import SwiftUI

/// The heart of the app: a small state machine that ties the recorder and the
/// transcriber together. Both the macOS menu-bar app and the iOS app drive this
/// same class — only the UI around it differs.
@MainActor
final class DictationEngine: ObservableObject {
    enum State: Equatable {
        case idle
        case loadingModel
        case recording
        case transcribing
        case error(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var lastTranscript = ""

    /// Called with the finished text. On macOS this types it into the active app;
    /// on iOS the view shows it and offers Copy.
    var onTranscript: ((String) -> Void)?

    private let recorder = AudioRecorder()
    private let transcriber = WhisperTranscriber()

    /// Kick off the (one-time) model download so the first dictation isn't slow.
    func prepare() {
        guard state == .idle else { return }
        state = .loadingModel
        Task {
            do {
                try await transcriber.loadModelIfNeeded()
                if state == .loadingModel { state = .idle }
            } catch {
                state = .error("Could not load model: \(error.localizedDescription)")
            }
        }
    }

    func startRecording() {
        guard state == .idle else { return }
        Task {
            guard await recorder.requestPermission() else {
                state = .error("Microphone access denied — enable it in Settings.")
                return
            }
            do {
                try recorder.start()
                state = .recording
            } catch {
                state = .error("Recording failed: \(error.localizedDescription)")
            }
        }
    }

    func stopAndTranscribe() {
        guard state == .recording else { return }
        let samples = recorder.stop()
        state = .transcribing
        Task {
            do {
                let text = try await transcriber.transcribe(samples)
                lastTranscript = text
                state = .idle
                if !text.isEmpty { onTranscript?(text) }
            } catch {
                state = .error("Transcription failed: \(error.localizedDescription)")
            }
        }
    }

    /// Tap-to-start / tap-to-stop, used by the iOS UI.
    func toggle() {
        switch state {
        case .idle: startRecording()
        case .recording: stopAndTranscribe()
        case .error: state = .idle
        default: break
        }
    }
}
