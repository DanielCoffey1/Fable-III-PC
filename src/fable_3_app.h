// fable_3 - ReXGlue Recompiled Project
//
// Customize your app by overriding virtual hooks from rex::ReXApp.

#pragma once

#include <rex/rex_app.h>
#include <rex/system/gpu_plugin.h>
#include <rex/logging/macros.h>
#include <rex/ui/keybinds.h>
#include "frame_stats.h"

REXCVAR_DECLARE(std::string, fable3_gpu_backend);

class Fable3App : public rex::ReXApp {
 public:
  using rex::ReXApp::ReXApp;

  static std::unique_ptr<rex::ui::WindowedApp> Create(
      rex::ui::WindowedAppContext& ctx) {
    return std::unique_ptr<Fable3App>(new Fable3App(ctx, "fable_3",
        PPCImageConfig));
  }

  // Override virtual hooks for customization:
  // void OnPostInitLogging() override {}
  void OnPreSetup(rex::RuntimeConfig& config) override {
    if (config.gpu_plugin.empty()) config.gpu_plugin = "xenos";
    const auto backend = REXCVAR_GET(fable3_gpu_backend);
    if (backend != "any") {
      config.graphics = rex::system::LoadGpuPlugin(config.gpu_plugin, backend);
      if (!config.graphics) throw std::runtime_error("Requested Fable III GPU backend is unavailable");
    }
  }
  void OnPostSetup() override {
    SetGuestFrameStats(Fable3FrameStats);
    REXSYS_INFO("[render-config] target={} readback={} fuzzy_alpha={} gamma_unorm16={} vsync={} frame_limit={}",
        rex::cvar::GetFlagByName("render_target_path_d3d12"),
        rex::cvar::GetFlagByName("readback_resolve"),
        rex::cvar::GetFlagByName("use_fuzzy_alpha_epsilon"),
        rex::cvar::GetFlagByName("gamma_render_target_as_unorm16"),
        rex::cvar::GetFlagByName("vsync"),
        rex::cvar::GetFlagByName("fable3_frame_limit"));
  }
  void OnCreateDialogs(rex::ui::ImGuiDrawer*) override {
    rex::ui::RegisterBind("bind_fable3_capture", "F10", "Capture game frames with RenderDoc", RequestFable3Capture);
  }
  void OnShutdown() override { rex::ui::UnregisterBind("bind_fable3_capture"); }
  // void OnLoadXexImage(std::string& xex_image) override {}
  // void OnPostLoadXexImage() override {}
  // void OnPostSetup() override {}
  // void OnCreateDialogs(rex::ui::ImGuiDrawer* drawer) override {}
  // std::unique_ptr<rex::ui::ImGuiDialog> CreateAchievementsOverlay() override;
  // std::unique_ptr<rex::ui::AchievementNotificationDialog>
  // CreateAchievementNotificationDialog() override;
  // void OnShutdown() override {}
  // void OnConfigurePaths(rex::PathConfig& paths) override {}
};
