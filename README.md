# Spanish screenshot translator

Takes a screenshot with Spanish text and paints the English translation over the original.

| Folder | What it is |
|---|---|
| `server/` | NestJS version (Google Vision + Google Translate). Practice project; run with `npm run start:dev` inside `server/`. |
| `ios/` | Native iOS app, **Spanish Lens**. Fully on-device (Apple Vision + Translation), works offline. Needs iOS 26+. |

## iOS builds

There's no Mac in this setup, so the app is built by GitHub Actions (`.github/workflows/ios.yml`) and uploaded to TestFlight on every push to `main` that changes `ios/`. The Xcode project is generated from `ios/project.yml` by XcodeGen, so there's no `.xcodeproj` in the repo.
