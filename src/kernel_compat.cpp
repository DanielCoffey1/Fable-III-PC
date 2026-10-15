// Local compatibility for the SDK's unimplemented title-ID query.
#include "generated/default/fable_3_pch.h"
#include <rex/system/kernel_state.h>
#include <rex/logging/macros.h>
#include <atomic>

REX_EXTERN(__imp__XNetLogonGetTitleID) {
  const uint32_t service = ctx.r3.u32;
  auto* state = REX_KERNEL_STATE();
  const uint32_t title = state ? state->title_id() : 0;
  ctx.r3.u64 = title;
  static std::atomic_flag reported = ATOMIC_FLAG_INIT;
  if (!reported.test_and_set()) {
    REXSYS_INFO("[compat] XNetLogonGetTitleID(service={}) -> 0x{:08X}", service, title);
  }
}
