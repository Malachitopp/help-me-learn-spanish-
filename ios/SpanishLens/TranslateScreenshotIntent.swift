import AppIntents
import UniformTypeIdentifiers

/// Shows up in the Shortcuts app as "Translate Screenshot", so it can be chained after
/// "Take Screenshot" and bound to the Action Button.
struct TranslateScreenshotIntent: AppIntent {
    static let title: LocalizedStringResource = "Translate Screenshot"
    static let description = IntentDescription(
        "Translates the Spanish text in an image into English and paints it over the original."
    )

    // Auto-connects to the previous action's output (e.g. Take Screenshot) instead of asking for a file.
    @Parameter(
        title: "Screenshot",
        supportedContentTypes: [.image],
        inputConnectionBehavior: .connectToPreviousIntentResult
    )
    var screenshot: IntentFile

    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
        let output = try await ScreenshotTranslator.translate(imageData: screenshot.data)
        // No text found: hand the screenshot back unchanged.
        guard let jpeg = output.translatedJPEG else { return .result(value: screenshot) }
        return .result(value: IntentFile(data: jpeg, filename: "translated.jpg", type: .jpeg))
    }
}
