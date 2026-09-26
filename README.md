# Spanish screenshot translator

Take a screenshot of anything in Spanish (a chat, a website, an app) and get the same image back with the English translation painted over the original text, in the same place.

The project was built twice:

| Folder | What it is |
|---|---|
| [`server/`](server/) | **The first version:** a NestJS (TypeScript) backend. Built as a learning project. |
| [`ios/`](ios/) | **The final version:** *Spanish Lens*, a native Swift iPhone app that does everything on the phone, offline. |

Both run the same three-step pipeline:

```
screenshot → read the text and where it is (OCR) → translate each piece → paint the English over the Spanish
```

---

## Version 1: NestJS server (`server/`)

Written by hand as practice with NestJS, dependency injection, file uploads and third-party APIs.

**How it works:** an iOS Shortcut takes a screenshot and uploads it to the server. The server sends back the translated image.

- `POST /translate` takes a `multipart/form-data` upload with the image in a field called `file` (PNG or JPEG, up to 10 MB), and returns a PNG.
- **OCR:** Google Cloud Vision (`documentTextDetection`) returns each paragraph's text and bounding box.
- **Translate:** Google Cloud Translation (Basic, v2), Spanish → English.
- **Draw:** [`@napi-rs/canvas`](https://www.npmjs.com/package/@napi-rs/canvas) paints a white box over each paragraph and writes the English on top.

The code lives in `server/src/`: `app.controller.ts` is the endpoint, and `app.service.ts` holds the OCR, translate and render services.

**Running it:**

```bash
cd server
npm install
npm run start:dev
curl -F "file=@screenshot.png" http://localhost:3000/translate --output result.png
```

It needs a Google Cloud project with the **Cloud Vision API** and **Cloud Translation API** enabled, and local credentials from `gcloud auth application-default login`.

**Why it wasn't the final version:** it needs internet, a running server, and Google Cloud billing. It also sends every screenshot to a server.

---

## Version 2: Spanish Lens, the iOS app (`ios/`)

The same idea rebuilt in Swift, using Apple's built-in frameworks, so **nothing leaves the phone and it works offline**.

**How you use it:** set up a Shortcut with three actions (**Take Screenshot → Translate Screenshot → Quick Look**) and put it on the **Action Button**, or on Back Tap for iPhones without one. One press shows the English version of whatever is on screen. The app also has a **Try it here** screen for picking a screenshot from Photos.

**How it works:**

| Step | File | Uses |
|---|---|---|
| OCR | `TextRecognizer.swift` | Apple **Vision** (`VNRecognizeTextRequest`, set to Spanish) |
| Skip what doesn't need translating | `LineFilter.swift` | **NaturalLanguage**: drops times and numbers, and lines that are clearly English UI text |
| Translate | `Translator.swift` | Apple **Translation** framework, on-device. Keeps the model loaded between runs and translates repeated lines once |
| Draw | `Renderer.swift` | UIKit: covers each line with the colour sampled from the background (so dark mode and chat bubbles blend in), and fits the English text to the box |
| Pipeline | `ScreenshotTranslator.swift` | Runs the steps above and times each one |
| Shortcuts action | `TranslateScreenshotIntent.swift` | **App Intents**: the "Translate Screenshot" action |
| App screen | `ContentView.swift` | Language download, setup steps, and **Try it here** with per-step timings |

**Speed:** about 3 seconds per screenshot. Most of that is Apple's translation model; OCR takes about 0.5 s and drawing about 0.05 s.

**Requirements:** iOS 26 or later (iPhone 11 and newer), because the app uses Apple's on-device translation without a visible view. The first time, the Spanish and English language packs are downloaded from inside the app.

### Building without a Mac

This project was developed on Windows, so the app is built in the cloud:

- `ios/project.yml` describes the Xcode project, and [XcodeGen](https://github.com/yonaskolb/XcodeGen) generates the `.xcodeproj` during the build. That's why there's no `.xcodeproj` in the repo.
- `.github/workflows/ios.yml` runs on a GitHub-hosted Mac on every push to `main` that changes `ios/`. It generates the project, archives it, signs it automatically, and uploads it to **TestFlight**.
- Signing uses an App Store Connect API key stored as repository secrets: `APPLE_TEAM_ID`, `ASC_KEY_ID`, `ASC_ISSUER_ID` and `ASC_KEY_P8`.

With a Mac, you can also run `brew install xcodegen && cd ios && xcodegen generate` and then open `SpanishLens.xcodeproj` in Xcode.

---

## Possible next steps

- Group OCR lines into paragraphs before translating, so sentences that wrap across lines translate as whole sentences.
- Add the Back Tap setup steps to the app's setup screen.
