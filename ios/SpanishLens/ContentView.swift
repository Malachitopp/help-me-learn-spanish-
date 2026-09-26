import PhotosUI
import SwiftUI
import Translation

struct ContentView: View {
    @State private var languagesReady = false
    @State private var downloadConfig: TranslationSession.Configuration?
    @State private var pickedItem: PhotosPickerItem?
    @State private var result: UIImage?
    @State private var errorMessage: String?
    @State private var working = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    GroupBox("1. Download Spanish → English") {
                        if languagesReady {
                            Label("Ready. Works offline.", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Button("Download languages") {
                                downloadConfig = TranslationSession.Configuration(
                                    source: Translator.source,
                                    target: Translator.target
                                )
                            }
                            .buttonStyle(.borderedProminent)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    GroupBox("2. Set up the Action Button") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("In the Shortcuts app, make a new shortcut with these actions:")
                            Text("• Take Screenshot\n• Translate Screenshot (Spanish Lens)\n• Quick Look")
                            Text("Then go to Settings → Action Button → Shortcut and choose it.")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    GroupBox("Try it here") {
                        VStack(alignment: .leading, spacing: 12) {
                            PhotosPicker("Pick a screenshot", selection: $pickedItem, matching: .images)
                            if working { ProgressView() }
                            if let errorMessage {
                                Text(errorMessage).foregroundStyle(.red)
                            }
                            if let result {
                                Image(uiImage: result)
                                    .resizable()
                                    .scaledToFit()
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()
            }
            .navigationTitle("Spanish Lens")
        }
        .task {
            languagesReady = await Translator.isReady()
        }
        // Asks the system to download the language packs (shows Apple's download prompt).
        .translationTask(downloadConfig) { session in
            do {
                try await session.prepareTranslation()
            } catch {
                errorMessage = error.localizedDescription
            }
            languagesReady = await Translator.isReady()
        }
        .onChange(of: pickedItem) { _, item in
            guard let item else { return }
            Task { await translate(item) }
        }
    }

    private func translate(_ item: PhotosPickerItem) async {
        working = true
        errorMessage = nil
        defer { working = false }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            let png = try await ScreenshotTranslator.translate(imageData: data)
            result = UIImage(data: png)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
