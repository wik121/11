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

    /// Dictation language, remembered across launches. Auto-detect works well
    /// when you switch languages mid-day; picking one explicitly is more accurate.
    @Published var language: DictationLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: Self.languageKey) }
    }

    /// Polish the transcript (drop filler words, fix punctuation) before using it.
    /// Uses Apple's on-device model when available, a rule-based pass otherwise.
    @Published var cleanupEnabled: Bool {
        didSet { UserDefaults.standard.set(cleanupEnabled, forKey: Self.cleanupKey) }
    }

    /// Stop recording automatically after ~1.5 s of silence. Defaults on for iOS
    /// (tap-to-stop is clumsy mid-thought) and off for macOS, where releasing
    /// the push-to-talk key already is the natural stop.
    @Published var autoStopEnabled: Bool {
        didSet { UserDefaults.standard.set(autoStopEnabled, forKey: Self.autoStopKey) }
    }

    /// Past dictations, stored only on-device.
    let history = TranscriptHistory()

    /// Called with the finished text. On macOS this types it into the active app;
    /// on iOS the view shows it and offers Copy.
    var onTranscript: ((String) -> Void)?

    private static let languageKey = "dictation.language"
    private static let cleanupKey = "dictation.cleanup"
    private static let autoStopKey = "dictation.autostop"
    private static let silenceLimit: TimeInterval = 1.5

    private let recorder = AudioRecorder()
    private let transcriber = WhisperTranscriber()

    init() {
        let defaults = UserDefaults.standard
        let savedLanguage = defaults.string(forKey: Self.languageKey) ?? ""
        language = DictationLanguage(rawValue: savedLanguage) ?? .auto
        cleanupEnabled = (defaults.object(forKey: Self.cleanupKey) as? Bool) ?? true
        #if os(iOS)
        autoStopEnabled = (defaults.object(forKey: Self.autoStopKey) as? Bool) ?? true
        #else
        autoStopEnabled = (defaults.object(forKey: Self.autoStopKey) as? Bool) ?? false
        #endif

        recorder.onAutoStop = { [weak self] in
            Task { @MainActor in self?.stopAndTranscribe() }
        }
    }

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
                recorder.autoStopAfterSilence = autoStopEnabled ? Self.silenceLimit : nil
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
                var text = try await transcriber.transcribe(samples, language: language)
                if cleanupEnabled {
                    text = await TranscriptCleaner.clean(text)
                }
                lastTranscript = text
                state = .idle
                if !text.isEmpty {
                    history.add(text)
                    onTranscript?(text)
                }
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
