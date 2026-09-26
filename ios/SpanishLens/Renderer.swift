import UIKit

/// Paints each translation over its original line (the Swift version of the Nest canvas service).
enum Renderer {
    static func draw(on image: CGImage, lines: [RecognizedLine], translations: [String]) -> Data? {
        let size = CGSize(width: image.width, height: image.height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        let pixels = PixelSampler(image)

        // JPEG rather than PNG: much faster to encode at full resolution, and a smaller file to hand back.
        return UIGraphicsImageRenderer(size: size, format: format).jpegData(withCompressionQuality: 0.9) { context in
            UIImage(cgImage: image).draw(in: CGRect(origin: .zero, size: size))

            for (line, text) in zip(lines, translations) {
                // Grow the cover so accents and ¿ ¡ poking out of the box are hidden too.
                let pad = max(2, line.rect.height * 0.15)
                let cover = line.rect.insetBy(dx: -pad, dy: -pad)

                // Match the background just outside the cover, so dark mode and chat bubbles blend in.
                let background = pixels?.averageColor(around: cover.insetBy(dx: -2, dy: -2)) ?? .white
                background.setFill()
                context.fill(cover)

                drawFitted(text, in: line.rect, color: background.isLight ? .black : .white)
            }
        }
    }

    /// Picks the largest font where the text (wrapping if needed) fits the box, then centres it vertically.
    private static func drawFitted(_ text: String, in rect: CGRect, color: UIColor) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping

        func attributes(_ fontSize: CGFloat) -> [NSAttributedString.Key: Any] {
            [.font: UIFont.systemFont(ofSize: fontSize), .foregroundColor: color, .paragraphStyle: paragraph]
        }
        func textSize(_ fontSize: CGFloat) -> CGRect {
            (text as NSString).boundingRect(
                with: CGSize(width: rect.width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin],
                attributes: attributes(fontSize),
                context: nil
            )
        }
        func fits(_ fontSize: CGFloat) -> Bool { textSize(fontSize).height <= rect.height * 1.05 }

        // Binary search between 8pt and 85% of the box height: ~7 measurements instead of dozens.
        var low: CGFloat = 8
        var high = max(low, rect.height * 0.85)
        if fits(high) {
            low = high
        } else {
            for _ in 0..<7 {
                let mid = (low + high) / 2
                if fits(mid) { low = mid } else { high = mid }
            }
        }

        let finalAttributes = attributes(low)
        let needed = textSize(low)
        let origin = CGPoint(x: rect.minX, y: rect.midY - needed.height / 2)
        (text as NSString).draw(
            with: CGRect(origin: origin, size: CGSize(width: rect.width, height: needed.height)),
            options: [.usesLineFragmentOrigin],
            attributes: finalAttributes,
            context: nil
        )
    }
}

/// Reads pixel colours out of a CGImage (used to pick the cover colour).
private struct PixelSampler {
    let width: Int
    let height: Int
    let bytes: [UInt8]

    init?(_ image: CGImage) {
        let width = image.width
        let height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)

        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }

        self.width = width
        self.height = height
        self.bytes = bytes
    }

    /// Averages the four corners of `rect` (clamped to the image).
    func averageColor(around rect: CGRect) -> UIColor {
        let corners = [
            CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.minX, y: rect.maxY), CGPoint(x: rect.maxX, y: rect.maxY),
        ]
        var r = 0.0, g = 0.0, b = 0.0
        for point in corners {
            let x = min(max(Int(point.x), 0), width - 1)
            let y = min(max(Int(point.y), 0), height - 1)
            let i = (y * width + x) * 4
            r += Double(bytes[i]); g += Double(bytes[i + 1]); b += Double(bytes[i + 2])
        }
        let n = Double(corners.count) * 255
        return UIColor(red: r / n, green: g / n, blue: b / n, alpha: 1)
    }
}

private extension UIColor {
    var isLight: Bool {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return 0.299 * r + 0.587 * g + 0.114 * b > 0.6
    }
}
