# fable_3 - ReXGlue Recompiled Project
#
# SDK boilerplate lives in generated/rexglue.cmake.

cmake_minimum_required(VERSION 3.25)
project(fable_3 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

include(generated/rexglue.cmake)

# Sources
set(FABLE3_SOURCES
    src/main.cpp
    src/startup_diagnostics.cpp
    src/kernel_compat.cpp
)

if(WIN32)
    add_executable(fable_3 WIN32 ${FABLE3_SOURCES})
else()
    add_executable(fable_3 ${FABLE3_SOURCES})
endif()

rexglue_setup_target(fable_3 GPU_PLUGINS xenos)

if(WIN32)
    # Preserve guest-code line tables for diagnosing startup faults.
    target_link_options(fable_3 PRIVATE LINKER:/DEBUG:FULL LINKER:/INCREMENTAL:NO)
endif()
