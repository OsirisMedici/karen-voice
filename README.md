# Karen Voice

Free, open-source dictation that runs on your computer. Press a shortcut, speak, and paste your words into the app you are using.

[Download the Mac preview](https://github.com/OsirisMedici/karen-voice/releases) · [Report a problem](https://github.com/OsirisMedici/karen-voice/issues)

## Download and start

1. Download the Apple Silicon DMG for an M-series Mac, or the Intel DMG for an Intel Mac. macOS 13 or newer is required.
2. Open the DMG and drag **Karen Voice** into Applications.
3. Launch Karen Voice. These early preview builds are ad-hoc signed, **not Apple notarized**. If macOS blocks opening, use System Settings → Privacy & Security → Open Anyway for the downloaded app. See [Apple's instructions](https://support.apple.com/en-us/102445).
4. Grant microphone and Accessibility access when prompted.
5. Download a speech model in the app. Try Parakeet V3 on Apple Silicon, or choose another model that fits your computer.
6. Set your shortcut, put the cursor in a text field, speak, and stop recording. The transcription appears there.

Quit other dictation apps while using the same shortcut. Karen Voice has its own settings and model directory, so another app's setup is not migrated automatically.

## Install with an agent or Terminal

**Use the prebuilt release. No Rust, Bun, Homebrew or source build is needed.** Give an agent running on the recipient's Mac this instruction today:

> Install Karen Voice from [v0.1.0-preview.1](https://github.com/OsirisMedici/karen-voice/releases/tag/v0.1.0-preview.1). Detect Apple Silicon hardware (including a Rosetta shell) or Intel and require macOS 13+. Download the matching DMG and `SHA256SUMS-*-public.txt`; verify its SHA-256 before opening. Verify the contained app's strict code signature, `com.osirismedici.karenvoice` identity, version `0.1.0`, architecture and pinned CDHash listed in [the installer guide](docs/INSTALL.md). Install into `~/Applications` without changing Handy, settings or models. Preserve any existing Karen Voice app; refuse an unrecognized bundle or downgrade. Open the exact installed app and verify that executable is running. Report macOS approval or permission prompts for me to complete. Never disable Gatekeeper or remove quarantine.

The new automatic installer is **local and pending publication**. From this checkout, run:

```sh
bash scripts/install-macos.sh
```

It selects the exact released DMG, verifies its pinned checksum and bundle, installs into `~/Applications`, opens the app and checks the running executable path. It safely repeats an exact install, refuses downgrades and changed same-version bundles, and retains a backup when replacing an older version. It never kills a running app or modifies application data. macOS may still require **Open Anyway**; a successful installation is separate from permission and dictation acceptance.

See [installation, offline verification, recovery and maintainer publication](docs/INSTALL.md). There is no live remote installer command yet; do not run a guessed raw-file URL. The DMG links above work now.

## What is included

- Local speech recognition with Whisper and ONNX models.
- Configurable shortcuts, hold-to-talk and toggle recording.
- Microphone selection, model management, transcript history and recording overlays.
- Light and dark themes with T3 Code Grove green accents.

This first release provides dictation. A connection to the Karen assistant and voice commands that perform actions are future work.

## Privacy and updates

Local dictation processes audio on your computer. Model downloads require the internet. Optional post-processing can send transcribed text to a provider you configure; it is off by default. Local history may contain sensitive text and audio, and you can manage it in Settings.

Preview releases use manual downloads from this repository. Automatic installation of updates is disabled until Karen Voice has its own signed update channel.

## Troubleshooting

If typing or shortcuts stop working, check microphone and Accessibility permissions for **Karen Voice**, confirm your shortcut does not conflict with another app, and try a normal text field. macOS Secure Input in password fields or another app can block keyboard listeners. Keep password fields closed while dictating. Logs and the app data directory are available in Settings → About.

## Build and contribute

See [BUILD.md](BUILD.md) and [CONTRIBUTING.md](CONTRIBUTING.md). Current release automation builds macOS. Windows and Linux source is retained, but their Karen Voice installers are not published or verified yet.

## License

MIT. The original copyright and permission notices are preserved in [LICENSE](LICENSE). See [third-party notices](THIRD_PARTY_NOTICES.md) for source provenance and dependencies.
