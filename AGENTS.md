# AGENTS.md

This file provides guidance and important rules working with code in this repository.

## When coding / building plan

- Use a progressive disclosure approach for agent coding in this repository: start from high-level
  information in the Basic Memory knowledge base first, and only locate/read specific files or
  symbols when necessary, instead of expanding a large amount of context at once.

#### Basic Memory knowledge base (project-scoped, `memory/`)

- Notes live in `memory/` (markdown with YAML frontmatter: `title`/`type`/`permalink`), tracked in git.
- This repository contains the standalone StudioEvents plugin, extracted from MetaHookSv
  `Plugins/StudioEvents`. Its notes were migrated from MetaHookSv and adapted to the CMake workspace;
  see `memory/project_overview.md` for scope and provenance.
- Basic Memory is registered as MCP server `basic-memory`, pinned to the `studioevents` project
  (project-level `.mcp.json`, mirrored by `.codex/config.toml`). The `metahooksv` project belongs to
  the source repository.
- Prefer Basic Memory MCP tools (`search_notes` / `read_note` / `write_note` / `edit_note`) only when
  their project resolves to this repository's `memory/` directory. Verify the project binding before
  writing; when no matching project is available, read and edit the local markdown files directly.
- Notes use the `studioevents/` permalink prefix to distinguish them from the source repository.
- Historical records are not current evidence: the migrated note retains MetaHookSv paths and does not
  describe the whitelists, which were added to the implementation; the current sources are `src/<file>`.
  Do not extend an old statement to a new change without checking the code.

#### High-level information in this repository (read corresponding notes first)

- Project overview, provenance, filtering pipeline, whitelists and dependencies: `project_overview`

#### When notes are insufficient: source entry points (query and read on demand)

- Build: `CMakeLists.txt`, `cmake/Sources.cmake` (explicit compile list: 4 plugin units plus the SDK's
  `interface.cpp`), `cmake/Dependencies.cmake`, `cmake/VCLTL.cmake`,
  `scripts/build-StudioEvents-x86-{Debug,Release}.bat`
- Plugin sources: `src/`; lifecycle `src/plugins.cpp`, all filtering behavior `src/exportfuncs.cpp`,
  `r_model` resolution `src/privatehook.cpp`, whitelist hashing `src/MurmurHash2.cpp`
- Runtime data: `assets/svencoop/studioevents/sound_whitelist.txt` and
  `sourcemodel_whitelist.txt`, installed next to the game's `svencoop/` directory
- Public API / interface: MetaHook's `include/metahook.h`, `include/HLSDK/` and `include/Interface/`
  are consumed as an SDK (the launcher is never built here); `GamedataResolvePtr` in `src/plugins.h`
  is the local gamedata wrapper
- gamedata: `scripts/manifests/studioevents.json` (the single `engine` / `r_model` global),
  `scripts/sync-gamedata.py`, `scripts/validate-gamedata.py`; the build-time sync prunes the upstream
  catalog into the nested `metahook/gamedata/studioevents/` directory, which the host launcher merges
- Docs: `README.md` / `README.zh-CN.md`, features in `docs/en/features.md` and `docs/zh-CN/features.md`.
  There is no test suite in this repository
- External sources, all read-only inputs: `METAHOOK_SOURCE_PATH` (must provide `include/metahook.h`,
  `include/HLSDK`, `include/Interface` and `include/SourceSDK`) and `CAPSTONE_INCLUDE_DIRS` (headers
  only; Capstone is not linked). Empty paths fall back to pinned FetchContent; VC-LTL 5.3.1 is
  downloaded into `thirdparty/cache`
- Build output: `build/x86/<configuration>/`; install output: `install/x86/<configuration>/svencoop/`.
  Neither is tracked, and nothing is deployed to the game automatically

#### Progressive disclosure key points

- Read notes first, then locate a single file/symbol; do not read the whole repository at once.
- Prefer correctly scoped Basic Memory MCP tools for knowledge retrieval; otherwise use the local
  notes before reading source.
- Prefer Context7 for external dependency/library usage (query on demand).

## Repository rules

- Preserve the MetaHook API, plugin exports, calling conventions and filtering semantics. Match the
  naming, indentation and comment style of the files you touch.
- Resolve engine symbols only through the host gamedata contract. Do not add a signature-scan
  fallback for `r_model`; a failed resolution must stay fatal, and the whitelist decision must keep
  its current precedence (whitelists bypass both the anti-spam filter and player blocking).
- Keep the decision order and interval semantics in `HUD_StudioEvent` intact: expire by
  `max(anti_spam_diff, anti_spam_same)`, classify a match by entity index + animation frame +
  case-sensitive sound name, and call the original in every non-blocked path.
- CVar names, defaults and flags, the whitelist file paths and the delayed-replay behavior are
  user-visible contracts: change them together with `README.md` / `README.zh-CN.md` and the feature
  pages.
- When gamedata usage changes, update `scripts/manifests/studioevents.json` in the same change.
- Do not modify external sources or third-party sources. MetaHook and Capstone are read-only build
  inputs; MurmurHash2 keeps its public-domain notice.
- The plugin builds for MSVC x86 only. Keep the static CRT / VC-LTL, C++20 and warning-level settings
  in `CMakeLists.txt` in sync with the other standalone plugin repositories.
- The empty hook entry points (`Engine_FillAddress`, `Engine_InstallHooks`, `EngineStudio_InstalHooks`,
  `ExitGame`, `Shutdown`) and the mirror-image/`ConvertDllInfoSpace` scaffolding are inherited
  leftovers. Do not assume they run, and do not delete them as part of an unrelated change.
- Verification distinguishes build checks from a real game run: there is no test suite here, so a
  successful configure/build says nothing about whether a sound is filtered or a delayed sound is
  replayed at runtime. Claims about in-game behavior must not be made without evidence. Documentation
  changes need content, path and format checks, not a plugin rebuild.

## Explore SKILLs

- Project-level skills, when present, live in `.claude/skills` no matter what harness tool is being
  used.
