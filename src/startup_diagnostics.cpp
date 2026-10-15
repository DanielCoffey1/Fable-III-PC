// Forward-only diagnostics: retain the original guest error behavior.
#include "generated/default/fable_3_pch.h"
#include <rex/logging/macros.h>
#include <windows.h>
#include <string>

namespace {
std::string GuestText(uint8_t* base, uint32_t address) {
  if (!address) return "<null>";
  std::string result;
  for (uint32_t i = 0; i < 384; ++i) {
    const auto* p = base + uint64_t(address) + i;
    MEMORY_BASIC_INFORMATION info{};
    if (!VirtualQuery(p, &info, sizeof(info)) || info.State != MEM_COMMIT ||
        (info.Protect & (PAGE_NOACCESS | PAGE_GUARD))) return "<unreadable>";
    const unsigned char value = *p;
    if (!value) return result;
    if (value < 0x20 && value != '\n' && value != '\t') return "<binary>";
    result.push_back(static_cast<char>(value));
  }
  return result + "...";
}
}  // namespace

REX_EXTERN(__imp__sub_822D1318);
REX_EXTERN(sub_822D1318) {
  REXSYS_ERROR("[guest-error] state=0x{:08X} lr=0x{:08X} format={} arg1={} arg2={}",
               ctx.r3.u32, uint32_t(ctx.lr), GuestText(base, ctx.r4.u32),
               GuestText(base, ctx.r5.u32), GuestText(base, ctx.r6.u32));
  __imp__sub_822D1318(ctx, base);
}
