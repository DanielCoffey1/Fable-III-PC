#include "generated/default/fable_3_pch.h"
#include <rex/cvar.h>
#include <rex/logging/macros.h>
#include <atomic>
#include <bit>
#include <cmath>

REXCVAR_DEFINE_DOUBLE(fable3_static_draw_distance_multiplier, 1.0, "Fable III",
                     "Experimental static-entity draw distance scale; 1 preserves the original")
    .range(1.0, 8.0);

// USA/Europe XEX: SetStaticEntityDrawDistanceMultiplier (82333F10) writes
// 8329EAB8. This routine selects that scale for static appearances, multiplies
// their MaxDrawDistance, and stores the linear distance at appearance + 24.
// Forward the original calculation, then scale only its static result. Keep
// nonpositive sentinel values and animated/creature distances unchanged.
REX_EXTERN(__imp__sub_826873F0);
REX_EXTERN(sub_826873F0) {
  const uint32_t appearance = ctx.r3.u32;
  __imp__sub_826873F0(ctx, base);
  const double scale = REXCVAR_GET(fable3_static_draw_distance_multiplier);
  if (scale == 1.0) return;
  const uint32_t entity = REX_LOAD_U32(appearance + 4);
  if (REX_LOAD_U64(entity + 0x28) & 0x40) return;
  const float original = std::bit_cast<float>(REX_LOAD_U32(appearance + 0x24));
  const float extended = float(double(original) * scale);
  if (!(original > 0.0f) || !std::isfinite(original) || !std::isfinite(extended)) return;
  REX_STORE_U32(appearance + 0x24, std::bit_cast<uint32_t>(extended));
  static std::atomic<uint32_t> observations{0};
  if (observations.fetch_add(1, std::memory_order_relaxed) < 32) {
    REXSYS_INFO("[visibility-distance] appearance=0x{:08X} original={} extended={} scale={}",
                appearance, original, extended, scale);
  }
}

