#!/usr/bin/env python3
"""macOS integration tests; all writes stay in a disposable directory.

Usage: python3 scripts/test-installer.py /path/to/official-hardware-matched.dmg
Requires Python only for developers. The shipped installer does not use Python.
Real-artifact tests are separate from explicitly injected platform/fault tests.
"""

import hashlib
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import tempfile

SCRIPT = Path(__file__).with_name("install-macos.sh").resolve()
DMG = Path(sys.argv[1]).resolve()
assert sys.platform == "darwin", "Run on macOS"
silicon = subprocess.run(
    ["/usr/sbin/sysctl", "-n", "hw.optional.arm64"],
    capture_output=True, text=True,
).stdout.strip() == "1"
digest = (
    "c54eca9b1b10cf4ba93d4db0a765f4355ec13920b2764612f612cf58289fee3a"
    if silicon else
    "37de39b89a83ef90abc8bf5554f5c4ec532379bd7f664b471e21caea28403cd8"
)
assert hashlib.sha256(DMG.read_bytes()).hexdigest() == digest, "Supply the actual pinned hardware-matched DMG"
ROOT = Path(tempfile.mkdtemp(prefix="karen-installer-tests."))
passed = []


def run(args, expected=0, contains="", script=SCRIPT, env=None):
    result = subprocess.run(
        ["/bin/bash", str(script), *map(str, args)],
        text=True, capture_output=True, timeout=60, env=env,
    )
    output = result.stdout + result.stderr
    assert result.returncode == expected, output
    assert contains in output, output
    return output


def check(name, fn):
    fn()
    passed.append(name)
    print("PASS", name, flush=True)


def args(dest):
    return ["--destination", dest, "--dmg", DMG, "--no-open"]


def variant(name, replacements):
    """Explicit test-only source copy; never weakens the production script."""
    text = SCRIPT.read_text()
    for before, after in replacements:
        assert before in text
        text = text.replace(before, after, 1)
    path = ROOT / (name + ".sh")
    path.write_text(text)
    return path


def modified_app(dest, version=None, identifier=None):
    dest.mkdir()
    app = dest / "Karen Voice.app"
    subprocess.run(["/usr/bin/ditto", str(INSTALLED), str(app)], check=True)
    plist = app / "Contents/Info.plist"
    data = plistlib.loads(plist.read_bytes())
    if version:
        data["CFBundleShortVersionString"] = version
        data["CFBundleVersion"] = version
    if identifier:
        data["CFBundleIdentifier"] = identifier
    plist.write_bytes(plistlib.dumps(data))
    subprocess.run(["/usr/bin/codesign", "--force", "--deep", "--sign", "-", str(app)], check=True, capture_output=True)
    return app


try:
    dest = ROOT / "fresh"
    check("actual release installs and verifies", lambda: run(args(dest), contains="Verified installed bundle"))
    INSTALLED = dest / "Karen Voice.app"
    before = INSTALLED.stat().st_ino
    check("repeat verifies without replacement", lambda: run(args(dest), contains="no replacement"))
    assert INSTALLED.stat().st_ino == before
    check("inspect makes no destination", lambda: run(["--inspect", "--destination", ROOT / "untouched"]))
    assert not (ROOT / "untouched").exists()
    check("invalid arguments", lambda: run(["--destination"], expected=2))
    check("relative destination", lambda: run(["--destination", "relative"], expected=1, contains="absolute path"))
    check("read-only destination", lambda: run(args(Path("/System/Karen-installer-test")), expected=1, contains="Cannot create"))
    locked = ROOT / "locked"
    (locked / ".karen-voice-install.lock").mkdir(parents=True)
    check("concurrent/stale lock", lambda: run(args(locked), expected=1, contains="Install locked"))
    corrupt = ROOT / "corrupt.dmg"
    corrupt.write_bytes(b"not an official image")
    check("corrupt actual download refused", lambda: run(["--destination", ROOT / "corrupt", "--dmg", corrupt, "--no-open"], expected=1, contains="Checksum mismatch"))
    assert not list((ROOT / "corrupt").glob(".karen-voice-*"))
    check("missing offline download", lambda: run(["--destination", ROOT / "missing", "--dmg", ROOT / "missing.dmg", "--no-open"], expected=1, contains="does not exist"))
    link = ROOT / "link"
    link.symlink_to(dest, target_is_directory=True)
    check("symlink destination refused", lambda: run(args(link), expected=1, contains="symlink"))
    modified_app(ROOT / "wrong", identifier="org.example.unrelated")
    check("wrong bundle identity preserved", lambda: run(args(ROOT / "wrong"), expected=1, contains="Unexpected bundle identity"))
    modified_app(ROOT / "newer", version="0.2.0")
    check("newer bundle not downgraded", lambda: run(args(ROOT / "newer"), expected=1, contains="Refusing downgrade"))
    modified_app(ROOT / "overflow", version="18446744073709551616.0.0")
    check("unbounded version refused without arithmetic overflow", lambda: run(args(ROOT / "overflow"), expected=1, contains="Unrecognized installed version"))
    changed = modified_app(ROOT / "changed")
    check("same version changed signature refused", lambda: run(args(ROOT / "changed"), expected=1, contains="CDHash differs"))
    invalid = ROOT / "invalid"
    shutil.copytree(dest, invalid)
    with (invalid / "Karen Voice.app/Contents/MacOS/karen-voice").open("ab") as f:
        f.write(b"tampered")
    check("invalid signature refused", lambda: run(args(invalid), expected=1, contains="Invalid code signature"))
    old = modified_app(ROOT / "older", version="0.0.9")
    check("older signed fixture replaced with actual release", lambda: run(args(ROOT / "older"), contains="Previous app retained"))
    assert len(list((ROOT / "older").glob("Karen Voice.backup.*.app"))) == 1
    rollback = modified_app(ROOT / "rollback", version="0.0.8")
    original_plist = (rollback / "Contents/Info.plist").read_bytes()
    fault = variant("activation-fault", [('  mv "$WORK/Karen Voice.app" "$APP"', '  mv "$WORK/Karen Voice.app" "$APP"\n  fail "Injected activation verification failure"')])
    check("injected activation failure restores older fixture", lambda: run(args(ROOT / "rollback"), expected=1, contains="Injected activation", script=fault))
    assert (rollback / "Contents/Info.plist").read_bytes() == original_plist
    assert not list((ROOT / "rollback").glob(".karen-voice-*"))
    interrupted = modified_app(ROOT / "interrupted", version="0.0.6")
    interrupted_plist = (interrupted / "Contents/Info.plist").read_bytes()
    interrupted_script = variant("backup-interruption", [('    mv "$APP" "$BACKUP"', '    mv "$APP" "$BACKUP"\n    fail "Injected interruption after backup move"')])
    check("injected backup interruption restores old fixture", lambda: run(args(ROOT / "interrupted"), expected=1, contains="Injected interruption", script=interrupted_script))
    assert (interrupted / "Contents/Info.plist").read_bytes() == interrupted_plist
    copyapp = modified_app(ROOT / "copyfault", version="0.0.7")
    copyplist = (copyapp / "Contents/Info.plist").read_bytes()
    copyfault = variant("copy-fault", [('  ditto --rsrc --extattr "$WORK/mount/Karen Voice.app" "$WORK/Karen Voice.app"', '  false')])
    check("injected copy failure preserves old fixture", lambda: run(args(ROOT / "copyfault"), expected=1, contains="Copy failed", script=copyfault))
    assert (copyapp / "Contents/Info.plist").read_bytes() == copyplist
    busy = variant("running-app", [('running() { ps -axo command=', 'running() { return 0; }\nunused_running() { ps -axo command=')])
    check("injected running app refuses replacement", lambda: run(args(ROOT / "copyfault"), expected=1, contains="Quit Karen Voice", script=busy))
    disk = variant("low-disk", [('FREE=$(df -Pk "$DEST" | awk \'END {print $4}\')', 'FREE=1')])
    check("injected low disk refuses before download", lambda: run(args(ROOT / "lowdisk"), expected=1, contains="200 MiB", script=disk))
    platform = variant("old-macos", [('OS=$(sw_vers -productVersion)', 'OS=12.7')])
    check("injected unsupported macOS", lambda: run(["--inspect"], expected=1, contains="macOS 13+", script=platform))
    intel = variant("intel-selection", [('$(sysctl -n hw.optional.arm64 2>/dev/null || true)', '0'), ('$(uname -m)', 'x86_64')])
    check("injected Intel selects pinned Intel artifact", lambda: run(["--inspect"], contains="37de39b89a83ef90", script=intel))
    offline = dict(os.environ, https_proxy="http://127.0.0.1:9", HTTPS_PROXY="http://127.0.0.1:9", ALL_PROXY="http://127.0.0.1:9", NO_PROXY="")
    check("real unavailable network leaves no app", lambda: run(["--destination", ROOT / "network", "--no-open"], expected=1, contains="Download failed", env=offline))
    assert not list((ROOT / "network").glob(".karen-voice-*"))
    print(f"{len(passed)}/{len(passed)} passed. Platform/fault cases are injected; other hardware execution and UI acceptance remain separate.")
finally:
    shutil.rmtree(ROOT)
