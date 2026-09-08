# Audio source inventory

Recorded: 2026-09-08. No stock, generated, purchased, or placeholder SFX used.

## Miraie — temporary main theme

- Working filename: `2026 09 03 miraie joltrome VENDING MACHINE BGM demo v2.mp3`.
- Composer: **Miraie**; supplied directly by the composer to the founder, composed specifically while watching **Vending Machine Survival**.
- Original supplied file: `/Users/jeromenicholaz/Downloads/2026 09 03 miraie joltrome VENDING MACHINE BGM demo v2.mp3` (preserved unchanged).
- Runtime: `res://assets/audio/miraie_main_theme_TEMPORARY_DEMO.mp3`.
- Status: **TEMPORARY COMPOSER DEMO**, not a final production loop.
- Permission evidence: founder reports composer replied “of course bro!! i made this for you” when asked to use it as the main theme. This milestone's temporary runtime integration is authorized by the founder.
- Explicit commercial-use confirmation: **pending**. Do not describe the demo as commercially cleared on this evidence alone.
- Credit: **Miraie** provisionally displayed; preferred final credit name pending composer confirmation.
- Modifications/conversions: filename change and byte-for-byte copy only; standard Godot MP3 import. No trimming, remastering, conversion, reconstruction, or speculative loop edit.
- Original and runtime SHA-256: `6d5fe498d000d2d0aff5fea232b3ec9b007da89908b9598d094324c61e5ca001`.
- Size: 4,361,338 bytes; browser-decoded duration approximately 109.032 seconds.
- Demo behavior: play through **once per application/page session**, including its quiet/faded ending. Menu, Play, results, Retry and menu return never restart it. After it ends, music stays silent until a fresh launch. Mute changes gain only, not play position.
- The soda/can-opening sound is part of the composition; it is not a gameplay SFX trigger.

## Final asset swap

1. Obtain composer commercial-use confirmation, preferred credit, lossless master WAV, explicit seamless-loop WAV/OGG, BPM and exact loop point/bar (optional stems).
2. Keep the lossless master as a production source outside the Web payload when a suitable compressed OGG runtime export is supplied.
3. Add the approved seamless asset under `assets/audio/`. Set its Godot import loop option to the composer's exact intended behavior; verify the boundary by listening.
4. Change **Audio → music_stream** in `scenes/presentation/standard_session.tscn` to that resource. The menu and gameplay lifecycle require no changes.
5. Remove the superseded demo from the shipped resource set once no longer required, update this inventory with hashes/permission evidence and repeat Web start/mute/retry/loop QA.

## Future SFX slots

`SessionAudio.sfx_streams` is an empty event-to-AudioStream dictionary. `request_sfx()` emits `sfx_requested` for local testing and plays only a supplied resource through SFX. No files are fetched or synthesized. Events: `coin_pickup`, `jump`, `landing`, `product_impact`, `rack_warning`, `rack_release`, `carriage_warning`, `carriage_sweep`, `player_death`, `final_seconds`, `round_complete`, `ui_confirm`, `ui_back`.

All future third-party SFX need source, author, license, permission, modifications and runtime-path records before integration. Sourcing and mix approval belong to a later authorized milestone.
