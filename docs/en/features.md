# StudioEvents documentation

[中文文档](../zh-CN/features.md) · [Build and installation](../../README.md)

## Features

StudioEvents filters nonempty Studio sound events (event 5004). It can discard or delay repeated sounds and block player sound events. Other Studio events are forwarded to the original client callback.

![StudioEvents console example](../img/8.png)

## Compatibility

| Engine | Original plugin support |
| --- | --- |
| GoldSrc_blob (< 4554) | Yes |
| GoldSrc_legacy (< 6153) | Yes |
| GoldSrc_new (8684 ~) | Yes |
| SvEngine (8832 ~) | Yes |
| GoldSrc_HL25 (>= 9884) | Yes |

This table is inherited from the original plugin. Runtime compatibility also requires MetaHook API 109 or newer and a matching gamedata snapshot containing `engine/r_model`. It is not a record of runtime tests for this standalone build.

## Console variables

| CVar | Default | Behavior |
| --- | --- | --- |
| `cl_studiosnd_anti_spam_diff` | `0.5` | Minimum interval in seconds after an event with a different entity, animation frame, or sound name. |
| `cl_studiosnd_anti_spam_same` | `1.0` | Minimum interval in seconds for the same entity, animation frame, and case-sensitive sound name. |
| `cl_studiosnd_anti_spam_delay` | `0` | Nonzero delays filtered sounds instead of discarding them. |
| `cl_studiosnd_block_player` | `0` | Values greater than zero block player sound events; viewmodels are not player entities. |
| `cl_studiosnd_debug` | `0` | Nonzero prints sound-event decisions to the game console. |

Intervals apply to the shared playback history, including events from different entities. Deferred sounds are retried from `HUD_Frame` when due and only while the entity passes the original message-number check. `HUD_VidInit` clears playback history and the delayed queue.

## Whitelists

- `studioevents/sound_whitelist.txt` matches sound file names.
- `studioevents/sourcemodel_whitelist.txt` matches the source model currently rendered by the engine.

Both lists are loaded at client initialization (`HUD_Init`). Put one full path on each line; quote paths containing spaces. Matching is exact and case-sensitive. A match in either list bypasses both anti-spam filtering and player sound blocking.

The package preserves the original default lists. For example, the sound whitelist includes:

```text
weapons/357_chamberout.wav
```
