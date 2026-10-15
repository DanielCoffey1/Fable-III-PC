# Fable III PC

Daniel's standalone Fable III static recompilation research project, initialized with [ReXGlue SDK v0.10.0](https://github.com/rexglue/rexglue-sdk/releases/tag/v0.10.0).

**Status: branch validation passes; native build in progress; not yet a playable PC port.** This is a separate project from Fable-II-PC. Fable II's game-specific function mappings and patches must not be applied to Fable III.

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

Native compilation requires LLVM/Clang 20+, CMake 3.25+, Ninja, and MSVC/Windows SDK development libraries. Visual Studio Build Tools 2022 is now installed locally; its bundled Clang 19.1.5 configured successfully. Native compilation is being checked. The prebuilt SDK does not include a complete Windows C++ toolchain.

Use `tools/build.ps1` to load the installed x64 developer environment, verify the game executable hash, locate the pinned SDK, configure, and build. Use `tools/build.ps1 -ConfigureOnly` to check configuration. The underlying CMake commands are:

```powershell
cmake --preset win-amd64-release
cmake --build --preset win-amd64-release
```

Check `CMakePresets.json` for the generated preset names. Code generation alone is not a playable build: function boundaries, indirect calls, imports, and game-specific runtime behavior may need manual work.

## Credits

ReXGlue provides the scaffold, recompiler, and runtime, building on Xenia and earlier Xbox 360 recompilation work. Upstream dependencies retain their own licenses. Fable III and its game content belong to their respective owners.
