# AGENTS.md - StudioEvents Project Guide

## Project Overview

**StudioEvents** is a MetaHookSV plugin that controls and filters Studio model event sounds (event 5004). It implements an anti-spam mechanism that prevents repeated or overlapping sound-event playback, can delay filtered sounds instead of discarding them, can block player sound events, and lets individual sound files and source models bypass the filtering through whitelists.

- **Project type**: Native C++ plugin (Windows DLL), MSVC x86 only
- **Engine**: GoldSrc / SvEngine
- **Framework**: MetaHookSV Plugin API (`IPluginsV4`, API 109 or newer)
- **Main dependencies**: MetaHook SDK (public API, `include/HLSDK`, `include/Interface`, `include/SourceSDK`) and Capstone headers used indirectly through the MetaHook API. **No third-party library is linked**, and MurmurHash2 is vendored in-tree (public domain)

## Project Structure

```
StudioEvents/
├── src/
│   ├── plugins.cpp            # IPluginsV4 lifecycle; empty Engine_FillAddress/InstallHooks calls
│   ├── plugins.h              # API guard, shared globals, GamedataResolvePtr, legacy search macros
│   ├── exportfuncs.cpp        # ALL behavior: cvars, whitelists, filtering, delayed queue, exports
│   ├── exportfuncs.h          # Replaced export declarations
│   ├── privatehook.cpp        # r_model resolution plus inherited (empty) hook entry points
│   ├── privatehook.h          # r_model declaration, private_funcs_t placeholder, entry points
│   ├── MurmurHash2.cpp/.h     # Austin Appleby's public-domain hash, used for whitelist membership
│   └── (no enginedef.h)       # <metahook.h> and the SDK headers are included directly
├── assets/svencoop/studioevents/
│   ├── sound_whitelist.txt        # Shipped default: one sound path
│   └── sourcemodel_whitelist.txt  # Shipped default: 431 model paths
├── cmake/
│   ├── Sources.cmake          # Explicit compile list (4 plugin units + the SDK's interface.cpp)
│   ├── Dependencies.cmake     # Source-path resolution and FetchContent fallback
│   ├── LaunchGame.cmake       # Optional F5 deploy support
│   └── VCLTL.cmake            # VC-LTL 5.3.1
├── scripts/
│   ├── build-StudioEvents-x86-{Debug,Release}.bat
│   ├── manifests/studioevents.json     # Gamedata manifest (one engine global)
│   ├── sync-gamedata.py                # Prunes the upstream catalog into the build tree
│   └── validate-gamedata.py            # Validates it before the plugin target builds
├── docs/en/, docs/zh-CN/      # Bilingual features.md and debugging.md; docs/img/8.png screenshot
├── memory/project_overview.md # Longer design note (permalink prefix `studioevents/`)
├── thirdparty/cache/          # Ignored VC-LTL binary cache
├── build/x86/<configuration>/    # Ignored build output
├── install/x86/<configuration>/  # Ignored install output
├── README.md, README.zh-CN.md # Bilingual install / build documentation
└── CMakeLists.txt             # Windows MSVC x86 build and install rules
```

## Core Modules

### 1. Plugin lifecycle (`src/plugins.cpp`)

`IPluginsV4` exported through `EXPOSE_SINGLE_INTERFACE(IPluginsV4, IPluginsV4, METAHOOK_PLUGIN_API_VERSION_V4)`:

- `LoadEngine`: collects the file system (`FileSystem`, else `FileSystem_HL25`), engine type/buildnum, the engine image sections (plus the mirror image when the host provides one) and copies `cl_enginefunc_t`. It then calls `Engine_FillAddress()` and `Engine_InstallHooks()` — **both are empty**
- `LoadClient`: copies the export table and **takes over five slots** — `HUD_Init`, `HUD_VidInit`, `HUD_Frame`, `HUD_StudioEvent`, `HUD_GetStudioModelInterface`. These are replacements, not inline hooks
- `ExitGame` and `Shutdown`: empty
- `GetVersion`: returns the build timestamp baked in by CMake

### 2. Filtering (`HUD_StudioEvent`, `src/exportfuncs.cpp`)

Only events with `ev->event == 5004` **and** a non-empty `ev->options` are filtered; every other event is forwarded to `gExportfuncs.HUD_StudioEvent` untouched. For a filtered event the decision order is fixed:

| # | Check | Result |
| --- | --- | --- |
| 1 | sound name hash in `sound_whitelist` | forward to the original |
| 2 | current render model name hash in `sourcemodel_whitelist` | forward to the original |
| 3 | `cl_studiosnd_block_player > 0` and `ent->player` | drop, return without calling the original |
| 4 | playback history conflict | delay or drop (see below) |
| 5 | no conflict | record in the played list and fall through to the original |

The whitelists sit first and bypass *both* the anti-spam filter and player blocking.

History conflict detection walks `g_StudioEventSoundPlayed` once and does two things per entry:

- erases entries older than `max(anti_spam_diff, anti_spam_same)` — `max_time` is recomputed from the remaining, live entries
- classifies a still-live entry as "same sound" when `entindex`, `frame` and a **case-sensitive `strcmp`** on the name all match, comparing it against `cl_studiosnd_anti_spam_same`; every other entry is compared against `cl_studiosnd_anti_spam_diff`

On a conflict the plugin keeps the **latest** allowed time (`max` over `entry.time + interval`) and either appends the sound to the delayed queue (when `cl_studiosnd_anti_spam_delay` is nonzero) or drops it — both paths return without calling the original. Without a conflict it appends to the played list with the current client time and lets the call through.

`cl_studiosnd_debug` prints one line per decision: `Sound whitelisted`, `Source model whitelisted`, `Blocked`, `Delayed`, `Played`.

### 3. Delayed replay (`HUD_Frame`)

`HUD_Frame` forwards to the original, then **returns early when there is no local player** — so the delayed queue is only serviced while a local player exists. For entries whose stored time has passed it:

1. resolves the entity by index and requires `ent->curstate.messagenum == local->curstate.messagenum` (the code carries a `TODO` noting `cl_parsecount` may be the correct counter, because a player that was not emitted can keep a stale `messagenum`)
2. rebuilds an `mstudioevent_s` (`event = 5004`, the stored `frame`, `options` = the stored name, `type = 0`) and calls the plugin's own `HUD_StudioEvent` with it, so the replayed sound goes through the whole filter again
3. erases the entry from the queue **whether or not** the replay happened

`HUD_VidInit` clears both the played list and the delayed queue, which is what resets state across map changes and reconnections.

### 4. Whitelists (`src/exportfuncs.cpp`)

- Files: `studioevents/sound_whitelist.txt` and `studioevents/sourcemodel_whitelist.txt`, both read only at `HUD_Init` through `FILESYSTEM_ANY_OPEN(..., "rt")` and closed with `FILESYSTEM_ANY_CLOSE`
- Format: one full path per line, optional quotes handled by `FILESYSTEM_ANY_PARSEFILE`, first token only, 256-byte line buffer
- Membership stores `MurmurHash2(name, strlen(name), 0)` in a `std::unordered_set<uint32_t>` — matching is exact and case-sensitive on the full string, but a 32-bit hash collision would whitelist an unrelated name. The same hash function serves both lists
- The set is cleared **inside** the successful-open branch, so a missing file is reported only through `Con_DPrintf` and leaves whatever was loaded before in place (an empty set on the first run)
- The downloaded defaults ship in `assets/svencoop/studioevents/` and are installed next to the game's `svencoop/` directory

### 5. `r_model` resolution (`src/privatehook.cpp`)

`EngineStudio_FillAddress` resolves the single `engine` / `r_model` global with `GamedataResolvePtr(RealDllInfo.ImageBase, "engine", "r_model", MH_GAMESYMBOL_KIND_GLOBAL)`. It runs from `HUD_GetStudioModelInterface`, **not** from `LoadEngine`, because that is the first point where the Studio interface exists.

The helper (`src/plugins.h`) is fatal on failure: `Could not resolve gamedata symbol: r_model (module engine, <status>)` plus the engine buildnum. Unlike some other standalone plugins, this diagnostic carries **no CRC64**. There is no signature-scan fallback.

`EngineStudio_GetCurrentRenderModelName` returns an empty string when `r_model` or `*r_model` is null, so the source-model whitelist simply cannot match in that state.

`HUD_GetStudioModelInterface` then copies `engine_studio_api_t` into `IEngineStudio`, caches `ppinterface` in `gpStudioInterface`, and calls the original export when present (defaulting to `1` when `gExportfuncs.HUD_GetStudioModelInterface` is null).

### 6. Inherited scaffolding — do not build on it

Empty or unused by design in the current version: `Engine_FillAddress`, `Engine_InstallHooks`, `EngineStudio_InstalHooks` (all empty), `ExitGame` / `Shutdown` (empty), `ConvertDllInfoSpace` (declared, defined, never called), `GetVFunctionFromVFTable` (defined, never declared or called), the `g_ClientDLLInfo` / `g_MirrorClientDLLInfo` image records (defined, never read) and `private_funcs_t`, which is a placeholder struct holding `int unused`. The `Search_Pattern*` macros in `src/plugins.h` are retained but no scan path remains. `src/privatehook.h` also declares `EngineStudio_FillAddress` twice.

## Key Code Flow

```
Engine dispatches a Studio model event → HUD_StudioEvent (taken over)
    ↓
event == 5004 && options[0] ?
    ├── no → original HUD_StudioEvent
    └── yes → sound whitelist?  → original
              source-model whitelist? → original
              block_player && ent->player ? → drop
              walk history: erase expired, classify same/different sound
                  ├── conflict → delay (append with the latest allowed time) or drop → return
                  └── clean   → record as played → original

HUD_Frame
    ↓
no local player → return (queue untouched)
    ↓
entry due → entity valid (messagenum matches) ? → rebuild mstudioevent_s → HUD_StudioEvent
    ↓
erase the entry either way

HUD_GetStudioModelInterface
    ↓
EngineStudio_FillAddress → ResolveGameSymbol("r_model", GLOBAL) → fatal on failure
    ↓
copy engine_studio_api_t, cache ppinterface, call the original export
```

## Console Variables and Whitelist Files

User-visible contract — change these together with `README.md` / `README.zh-CN.md` and the feature pages.

| CVar | Default | Flags | Meaning |
| --- | --- | --- | --- |
| `cl_studiosnd_anti_spam_diff` | `0.5` | `FCVAR_CLIENTDLL \| FCVAR_ARCHIVE` | Minimum interval (s) after an event with a different entity, frame or sound name |
| `cl_studiosnd_anti_spam_same` | `1.0` | `FCVAR_CLIENTDLL \| FCVAR_ARCHIVE` | Minimum interval (s) for the same entity, frame and sound name |
| `cl_studiosnd_anti_spam_delay` | `0` | `FCVAR_CLIENTDLL \| FCVAR_ARCHIVE` | Nonzero delays filtered sounds instead of discarding them |
| `cl_studiosnd_block_player` | `0` | `FCVAR_CLIENTDLL \| FCVAR_ARCHIVE` | Greater than zero blocks player sound events; viewmodels are not player entities |
| `cl_studiosnd_debug` | `0` | `FCVAR_CLIENTDLL` | Nonzero prints every decision to the console |

Intervals apply to one shared playback history, including events from different entities.

## Build Instructions

Requirements: Windows, Visual Studio 2022 with C++ tools, CMake 3.21 or newer, Git, Python 3.8 or newer, MSVC x86 (`-A Win32`), C++20 (`cxx_std_20`), static CRT (`MultiThreaded`), `_MBCS`, `NO_MALLOC_OVERRIDE` and VC-LTL 5.3.1.

```bat
scripts\build-StudioEvents-x86-Release.bat
scripts\build-StudioEvents-x86-Debug.bat
```

The scripts configure, build and install, forwarding extra CMake arguments. Debug compiles at `/W0`, Release at `/W3`; both suppress `/wd4311 /wd4312 /wd4819 /wd4996` and pass `/permissive`. Release also enables interprocedural optimization and `/OPT:REF /OPT:ICF`; the DLL links with `/SUBSYSTEM:WINDOWS`. Output stays in `build/x86/<configuration>/`; the DLL, its PDB, the gamedata catalog and the `studioevents/` whitelists are installed to `install/x86/<configuration>/svencoop/`. Nothing is deployed to the game automatically.

### Dependencies

- **MetaHook SDK**: fetched automatically at a pinned commit; pass `-DMETAHOOK_SOURCE_PATH=D:\MetaHook` or export the same environment variable to build against a local tree. The path is the repository root providing `include/metahook.h`, `include/HLSDK`, `include/Interface` and `include/SourceSDK`
- **Capstone headers**: resolve from `CAPSTONE_INCLUDE_DIRS`, else the SDK's `thirdparty/capstone_fork`, else a pinned checkout. Used only through the MetaHook API; **Capstone is not linked**
- **VC-LTL 5.3.1**: downloaded once into `thirdparty/cache`, SHA256-verified
- **MurmurHash2**: vendored in `src/`, public domain, not a build dependency

Keep `cmake/Sources.cmake` as the explicit compile list (4 plugin units); `include/HLSDK/common/interface.cpp` is compiled in because `EXPOSE_SINGLE_INTERFACE` (which exports `CreateInterface`) lives there.

### gamedata

`scripts/manifests/studioevents.json` declares a single `engine` / `r_model` **global** across 11 engine snapshots (`cof-5936`, `hl-10210`, `hl-3248`, `hl-3266`, `hl-3329`, `hl-3647`, `hl-4554`, `hl-6153`, `hl-8684`, `svencoop-10257`, `svencoop-8948`). There are no function or patch records.

`scripts/manifests/studioevents.json` → `scripts/sync-gamedata.py` → pruned catalog under `build/x86/<Configuration>/assets/svencoop/metahook/gamedata/studioevents`, validated by `scripts/validate-gamedata.py` before the plugin target builds. Disable with `-DSTUDIOEVENTS_SYNC_GAMEDATA=OFF`; `STUDIOEVENTS_GAMEDATA_DIR` overrides the catalog directory used by the build and install steps. When gamedata usage changes, update the manifest in the same change.

To validate an installed catalog:

```bat
python scripts\validate-gamedata.py install\x86\Release\svencoop\metahook\gamedata\studioevents --manifest scripts\manifests\studioevents.json
```

### Optional F5 debugging

```powershell
cmake -S . -B build/launch -G "Visual Studio 17 2022" -A Win32 -DMETAHOOKSV_ENABLE_LAUNCH_GAME=ON
```

Select **LaunchGame** and press F5; **DeployGame** builds, stages and copies the plugin DLL/PDB/resources into an existing MetaHook installation before the debugger attaches. The feature defaults OFF. See `docs/en/debugging.md` for `METAHOOKSV_GAME_*` options.

## Engine Compatibility

`r_model` must exist in the gamedata catalog for the running engine build:

| Game build | Support |
| --- | --- |
| `hl-3248`, `hl-3266`, `hl-3329`, `hl-3647`, `hl-4554` | ✅ |
| `hl-6153` | ✅ |
| `hl-8684`, `hl-10210` | ✅ |
| `svencoop-8948`, `svencoop-10257` | ✅ |
| `cof-5936` (Cry of Fear) | ✅ |
| Any build absent from the catalog | ❌ fatal at `HUD_GetStudioModelInterface` |

Catalog coverage is not a correctness statement: a listed build only means the record exists, not that the filter was verified in-game. `docs/en/features.md` carries an inherited "original plugin support" table that claims support for every engine family; it says nothing about this standalone build.

## Important Constants, Macros and Types

```cpp
static_assert(METAHOOK_API_VERSION >= 109, ...);  // ResolveGameSymbol requires MetaHook API 109
#define MHPluginName "StudioEvents"

// The filtered event and the record kept per played sound
ev->event == 5004                                 // Studio model sound event
typedef struct studio_event_sound_s {             // src/exportfuncs.cpp
    char name[64];                                // strcpy, never length-checked
    int entindex; int frame; float time;
} studio_event_sound_t;

// Hash-based whitelist membership
std::unordered_set<uint32_t> g_StudioEventSoundWhitelist;
std::unordered_set<uint32_t> g_StudioEventSourceModelWhitelist;
uint32_t CalcSoundNameHash(const char* name);      // MurmurHash2(name, strlen(name), 0)

// Engine global
model_t** r_model;                                 // resolved from gamedata, never scanned

// File-system access for the whitelists
FILESYSTEM_ANY_OPEN(path, mode)
FILESYSTEM_ANY_READLINE(buffer, size, handle)
FILESYSTEM_ANY_PARSEFILE(p, token, &quoted)
FILESYSTEM_ANY_EOF(handle) / FILESYSTEM_ANY_CLOSE(handle)
```

Runtime data: `svencoop/studioevents/{sound_whitelist,sourcemodel_whitelist}.txt` and `metahook/plugins/StudioEvents.dll` in `metahook/configs/plugins.lst`, with `metahook/gamedata/studioevents` next to it.

## Debugging Tips

1. **Console output**: set `cl_studiosnd_debug 1` — every decision prints one line (`Sound whitelisted`, `Source model whitelisted`, `Played`, `Delayed`, `Blocked`). Whitelist loading and the `r_model` failure use `Con_DPrintf` / `Sys_Error`
2. **Breakpoint locations**: `HUD_StudioEvent()` (the whole decision), `HUD_Frame()` (the delayed queue), `LoadWhitelist()` (parsing), `EngineStudio_FillAddress()` (the gamedata lookup), `HUD_GetStudioModelInterface()` (when the lookup happens)
3. **The sound name is copied with `strcpy`** into `char name[64]` and into `mstudioevent_s::options` without a length check — a breakpoint there is the only way to see an over-long name
4. **A delayed sound that never replays** is usually the message-number check: the entity's `messagenum` must equal the local player's at the moment the entry comes due, and the entry is erased even when it fails

## Repository Rules

- Preserve the MetaHook API, plugin exports, calling conventions and filtering semantics. Match the naming, indentation and comment style of the files you touch
- Resolve engine symbols only through the host gamedata contract. **Do not** add a signature-scan fallback for `r_model`; a failed resolution stays fatal, and the whitelist decision keeps its current precedence (whitelists bypass both the anti-spam filter and player blocking)
- Keep the decision order and interval semantics in `HUD_StudioEvent` intact: expire by `max(anti_spam_diff, anti_spam_same)`, classify a match by entity index + animation frame + case-sensitive sound name, and call the original in every non-blocked path
- CVar names, defaults and flags, the whitelist paths and the delayed-replay behavior are user-visible contracts: change them together with `README.md` / `README.zh-CN.md` and the feature pages
- When gamedata usage changes, update `scripts/manifests/studioevents.json` in the same change
- Do not modify external or third-party sources. MetaHook and Capstone are read-only build inputs; MurmurHash2 keeps its public-domain notice
- MSVC x86 only. Keep the static CRT / VC-LTL and C++20 (`cxx_std_20`) settings in `CMakeLists.txt` in sync with the other standalone plugin repositories
- The empty entry points (`Engine_FillAddress`, `Engine_InstallHooks`, `EngineStudio_InstalHooks`, `ExitGame`, `Shutdown`) and the mirror-image / `ConvertDllInfoSpace` scaffolding are inherited leftovers. Do not assume they run, and do not delete them as part of an unrelated change
- Verification distinguishes build checks from a real game run: there is no test suite here, so a successful configure/build says nothing about whether a sound is filtered or a delayed sound is replayed at runtime. Claims about in-game behavior must not be made without evidence. Documentation changes need content, path and format checks, not a plugin rebuild

## Related Links

- **MetaHookSV**: https://github.com/hzqst/MetaHookSv
- **Gamedata symbol catalog**: https://hlnd2t.github.io/GoldSrc_VibeSignatures/
- **MurmurHash2**: https://github.com/aappleby/smhasher
