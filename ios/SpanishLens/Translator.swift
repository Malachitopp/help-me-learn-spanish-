import Foundation
import Translation

/// On-device Spanish → English with Apple's Translation framework (the Swift version of TranslateService).
enum Translator {
    static let source = Locale.Language(identifier: "es")
    static let target = Locale.Language(identifier: "en")

    /// True once the Spanish and English language packs are downloaded, so translation works offline.
    static func isReady() async -> Bool {
        await LanguageAvailability().status(from: source, to: target) == .installed
    }

    /// Returns one translation per input, in the same order.
    static func translate(_ texts: [String]) async throws -> [String] {
        let session = TranslationSession(installedSource: source, target: target)
        let requests = texts.enumerated().map { index, text in
            TranslationSession.Request(sourceText: text, clientIdentifier: String(index))
        }
        let responses = try await session.translations(from: requests)

        // Match responses back to their line by the identifier, rather than relying on order.
        var results = texts
        for response in responses {
            if let id = response.clientIdentifier, let index = Int(id), results.indices.contains(index) {
                results[index] = response.targetText
            }
        }
        return results
    }
}
