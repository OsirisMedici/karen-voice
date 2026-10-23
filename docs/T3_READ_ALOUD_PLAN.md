# Read T3 replies aloud with Karen Voice

Date: 22 October 2026. Status: researched proposal, not implemented or released.

## What we are building

Add manual read-aloud to Karen Voice on macOS. Osiris chose "Read a reply when I press a shortcut" in this task. Automatic reading is outside this first version.

The proposed first workflow is to copy the desired T3 reply and press a configurable Karen Voice shortcut. Karen Voice reads that clipboard snapshot using an installed macOS voice. The clipboard step is a proposed implementation choice, not an additional preference explicitly selected by Osiris.

The proposed integration targets the existing Karen Voice project. Source inspection used revision `0d2af56de9347f0634cb24c020f0d9d7cacbcdc0`.

## Why it matters

Osiris can listen to a long answer while looking away from the chat, using the same app that already handles dictation. Choosing the reply explicitly avoids reading an answer from the wrong T3 window or project.

Copying adds one step, but requires no T3 fork, account connection, screen scraping, or chat database access. It also works with text copied from other apps. A future "read latest reply" action can remove this step once it has an explicit thread target.

## Finished experience

1. Wait for a T3 answer to finish, then use its Copy message button. A selected paragraph copied with Cmd+C also works.
2. Press the Karen Voice read-aloud shortcut. Onboarding asks the user to choose a shortcut that does not conflict with dictation or T3.
3. A small playback control shows that Karen Voice is reading copied text. It provides pause/resume and stop. The shortcut toggles pause/resume while a reading session exists; after stopping, the next press reads a new clipboard snapshot.
4. Choose the voice and speed in Karen Voice settings. Settings survive relaunch. Downloading an optional system voice may require internet; playback with a verified installed local voice should work offline.
5. Starting dictation stops playback before admitting microphone audio for dictation. A read-aloud request during recording reports that dictation is active and does not play through the recording.

The result should preserve the author's wording. Convert Markdown to readable text using a parser, retain list order and inline text, read link labels, and skip fenced code blocks and bare URLs by default. Let the user include code if needed. Do not generate a summary or paraphrase the answer.

## Included and excluded

Include manual clipboard capture only on shortcut activation, local voice selection, speed, pause/resume, stop, visible playback state, useful empty/non-text clipboard errors, and dictation coordination. Reading must not write to or clear the clipboard. Keep copied text and generated audio out of logs and dictation history.

Exclude automatic reply reading, streaming partial responses, automatic foreground-thread detection, reading every open chat, T3 UI modifications, cloud voice services, voice cloning, and Windows/Linux speech support in this first version. Existing dictation remains a separate action.

## Technical implementation

### Text input

T3 source has a Copy message component used by assistant rows. This establishes a source-supported clipboard handoff, not a visual acceptance test of this installed T3 build. See [MessageCopyButton.tsx](https://github.com/pingdotgg/t3code/blob/f054d1b8018721bd997d99cbb918a7b17bf098a4/apps/web/src/components/chat/MessageCopyButton.tsx) and [TimelineAssistantRows.tsx](https://github.com/pingdotgg/t3code/blob/f054d1b8018721bd997d99cbb918a7b17bf098a4/apps/web/src/components/chat/TimelineAssistantRows.tsx#L194-L214).

Karen Voice already depends on the Tauri clipboard manager and has native clipboard access in [clipboard.rs](../src-tauri/src/clipboard.rs). Add a dedicated read command which snapshots text into memory. Do not reuse the paste operation, synthesize Cmd+C, or poll the clipboard in the background. Empty, image-only and excessively long clipboard inputs need explicit handling.

### Speech and controls

Use a native macOS speech adapter managed by the Rust app, with one owned playback session and a generation ID for callbacks. Prefer AVSpeechSynthesizer for the full playback lifecycle, subject to the engine research and a native build spike. See [Apple AVSpeechSynthesizer](https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer) and the companion [engine research](READ_ALOUD_ENGINE_RESEARCH.md).

The system `/usr/bin/say` command is a proven feasibility path and an option for a small start/stop prototype. It is not proof of AVSpeechSynthesizer integration or pause/resume behavior in Karen Voice. If used, launch the fixed executable directly and send text via stdin, never interpolate copied text into a shell command.

### Existing integration points

- Register a separate read-aloud binding through [settings.rs](../src-tauri/src/settings.rs) and an action through [actions.rs](../src-tauri/src/actions.rs). The current defaults define transcription and cancellation; speech output is new work.
- [shortcut/handler.rs](../src-tauri/src/shortcut/handler.rs) routes transcription through its coordinator and other actions through ACTION_MAP. Preserve both keyboard implementations and conflict checks. Extend settings with safe defaults and verify that existing installations receive the new binding without losing their shortcuts. The existing cancel handler only fires while recording, so it will not automatically stop speech.
- Put speech ownership and lifecycle in a dedicated manager. Route every recording entry path through playback coordination, including keyboard, tray, CLI and signal triggers. Protect ordering so a delayed callback cannot resume old speech or open the microphone during playback. Playback must hold an input exclusion even in AlwaysOn microphone mode. Await capture finalization, including trailing buffers, before speaking. Restore the prior microphone mode afterward and verify residual audio is discarded before dictation.
- Register playback commands/events through [lib.rs](../src-tauri/src/lib.rs), regenerate Specta bindings, and use the existing settings store and i18next translations for controls and copy. Do not hand-edit generated bindings.
- Keep the player usable while the main window is hidden. Stop and release speech on app exit. A cancelled or replaced session must ignore late callbacks. Track stopped state explicitly instead of assuming every stop produces a cancellation callback.

### Future direct T3 integration

A future direct integration should use the supported T3 CLI or read-only MCP interface. It needs an explicit selected thread, full-text retrieval, a completed-run check, and rejection of tool activity or partial output. Agent access injected into a development session is not Karen Voice authorization.

Official T3 documentation describes both host CLI access and authenticated read-only MCP clients in [Outside agents](https://github.com/pingdotgg/t3code/blob/main/docs/user/outside-agents.md). No always-running watcher or T3 access setup was installed in this task.

## Testing and handoff

### Evidence limits

Repository and primary-documentation research support this proposal. Local project registration and machine-specific speech or chat probes are omitted from this public source checkpoint. They do not establish native app integration, audible quality, offline operation, or dictation safety.

### Acceptance after implementation

1. Open T3 and Karen Voice. Choose a read-aloud shortcut. Copy one completed reply containing prose, a list, a link and a fenced code block. Press the shortcut. Confirm the intended words are audible, the list order is preserved and omitted content follows settings.
2. Pause, resume and stop. Copy another reply and start again. Confirm only one session speaks and no old session resumes later.
3. Test an empty clipboard, image-only content, long input, Unicode, unsupported voice, and a text string containing shell metacharacters. No command should execute and clipboard contents must remain intact.
4. Begin dictation during playback through each supported trigger. Confirm playback stops before recording and no spoken answer is transcribed. Attempt reading during recording and confirm it does not play.
5. Relaunch with the main window hidden, then test the shortcut and saved voice/speed. Test offline with the selected installed voice and inspect logs/history for copied-text leakage.
6. Run repository-required lint, formatting, frontend build, appropriate existing tests, Rust formatting and clippy for the implementation. Add focused tests for text normalization and playback/recording races. Verify the packaged Mac app separately from a browser mock.

No application feature, installer, signing state or release was changed during this research task. End-to-end read-aloud acceptance remains future work.
