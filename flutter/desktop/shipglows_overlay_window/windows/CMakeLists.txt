cmake_minimum_required(VERSION 3.14)
set(PROJECT_NAME "shipglows_overlay_window")
project(${PROJECT_NAME} LANGUAGES CXX)

# This value is used when generating builds using this plugin, so it must
# not be changed.
set(PLUGIN_NAME "shipglows_overlay_window_plugin")

# Overlays host their own engine and view, so the plugin also needs the
# app-side wrapper classes (FlutterEngine, FlutterViewController), which
# flutter_wrapper_plugin does not contain.
set(OVERLAY_WRAPPER_ROOT "${CMAKE_SOURCE_DIR}/flutter/ephemeral/cpp_client_wrapper")
set(OVERLAY_WRAPPER_APP_SOURCES
  "${OVERLAY_WRAPPER_ROOT}/flutter_engine.cc"
  "${OVERLAY_WRAPPER_ROOT}/flutter_view_controller.cc"
)
set_source_files_properties(${OVERLAY_WRAPPER_APP_SOURCES} PROPERTIES GENERATED TRUE)

add_library(${PLUGIN_NAME} SHARED
  "shipglows_overlay_window_plugin.cpp"
  "overlay_window_impl.cpp"
  "overlay_store.cpp"
  ${OVERLAY_WRAPPER_APP_SOURCES}
)
apply_standard_settings(${PLUGIN_NAME})
set_target_properties(${PLUGIN_NAME} PROPERTIES CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE
  FLUTTER_PLUGIN_IMPL SHIPGLOWS_OVERLAY_WINDOW_IMPL NOMINMAX)
# Runners include <shipglows_overlay_window/overlay_window.h> to create
# overlays natively.
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin
  dwmapi.lib shell32.lib ole32.lib)

set(shipglows_overlay_window_bundled_libraries
  ""
  PARENT_SCOPE
)
