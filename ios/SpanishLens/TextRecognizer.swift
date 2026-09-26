import CoreGraphics
import Vision

/// One line of text found in the image. `rect` is in image pixels, origin top-left.
struct RecognizedLine {
    let text: String
    let rect: CGRect
}

/// On-device OCR with Apple's Vision framework (the Swift version of the Nest OcrService).
enum TextRecognizer {
    static func recognize(in image: CGImage) throws -> [RecognizedLine] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["es-ES"]
        request.usesLanguageCorrection = true

        try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])

        let width = CGFloat(image.width)
        let height = CGFloat(image.height)

        return (request.results ?? []).compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            // Vision boxes are 0...1 with the origin at the bottom-left; flip to top-left pixels.
            let box = observation.boundingBox
            let rect = CGRect(
                x: box.minX * width,
                y: (1 - box.maxY) * height,
                width: box.width * width,
                height: box.height * height
            )
            return RecognizedLine(text: candidate.string, rect: rect)
        }
    }
}
