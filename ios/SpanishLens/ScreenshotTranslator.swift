import UIKit

struct TranslationOutput {
    /// JPEG of the translated screenshot, or nil when no text was found.
    let translatedJPEG: Data?
    /// How long each step took, shown in the app to find what's slow.
    let stages: [(name: String, duration: Duration)]
}

/// The whole pipeline, same as the Nest controller: OCR → translate → draw.
enum ScreenshotTranslator {
    enum Failure: LocalizedError {
        case unreadableImage
        case languagesNotDownloaded
        case renderFailed

        var errorDescription: String? {
            switch self {
            case .unreadableImage:
                return "That file couldn't be read as an image."
            case .languagesNotDownloaded:
                return "Open Spanish Lens and tap Download languages first."
            case .renderFailed:
                return "Couldn't draw the translated image."
            }
        }
    }

    static func translate(imageData: Data) async throws -> TranslationOutput {
        let clock = ContinuousClock()
        var stages: [(name: String, duration: Duration)] = []
        var stageStart = clock.now
        func finishStage(_ name: String) {
            let now = clock.now
            stages.append((name, now - stageStart))
            stageStart = now
        }

        guard let image = UIImage(data: imageData)?.cgImage else { throw Failure.unreadableImage }
        finishStage("Decode image")

        let lines = try TextRecognizer.recognize(in: image)
        finishStage("Read text (OCR)")
        if lines.isEmpty { return TranslationOutput(translatedJPEG: nil, stages: stages) }

        let translations: [String]
        do {
            translations = try await Translator.translate(lines.map(\.text))
        } catch {
            // Only check the language packs when translating fails, rather than on every run.
            let ready = await Translator.isReady()
            if !ready { throw Failure.languagesNotDownloaded }
            throw error
        }
        finishStage("Translate")

        guard let jpeg = Renderer.draw(on: image, lines: lines, translations: translations) else {
            throw Failure.renderFailed
        }
        finishStage("Draw + save image")

        return TranslationOutput(translatedJPEG: jpeg, stages: stages)
    }
}
