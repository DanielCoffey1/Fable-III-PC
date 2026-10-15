# Initial findings

Date: 2026-10-14 (America/New_York)

- Input: Fable III USA/Europe Xbox 360 disc image, 7,838,695,424 bytes.
- ISO SHA-256: `41d05a825ffe073d9f8d48846cead4fd5b6cdbc07e5c654dbf3039ac53c9c7d1`.
- Extracted default.xex SHA-256: `fc725386570788ee08b72a3bff06cf8227c17922e322fe45860348dda31ddd54`.
- SDK: official ReXGlue v0.10.0 Windows x64 prebuilt package.
- Title ID: `4D5308D6`.
- Media ID: `D99E18E7`.
- XEX version reported by SDK: `0.0.0.3`.
- XEX filetime reported by SDK: `2010-09-10 18:19:25 UTC`.
- Extraction: default.xex and data/, 286 files, 5,965,224,059 bytes.
- Project scaffold and entrypoint manifest generated successfully.
- No ready-made Fable III recomp release found in initial web/GitHub repository searches. This is not proof that no private or unindexed project exists.
- No native gameplay or performance claims have been validated.

The original ISO and extracted content are local only. Development logs and generated game code are ignored.

## First analysis result

`rexglue codegen fable_3_manifest.toml` completed its discovery/validation pass in 40.8 seconds and exited with code 1. No generated C++ or playable binary was produced. Seven unresolved branch edges remain (six unique target addresses):

| Target | Source |
| --- | --- |
| 0x82DC61E0 | 0x82DBEFF0 |
| 0x8303CC38 | 0x8323B488 |
| 0x82DC61F0 | 0x82DBF04C |
| 0x82DC6200 | 0x82DBF07C |
| 0x82DDCED8 | 0x82DCF868 |
| 0x82DDCED8 | 0x82DCF8A8 |
| 0x83062898 | 0x83063090 |

Next: inspect these targets and their containing functions, establish correct boundaries or tail-call relationships, then rerun validation. Do not invent function sizes or force generation and call it validated. Additional issues may appear after these are fixed. A Windows C++ toolchain is also needed before compilation.

## Build tool setup milestone

Visual Studio Build Tools 2022 17.14.42 installed successfully with the MSVC x64 libraries, Windows SDK, Clang 19.1.5, CMake, and Ninja. `tools/build.ps1 -ConfigureOnly` successfully detected the compiler and configured a Release Ninja build against the official ReXGlue v0.10.0 SDK. The installed Clang is older than the wiki recommendation of 20+; native compilation will determine whether further compiler work is required.

The SDK is kept locally in ignored tooling/rexglue-sdk. `tools/setup-sdk.ps1` can fetch the exact package with SHA-256 validation. `.vsconfig` records the requested Visual Studio components. `tools/run.ps1` points the runtime at the local game directory without copying game assets into build outputs.

## Branch validation milestone

Eleven explicit function boundaries resolved all seven original unresolved branches plus newly discovered neighboring calls. Normal (non-forced) codegen completed successfully in 47.9 seconds, writing 51 files and retaining 532 unchanged files. A generated-source scan found no unresolved-call traps. Twenty `Unexpected float16_4 pack instruction` warnings remain; codegen success is not runtime or instruction-semantics validation. Native compilation is the next check.

## First native build and startup

The complete Release build compiled and linked successfully with Clang 19.1.5 (296 build steps). This validates local compilation despite the wiki's newer compiler recommendation. The source executable is approximately 98 MB; generated game code, the executable, and PDB files remain local and ignored.

The first launch initialized audio and guest execution, then stopped at unregistered indirect callback 0x82D65110. Inspection showed a 16-byte vtable dispatch thunk, whose address is explicitly materialized and passed to the streaming callback setup. Added that mapping and the adjacent 8-byte member thunk at 0x82D65120. The incremental build passed.

The scaffold did not enable GPU emulation by default. The project now stages the xenos plugin in CMake and selects it in OnPreSetup when no plugin is supplied. A subsequent launch selected the RTX 5090 and initialized Direct3D 12, shader storage, audio, and input, but did not reach the menu.

Startup then failed on a guest null read. A local debugger capture identified __imp__sub_822D3E40. Forward-only diagnostics at the upstream guest error formatter exposed an earlier Lua error: `function expected instead of nil` (caller 0x822A596C). Diagnostics log the error and call the original implementation without skipping it. The initial allocation-path interpretation was incorrect; these functions belong to Lua's error path.

CRT inspection located setjmp at 0x83140BE0 and longjmp at 0x82E31DA0 (saving/restoring f14-f31, r13-r31, LR, and other jump-buffer state). Native nonlocal control-flow handling is being configured next. No claim of menu/gameplay success is made.
