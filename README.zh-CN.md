# StudioEvents

[English](README.md)

StudioEvents 是 MetaHook 插件，可过滤 Studio 模型自带音效，避免重复或密集播放，并支持延迟播放、玩家音效屏蔽及声音/模型白名单。

## 安装

1. 安装最新版本的 [MetaHookSv](https://github.com/MetaHookSv/MetaHook)。
2. 从 [GitHub Releases](https://github.com/MetaHookSv/StudioEvents/releases) 下载 `StudioEvents-windows-x86.7z`，或自行从源码构建。
3. 将压缩包中的 `svencoop/` 内容合并到游戏的 mod 目录。
4. 在 `metahook/configs/plugins.lst` 中单独添加一行 `StudioEvents.dll`，通过 MetaHook 启动游戏。

压缩包包含原插件的声音和来源模型白名单。

## 文档

- [功能](docs/zh-CN/features.md)
- [F5 调试（可选）](docs/zh-CN/debugging.md)

## 构建

要求：Windows、安装 C++ 工具的 Visual Studio 2022、CMake 3.21 或更新版本、Git、Python 3.8 或更新版本。仅支持 MSVC x86。

```bat
scripts\build-StudioEvents-x86-Release.bat
scripts\build-StudioEvents-x86-Debug.bat
```

脚本使用 `build/x86/<Configuration>` 构建目录，将 DLL、PDB、gamedata 和白名单安装到 `install/x86/<Configuration>/svencoop/`，不会自动部署到本机游戏目录。

首次配置会获取最新 `main` 的 MetaHook SDK、按需获取 Capstone 头文件，并在 `thirdparty/cache` 缓存经 SHA256 校验的 VC-LTL 5.3.1 包。SDK 仅作为输入，不构建启动器。显式源码清单保留原插件的 4 个编译单元和 SDK 的 `interface.cpp`，使用 C++20 和静态 CRT。Capstone 仅通过 MetaHook API 使用其类型，不链接 Capstone 库。

使用本地 SDK 时，传入包含 `include/metahook.h`、`include/HLSDK`、`include/Interface` 和 `include/SourceSDK` 的仓库根目录：

```bat
scripts\build-StudioEvents-x86-Release.bat -DMETAHOOK_SOURCE_PATH=D:\MetaHook
```

`METAHOOK_SOURCE_PATH` 和 `CAPSTONE_INCLUDE_DIRS` 也支持同名环境变量。Capstone 头文件依次从显式指定目录、SDK 的 `thirdparty/capstone_fork`、固定 commit 的下载目录获取。构建脚本会转发额外 CMake 参数。

## gamedata

每次构建会同步并校验上游 catalog，仅保留 StudioEvents 使用的引擎全局变量 `r_model`。该变量用于识别当前产生 Studio 音效的模型，来源模型白名单依赖此 catalog。

Manifest 包含 11 个引擎快照。无法识别引擎或缺少必要符号时，插件会报告错误；没有签名扫描回退。功能文档中的兼容性表继承自原插件，不代表此独立构建已经逐一完成游戏内验证。

使用 `-DSTUDIOEVENTS_SYNC_GAMEDATA=OFF` 可跳过构建时下载 gamedata，安装时需要自行提供兼容 catalog。`STUDIOEVENTS_GAMEDATA_DIR` 可覆盖构建和安装使用的 catalog 目录。校验安装后的 catalog：

```bat
python scripts\validate-gamedata.py install\x86\Release\svencoop\metahook\gamedata\studioevents --manifest scripts\manifests\studioevents.json
```

## 许可证

采用 [MIT License](LICENSE)。MurmurHash2 保留 Austin Appleby 的公有领域声明，各 SDK 依赖保留其原有许可证。

## C/C++ 格式化

使用 [MetaHookSv/FormatValidation](https://github.com/MetaHookSv/FormatValidation)
共享工具及固定版本 **clang-format 23.1.3**，采用 DiligentCore 风格（4 空格，保留
include 顺序）。为 CMake 使用的 Python 解释器安装格式工具：

```sh
python -m pip install clang-format==23.1.3
cmake -S . -B build/format "-DFORMAT_VALIDATION_ONLY=ON"
cmake --build build/format --target format-check
cmake --build build/format --target format
```

格式专用配置需要 CMake 3.21+、Git、Python 3.9+（CI 使用 3.12）及构建生成器；
使用 `-G Ninja` 可无需 Visual Studio。它不准备原生 SDK 或游戏依赖。
格式目标需显式执行，不加入普通 DLL 构建。使用 Visual Studio 生成器时，执行目标
需追加 `--config Debug` 或 `--config Release`。

聚合仓库注入 `FORMAT_VALIDATION_SOURCE_PATH=thirdparty/FormatValidation`。
独立组件支持该 CMake 参数及同名环境变量；为空时通过 FetchContent 获取固定工具
提交。相对路径应加引号，例如
`"-DFORMAT_VALIDATION_SOURCE_PATH=../../thirdparty/FormatValidation"`。
配置时在仓库根目录生成被 gitignore 的 `.clang-format` 供编辑器使用；格式规则应
在共享仓库修改，不修改生成副本。可通过 `FORMAT_VALIDATION_CLANG_FORMAT_EXECUTABLE`
指定工具路径，但版本仍须与固定版本一致。

检查覆盖 `src/`、`include/`、`tests/` 中维护的 C/C++ 文件，包括未被 Git 忽略的新文件。
相对仓库根目录的排除规则位于 `.clang-format-ignore`；第三方源和构建产物不纳入检查。
`clang-format` workflow 在 push、pull request 和手动运行时执行全量检查。
