# Fable III PC

Daniel's standalone Fable III static recompilation research project, initialized with [ReXGlue SDK v0.10.0](https://github.com/rexglue/rexglue-sdk/releases/tag/v0.10.0).

**Status: gameplay, controller input, audio, saving, and reloading have been exercised locally.** Daniel reported a session without crashes, and confirmed smoother movement with the new 60 FPS pacing. Dark/missing surfaces remain unresolved, and full-game compatibility is untested. This is a separate project from Fable-II-PC. Fable II's game-specific function mappings and patches must not be applied to Fable III.

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

Run `tools/run.ps1` to launch the local build in a visible 1280x720 window with the local game files and a 60 FPS host submission cap. `tools/run.ps1 -Smooth60:$false` restores the original pacing. Shader/pipeline caches are retained between launches; first-time compilation and area loading can still cause pauses. No Fable II tick-rate patch is applied to Fable III.

For development, `-FrameStats` logs interval aggregates every 300 guest frame submissions and F3 shows the timing overlay. These are submission measurements, not display-present measurements. Diagnostic rendering options include `-RenderTargetPath rov`, `-ReadbackResolve full`, `-FuzzyAlpha`, `-SrgbRenderTargets`, `-SynchronousMemexport`, `-Bindful`, and `-SynchronousShaders`. They are experiments, not recommended fixes. The pinned Windows GPU plugin includes D3D12 only; `-Backend vulkan` cannot run with that package. Check the startup `[render-config]` line when comparing settings: late-loaded GPU cvars require `--name=value` CLI syntax.

When launched under RenderDoc, F10 captures a short span of game submissions for diagnosing missing rendering. It has no capture effect without RenderDoc already attached. `-CaptureAfterSeconds N` optionally requests a timed startup capture; prefer F10 after the saved scene has loaded. Captures contain game resources and remain local under ignored development folders.

The build helper also rejects unresolved-branch fatal placeholders in generated C++, which can otherwise compile successfully.

Check `CMakePresets.json` for the generated preset names. Code generation alone is not a playable build: function boundaries, indirect calls, imports, and game-specific runtime behavior may need manual work.

## Credits

ReXGlue provides the scaffold, recompiler, and runtime, building on Xenia and earlier Xbox 360 recompilation work. Upstream dependencies retain their own licenses. Fable III and its game content belong to their respective owners.
