// fable_3 - ReXGlue Recompiled Project

#include "generated/default/fable_3_init.h"

#include "fable_3_app.h"

REXCVAR_DEFINE_STRING(fable3_gpu_backend, "any", "Fable III", "GPU backend for rendering comparisons")
    .allowed({"any", "d3d12", "vulkan"});

REX_DEFINE_APP(fable_3, Fable3App::Create)
