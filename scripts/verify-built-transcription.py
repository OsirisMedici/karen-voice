"""Exercise a built app's real speech engine with generated, non-private audio."""

import json
from pathlib import Path
import subprocess
import sys
import wave

binary, audio = map(Path, sys.argv[1:3])
with wave.open(str(audio)) as sample:
    assert (sample.getnchannels(), sample.getframerate(), sample.getsampwidth()) == (
        1, 16000, 2
    )


def run(*args):
    result = subprocess.run(
        [str(binary.resolve()), *args],
        capture_output=True,
        text=True,
        timeout=180,
    )
    if result.returncode:
        print(result.stderr[-8000:], file=sys.stderr)
        raise SystemExit(result.returncode)
    return result.stdout


models = json.loads(run("--list-models", "--json"))
model = next(
    model for model in models
    if model["filename"] == "parakeet-tdt-0.6b-v3-Q8_0.gguf"
    and model["is_downloaded"]
)
result = json.loads(run(
    "--transcribe-file", str(audio.resolve()), "--model", model["id"], "--json"
))
assert "local transcription test" in result["text"].lower(), result
Path("transcription-result.json").write_text(json.dumps(result, indent=2) + "\n")
print(json.dumps(result, indent=2))
