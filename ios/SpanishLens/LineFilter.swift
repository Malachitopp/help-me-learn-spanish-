import NaturalLanguage

/// Decides which OCR lines are worth translating. Fewer lines means faster translation,
/// and lines that are skipped stay exactly as they were in the screenshot.
enum LineFilter {
    static func linesToTranslate(_ lines: [RecognizedLine]) -> [RecognizedLine] {
        let recognizer = NLLanguageRecognizer()
        recognizer.languageConstraints = [.spanish, .english]

        return lines.filter { line in
            // Times, numbers, emoji: nothing to translate.
            guard line.text.contains(where: \.isLetter) else { return false }

            recognizer.reset()
            recognizer.processString(line.text)
            let englishConfidence = recognizer.languageHypotheses(withMaximum: 2)[.english] ?? 0

            // Very short lines are hard to classify, so only skip lines with a few words
            // that are clearly English (e.g. "Delivered", "Tap to reply" in the phone's UI).
            let wordCount = line.text.split(whereSeparator: \.isWhitespace).count
            return !(wordCount >= 2 && englishConfidence > 0.9)
        }
    }
}
