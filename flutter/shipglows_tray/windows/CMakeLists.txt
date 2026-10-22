cmake_minimum_required(VERSION 3.14)
set(PROJECT_NAME "shipglows_tray")
project(${PROJECT_NAME} LANGUAGES CXX)

# This value is used when generating builds using this plugin, so it must
# not be changed.
set(PLUGIN_NAME "shipglows_tray_plugin")

add_library(${PLUGIN_NAME} SHARED
  "shipglows_tray_plugin.cpp"
  "tray_host.cpp"
  "tray_menu.cpp"
  "single_instance.cpp"
)
apply_standard_settings(${PLUGIN_NAME})
set_target_properties(${PLUGIN_NAME} PROPERTIES CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE
  FLUTTER_PLUGIN_IMPL SHIPGLOWS_TRAY_IMPL NOMINMAX)
# Runners include <shipglows_tray/single_instance.h> from wWinMain.
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin
  shell32.lib version.lib shcore.lib)

set(shipglows_tray_bundled_libraries
  ""
  PARENT_SCOPE
)
