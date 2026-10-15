# Fable III lighting compatibility

The tested castle save originally rendered many walls and floors black. A local graphics capture traced this to the production of a compressed lighting atlas, rather than its final texture upload or tone mapping. The normal launcher now uses a custom D3D12 GPU plugin, `rexgpu-fable3.dll`, with two related corrections. Daniel confirmed that the combined correction restored the surfaces and lighting; the agent also inspected the corrected stone walls, wood beams, floor, and stairs.

## Corrections

The atlas copy pass uses a signed RGBA16 texture with integer `num_format=1`. The pinned SDK samples its host SNORM view as normalized values. The title's following division by 1024 then loses the integer magnitude needed to reproduce the packed atlas data. The local DXBC translator patch restores that magnitude before exponent adjustment, guarded by format 26, integer number format, and all four signed component modes. Normal fractional fetches are unchanged. Testing this correction alone improved the scene but left block patterns.

The atlas resolve requests signed-integer output (`copy_dest_number=3`). The old full 64bpp resolve shader does not interpret that field. The custom plugin uses newer upstream full 64bpp resolve shaders that do, adapted to the pinned SDK's typed `uint4` UAV binding. Direct host resolves are disabled for this plugin so the corrected conversion path is used. Testing both corrections together restored the castle scene.

This is a title-specific compatibility implementation, not complete integer-texture support across the SDK. The SNORM view aliases the two most-negative signed values; restoring magnitude cannot independently recover their original distinction. Exact endpoint preservation, other integer formats, scaled rendering, and later game areas need further validation. No forced-white atlas, global brightness change, or game-asset replacement is used.

## Reproducible build

- ReXGlue v0.10.0 source: `f5337cdc947ff6d4c4196737e2c807a48f2a1fc2`.
- Xenia Canary resolve source: `b7350635be5a48a1b28b3bcf0e334b7f7c671abd`.
- `tools/gpu-plugin/shader-sources.json` pins the SHA-256 of each downloaded shader source.
- `patches/rexglue-v0.10.0-signed16-integer-fetch.patch` contains the guarded fetch correction, plugin identification, and direct-resolve default.
- `patches/xenia-canary-b7350635-typed-resolve.patch` adapts the output binding without changing the upstream signed packing logic.
- `tools/build-gpu-plugin.ps1 -Stage` compiles HLSL with the installed Windows SDK FXC compiler, then builds only the GPU plugin against the existing SDK runtime. It does not rebuild or replace the original runtime/plugin.

The normal `tools/build.ps1` invokes that helper. The normal `tools/run.ps1` and application's empty-plugin default select `fable3`. `tools/run.ps1 -OriginalGpu` selects `xenos` for comparison. The original plugin remains available locally. Caches, downloaded sources, compiled shader headers, binaries, captures, and game data remain ignored.

## Validation

Native Release and isolated GPU-plugin builds passed. The rebuild helper was also exercised from a separate clean SDK checkout, then its cache/staging path was checked. Windows process-module inspection confirmed the test loaded the corrected plugin.

In the corrected, settled scene, representative submission timing windows averaged 16.67 ms, with p95 around 17.03–17.06 ms and no intervals over 50 ms in those windows. These are guest submission measurements, not display-present measurements or a full-game benchmark. Loading and first-time shader compilation still produce spikes. Earlier gameplay and save/reload testing passed, but the entire game and every later save path have not been retested with this GPU change.

The upstream shader sources retain their BSD license. Licenses are preserved under `third_party/licenses`. Source references: [ReXGlue SDK](https://github.com/rexglue/rexglue-sdk/tree/f5337cdc947ff6d4c4196737e2c807a48f2a1fc2), [Xenia Canary signed-format packing](https://github.com/xenia-canary/xenia-canary/blob/b7350635be5a48a1b28b3bcf0e334b7f7c671abd/src/xenia/gpu/shaders/pixel_formats.xesli).

## Distant geometry investigation (2026-10-15)

Status: unresolved. Daniel reports scenery disappearing at a distance and returning on approach. A reproducible stationary view in the castle kitchen shows a pale opening above the carpeted stairs. The corrected lighting plugin is active; this is separate from the previously fixed dark surfaces.

A local RenderDoc capture of that view was replayed successfully. In the main 1280-wide HDR target, pixels (420,45) and (400,60) receive approximately RGB (4.67,6.41,8.66) from the background draw (VS `8D7098792CE1C780`, PS `ED61745A66F939AC`). The adjacent pixel (450,50) is covered by scene geometry and rejects that background on depth. The pale region is therefore not simply a white texture sample. A scene draw touching the pale region is backface-culled; this alone does not establish an incorrect cull state. The expected covering surface has not yet been identified.

Two live, temporary comparisons left the opening visually unchanged:

- `occlusion_query_enable=false`, using the SDK's fallback sample count of 1000.
- `readback_memexport_fast=false`, using synchronous memexport readback.

Both settings were restored. These stationary tests do not exclude a visibility or streaming decision made earlier during loading, or prove that backface culling is the cause. No speculative rendering change was adopted. Temporary keyboard diagnostic bindings were also restored. Raw captures, exported render targets, replay scripts, save backups, and logs remain local in ignored directories.

Next investigation: identify the expected distant surface and compare its draw submission and geometry between the distant and approached views. Preserve the lighting fix while distinguishing guest visibility/streaming from rasterizer rejection.

### Two-sided geometry diagnostic

Byte-for-byte verification against the source ISO passed for all 286 extracted files (5,965,224,059 bytes). No extracted file was missing, truncated, or different from its source.

A temporary GPU build added a live `fable3_diagnostic_no_face_cull` flag. In a fixed camera view partway up the castle stairs, enabling it removed the narrow bright vertical and horizontal edge around the far doorway. Disabling it brought those edges back; enabling it again removed them. This establishes that face culling affects that visible artifact, but does not yet prove why the intended surface is absent, or that the broader distance-dependent pop-in is fixed. Gameplay comparison is pending.

The diagnostic is reproducible through `patches/rexglue-v0.10.0-face-cull-diagnostic.patch` and `tools/build-gpu-plugin.ps1`. Run `tools/run.ps1 -DiagnosticTwoSidedGeometry` to opt in. In the running game, F4 > GPU > D3D12 > `fable3_diagnostic_no_face_cull` toggles it without moving the camera. Leave "Save to config" alone for temporary comparisons.

The flag defaults to false. It disables polygon face culling while preserving draws that already disable rasterization. Depth, clipping, guest streaming, texture conversion, and lighting behavior are not overridden. Drawing both sides can cover holes with an unintended back surface, change shadows, or cost performance, so this is a diagnostic rather than an adopted rendering fix. The existing lighting correction remains the normal default.

### Static entity distance control (2026-10-15)

The game's `SetStaticEntityDrawDistanceMultiplier` registration points to 0x82333F10, which stores a float at 0x8329EAB8. Routine 0x826873F0 selects that value for static appearances, multiplies their `MaxDrawDistance`, and stores the linear result at appearance + 0x24. Animated/creature branches select different globals. The string `DisableDistanceCulling` inspected elsewhere belongs to audio waveform configuration and is not a graphics control.

`src/visibility.cpp` forwards 0x826873F0 and optionally scales its positive, finite static result. The default scale is 1 (original behavior); `tools/run.ps1 -StaticDrawDistanceMultiplier 2` selects the experiment. It preserves the original routine and its register/return state, excludes the animated branch, preserves nonpositive sentinel distances, and bounds the setting to 1–8. These values are consumed during appearance setup; restart/reload for comparisons.

The native Release build passed. In a save reload with scale 2 and two-sided rendering disabled, bounded runtime observations confirmed actual distances of 64→128, 100→200, and 30→60. Daniel reported **the scenery still disappears at the same distance**. This control is therefore not adopted as a missing-geometry fix or a default. A runtime scan also found many scene primitives with existing clipping distances of 1024, reinforcing the need to distinguish geometry visibility from this entity-distance control. The separate GPU visibility path is under investigation.
