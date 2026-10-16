# Fable III PC

Daniel's standalone Fable III static recompilation research project, initialized with [ReXGlue SDK v0.10.0](https://github.com/rexglue/rexglue-sdk/releases/tag/v0.10.0).

**Status: gameplay, controller input, audio, saving, and reloading have been exercised locally.** Daniel reported a session without crashes and confirmed smoother 60 FPS pacing. The custom GPU plugin restored the dark castle walls and floors in the tested save, confirmed visually and by Daniel. A conservative mesh-occlusion workaround also restored disappearing scenery in the tested castle area; disabling asynchronous draw skipping also removed the reported motion flashes. Full-game compatibility remains untested. This is a separate project from Fable-II-PC. Fable II's game-specific function mappings and patches must not be applied to Fable III.

## Local content

Supply your own game files under `game/`: `default.xex` and `data/`. No disc image, game content, extracted executable, or generated game code is included in Git.

The local disc was extracted without modifying the source ISO. It yielded 286 files totaling 5,965,224,059 bytes. See [initial findings](docs/INITIAL_FINDINGS.md) for identifiers and hashes.

## Development

Use the Windows x64 ReXGlue SDK v0.10.0 and its actual CLI help. Older wiki examples use different argument names.

```powershell
rexglue init --project-name fable_3 --xex-path game/default.xex --game-root game --project-root .
rexglue codegen fable_3_manifest.toml
```

The project is already initialized; run codegen after supplying local content. Do not rerun init over custom source changes.

Native compilation requires LLVM/Clang 20+, CMake 3.25+, Ninja, and MSVC/Windows SDK development libraries. Visual Studio Build Tools 2022 is now installed locally; its bundled Clang 19.1.5 configured successfully. The full native Release build succeeds with that installed compiler. The prebuilt SDK does not include a complete Windows C++ toolchain.

Use `tools/build.ps1` to load the installed x64 developer environment, verify the game executable hash, locate the pinned SDK, configure, and build. Use `tools/build.ps1 -ConfigureOnly` to check configuration. The underlying CMake commands are:

```powershell
cmake --preset win-amd64-release
cmake --build --preset win-amd64-release
```

The build helper also builds and stages `rexgpu-fable3.dll` from pinned upstream source and the tracked GPU patches. This requires Git, network access on the first build, and the Windows SDK HLSL compiler. Later builds reuse a hash-checked local cache. To rebuild only the plugin, run `tools/build-gpu-plugin.ps1 -Stage`. See [GPU compatibility details](docs/GPU_COMPATIBILITY.md) for the source revisions, correction, and limits.

Run `tools/run.ps1` to launch the local build in a visible 1280x720 window with corrected castle lighting, the mesh-occlusion workaround, and a 60 FPS host submission cap. `-MeshOcclusionWorkaround:$false` disables the visibility workaround for comparison. `tools/run.ps1 -OriginalGpu` selects the original SDK GPU plugin for comparison; `-Smooth60:$false` restores the original pacing. Shader/pipeline caches are retained between launches. The normal launcher waits for shader pipelines instead of skipping their draws; Daniel confirmed this removed the reported motion flashes. First-time compilation and area loading can still cause pauses. `-SynchronousShaders:$false` restores asynchronous compilation for comparison. No Fable II tick-rate patch is applied to Fable III.

For development, `-FrameStats` logs interval aggregates every 300 guest frame submissions and F3 shows the timing overlay. These are submission measurements, not display-present measurements. Diagnostic rendering options include `-RenderTargetPath rov`, `-ReadbackResolve full`, `-FuzzyAlpha`, `-SrgbRenderTargets`, `-SynchronousMemexport`, and `-Bindful`. They are experiments, not recommended fixes. The pinned Windows GPU plugin includes D3D12 only; `-Backend vulkan` cannot run with that package. Check the startup `[render-config]` line when comparing settings: late-loaded GPU cvars require `--name=value` CLI syntax.

When launched under RenderDoc, F10 captures a short span of game submissions for diagnosing missing rendering. It has no capture effect without RenderDoc already attached. `-CaptureAfterSeconds N` optionally requests a timed startup capture; prefer F10 after the saved scene has loaded. Captures contain game resources and remain local under ignored development folders.

`-LightingDiagnostics` enables bounded, forward-only observations of the original lightmap loader and registration functions (at most 64 observations per hook). `-ShaderIfFlow` tests alternative DXBC control flow; it did not correct the dark castle surfaces and is not a default. The startup log records effective shader-control-flow and memory-export settings. With RenderDoc already attached, `-CaptureLightmapRegion 58 -CaptureMilliseconds 1000` requests one capture after the castle lightmap registers; registration does not guarantee that all atlas generation has completed within that interval.

The build helper also rejects unresolved-branch fatal placeholders in generated C++, which can otherwise compile successfully.

Check `CMakePresets.json` for the generated preset names. Code generation alone is not a playable build: function boundaries, indirect calls, imports, and game-specific runtime behavior may need manual work.

## Credits

ReXGlue provides the scaffold, recompiler, and runtime, building on Xenia and earlier Xbox 360 recompilation work. Upstream dependencies retain their own licenses. Fable III and its game content belong to their respective owners.

## Albion Reborn automated releases

The **Build and publish Albion Reborn** workflow runs on main pushes, manual dispatch, and a 15-minute GitHub schedule. A Windows runner registered only to this private repository builds all three projects in isolated agent checkouts and publishes tested runtime bundles through Albion Reborn's public release feed. Source revisions are recorded in each release. Unchanged sources are skipped; failed builds leave the previous release available. The schedule also detects Fable II and launcher main-branch changes. The build PC must be awake, online, and signed in; the agent reconnects at sign-in through its Startup shortcut.

Local game files, generated guest code, runner credentials, and agent configuration stay outside Git and workflow artifacts. Publishing uses the owner's existing local GitHub CLI authentication. Do not add pull-request triggers or register this runner with a public repository. Use the workflow's `validate_only` manual input to build/test without publishing. Build and packaging checks do not replace gameplay testing. `tools/ci/Start-AlbionAgent.ps1 -ConfigPath <local-json>` reconnects the configured runner manually.
