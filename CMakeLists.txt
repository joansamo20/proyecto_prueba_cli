cmake_minimum_required(VERSION 3.20)
project(gmn_native LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(GODOTCPP_API_VERSION "4.7" CACHE STRING "" FORCE)
set(GODOTCPP_TARGET "editor" CACHE STRING "" FORCE)
set(GODOTCPP_PRECISION "single" CACHE STRING "" FORCE)
set(GODOTCPP_BUILD_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/build_profile.json" CACHE FILEPATH "" FORCE)

add_subdirectory(godot-cpp)

add_library(gmn_native SHARED
    src/gmn_native.cpp
    src/register_types.cpp
)

target_include_directories(gmn_native PRIVATE src)
target_link_libraries(gmn_native PRIVATE godot::cpp user32)
target_compile_definitions(gmn_native PRIVATE WIN32_LEAN_AND_MEAN NOMINMAX)

set_target_properties(gmn_native PROPERTIES
    PREFIX ""
    OUTPUT_NAME "gmn_native"
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/out"
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/out"
)

foreach(CONFIG Debug Release RelWithDebInfo MinSizeRel)
    string(TOUPPER "${CONFIG}" CONFIG_UPPER)
    set_target_properties(gmn_native PROPERTIES
        RUNTIME_OUTPUT_DIRECTORY_${CONFIG_UPPER} "${CMAKE_BINARY_DIR}/out"
        LIBRARY_OUTPUT_DIRECTORY_${CONFIG_UPPER} "${CMAKE_BINARY_DIR}/out"
    )
endforeach()
