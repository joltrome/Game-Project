# VM-0.6.1 — authorized derived-loop A/B experiment

Date: 2026-09-09 JST. Status: **two candidates ready for listening; no runtime selection**.

Subsequent decision: **Startup Lab rejected both A and B perceptually** because their musical restart is wrong. Do not reuse the 41-bar solution. The separately authorized [Candidate C experiment](vm061-candidate-c-loop.md) tests a 40-bar endpoint. This A/B report is historical.

## Authorization and scope

Startup Lab lifted the previous audio stop condition only for a non-destructive derived-loop experiment: retain the non-fade master, trim to the 41-bar boundary at 104 BPM, and compare the smallest seam treatment if needed. UI integration, final runtime replacement and distribution have not resumed in this experiment. The original [stop report](vm061-rc1-audio-stop.md) remains historical evidence of the untrimmed source's audible gap/click.

## Exact edits

All frame indices are zero-based; intervals are half-open. Each stereo frame contains two samples. The supplied source remains **4,542,981 frames**, 48 kHz stereo float32 WAV, SHA-256 `1e12cc678e944c2ea1aa560653c1c07e3b26a1dbdd9dfead40d3deced3b391d4`.

41 × 4 × 60 / 104 seconds corresponds to 4,541,538.461538 sample frames. An integer boundary is required: **4,541,538 retained frames**, or **94.615375 seconds**, is nearest (9.615 microseconds earlier than the mathematical boundary). This implements the requested approximate sample frame without resampling.

| Candidate | Exact change | End→start sample jump, L / R |
|---|---|---|
| A — trim only | Retain source frames **[0, 4,541,538)**; remove **[4,541,538, 4,542,981)** = **1,443 frames / 30.0625 ms**. Retained audio is byte-identical float32 PCM. | −0.0404674 / −0.0404437 |
| B — trim + 2 ms correction | Same length and trim as A; raised-cosine offset correction within **[0,96)**. Only frames **0–94** actually change; frame 95 has zero correction. All later audio is byte-identical to A. | **0 / 0** |

The original measured silence is approximately 30.1667 ms; the exact bar trim removes 30.0625 ms because five zero-valued frames (0.1042 ms) remain inside the retained musical interval. Neither candidate retains the original 30 ms padding gap.

B's exact per-channel formula, for n = 0…95:

`B[n,c] = A[n,c] - A[0,c] × (1 + cos(πn/95)) / 2`

At n=0 this matches the zero-valued tail; the correction smoothly reaches zero by n=95. This is a short offset correction, not a volume fade or musical overlap. It modifies the first two milliseconds of the attack and therefore still needs listening comparison. Maximum absolute sample change: **0.0404674**. Overall peak remains **1.0** in both candidates; overall RMS changes from **0.167257839** to **0.167257500**. There is no normalization, tempo change, crossfade between musical sections, resampling, arrangement edit or noticeable-length fade. Audibility has not been independently judged by Codex.

A zero-crossing alternative was inspected: source frame **78** (1.625 ms after start), just before the first shared stereo sign crossing, is approximately −0.00071956 / −0.00108815. Trimming the onset there reduces the amplitude discontinuity but shortens the loop and removes its initial attack samples. It was not exported; B preserves the authorized length and all frame positions instead. Zero sample jump alone does not guarantee perceptual transparency; selection remains pending.

## Listening files

All experiment artifacts live in [the local experiment folder](../builds/audio-loop-experiment-vm061/), outside runtime assets and ignored by Git.

- [A preview](../builds/audio-loop-experiment-vm061/A_trim_only_preview.wav)
- [B preview](../builds/audio-loop-experiment-vm061/B_trim_2ms_declick_preview.wav)
- [Original untrimmed control](../builds/audio-loop-experiment-vm061/original_control_preview.wav)
- [Full A candidate](../builds/audio-loop-experiment-vm061/A_trim_only.wav)
- [Full B candidate](../builds/audio-loop-experiment-vm061/B_trim_2ms_declick.wav)
- [Three uninterrupted A loops](../builds/audio-loop-experiment-vm061/A_trim_only_3_full_loops.wav)
- [Three uninterrupted B loops](../builds/audio-loop-experiment-vm061/B_trim_2ms_declick_3_full_loops.wav)
- [Exact edits / file hashes](../builds/audio-loop-experiment-vm061/sample-edits.json)
- [Godot verification results](../builds/audio-loop-experiment-vm061/godot-loop-validation.json)

The 20-second previews place true joins at **3, 10 and 17 seconds**. Each excerpt is the last three seconds followed by the first three seconds; one second of silence separates excerpts. Preview-only 20 ms fades suppress artificial clicks at the outer excerpt edges, three seconds away from the seam. Those fades/separators are absent from the candidate WAVs and full-loop files. Previews are 48 kHz stereo PCM16, with the same conversion and no loudness adjustment for A/B. Candidate and full-loop files remain float32 PCM.

Listen to A first for the former gap and any remaining click; compare B for both click reduction and a changed first-note attack. **Prefer A if it already sounds clean. No runtime version is selected here.**

## Verification and limitations

- Original source hash checked before and after: unchanged.
- A's entire retained PCM payload matches the source prefix byte for byte.
- B's PCM outside the 96-frame window matches A byte for byte; both have identical frame counts.
- Output WAVs re-read and matched to their intended samples; three full-loop files match exactly three concatenated candidate payloads, with no separators or added gap.
- An isolated **Godot 4.7.1** project loaded each float32 WAV into native PCM16 playback, set forward looping over frames [0,4541538), and mixed **13,632,000 frames per candidate at 48 kHz**. Each passed **three continuous end→start wraps** and remained playing, without restarting or seeking between cycles. The test uses [AudioStreamPlayback.mix_audio](https://docs.godotengine.org/en/stable/classes/class_audiostreamplayback.html#class-audiostreamplayback-method-mix-audio) and [AudioStreamWAV loop properties](https://docs.godotengine.org/en/stable/classes/class_audiostreamwav.html). This is an offline native-engine check, not audible playback, Web/OGG validation or physical-device testing. The existing macOS CA certificate diagnostic appeared; both checks passed.
- The previous 27/27 gameplay baseline was not rerun: no runtime code, configuration, assets or tests changed. All 188 tracked runtime/configuration/asset/test files were byte-compared with accepted RC0 and remain identical.
- No OGG conversion was retried; the missing libvorbis tooling remains a later runtime-format issue. No paid service was used.

Reproduction sources: `tools/audio/create_vm061_loop_candidates.py` and `tools/audio/verify_vm061_godot_loops.gd`. The former uses only Python's standard library; the latter runs against a throwaway project with `audio/driver/mix_rate=48000`. Candidate binaries are local ignored artifacts; scripts and this report preserve the exact recipe in Git.

## Repository and cost

Before: clean `release/vm-0.6.1-get-canned-rc1` at **55a7e8fa64c6c48c51277d2270b4010c8d02e0b1**. This checkpoint adds the experiment utilities and documentation only. The accepted RC0 runtime and temporary MP3 remain unchanged; no branch push, Web export or itch.io upload occurred.

GPT-6 family is exposed; Astra/High requested, exact variant/reasoning, token consumption and account-level subscription usage not independently reported. OpenAI API requests **0**; paid external-service requests **0**; separately billed task and recorded cumulative project cost **$0.00**. Check Codex Settings → Usage for subscription usage if needed.

**Return to Startup Lab: YES — audition A/B and select a candidate before runtime integration.**
