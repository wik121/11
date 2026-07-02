# WhisperFlow — a Wispr Flow clone for macOS and iOS

Hold a key, talk, let go — your words are typed into whatever app you're using.
Transcription runs **entirely on your device** with OpenAI's Whisper model
(via [WhisperKit](https://github.com/argmaxinc/WhisperKit)); no audio ever
leaves your Mac or iPhone.

Speaks your languages: **auto-detect** or pick **English, Norsk or اردو (Urdu)**
in the UI — Whisper understands ~99 languages, so adding more to the picker is
one line in `Shared/WhisperTranscriber.swift`.

- **macOS**: a menu-bar app. Hold **right ⌥ Option** in any app, speak, release —
  the text is pasted at your cursor.
- **iOS**: a companion app. Tap the mic, speak, tap again — then copy the
  transcript wherever you need it. (iOS doesn't allow apps to type into other
  apps, so copy/paste is the honest way to do this.)

---

## How the app works — the 5 building blocks

An app like Wispr Flow sounds magical, but it's just five simple pieces glued together:

| # | Piece | What it does | File |
|---|-------|--------------|------|
| 1 | **Microphone recorder** | Captures your voice and converts it to the audio format Whisper expects (16 kHz mono) | `Shared/AudioRecorder.swift` |
| 2 | **Transcriber** | Feeds the audio to a Whisper model running on-device and gets text back | `Shared/WhisperTranscriber.swift` |
| 3 | **State machine** | Glue: idle → recording → transcribing → done, with error handling | `Shared/DictationEngine.swift` |
| 4 | **Global hotkey** (macOS) | Notices when you hold/release right-Option, even when another app is focused | `macOS/HotkeyMonitor.swift` |
| 5 | **Text inserter** (macOS) | Puts the text into the frontmost app: copy to clipboard → simulate ⌘V → restore clipboard | `macOS/TextInserter.swift` |

Pieces 1–3 are shared between Mac and iPhone. Only the UI and the "type it for
me" part differ per platform.

On top of the core there are a few quality-of-life extras, all optional and
all offline:

- **Text cleanup** (`Shared/TranscriptCleaner.swift`) — removes filler words
  ("um", "altså", "یعنی") and fixes capitalization before the text is used.
  On macOS 26+/iOS 26+ Apple's on-device Foundation Models LLM does the
  polishing; older OSes get a rule-based pass.
- **Auto-stop on silence** (in `AudioRecorder.swift`) — a tiny energy-based
  voice-activity detector ends the recording ~1.5 s after you stop talking.
  Default on for iOS, off for macOS (releasing the key already stops there).
- **History** (`Shared/TranscriptHistory.swift`) — the last 50 dictations,
  stored only on-device; click/tap to copy, one button to clear.
- **Configurable push-to-talk key** (macOS) — right ⌥, right ⌘, right ⌃ or
  Fn/Globe, picked in the menu-bar popover.

```
 hold hotkey          release                 done
     │                   │                      │
     ▼                   ▼                      ▼
 [record mic] ──► [Whisper model] ──► [paste text into active app]
  (16 kHz mono)    (on-device AI)      (clipboard + fake ⌘V)
```

## Build & run

You need a Mac with **Xcode 15+** (free from the App Store). The project file is
generated from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```bash
brew install xcodegen
cd whisperflow
xcodegen generate
open WhisperFlow.xcodeproj
```

In Xcode:

1. Pick the **WhisperFlowMac** scheme (or **WhisperFlowiOS** + a simulator/your iPhone).
2. Set your own team under *Signing & Capabilities* (any free Apple ID works).
3. Press **⌘R**.

First launch downloads the Whisper model — watch the status in the menu-bar
popover; it's cached afterwards. The Mac defaults to `large-v3` (~3 GB, the
best quality, and clearly better for Urdu); iPhone defaults to `small`
(~500 MB). Change `defaultModel` in `Shared/WhisperTranscriber.swift` if you
want a faster first start on the Mac.

### Offline & privacy guarantees

- The **only** network access the app ever makes is the one-time model download
  on first launch. After that it works with Wi-Fi off. To ship with **zero**
  network access, bundle the model files in the app and load them with
  `WhisperKitConfig(modelFolder:)` instead.
- All recording, transcription and language detection happen on-device.
  Nothing is uploaded, ever.
- No analytics, no telemetry, no accounts, no logs.

### macOS permissions (first launch)

- **Microphone** — system prompt, click Allow.
- **Accessibility** — needed both to see the global hotkey and to paste for you:
  *System Settings → Privacy & Security → Accessibility → enable WhisperFlow*.
  Restart the app after granting it.

---

## How to build this from scratch, step by step

If you want to recreate this yourself instead of using this code:

1. **Create the project.** In Xcode: *File → New → Project → Multiplatform App*.
   This gives you one codebase with a macOS and an iOS target.

2. **Add the AI.** *File → Add Package Dependencies* → paste
   `https://github.com/argmaxinc/WhisperKit`. WhisperKit runs Whisper models on
   Apple's Neural Engine — you get state-of-the-art speech-to-text in three
   lines of code, offline.

3. **Record audio.** Use `AVAudioEngine`: install a "tap" on the microphone
   input and collect the samples in an array. One catch: mics record at
   44.1/48 kHz but Whisper wants 16 kHz mono, so run the buffers through an
   `AVAudioConverter` (see `AudioRecorder.swift`). Add
   `NSMicrophoneUsageDescription` to Info.plist or recording silently fails.

4. **Transcribe.** `let kit = try await WhisperKit(WhisperKitConfig(model: "small"))`
   then `kit.transcribe(audioArray: samples)`. That's genuinely all. Pass a
   `DecodingOptions` with `language: "no"` / `"ur"` (or `detectLanguage: true`)
   to control the language.

5. **Make it a menu-bar app (macOS).** SwiftUI's `MenuBarExtra` scene gives you
   the icon + popover for free. Set `LSUIElement = true` in Info.plist so the
   app has no Dock icon.

6. **Listen for the hotkey system-wide (macOS).**
   `NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged)` fires even when
   other apps are focused. Watch keyCode 61 (right Option): flag on = start
   recording, flag off = stop and transcribe. Requires Accessibility permission.

7. **"Type" the result (macOS).** There's no API to type into other apps
   directly. The trick every dictation app uses: save the clipboard, put your
   text on it, synthesize a ⌘V keystroke with `CGEvent`, restore the clipboard.

8. **iOS version.** Reuse steps 3–4 unchanged. UI = one mic button + a Copy
   button. Configure `AVAudioSession` before recording (iOS-only requirement).

That's the entire product. Everything else — nicer models, streaming preview,
custom vocabulary — is polish on top of these eight steps.

## Ideas to extend it

- **Streaming preview**: WhisperKit supports real-time transcription while you talk.
- **Smarter cleanup**: swap the rule-based fallback in `TranscriptCleaner.swift`
  for a small local model via MLX or llama.cpp on OSes without Apple's
  Foundation Models.
- **iOS keyboard extension**: a custom keyboard could offer dictation inside
  other apps, but keyboard extensions have tight mic/memory restrictions —
  that's why it's not in this starter.

## Distributing it

For the Mac app, the standard open-source route (no App Store needed):

1. **Archive**: Xcode → Product → Archive (or
   `xcodebuild -scheme WhisperFlowMac archive`).
2. **Sign & notarize**: sign with a Developer ID Application certificate, zip
   the app, submit with `xcrun notarytool submit WhisperFlow.zip --wait`, then
   `xcrun stapler staple WhisperFlow.app`. Unsigned builds still run, but users
   have to right-click → Open past Gatekeeper.
3. **Publish** the zip on a GitHub Release, and optionally add a
   [Homebrew cask](https://docs.brew.sh/Cask-Cookbook) so people can
   `brew install --cask whisperflow`.

The iOS app can only realistically ship through the App Store (TestFlight for
testing). Note that Apple's developer program requires a real identity, so full
anonymity is only achievable for the GitHub/Homebrew side.

## License & branding

Open source under the [MIT License](LICENSE), attributed only to "WT".
The apps carry no author information — just a small **WT 2026** mark in the
bottom-right corner of each screen (`Shared/Watermark.swift`).
