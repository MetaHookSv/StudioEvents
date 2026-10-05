# StudioEvents

[中文文档](README.zh-CN.md)

StudioEvents is a MetaHook plugin that filters Studio model sound events to prevent repeated or overlapping playback. It supports delayed playback, player sound blocking, and sound/model whitelists.

## Install

1. Install [MetaHookSv](https://github.com/MetaHookSv/MetaHook).
2. Download `StudioEvents-windows-x86.7z` from [GitHub Releases](https://github.com/MetaHookSv/StudioEvents/releases), or build it locally from source.
3. Merge the package's `svencoop/` contents into your game's mod directory.
4. Add `StudioEvents.dll` on its own line in `metahook/configs/plugins.lst`, then launch game through MetaHook.

The package includes the original sound and source-model whitelists.

## Documentation

- [Features](docs/en/features.md)
- [F5 debugging (optional)](docs/en/debugging.md)

## Build

Requirements: Windows, Visual Studio 2022 with C++ tools, CMake 3.21 or newer, Git, and Python 3.8 or newer. The plugin builds for MSVC x86 only.

```bat
scripts\build-StudioEvents-x86-Release.bat
scripts\build-StudioEvents-x86-Debug.bat
```

The scripts configure under `build/x86/<Configuration>` and install the DLL, PDB, gamedata, and whitelists under `install/x86/<Configuration>/svencoop/`. They do not deploy files into a local game installation.

The first configure fetches the latest `main` of the MetaHook SDK, Capstone headers when needed, and a SHA256-verified VC-LTL 5.3.1 binary package in `thirdparty/cache`. The SDK is consumed without building the launcher. The explicit source list preserves the original 4 plugin compilation units and the SDK's `interface.cpp`, with C++20 and a static CRT. Capstone is not linked; its types are used through the MetaHook API.

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

## License

Licensed under the [MIT License](LICENSE). MurmurHash2 retains Austin Appleby's public-domain notice; each SDK dependency retains its own license.
