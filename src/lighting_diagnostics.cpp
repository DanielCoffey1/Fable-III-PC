// Opt-in, bounded observations of the original lightmap loader.
#include "generated/default/fable_3_pch.h"
#include <rex/cvar.h>
#include <rex/logging/macros.h>
#include <windows.h>
#include <atomic>
#include <string>
#include "frame_stats.h"

REXCVAR_DEFINE_BOOL(fable3_lighting_diagnostics, false, "Fable III",
                   "Log bounded lightmap load observations without modifying guest state");
REXCVAR_DEFINE_INT32(fable3_capture_lightmap_region, -1, "Fable III",
                    "With RenderDoc attached, request a capture when this lightmap region registers; -1 disables")
    .range(-1, 65535);

namespace {
bool Readable(const uint8_t* pointer, size_t size) {
  MEMORY_BASIC_INFORMATION info{};
  if (!VirtualQuery(pointer, &info, sizeof(info)) || info.State != MEM_COMMIT ||
      (info.Protect & (PAGE_NOACCESS | PAGE_GUARD))) return false;
  const auto end = reinterpret_cast<uintptr_t>(info.BaseAddress) + info.RegionSize;
  return reinterpret_cast<uintptr_t>(pointer) <= end &&
         size <= end - reinterpret_cast<uintptr_t>(pointer);
}

uint32_t Word(uint8_t* base, uint32_t address) {
  if (!address || address > UINT32_MAX - 3 || !Readable(base + uint64_t(address), 4)) return 0;
  const auto* p = base + uint64_t(address);
  return (uint32_t(p[0]) << 24) | (uint32_t(p[1]) << 16) |
         (uint32_t(p[2]) << 8) | uint32_t(p[3]);
}

std::string Filename(uint8_t* base, uint32_t object) {
  if (object > UINT32_MAX - 4) return "<invalid>";
  const uint32_t reference = Word(base, object + 4);
  const uint32_t text = Word(base, reference);
  std::string result;
  for (uint32_t i = 0; text && i < 256 && text <= UINT32_MAX - i; ++i) {
    const auto* p = base + uint64_t(text) + i;
    if (!Readable(p, 1)) return "<unreadable>";
    if (!*p) return result;
    if (*p < 32 || *p > 126) return "<binary>";
    result.push_back(char(*p));
  }
  return result.empty() ? "<null>" : result + "...";
}

std::atomic<uint32_t> loads{0};
std::atomic<uint32_t> registrations{0};
std::atomic<bool> region_capture_requested{false};
}  // namespace

REX_EXTERN(__imp__sub_82CC2620);
REX_EXTERN(sub_82CC2620) {
  const uint32_t object = ctx.r3.u32;
  const bool observe = REXCVAR_GET(fable3_lighting_diagnostics) &&
                       loads.fetch_add(1, std::memory_order_relaxed) < 64;
  if (observe) {
    REXSYS_INFO("[lighting-load] begin object=0x{:08X} file={}", object, Filename(base, object));
  }
  __imp__sub_82CC2620(ctx, base);
  if (observe && object <= UINT32_MAX - 0x50) {
    REXSYS_INFO("[lighting-load] end object=0x{:08X} field10={} field20={} version50=0x{:08X}",
                object, Word(base, object + 0x10), Word(base, object + 0x20),
                Word(base, object + 0x50));
  }
}

REX_EXTERN(__imp__sub_82CC8870);
REX_EXTERN(sub_82CC8870) {
  const uint32_t region = ctx.r4.u32;
  if (REXCVAR_GET(fable3_lighting_diagnostics) &&
      registrations.fetch_add(1, std::memory_order_relaxed) < 64) {
    REXSYS_INFO("[lighting-register] manager=0x{:08X} region={} record=0x{:08X}",
                ctx.r3.u32, ctx.r4.u32, ctx.r5.u32);
  }
  __imp__sub_82CC8870(ctx, base);
  if (REXCVAR_GET(fable3_capture_lightmap_region) == int32_t(region) &&
      !region_capture_requested.exchange(true, std::memory_order_relaxed)) {
    REXSYS_INFO("[lighting-capture] Requesting capture after region {} registers", region);
    RequestFable3Capture();
  }
}
