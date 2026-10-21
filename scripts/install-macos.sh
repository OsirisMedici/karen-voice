#!/bin/bash
# Karen Voice pinned public preview installer. Uses only macOS system tools.
set -euo pipefail
export PATH=/usr/bin:/bin:/usr/sbin:/sbin
export LC_ALL=C
umask 077

RELEASE=v0.1.0-preview.1
SOURCE_REVISION=f274822f519a1f5a83f3a882bc36da7a5ef62cb6
VERSION=0.1.0
BUNDLE_ID=com.osirismedici.karenvoice
BASE="https://github.com/OsirisMedici/karen-voice/releases/download/$RELEASE"
DEST="${HOME:?}/Applications"
LOCAL_DMG=
OPEN=1
INSPECT=0
usage() {
  cat <<'EOF'
Usage: bash scripts/install-macos.sh [--destination /absolute/folder] [--no-open]
       bash scripts/install-macos.sh --inspect
       bash scripts/install-macos.sh --dmg /absolute/download.dmg [--no-open]
Installs pinned v0.1.0-preview.1 into ~/Applications by default; no sudo/build tools.
--dmg verifies a previously downloaded official DMG against the same pinned hash.
--inspect prints the selected release and makes no changes or downloads.
Exit 0: verified installation (and exact process observed unless --no-open).
Exit 1: install/verification failure. Exit 2: usage. Exit 3: installed; launch pending.
EOF
}
fail() { printf 'Karen Voice: %s\n' "$*" >&2; exit 1; }
while [ "$#" -gt 0 ]; do
  case "$1" in
    --destination|--dmg)
      [ "$#" -ge 2 ] && [ -n "$2" ] || { usage >&2; exit 2; }
      case "$2" in /*) ;; *) fail "$1 requires an absolute path." ;; esac
      if [ "$1" = --destination ]; then DEST=$2; else LOCAL_DMG=$2; fi
      shift 2 ;;
    --no-open) OPEN=0; shift ;;
    --inspect) INSPECT=1; shift ;;
    --help|-h) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done
[ "$(uname -s)" = Darwin ] || fail 'macOS is required.'
OS=$(sw_vers -productVersion)
MAJOR=${OS%%.*}
[[ "$MAJOR" =~ ^[0-9]+$ ]] && [ "$MAJOR" -ge 13 ] || fail "macOS 13+ required; found $OS."
# Detect the hardware even when an agent's shell is translated by Rosetta.
if [ "$(sysctl -n hw.optional.arm64 2>/dev/null || true)" = 1 ]; then
  ARCH=arm64
  ASSET=Karen.Voice_0.1.0_aarch64.dmg
  SHA=c54eca9b1b10cf4ba93d4db0a765f4355ec13920b2764612f612cf58289fee3a
  CDHASH=15fa50cddb298defefa7a8679572e2e0ddd12e7b
elif [ "$(uname -m)" = x86_64 ]; then
  ARCH=x86_64
  ASSET=Karen.Voice_0.1.0_x64.dmg
  SHA=37de39b89a83ef90abc8bf5554f5c4ec532379bd7f664b471e21caea28403cd8
  CDHASH=4a01838ab81be41fc1e64e09a35dbc509496cb0d
else
  fail 'Only Apple Silicon and Intel Macs are supported.'
fi
printf 'Karen Voice %s | macOS %s | %s\nRelease source: %s\nURL: %s/%s\nSHA256: %s\nCDHash: %s\nDestination: %s/Karen Voice.app\n' "$RELEASE" "$OS" "$ARCH" "$SOURCE_REVISION" "$BASE" "$ASSET" "$SHA" "$CDHASH" "$DEST"
[ "$INSPECT" -eq 0 ] || exit 0
case "$DEST" in *$'\n'*|*$'\r'*|*/) fail 'Destination must have no line break or trailing slash.' ;; esac
[ ! -L "$DEST" ] || fail 'Destination must not be a symlink.'
mkdir -p "$DEST" || fail "Cannot create $DEST; choose a writable --destination."
DEST=$(cd "$DEST" && pwd -P)
[ -w "$DEST" ] || fail "Destination is not writable: $DEST. No sudo is used."
APP="$DEST/Karen Voice.app"
LOCK="$DEST/.karen-voice-install.lock"
mkdir "$LOCK" 2>/dev/null || fail "Install locked: $LOCK. If no installer is running, inspect and remove that empty lock directory, then retry."
WORK=
MOUNTED=0
BACKUP=
ACTIVATING=0
SUCCESS=0
cleanup() {
  status=$?
  trap - EXIT
  if [ "$SUCCESS" -eq 0 ] && [ "$ACTIVATING" -eq 1 ]; then
    # New bundle belongs to this transaction; previous bundle remains recoverable.
    if [ -e "$APP" ]; then mv "$APP" "$WORK/failed.app" || true; fi
    if [ -n "$BACKUP" ] && [ -e "$BACKUP" ]; then
      mv "$BACKUP" "$APP" || printf 'Restore manually from %s\n' "$BACKUP" >&2
    fi
  fi
  # Also cover interruption immediately after moving the old app, before
  # the activation flag is assigned. Filesystem state decides restoration.
  if [ "$SUCCESS" -eq 0 ] && [ -n "$BACKUP" ] && [ -e "$BACKUP" ] && [ ! -e "$APP" ]; then
    mv "$BACKUP" "$APP" || printf 'Restore manually from %s\n' "$BACKUP" >&2
  fi
  if [ "$MOUNTED" -eq 1 ]; then
    if hdiutil detach "$WORK/mount" -quiet; then
      MOUNTED=0
    else
      printf 'Unmount manually: %s/mount; staging retained.\n' "$WORK" >&2
    fi
  fi
  if [ -n "$WORK" ] && [ "$MOUNTED" -eq 0 ]; then rm -rf "$WORK"; fi
  # A mounted directory must never be traversed by recursive removal.
  rmdir "$LOCK" || true
  exit "$status"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM
WORK=$(mktemp -d "$DEST/.karen-voice-stage.XXXXXXXX")
FREE=$(df -Pk "$DEST" | awk 'END {print $4}')
[[ "$FREE" =~ ^[0-9]+$ ]] && [ "$FREE" -ge 204800 ] || fail 'At least 200 MiB of free space is required (models need additional space).'
plist() { /usr/libexec/PlistBuddy -c "Print :$2" "$1/Contents/Info.plist" 2>/dev/null; }
signature() { codesign -dv --verbose=4 "$1" 2>&1 | sed -n 's/^CDHash=//p'; }
identity() {
  [ -d "$1" ] && [ ! -L "$1" ] || fail "Not a regular app bundle: $1"
  [ "$(plist "$1" CFBundleIdentifier)" = "$BUNDLE_ID" ] || fail "Unexpected bundle identity: $1"
  [ "$(plist "$1" CFBundleExecutable)" = karen-voice ] || fail 'Unexpected app executable.'
  codesign --verify --deep --strict "$1" || fail "Invalid code signature: $1"
}
verify() {
  identity "$1"
  [ "$(plist "$1" CFBundleShortVersionString)" = "$VERSION" ] && [ "$(plist "$1" CFBundleVersion)" = "$VERSION" ] || fail 'Unexpected app version.'
  [ "$(plist "$1" CFBundleName)" = 'Karen Voice' ] || fail 'Unexpected app name.'
  [ "$(plist "$1" LSMinimumSystemVersion)" = 13.0 ] || fail 'Unexpected minimum macOS version.'
  [ "$(lipo -archs "$1/Contents/MacOS/karen-voice")" = "$ARCH" ] || fail 'Unexpected app architecture.'
  [ "$(signature "$1")" = "$CDHASH" ] || fail 'App CDHash differs from the pinned release.'
  [ -f "$1/Contents/Resources/resources/licenses/LICENSE" ] && [ -f "$1/Contents/Resources/resources/licenses/THIRD_PARTY_NOTICES.md" ] || fail 'Required notices are missing.'
}
running() { ps -axo command= | awk -v p="$1/Contents/MacOS/karen-voice" 'index($0,p)==1 {found=1} END {exit !found}'; }
REPEAT=0
if [ -e "$APP" ] || [ -L "$APP" ]; then
  identity "$APP"
  OLD=$(plist "$APP" CFBundleShortVersionString)
  # This installer intentionally has no forced overwrite or downgrade switch.
  if [ "$OLD" = "$VERSION" ]; then
    verify "$APP"
    REPEAT=1
    printf 'Exact pinned release already installed; no replacement.\n'
  else
    [[ "$OLD" =~ ^[0-9]{1,9}\.[0-9]{1,9}\.[0-9]{1,9}$ ]] || fail "Unrecognized installed version $OLD; keep it and review manually."
    IFS=. read -r oa ob oc <<< "$OLD"
    IFS=. read -r na nb nc <<< "$VERSION"
    if (( 10#$oa > 10#$na || (10#$oa == 10#$na && 10#$ob > 10#$nb) || (10#$oa == 10#$na && 10#$ob == 10#$nb && 10#$oc > 10#$nc) )); then
      fail "Refusing downgrade from $OLD to $VERSION."
    fi
    running "$APP" && fail 'Quit Karen Voice before replacing it. The installer never kills apps.'
  fi
fi
if [ "$REPEAT" -eq 0 ]; then
  if [ -n "$LOCAL_DMG" ]; then
    [ -f "$LOCAL_DMG" ] || fail "DMG does not exist: $LOCAL_DMG"
    ditto --rsrc --extattr "$LOCAL_DMG" "$WORK/release.dmg"
  else
    printf 'Downloading official prebuilt DMG…\n'
    curl --fail --location --proto '=https' --proto-redir '=https' --tlsv1.2 --retry 2 --connect-timeout 20 --max-time 600 --output "$WORK/release.dmg" "$BASE/$ASSET" || fail 'Download failed. Check network access to GitHub and retry; existing installation is unchanged.'
  fi
  GOT=$(shasum -a 256 "$WORK/release.dmg" | awk '{print $1}')
  [ "$GOT" = "$SHA" ] || fail "Checksum mismatch. Expected $SHA; got $GOT. No app installed."
  mkdir "$WORK/mount"
  hdiutil attach -readonly -nobrowse -mountpoint "$WORK/mount" "$WORK/release.dmg" -quiet || fail 'Could not mount the verified DMG.'
  MOUNTED=1
  verify "$WORK/mount/Karen Voice.app"
  ditto --rsrc --extattr "$WORK/mount/Karen Voice.app" "$WORK/Karen Voice.app" || fail 'Copy failed; existing app is unchanged.'
  verify "$WORK/Karen Voice.app"
  hdiutil detach "$WORK/mount" -quiet || fail 'Cannot unmount DMG; no replacement made.'
  MOUNTED=0
  running "$APP" && fail 'Karen Voice started during installation. Quit it and retry.'
  if [ -e "$APP" ]; then
    BACKUP="$DEST/Karen Voice.backup.$(date -u +%Y%m%dT%H%M%SZ).${WORK##*.}.app"
    mv "$APP" "$BACKUP"
  fi
  ACTIVATING=1
  mv "$WORK/Karen Voice.app" "$APP"
  verify "$APP"
fi
SUCCESS=1
printf 'Verified installed bundle: %s\n' "$APP"
[ -z "$BACKUP" ] || printf 'Previous app retained: %s\n' "$BACKUP"
printf 'Settings/models and Handy are untouched. Preview is ad-hoc signed, not Apple notarized; updates are manual.\n'
if [ "$OPEN" -eq 0 ]; then
  printf 'Launch not tested (--no-open). Open this exact bundle when ready.\n'
  exit 0
fi
if ! open "$APP"; then
  printf 'Installed, but macOS did not open it.\n' >&2
else
  for ((attempt=0; attempt<10; attempt++)); do
    if running "$APP"; then
      printf 'Launch verified: exact installed executable is running.\nGrant microphone and Accessibility access, download a model, and test dictation/paste yourself.\n'
      exit 0
    fi
    sleep 1
  done
fi
printf 'Launch pending: if blocked, use System Settings → Privacy & Security → Open Anyway, then rerun this command. Do not disable Gatekeeper or strip quarantine. Microphone/Accessibility and real paste require human acceptance.\n' >&2
exit 3
