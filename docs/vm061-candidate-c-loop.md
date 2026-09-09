# VM-0.6.1 — Candidate C, 40-bar loop experiment

Date: 2026-09-09 JST. **Ready for human listening. Neither endpoint is selected for runtime.**

Startup Lab rejected A/B perceptually and reports that the non-fade source spans 41 bars while the fade source spans 40 bars including its final fade-out bar. Its working diagnosis is an incorrect phrase restart at 41 bars given the music's reported four-bar phrasing. This is Startup Lab's musical analysis; numerical seam checks alone cannot confirm phrase correctness. The 41-bar candidates were not regenerated or retried.

The new authorization uses only the original non-fade WAV, loops from a 40-bar endpoint directly to original frame zero, and permits only a very small local endpoint search for a remaining click. If C is still musically wrong, stop and determine the loop manually in Audacity/REAPER or obtain Miraie's intended DAW markers.

## Source preservation

- Non-fade source: `/Users/jeromenicholaz/Downloads/2026 09 08 miraie joltrome VENDING MACHINE BGM fade-wav/2026 09 08 miraie joltrome VENDING MACHINE BGM.wav`.
- SHA-256 before/after: `1e12cc678e944c2ea1aa560653c1c07e3b26a1dbdd9dfead40d3deced3b391d4`.
- Stereo 48 kHz float32 PCM, 4,542,981 frames, 94.6454375 seconds. Preserved unchanged.
- Fade WAV was inspected read-only as a reference: 4,432,212 frames / 92.33775 seconds; SHA-256 `e5c2dbdd453bbb50b53ffba183018690defeed1a504c3c7c7a529acc19a8a64f`. It was not used to derive C.

## Exact frame edits

40 × 4 × 60 / 104 = **92.3076923077 seconds**. The nearest integral 48 kHz endpoint is **4,430,769 frames / 92.3076875 seconds**, 4.808 microseconds earlier than the mathematical boundary. Indices below are zero-based, half-open intervals; each frame includes both channels.

| File | Retained original frames | Duration | Change from exact frame boundary | Removed source frames |
|---|---|---|---|---|
| C_exact_40_bars.wav | [0, 4,430,769) | 92.3076875 s | None | [4,430,769, 4,542,981), 112,212 frames |
| C_nearby_endpoint.wav | [0, 4,430,863) | 92.3096458333 s | +94 frames / **+1.958333 ms** | [4,430,863, 4,542,981), 112,118 frames |

Both are **unaltered prefixes of the original non-fade float32 PCM**, verified byte for byte. Start remains exactly 0:00. No sample amplitudes are edited, no fade/crossfade is applied to either candidate, and there is no resampling, normalization or arrangement reconstruction. The adjusted endpoint retains an additional 94 original frames only.

The exact endpoint's last→first discontinuity is **+0.08334796 / +0.10076522** (L/R). That numerical jump warranted the authorized local waveform comparison; it is not a claim that Codex heard a click. The reproducible search covers only **±96 frames / ±2 ms** around the exact endpoint, minimizing the larger of the two channels' last-to-first amplitude differences, with distance breaking ties. It finds frame 4,430,863. A preliminary read-only ±5 ms inspection found no smaller amplitude mismatch than the same endpoint; the delivered search recipe is restricted to ±2 ms.

Because the original first frame is nonzero (approximately −0.04047 in both channels), matching that waveform level is more appropriate than assuming any zero crossing will align. At the nearby endpoint the remaining jump is **+0.00300352 / −0.00216637**, approximately 30.5 dB smaller in maximum absolute amplitude. This does not prove the restart sounds right or is click-free; it is only a bounded comparison for listening. No runtime preference is chosen automatically.

## Previews and full loops

[Exact-boundary preview](../builds/audio-loop-candidate-c-vm061/C_exact_40_bars_preview.wav) · [Nearby-endpoint preview](../builds/audio-loop-candidate-c-vm061/C_nearby_endpoint_preview.wav)

Each preview contains three joins with **four bars before and four bars after**, at **9.23, 28.69 and 48.15 seconds**. One second of silence separates the excerpts. The previews use identical PCM16 conversion without loudness normalization. Only the outer excerpt edges receive a 20 ms fade to avoid artificial audition-start/end clicks; those edges are about nine seconds away from each seam. These fades and separators do not exist in the full candidate/loop files.

- [Exact candidate, float32 WAV](../builds/audio-loop-candidate-c-vm061/C_exact_40_bars.wav)
- [Nearby candidate, float32 WAV](../builds/audio-loop-candidate-c-vm061/C_nearby_endpoint.wav)
- [Four uninterrupted exact loops — three joins](../builds/audio-loop-candidate-c-vm061/C_exact_40_bars_four_full_loops.wav)
- [Four uninterrupted nearby loops — three joins](../builds/audio-loop-candidate-c-vm061/C_nearby_endpoint_four_full_loops.wav)
- [Exact edits and file hashes](../builds/audio-loop-candidate-c-vm061/sample-edits.json)
- [Godot mixer verification](../builds/audio-loop-candidate-c-vm061/godot-loop-validation.json)

Four-copy listening files contain exactly four complete candidate payloads: no separation, edge fades or extra silence. Their joins occur at one, two and three times the relevant candidate duration.

## Validation and state

Original master hashes are unchanged. Both retained audio payloads and their four-copy repetitions passed byte-level verification. Both passed **three continuous native Godot 4.7.1 mixer wraps**, loaded into native PCM16 at 48 kHz, with no seek/restart between cycles. This is a technical offline test, not listening evidence, Web/OGG validation or a claim of musical correctness. The existing macOS CA certificate diagnostic appeared; both checks passed.

Reproduction: `tools/audio/create_vm061_candidate_c.py` (uses only shared WAV helpers from the historical A/B utility; does not execute its 41-bar experiment) and `tools/audio/verify_vm061_candidate_c.gd`. Binaries and verification JSON are local ignored artifacts under `builds/audio-loop-candidate-c-vm061/`.

Branch before: `release/vm-0.6.1-get-canned-rc1`, clean at `2b4e8e7337798446ddded4360c9fc95d3620c009`. This checkpoint changes experiment utilities and documentation only. All 188 accepted runtime/configuration/asset/test files remain byte-identical to RC0. The prior 27/27 gameplay baseline was not rerun because runtime is unchanged. No new UI integration, runtime music swap, OGG conversion, export, push or itch.io upload occurred.

**Next gate: human listening. If C remains musically wrong, stop; no further automatic endpoint or 41-bar experiments.**

Cost: OpenAI API requests **0**, paid external-service requests **0**, separately billed task/cumulative cost **$0.00**. GPT-6 family exposed; Astra/High requested, exact runtime variant/reasoning and token/subscription usage not independently available. Consult Codex Settings → Usage for subscription usage if needed.

**Return to Startup Lab: YES — Return now with Candidate C for listening.**
