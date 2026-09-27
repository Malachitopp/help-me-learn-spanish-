import PhotosUI
import SwiftUI
import Translation

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var languagesReady = false
    @State private var downloading = false
    @State private var downloadError: String?
    @State private var downloadConfig: TranslationSession.Configuration?
    @State private var pickedItem: PhotosPickerItem?
    @State private var result: UIImage?
    @State private var errorMessage: String?
    @State private var working = false
    @State private var stages: [(name: String, duration: Duration)] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    GroupBox("1. Download Spanish → English") {
                        VStack(alignment: .leading, spacing: 8) {
                            if languagesReady {
                                Label("Ready. Works offline.", systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            } else if downloading {
                                HStack(spacing: 8) {
                                    ProgressView()
                                    Text("Downloading…")
                                }
                            } else {
                                Button("Download languages") {
                                    // Setting an identical configuration again doesn't re-run .translationTask,
                                    // so later taps have to invalidate the existing one instead.
                                    if downloadConfig == nil {
                                        downloadConfig = TranslationSession.Configuration(
                                            source: Translator.source,
                                            target: Translator.target
                                        )
                                    } else {
                                        downloadConfig?.invalidate()
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                            }
                            if let downloadError {
                                Text(downloadError).foregroundStyle(.red)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
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
                            if !stages.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(Array(stages.enumerated()), id: \.offset) { _, stage in
                                        timingRow(stage.name, stage.duration)
                                    }
                                    timingRow("Total", stages.reduce(Duration.zero) { $0 + $1.duration })
                                        .bold()
                                }
                                .font(.footnote.monospacedDigit())
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
        // Check again when coming back to the app, e.g. after changing the phone's language
        // or downloading languages in Apple's Translate app.
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { languagesReady = await Translator.isReady() }
        }
        // Asks the system to download the language packs (shows Apple's download prompt).
        .translationTask(downloadConfig) { session in
            downloading = true
            downloadError = nil
            defer { downloading = false }
            do {
                try await session.prepareTranslation()
                languagesReady = await Translator.waitUntilReady()
                if !languagesReady {
                    downloadError = "Still not downloaded. Tap Download languages to try again, or download Spanish and English (US) in Apple's Translate app."
                }
            } catch {
                downloadError = error.localizedDescription
            }
        }
        .onChange(of: pickedItem) { _, item in
            guard let item else { return }
            Task { await translate(item) }
        }
    }

    private func translate(_ item: PhotosPickerItem) async {
        working = true
        errorMessage = nil
        stages = []
        defer { working = false }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            let output = try await ScreenshotTranslator.translate(imageData: data)
            stages = output.stages
            result = UIImage(data: output.translatedJPEG ?? data)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func timingRow(_ name: String, _ duration: Duration) -> some View {
        let (seconds, attoseconds) = duration.components
        let milliseconds = seconds * 1000 + attoseconds / 1_000_000_000_000_000
        return HStack {
            Text(name)
            Spacer()
            Text("\(milliseconds) ms")
        }
    }
}
