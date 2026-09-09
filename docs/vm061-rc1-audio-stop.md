# VM-0.6.1 RC1 — stopped at the music loop gate

> SUPERSEDED: Startup Lab rejected every A/B/C endpoint. The untouched full original WAV is accepted; the founder approved the corrected native capture and authorized RC1 to resume. See [original WAV investigation](vm061-original-wav-investigation.md). Historical observations below are not current runtime instructions.

Date: 2026-09-09 JST. **RC1 is not implemented or ready for review/export. Return to Startup Lab now.**

Subsequent authorization: Startup Lab lifted this stop only for the [derived-loop A/B experiment](vm061-derived-loop-experiment.md). The original findings below remain historical; runtime selection and RC1 integration are still pending.

## Stop decision and evidence

Startup Lab's RC1 integration brief, sections 20 and 43, requires reporting an unresolved audible music seam and returning rather than rewriting/crossfading the composition. The founder listened to the boundary audition in this session and selected: **“Audible gap/click — return audio issue to Startup Lab.”** This is human listening evidence; Codex did not independently hear playback.

The supplied non-fade WAV contains **30.1667 ms of trailing silence** at a numerical threshold of 1e-7. Its total duration is **94.6454375 seconds**, with the last above-threshold sample frame at **4,541,532** (zero-based), ending at **94.6152708 seconds**. The next full-file loop begins at approximately **-0.04047 / -0.04044** normalized left/right amplitude after silence. The silence and restart discontinuity are technical observations, not a complete diagnosis of the audible seam.

At the reported 104 BPM, 41 four-beat bars last approximately 94.6153846 seconds. This is a useful inference for asking the composer about the intended endpoint, **not an authorized loop point**. Do not trim to that number automatically. Ask Miraie for either a full-file seamless non-fade export without unintended padding, or exact loop start/end sample frames and instructions for any tail overlap. The composer should confirm how the musical boundary should join.

## Source and local audition

- Authoritative supplied source: `/Users/jeromenicholaz/Downloads/2026 09 08 miraie joltrome VENDING MACHINE BGM fade-wav/2026 09 08 miraie joltrome VENDING MACHINE BGM.wav`.
- Composer metadata supplied by Startup Lab: **Miraie; 104 BPM; C Major; Camelot 8B**.
- Format: stereo, 48,000 Hz, 32-bit floating-point PCM WAV; 4,542,981 frames; **36,343,964 bytes**.
- SHA-256: `1e12cc678e944c2ea1aa560653c1c07e3b26a1dbdd9dfead40d3deced3b391d4`.
- The original remains unchanged. No fade master or temporary MP3 was used as a conversion source.
- Local audition: `builds/validation-vm061/loop-boundary-audition.wav` (ignored QA evidence). It joins the final three seconds of the source to its first three seconds, repeats that excerpt three times, and uses 16-bit PCM for convenient playback. End-to-start boundaries are at approximately 3, 9 and 15 seconds. The resets between excerpts at approximately 6 and 12 seconds are not the musical loop boundary. This is an audition excerpt, not a runtime replacement or a repaired composition.
- A direct WAV-to-OGG attempt used local **FFmpeg 8.1.2**, `libvorbis`, quality 7, metadata stripped, bitexact flags. It failed because this FFmpeg build has no `libvorbis` encoder. **No OGG was produced**, and no conversion service or dependency installation was used. Only an experimental native Vorbis encoder was listed; it was not substituted for the requested high-quality conversion.
- No Godot runtime loop was accepted, no repeated Godot loop QA was claimed, and the temporary RC0 MP3 remains the runtime asset with its existing once-per-session behavior.

## Repository and baseline

Before: clean `release/vm-0.6.0-presentation-audio`, HEAD **`437f76f643d0caa35e6b9dbf88c437561ae893d9`**. The live GitHub branch was queried and matched that exact hash. Its history includes RC0 engineering `1dcaae7`, corrected leftward conveyor `e658cb8`, and accepted Standard coin micro-pass `e7f4d3`.

Created local integration branch **`release/vm-0.6.1-get-canned-rc1`** from that accepted baseline. The stop report is a documentation-only checkpoint on this branch; the branch has not been pushed. RC0's remote branch remains unchanged.

All **27 existing Godot test scripts passed before edits**, including the presentation/audio test's twelve clean retry cycles and full 60-second D3 completion check. Per-test logs are in `builds/validation-vm061/baseline/`. These establish RC0's baseline, not RC1 validation. Existing headless environment diagnostics remain visible in the logs.

Work's `implementation/HANDOFF.md`, manifest, font/source documentation and menu reference were inspected. All five reused sprite source hashes matched the repository. No visual mapping or architecture blocker was found in that preflight. Initial, unvalidated UI/death-cause/input edits were interrupted when the founder confirmed the seam. Only those task-owned edits were removed from the working tree; their draft copies are quarantined under ignored `builds/validation-vm061/interrupted-work/` and are not runtime resources or an accepted implementation.

The final checkpoint changes documentation only. All **188 tracked runtime/configuration/asset/test files** were byte-compared with `437f76f` and match. Runtime configuration, scripts, scenes, assets, tests and all frozen gameplay values remain identical to the accepted baseline. No RC1 export, screenshot, GIF, browser run, touch validation or physical-device validation was produced. No itch.io upload, external testing, SFX sourcing or Overload work occurred.

## Selected direction retained for resumption — not implemented

The authoritative production package remains outside the repository at `/Users/jeromenicholaz/.codex/.chatgpt-projects/g-p-6a620f9598f48191b1f5f1a94286b5cd/artifacts/vm060_get_canned_c2_production/`.

| Item | Startup Lab's selected RC1 requirement |
|---|---|
| Name / art | GET CANNED!; C2 Minimal; L1 Compact Stack; exact supplied textures/glyphs and authentic sprite timing |
| Start / brand | CLOCK IN without exclamation; VENTASTIC once on Menu at (1006,609), 102×14 |
| Result mapping | Ordinary and D3 products → CANNED.; carriage → GRABBED.; OUT → VENDED.; unknown → GAME OVER.; success → CLOCKED OUT. |
| Death data | Typed per-run cause, marked at lethal handlers/D3 spawn, first cause wins, snapshot into one shared result layout; preserve signal signatures where practical |
| Death presentation | Approximately 0.75 seconds of frozen/settled readability before results; no input, score or outcome mutation; clean Retry |
| Keyboard | Space, W and Up invoke the same jump action; physics unchanged; compact accurate legend |
| Mobile | Scoped landscape Web touch Left/Right/Jump, multitouch and cleanup; aspect-preserving scaling and portrait rotation guidance; physical-device validation still required |
| Audio | Direct lossless-master conversion, validated seamless loop, persistent single player and independent mutes; silent SFX hooks preserved |

Current RC0 still has no production death-cause field, an immediate generic death result, Space-only jump, and no new touch overlay. The detailed existing data flow and smallest proposed extension remain in [the functional contract](vm060-ui-functional-contract.md). No RC1 button-state, typography, death-beat, cause-mapping, input-alias or mobile result should be reported as tested.

## Next decision

Startup Lab should obtain corrected loop material or composer-confirmed loop points and resolve local Vorbis tooling, then explicitly resume RC1. It may instead authorize UI/input/death/mobile integration while keeping the demo and deferring final music. That scope exception was not assumed in this pass.

## Cost

GPT-6 family is exposed in session instructions; Astra/High was requested, but the exact runtime variant/reasoning and token consumption are not independently reported. Authentication is a Codex/ChatGPT session with exact account details unavailable. OpenAI API requests: **0**. Third-party paid-service requests: **0**. Separately billed task and recorded cumulative project cost: **$0.00**. Subscription usage is unavailable; consult Codex Settings → Usage if needed.
