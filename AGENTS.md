# Karen Voice

Karen Voice is a local dictation app derived from the source identified in THIRD_PARTY_NOTICES.md. Inspect the existing recording, model and paste behavior before changing it. The first public release changes identity and branding while preserving dictation behavior.

Read BUILD.md for build and validation commands. Before release work, read docs/PRODUCT.md and .github/workflows/release.yml. Verify the exact source revision, app bundle identity, native startup and downloadable assets before claiming a release is usable.

Product identity is Karen Voice. Keep required original copyright and license notices, dependency package names and model publisher identities intact. Keep user recordings, settings, model weights, credentials and local evidence out of the repository.

All product copy uses the i18next translation system. Keep React components functional, use existing state stores, and preserve the Rust command/event model. Keep dictation separate from assistant actions; a dictated sentence must not execute a command.

Use conventional commits. Run lint, format:check, frontend build and appropriate existing tests. Run cargo fmt and cargo clippy for Rust changes. For UI changes, inspect the rendered app and test an affected interaction. Browser previews with mocked native commands demonstrate UI only; record native dictation acceptance separately.

Preview updates are manual. A future updater must use this repository and its own signing keys. Mac previews are ad-hoc signed, not notarized, until a maintainer configures Developer ID signing.
