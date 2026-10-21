# Building Karen Voice

Use Bun and stable Rust with the macOS Command Line Tools, CMake and Xcode installed. Apple Silicon release builds use the native Metal backend. Intel builds require the matching ONNX Runtime dynamic library, configured by the release workflow.

```sh
bun install --frozen-lockfile
bun run build
bun run tauri dev
```

The voice activity model is included at `src-tauri/resources/models/silero_vad_v4.onnx`. Speech recognition models download on first use; model weights and personal transcripts are not bundled or committed.

## Checks

```sh
bun run lint
bun run format:check
bun run build
bun run test:keyboard
cargo clippy --locked --manifest-path src-tauri/Cargo.toml
```

## Installer checks

The prebuilt installer needs only the macOS system tools. Its developer integration suite needs Python 3 and the exact published DMG matching the test Mac's hardware:

```sh
python3 scripts/test-installer.py /absolute/path/to/the/published.dmg
```

The suite uses disposable destinations, verifies the actual release bytes, exercises failure/repeat/replacement paths, and clearly labels injected platform and activation faults. It never grants permissions or runs dictation. `.github/workflows/installer.yml` runs it on Apple Silicon and Intel runners. Successful local checks do not mean that unrun CI or recipient acceptance has passed.

## Mac release

```sh
bun run tauri build --target aarch64-apple-darwin --bundles app,dmg -- --locked
```

The GitHub Actions workflow builds Apple Silicon and Intel apps, verifies their bundle identities and code signatures, checks native compute-device startup, and uploads archives with checksums. The release job publishes downloads only after all jobs pass. Published previews are ad-hoc signed and not notarized. Apple notarization requires a maintainer's Developer ID setup.

The app identity is `com.osirismedici.karenvoice`, the executable is `karen-voice`, and the data directory is managed by Tauri under that identity. Keep it separate from other installed dictation apps.

## Branding

The original vector icon lives in `assets/icon.svg`. Regenerate platform icons with `bun run tauri icon assets/icon.svg`. Shared UI and recording-overlay accents live in `src/styles/theme.css`; their light and dark accent values match the Grove palette in T3 Code.

## Verify real speech recognition

In GitHub Actions, run **Verify built-app transcription** and provide the successful Mac build run ID. This downloads the exact Apple Silicon app artifact, verifies its archive and signature, downloads a pinned public model with a SHA-256 check, and transcribes generated speech. The model stays on the disposable runner and is not included in the release.

This checks the real speech engine. Microphone capture, Accessibility permissions and paste into another app remain separate user acceptance checks.
