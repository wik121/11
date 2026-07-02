import Foundation
import WhisperKit

/// Wraps WhisperKit: downloads a Whisper model on first launch (cached afterwards)
/// and turns raw audio samples into text — fully on-device, nothing leaves the device.
actor WhisperTranscriber {
    /// "base.en" is small and fast. For better accuracy try "small.en",
    /// or "large-v3" on Apple Silicon Macs. Non-".en" models handle all languages,
    /// including Norwegian.
    static let defaultModel = "base.en"

    private var whisperKit: WhisperKit?

    func loadModelIfNeeded(model: String = WhisperTranscriber.defaultModel) async throws {
        guard whisperKit == nil else { return }
        whisperKit = try await WhisperKit(WhisperKitConfig(model: model))
    }

    func transcribe(_ samples: [Float]) async throws -> String {
        try await loadModelIfNeeded()
        guard let whisperKit, !samples.isEmpty else { return "" }

        let results = try await whisperKit.transcribe(audioArray: samples)
        return results
            .map(\.text)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
