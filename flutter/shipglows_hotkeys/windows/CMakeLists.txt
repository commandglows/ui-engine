cmake_minimum_required(VERSION 3.14)
set(PROJECT_NAME "shipglows_hotkeys")
project(${PROJECT_NAME} LANGUAGES CXX)

# This value is used when generating builds using this plugin, so it must
# not be changed.
set(PLUGIN_NAME "shipglows_hotkeys_plugin")

add_library(${PLUGIN_NAME} SHARED
  "shipglows_hotkeys_plugin.cpp"
)
apply_standard_settings(${PLUGIN_NAME})
set_target_properties(${PLUGIN_NAME} PROPERTIES CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE
  FLUTTER_PLUGIN_IMPL SHIPGLOWS_HOTKEYS_IMPL NOMINMAX)
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin)

set(shipglows_hotkeys_bundled_libraries
  ""
  PARENT_SCOPE
)
