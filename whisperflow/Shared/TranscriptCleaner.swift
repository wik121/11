import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Polishes a raw transcript before it's used: removes filler words and fixes
/// capitalization. On OSes with Apple's on-device Foundation Models
/// (macOS 26+ / iOS 26+) a local LLM does the polishing; everywhere else a
/// rule-based fallback runs. Either way it is 100% offline — no network, ever.
enum TranscriptCleaner {
    static func clean(_ text: String) async -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }

        #if canImport(FoundationModels)
        if #available(macOS 26.0, iOS 26.0, *) {
            if let polished = await polishWithLocalModel(trimmed) {
                return polished
            }
        }
        #endif
        return ruleBasedClean(trimmed)
    }

    /// Dependency-free fallback: strip the most common filler words
    /// (English, Norwegian, Urdu), tidy whitespace, capitalize the first letter.
    private static func ruleBasedClean(_ text: String) -> String {
        let fillers: Set<String> = [
            "um", "uh", "uhm", "ehm", "eh", "hmm", "mmm",   // English
            "altså", "liksom", "eeh", "øh", "øhm",          // Norwegian
            "یعنی", "اا", "ہمم",                              // Urdu
        ]

        let words = text.split(separator: " ").map(String.init).filter { word in
            !fillers.contains(word.lowercased().trimmingCharacters(in: .punctuationCharacters))
        }

        var cleaned = words.joined(separator: " ")
        if let first = cleaned.first, first.isLowercase {
            cleaned = first.uppercased() + cleaned.dropFirst()
        }
        return cleaned
    }
}

#if canImport(FoundationModels)
@available(macOS 26.0, iOS 26.0, *)
extension TranscriptCleaner {
    private static func polishWithLocalModel(_ text: String) async -> String? {
        guard case .available = SystemLanguageModel.default.availability else { return nil }

        let session = LanguageModelSession(instructions: """
            You clean up dictated text. Remove filler words (um, uh, ehm, altså, \
            liksom, یعنی), fix punctuation and capitalization, and keep the \
            language, wording and meaning exactly as spoken. \
            Reply with the cleaned text only — no commentary.
            """)
        guard let response = try? await session.respond(to: text) else { return nil }
        let polished = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        return polished.isEmpty ? nil : polished
    }
}
#endif
