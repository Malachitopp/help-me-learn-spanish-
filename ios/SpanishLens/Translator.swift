import Foundation
import Translation

/// On-device Spanish → English with Apple's Translation framework (the Swift version of TranslateService).
enum Translator {
    static let source = Locale.Language(identifier: "es")
    static let target = Locale.Language(identifier: "en")

    /// Reused between runs, so the language model stays loaded while the app is alive.
    private static var cachedSession: TranslationSession?

    /// True once the Spanish and English language packs are downloaded, so translation works offline.
    static func isReady() async -> Bool {
        await LanguageAvailability().status(from: source, to: target) == .installed
    }

    /// Returns one translation per input, in the same order.
    /// `onFirstResult` fires when the first line comes back (used to time how long the model takes to load).
    static func translate(_ texts: [String], onFirstResult: () -> Void = {}) async throws -> [String] {
        // Translate each distinct string once (e.g. a name repeated above several messages).
        var uniqueTexts: [String] = []
        var uniqueIndex: [String: Int] = [:]
        for text in texts where uniqueIndex[text] == nil {
            uniqueIndex[text] = uniqueTexts.count
            uniqueTexts.append(text)
        }

        let session = cachedSession ?? TranslationSession(installedSource: source, target: target)
        cachedSession = session

        let requests = uniqueTexts.enumerated().map { index, text in
            TranslationSession.Request(sourceText: text, clientIdentifier: String(index))
        }

        var translated = uniqueTexts
        var isFirst = true
        do {
            for try await response in session.translate(batch: requests) {
                if isFirst {
                    onFirstResult()
                    isFirst = false
                }
                // Match responses back by identifier, rather than relying on order.
                if let id = response.clientIdentifier, let index = Int(id), translated.indices.contains(index) {
                    translated[index] = response.targetText
                }
            }
        } catch {
            // Start with a fresh session next time in case this one is no longer usable.
            cachedSession = nil
            throw error
        }

        return texts.map { text in uniqueIndex[text].map { translated[$0] } ?? text }
    }
}
