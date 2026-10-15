// Measure the guest frame-submission routine without replacing its behavior.
#include "generated/default/fable_3_pch.h"
#include "frame_stats.h"
#include <rex/cvar.h>
#include <rex/logging/macros.h>
#include <algorithm>
#include <array>
#include <atomic>
#include <chrono>
#include <thread>
#include <windows.h>

REXCVAR_DEFINE_BOOL(fable3_frame_stats, false, "Fable III",
                   "Log aggregate guest submission intervals every 300 frames");
REXCVAR_DEFINE_INT32(fable3_frame_limit, 0, "Fable III",
                    "Host guest-submission limit; 0 leaves original pacing in control")
    .range(0, 240);

namespace {
std::atomic<double> frame_ms{0};
std::atomic<uint64_t> frame_count{0};

void PaceFrame() {
  using Clock = std::chrono::steady_clock;
  struct Timer {
    HANDLE handle = CreateWaitableTimerExW(nullptr, nullptr, CREATE_WAITABLE_TIMER_HIGH_RESOLUTION,
                                          TIMER_MODIFY_STATE | SYNCHRONIZE);
    ~Timer() { if (handle) CloseHandle(handle); }
  };
  thread_local Timer timer;
  thread_local auto deadline = Clock::time_point{};
  thread_local int previous_limit = 0;
  const int limit = REXCVAR_GET(fable3_frame_limit);
  if (limit <= 0) { deadline = {}; previous_limit = 0; return; }
  const auto period = std::chrono::duration_cast<Clock::duration>(std::chrono::duration<double>(1.0 / limit));
  const auto now = Clock::now();
  if (deadline == Clock::time_point{} || limit != previous_limit || now > deadline + period) {
    deadline = now;
  }
  if (now < deadline) {
    const auto remaining = deadline - now;
    LARGE_INTEGER due;
    due.QuadPart = -std::max<int64_t>(1, std::chrono::duration_cast<std::chrono::nanoseconds>(remaining).count() / 100);
    if (timer.handle && SetWaitableTimer(timer.handle, &due, 0, nullptr, nullptr, FALSE)) {
      WaitForSingleObject(timer.handle, INFINITE);
    } else {
      std::this_thread::sleep_until(deadline);
    }
  }
  deadline += period;
  previous_limit = limit;
}
}

rex::ui::FrameStats Fable3FrameStats() {
  const double ms = frame_ms.load(std::memory_order_relaxed);
  return {ms, ms > 0 ? 1000.0 / ms : 0, frame_count.load(std::memory_order_relaxed)};
}

REX_EXTERN(__imp__sub_82D27AD0);
REX_EXTERN(sub_82D27AD0) {
  using Clock = std::chrono::steady_clock;
  PaceFrame();
  // This routine runs on the rendering thread; keep samples local to that thread.
  thread_local auto previous = Clock::time_point{};
  thread_local std::array<double, 300> intervals{};
  thread_local size_t count = 0;
  const auto now = Clock::now();
  if (previous != Clock::time_point{}) {
    const double ms = std::chrono::duration<double, std::milli>(now - previous).count();
    frame_ms.store(ms, std::memory_order_relaxed);
    if (REXCVAR_GET(fable3_frame_stats)) {
      intervals[count++] = ms;
      if (count == intervals.size()) {
        auto sorted = intervals;
        std::sort(sorted.begin(), sorted.end());
        double total = 0;
        size_t over_50ms = 0;
        for (double value : intervals) { total += value; over_50ms += value > 50.0; }
        REXSYS_INFO("[frame-pacing] guest submissions: avg={:.2f}ms p50={:.2f}ms p95={:.2f}ms p99={:.2f}ms max={:.2f}ms >50ms={}/300",
                    total / sorted.size(), sorted[149], sorted[284], sorted[296], sorted.back(), over_50ms);
        count = 0;
      }
    } else {
      count = 0;
    }
  }
  previous = now;
  frame_count.fetch_add(1, std::memory_order_relaxed);
  __imp__sub_82D27AD0(ctx, base);
}
