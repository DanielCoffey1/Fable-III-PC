cmake_minimum_required(VERSION 3.25)
project(fable3_gpu LANGUAGES C CXX)
set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
find_package(rexglue 0.10.0 EXACT CONFIG REQUIRED)
if(NOT FABLE3_GPU_SDK_SOURCE)
    message(FATAL_ERROR "Set FABLE3_GPU_SDK_SOURCE to the patched, pinned SDK source")
endif()
file(TO_CMAKE_PATH "${FABLE3_GPU_SDK_SOURCE}" FABLE3_GPU_SDK_SOURCE)

# Same D3D12-only plugin sources as ReXGlue v0.10.0. Link the installed
# runtime rather than recompiling runtime objects and duplicating global state.
set(gpu_sources
    plugin_main.cpp flags.cpp register_file.cpp registers.cpp sampler_info.cpp
    graphics_system.cpp command_processor.cpp packet_disassembler.cpp
    primitive_processor.cpp shared_memory.cpp format/ucode.cpp
    util/draw_extent_estimator.cpp util/draw.cpp
    pipeline/render_target/cache.cpp pipeline/texture/cache.cpp
    pipeline/shader/shader.cpp pipeline/shader/interpreter.cpp
    pipeline/shader/translator.cpp pipeline/shader/translator_disasm.cpp
    pipeline/shader/dxbc.cpp pipeline/shader/dxbc_translator.cpp
    pipeline/shader/dxbc_translator_alu.cpp pipeline/shader/dxbc_translator_fetch.cpp
    pipeline/shader/dxbc_translator_memexport.cpp pipeline/shader/dxbc_translator_om.cpp
    d3d12/graphics_system.cpp d3d12/command_processor.cpp
    d3d12/primitive_processor.cpp d3d12/render_target_cache.cpp
    d3d12/shader.cpp d3d12/shared_memory.cpp d3d12/texture_cache.cpp
    d3d12/deferred_command_list.cpp d3d12/pipeline_cache.cpp
)
list(TRANSFORM gpu_sources PREPEND "${FABLE3_GPU_SDK_SOURCE}/src/graphics/")
add_library(fable3_gpu SHARED ${gpu_sources}
    "${FABLE3_GPU_SDK_SOURCE}/thirdparty/dxbc/DXBCChecksum.cpp")
set_target_properties(fable3_gpu PROPERTIES OUTPUT_NAME rexgpu-fable3)
target_include_directories(fable3_gpu PRIVATE "${FABLE3_GPU_SDK_SOURCE}")
target_compile_options(fable3_gpu PRIVATE -msse4.1 -Wno-unused-variable)
target_link_libraries(fable3_gpu PRIVATE rex::runtime rex::xxhash rex::renderdoc d3d12 dxgi dxguid)
include("${FABLE3_GPU_SDK_SOURCE}/cmake/rex_pch.cmake")
rex_target_pch(fable3_gpu
    <mutex> <unordered_map> <rex/math.h> <rex/memory.h> <rex/thread/mutex.h>
    <rex/system/xmemory.h> <rex/graphics/xenos.h> <rex/graphics/registers.h>
    <rex/graphics/format/ucode.h> <rex/graphics/pipeline/shader/shader.h>)
set_source_files_properties("${FABLE3_GPU_SDK_SOURCE}/thirdparty/dxbc/DXBCChecksum.cpp"
    PROPERTIES SKIP_PRECOMPILE_HEADERS ON)
