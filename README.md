# StudioEvents

[中文文档](README.zh-CN.md)

StudioEvents is a MetaHook plugin that filters Studio model sound events to prevent repeated or overlapping playback. It supports delayed playback, player sound blocking, and sound/model whitelists.

## Install

1. Install [MetaHookSv](https://github.com/MetaHookSv/MetaHook).
2. Download `StudioEvents-windows-x86.7z` from [GitHub Releases](https://github.com/MetaHookSv/StudioEvents/releases), or build it locally from source.
3. Merge the package's `svencoop/` contents into your game's mod directory.
4. Add `StudioEvents.dll` on its own line in `metahook/configs/plugins.lst`, then launch game through MetaHook.

The package includes the original sound and source-model whitelists. See [Features](docs/en/features.md) for CVar defaults and matching rules.

## Build

Requirements: Windows, Visual Studio 2022 with C++ tools, CMake 3.21 or newer, Git, and Python 3.8 or newer. The plugin builds for MSVC x86 only.

```bat
scripts\build-StudioEvents-x86-Release.bat
scripts\build-StudioEvents-x86-Debug.bat
```

The scripts configure under `build/x86/<Configuration>` and install the DLL, PDB, gamedata, and whitelists under `install/x86/<Configuration>/svencoop/`. They do not deploy files into a local game installation.

The first configure fetches a pinned MetaHook SDK, Capstone headers when needed, and a SHA256-verified VC-LTL 5.3.1 binary package in `thirdparty/cache`. The SDK is consumed without building the launcher. The explicit source list preserves the original 4 plugin compilation units and the SDK's `interface.cpp`, with C++20 and a static CRT. Capstone is not linked; its types are used through the MetaHook API.

To use a local SDK, pass the repository root containing `include/metahook.h`, `include/HLSDK`, `include/Interface`, and `include/SourceSDK`:

```bat
scripts\build-StudioEvents-x86-Release.bat -DMETAHOOK_SOURCE_PATH=D:\MetaHook
```

`METAHOOK_SOURCE_PATH` and `CAPSTONE_INCLUDE_DIRS` also accept environment variables. Capstone headers resolve from the explicit include directories, then the SDK's `thirdparty/capstone_fork`, then a pinned checkout. Build scripts forward additional CMake arguments.

## gamedata

Each build synchronizes and validates an upstream catalog, pruned to the engine global `r_model` consumed by StudioEvents. It identifies the model currently producing a Studio sound event, so source-model whitelists depend on this catalog.

The manifest declares 11 engine snapshots. An unknown engine or a missing required symbol causes a diagnostic error at runtime; the plugin has no signature-scan fallback. The inherited compatibility table in the feature documentation does not establish that this standalone build has been tested in every engine.

Use `-DSTUDIOEVENTS_SYNC_GAMEDATA=OFF` to skip downloading gamedata during a build; provide a compatible catalog yourself when installing. `STUDIOEVENTS_GAMEDATA_DIR` overrides the catalog directory used by the build and install steps. To validate the installed catalog:

```bat
python scripts\validate-gamedata.py install\x86\Release\svencoop\metahook\gamedata\studioevents --manifest scripts\manifests\studioevents.json
```

## F5 debugging (optional)

Install MetaHook and enable this plugin in the game's `plugins.lst` first. Configure a standalone Visual Studio Win32 solution:

```powershell
cmake -S . -B build/launch -G "Visual Studio 17 2022" -A Win32 -DMETAHOOKSV_ENABLE_LAUNCH_GAME=ON
```

Open the solution, select **LaunchGame** and press **F5**. **DeployGame** builds this plugin and its dependencies, stages Install, and copies plugin DLLs/PDBs/resources before the native debugger starts the existing game launcher. Root launchers/runtime files and plugin lists remain unchanged. Set VS to build before running and **Do not launch** on build errors; stop the game before redeploying. Ordinary builds do not deploy.

`METAHOOKSV_GAME_DIRECTORY` defaults to Steam discovery; `METAHOOKSV_GAME_APPID` defaults to `225840`. Set `METAHOOKSV_GAME_MOD` for a custom mod and `METAHOOKSV_GAME_ARGUMENTS` for extra arguments. Debug and Release are supported.

The shared module uses `METAHOOKSV_LAUNCH_GAME_MODULE_DIR`, the surrounding MetaHookSv checkout, or a pinned source archive. Without Installer sources, it downloads the self-contained CLI from GitHub `latest` (no .NET required); `METAHOOKSV_INSTALLER_RELEASE` selects a fixed tag, and `METAHOOKSV_INSTALLER_CLI_EXECUTABLE` supplies an offline EXE. Plugin mode requires v20261004c or later. Valid caches under `build/launch/launch-game/installer/<release>` are reused without update checks; select another tag or clear that private cache to upgrade. `GH_TOKEN`/`GITHUB_TOKEN` may be supplied through the environment if GitHub API rate limits prevent the first download. The feature defaults OFF and performs no extra downloads when disabled.

## License

Licensed under the [MIT License](LICENSE). MurmurHash2 retains Austin Appleby's public-domain notice; each SDK dependency retains its own license.
