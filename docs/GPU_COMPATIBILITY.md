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
