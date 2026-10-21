# Install Karen Voice on a Mac

Ordinary installation uses the [published prebuilt DMGs](https://github.com/OsirisMedici/karen-voice/releases/tag/v0.1.0-preview.1). It needs macOS 13 or newer and an Apple Silicon or Intel Mac. No compiler, package manager, paid account or source build is required. Speech models download separately in the app.

## Automatic local installer

The installer is prepared in this source checkout. It is not published at a remote command URL yet:

```sh
bash scripts/install-macos.sh
```

Default: `~/Applications/Karen Voice.app`. Use `--destination /Applications` only if that folder is already writable. The script never invokes sudo. `--inspect` prints the hardware-selected release, hashes and destination without downloads or writes. `--no-open` installs and verifies without claiming a launch check. `--dmg /absolute/path/to/download.dmg` uses an offline copy with the same pinned verification.

Exit 0 means installation verification passed and the exact executable was observed running, unless `--no-open` was selected. Exit 3 means installation succeeded but opening remains pending; read the message, approve in macOS if appropriate and rerun. Exit 1 is a verification/install error; exit 2 is invalid usage. A running process proves startup, not microphone capture, speech recognition or paste.

## Release verification

The installer pins `v0.1.0-preview.1` (source revision `f274822f519a1f5a83f3a882bc36da7a5ef62cb6`, not current main), version `0.1.0`, `com.osirismedici.karenvoice`, executable `karen-voice`, minimum macOS `13.0`, required license files, exact architecture and the following measured release values:

| Hardware      | DMG                             | SHA-256                                                            | App CDHash                                 |
| ------------- | ------------------------------- | ------------------------------------------------------------------ | ------------------------------------------ |
| Apple Silicon | `Karen.Voice_0.1.0_aarch64.dmg` | `c54eca9b1b10cf4ba93d4db0a765f4355ec13920b2764612f612cf58289fee3a` | `15fa50cddb298defefa7a8679572e2e0ddd12e7b` |
| Intel         | `Karen.Voice_0.1.0_x64.dmg`     | `37de39b89a83ef90abc8bf5554f5c4ec532379bd7f664b471e21caea28403cd8` | `4a01838ab81be41fc1e64e09a35dbc509496cb0d` |

The SHA values match both the release API's uploaded-asset digests and its `SHA256SUMS-*-public.txt` files. CDHashes were measured from those verified DMGs with `codesign -dv --verbose=4`. `codesign --verify --deep --strict` checks the bundle's signed contents. An ad-hoc signature checks integrity; it does **not** establish a Developer ID or Apple notarization. These pins trust the reviewed installer/source and the repository's release distribution. They do not make a mutable release tag immutable: substituted asset bytes fail the pinned hash.

For manual downloads, put the matching checksum manifest beside the DMG and run `shasum -a 256 -c SHA256SUMS-*-public.txt`. That manifest also lists a ZIP; a missing ZIP is reported separately. Compare the DMG's line with the pinned value above. Mount the DMG read-only, then check:

```sh
codesign --verify --deep --strict "/Volumes/Karen Voice/Karen Voice.app"
codesign -dv --verbose=4 "/Volumes/Karen Voice/Karen Voice.app"
/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "/Volumes/Karen Voice/Karen Voice.app/Contents/Info.plist"
```

Use the actual mounted volume name shown by Finder if it differs. The installer handles mounting at its own private path.

## macOS approval and first dictation

This preview is **ad-hoc signed, not notarized**. If macOS blocks it, follow [Apple's Open Anyway instructions](https://support.apple.com/en-us/102445) in System Settings → Privacy & Security. Do not disable Gatekeeper, change global security policy, or strip quarantine. The installer preserves extended attributes when copying and uses Launch Services to open the app.

Grant microphone and Accessibility access to **Karen Voice**, download a suitable model, and select a shortcut that does not conflict with another dictation app. Place the cursor in a normal text field, record a short sentence, stop and confirm the exact text appears. Test cancellation and another recording. Relaunch and check your chosen setting persists. These are human acceptance checks; agents must report prompts and incomplete checks honestly. Dictation turns speech into text; it does not execute dictated commands or provide assistant chat.

## Repeats, replacement and recovery

- The exact pinned release is reverified and reused. A newer release, unknown version, wrong identity, invalid signature or a different same-version CDHash is refused. There is no force/downgrade switch.
- An older valid Karen Voice bundle is replaced only while stopped. It remains alongside the new app as `Karen Voice.backup.<timestamp>.<id>.app`. If activation verification fails, the installer attempts to restore it and prints a recovery path if restoration fails.
- A per-destination `.karen-voice-install.lock` prevents concurrent installers. A hard crash can leave it behind. Confirm no installer is active, inspect the empty directory, then remove it with `rmdir`; do not delete another running install's lock.
- Downloads and copies stage privately on the destination filesystem. Failed downloads, checksum/mount/copy failures leave the prior bundle in place. At least 200 MiB free space is required; models need additional space. A full disk can still cause a later write to fail.
- Settings, models, history and recordings under Karen Voice's data identity are never deleted or migrated. Handy's application/data are never targeted. To restore a retained backup, quit Karen Voice, move the new bundle aside, rename the backup to `Karen Voice.app`, then open that exact path.

## Optional source build

Developers can follow [BUILD.md](../BUILD.md). That path needs Bun, Rust and native build dependencies; it is separate from prebuilt installation. Current main may differ from the pinned public preview. An app built from source does not prove the released artifact works.

## Maintainer publication gate

Review and approve these committed changes before pushing. After publication, use an immutable **full commit SHA** URL for `scripts/install-macos.sh`, download it to a file with HTTPS-only redirects, verify its separately published SHA-256, inspect/run it, and recheck that URL from a recipient Mac. Do not advertise that command until the exact URL returns the reviewed script. A new application release is not required for this installer: it deliberately targets existing public assets. Future releases require a reviewed update to both architecture pins, version/CDHashes and corresponding actual-artifact tests. Preview updates remain manual.
