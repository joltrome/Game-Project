#!/usr/bin/env python3
"""Create the VM-0.6.3 Refund Coin runtime derivative.

The founder master is immutable. This copies PCM frames beginning at a reviewed
near-zero stereo frame and performs no resampling, gain, fade, or other signal
processing.
"""

from __future__ import annotations

import argparse
import hashlib
import wave
from pathlib import Path


EXPECTED_SOURCE_SHA256 = "cd2f783815ac8ae304d380fc9520b86029bab725be08ded030769e30bf852e81"
TRIM_FRAMES = 8_126
EXPECTED_RATE = 48_000
EXPECTED_CHANNELS = 2
EXPECTED_SAMPLE_WIDTH = 2


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def build(source: Path, output: Path) -> None:
    actual_hash = sha256(source)
    if actual_hash != EXPECTED_SOURCE_SHA256:
        raise ValueError(
            f"Unexpected CoinRefund1.wav SHA-256: {actual_hash}; source master was not modified"
        )

    with wave.open(str(source), "rb") as reader:
        parameters = reader.getparams()
        if (
            parameters.framerate != EXPECTED_RATE
            or parameters.nchannels != EXPECTED_CHANNELS
            or parameters.sampwidth != EXPECTED_SAMPLE_WIDTH
            or parameters.comptype != "NONE"
        ):
            raise ValueError(f"Unexpected PCM contract: {parameters}")
        if parameters.nframes <= TRIM_FRAMES:
            raise ValueError("Trim would remove the complete source")
        reader.setpos(TRIM_FRAMES)
        retained_pcm = reader.readframes(parameters.nframes - TRIM_FRAMES)

    output.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(output), "wb") as writer:
        writer.setnchannels(parameters.nchannels)
        writer.setsampwidth(parameters.sampwidth)
        writer.setframerate(parameters.framerate)
        writer.setcomptype(parameters.comptype, parameters.compname)
        writer.writeframes(retained_pcm)

    with wave.open(str(output), "rb") as derivative:
        expected_frames = parameters.nframes - TRIM_FRAMES
        if derivative.getnframes() != expected_frames:
            raise RuntimeError(
                f"Derivative frame mismatch: {derivative.getnframes()} != {expected_frames}"
            )

    print(
        "VM063_COIN_TRIM=PASS "
        f"trim_frames={TRIM_FRAMES} "
        f"trim_ms={TRIM_FRAMES / EXPECTED_RATE * 1000.0:.6f} "
        f"output_frames={expected_frames} "
        f"output_sha256={sha256(output)}"
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    arguments = parser.parse_args()
    build(arguments.source, arguments.output)


if __name__ == "__main__":
    main()
