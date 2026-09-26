import UIKit

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

    static func translate(imageData: Data) async throws -> Data {
        guard let image = UIImage(data: imageData)?.cgImage else { throw Failure.unreadableImage }

        let lines = try TextRecognizer.recognize(in: image)
        // No text found: hand the screenshot back unchanged.
        if lines.isEmpty { return imageData }

        guard await Translator.isReady() else { throw Failure.languagesNotDownloaded }
        let translations = try await Translator.translate(lines.map(\.text))

        guard let png = Renderer.draw(on: image, lines: lines, translations: translations) else {
            throw Failure.renderFailed
        }
        return png
    }
}
