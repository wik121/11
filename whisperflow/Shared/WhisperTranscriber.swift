import Foundation
import WhisperKit

/// Languages offered in the UI. Whisper itself understands ~99 languages,
/// so adding another one here is a single new case.
enum DictationLanguage: String, CaseIterable, Identifiable {
    case auto = "auto"
    case english = "en"
    case norwegian = "no"
    case urdu = "ur"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .auto: "Auto-detect"
        case .english: "English"
        case .norwegian: "Norsk"
        case .urdu: "اردو (Urdu)"
        }
    }
}

/// Wraps WhisperKit: downloads a Whisper model on first launch (cached afterwards)
/// and turns raw audio samples into text — fully on-device, nothing leaves the device.
actor WhisperTranscriber {
    /// Both are multilingual (English, Norwegian, Urdu, ~96 more).
    /// Macs get "large-v3" — noticeably better for Urdu, and Apple Silicon
    /// handles it fine (one-time ~3 GB download; switch to "small" for a
    /// quicker start). iPhones get "small" for speed and battery.
    static let defaultModel: String = {
        #if os(macOS)
        return "large-v3"
        #else
        return "small"
        #endif
    }()

    private var whisperKit: WhisperKit?

    func loadModelIfNeeded(model: String = WhisperTranscriber.defaultModel) async throws {
        guard whisperKit == nil else { return }
        whisperKit = try await WhisperKit(WhisperKitConfig(model: model))
    }

    func transcribe(_ samples: [Float], language: DictationLanguage = .auto) async throws -> String {
        try await loadModelIfNeeded()
        guard let whisperKit, !samples.isEmpty else { return "" }

        var options = DecodingOptions(task: .transcribe)
        if language == .auto {
            options.detectLanguage = true
        } else {
            options.language = language.rawValue
        }

        let results = try await whisperKit.transcribe(audioArray: samples, decodeOptions: options)
        return results
            .map(\.text)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
