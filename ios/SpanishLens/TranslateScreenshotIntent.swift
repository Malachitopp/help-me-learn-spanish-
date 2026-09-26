import AppIntents
import UniformTypeIdentifiers

/// Shows up in the Shortcuts app as "Translate Screenshot", so it can be chained after
/// "Take Screenshot" and bound to the Action Button.
struct TranslateScreenshotIntent: AppIntent {
    static let title: LocalizedStringResource = "Translate Screenshot"
    static let description = IntentDescription(
        "Translates the Spanish text in an image into English and paints it over the original."
    )

    @Parameter(title: "Screenshot", supportedContentTypes: [.image])
    var screenshot: IntentFile

    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
        let png = try await ScreenshotTranslator.translate(imageData: screenshot.data)
        return .result(value: IntentFile(data: png, filename: "translated.png", type: .png))
    }
}
