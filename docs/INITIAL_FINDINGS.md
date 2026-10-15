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

## Native nonlocal control-flow fix

Configured the inspected setjmp/longjmp addresses in the entrypoint manifest. Normal codegen regenerated the relevant call sites to use ppc_setjmp/ppc_longjmp; the incremental Release build passed. The next launch recovered from the initial Lua nil-function error and continued into GPU interrupt setup instead of faulting in the error handler. It then exposed another unmapped virtual callback at 0x821DFB30. That routine was inspected through its final return at 0x821DFB94, immediately before the next function at 0x821DFB98 (size 0x68), and is being added.

## Additional indirect-call coverage

The next launch passed GPU interrupt setup and stopped at 0x82D01798. This is a six-instruction, 24-byte member/vtable dispatch thunk referenced at 0x820E7D30 in the executable's data tables.

A local pointer-table scan identified other absent entries. Fifty-six were accepted only after checking that they start after a prior return/tail branch/padding, are referenced in a table near known function pointers, and consist entirely of a short straight-line integer sequence ending in a return, indirect tail dispatch, or tail branch to an already known function. The resulting fable_3_leaf_callbacks.toml records each address, exact size, and one table-reference address. The remaining complex candidates were not added speculatively. Names remain descriptive placeholders.

Normal codegen with these mappings passed; the native incremental build is being checked. This increases indirect-call coverage but does not prove all runtime functions are mapped.

## Format-conversion jump-table correction

The 56 leaf mappings compiled and startup advanced beyond the prior callback failures. Windows then reported an illegal-instruction exception. A local symbolized debug capture and native disassembly identified a generated UD2 in sub_82D6E9C8, not an unsupported CPU ISA feature. The generated switch for guest bctr 0x82D6ECE0 contained cases 0..2, while the executable's adjacent table at 0x82D6ECE4 has 13 entries and ends exactly at the first destination 0x82D6ED18. Earlier code permits format values 0..12. Added all 13 original labels using register 18 in entrypoint.switch_tables; no trap bypass or game-result stub is used.

The diagnostic helper tools/debug-startup.py uses Windows x64 debugging APIs and the locally built PDB. It passes expected first-chance guest memory faults to ReXGlue, captures fatal exceptions, and prints candidate native return addresses (not a proper unwound stack). It terminates only the process it launches after an exception or a 40-second diagnostic timeout. Run it separately from a normal play session; no game content or crash logs are uploaded.
