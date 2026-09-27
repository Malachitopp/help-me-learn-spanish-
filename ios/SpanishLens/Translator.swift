import Foundation
import Translation

/// On-device Spanish → English with Apple's Translation framework (the Swift version of TranslateService).
enum Translator {
    // Regions are spelled out (matching LanguageAvailability's supportedLanguages) so the system doesn't
    // pick them from the phone's language settings. Bare "es"/"en" broke after switching the phone to Spanish.
    static let source = Locale.Language(identifier: "es-ES")
    static let target = Locale.Language(identifier: "en-US")

    /// Reused between runs, so the language model stays loaded while the app is alive.
    private static var cachedSession: TranslationSession?

    /// True once the Spanish and English language packs are downloaded, so translation works offline.
    static func isReady() async -> Bool {
        await LanguageAvailability().status(from: source, to: target) == .installed
    }

    /// Apple's download prompt closes as soon as the person agrees, and the download carries on in the
    /// background, so check every couple of seconds until the packs are installed.
    static func waitUntilReady(timeout: Duration = .seconds(300)) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now + timeout
        while clock.now < deadline {
            if await isReady() { return true }
            do {
                try await Task.sleep(for: .seconds(2))
            } catch {
                return false  // The screen went away.
            }
        }
        return await isReady()
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
