cmake_minimum_required(VERSION 3.22)
project(CADNC VERSION 0.1.0 LANGUAGES CXX)

# ── C++ Standard ──────────────────────────────────────────────────────────────
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

# ── Build Options ─────────────────────────────────────────────────────────────
option(CADNC_ENABLE_ASAN    "Enable AddressSanitizer"              OFF)
option(CADNC_ENABLE_TSAN    "Enable ThreadSanitizer"               OFF)
option(CADNC_ENABLE_UBSAN   "Enable UndefinedBehaviorSanitizer"    OFF)
option(CADNC_ENABLE_COVERAGE "Enable code coverage (gcov/lcov)"    OFF)
option(CADNC_BUILD_TESTS    "Build unit tests"                     ON)

# ── Sanitizer Configuration ───────────────────────────────────────────────────
if(CADNC_ENABLE_ASAN)
    add_compile_options(-fsanitize=address -fno-omit-frame-pointer)
    add_link_options(-fsanitize=address)
endif()
if(CADNC_ENABLE_TSAN)
    add_compile_options(-fsanitize=thread)
    add_link_options(-fsanitize=thread)
endif()
if(CADNC_ENABLE_UBSAN)
    add_compile_options(-fsanitize=undefined)
    add_link_options(-fsanitize=undefined)
endif()
if(CADNC_ENABLE_COVERAGE)
    add_compile_options(--coverage -fprofile-arcs -ftest-coverage)
    add_link_options(--coverage)
endif()

# ── Find Dependencies ─────────────────────────────────────────────────────────
# Qt6
find_package(Qt6 REQUIRED COMPONENTS Core Gui Quick Qml Widgets OpenGL OpenGLWidgets Svg Xml)

# OpenCASCADE
if(UNIX AND NOT APPLE)
    set(OpenCASCADE_DIR "/usr/lib/x86_64-linux-gnu/cmake/opencascade"
        CACHE PATH "OpenCASCADE CMake config path")
endif()
find_package(OpenCASCADE REQUIRED)

# Python3 (required by FreeCAD modules)
find_package(Python3 REQUIRED COMPONENTS Development Interpreter)

# Boost
find_package(Boost REQUIRED)

# Eigen3
find_package(Eigen3 REQUIRED)

# XercesC (required by FreeCAD Base)
find_package(XercesC REQUIRED)

# ZLIB
find_package(ZLIB REQUIRED)

# ICU (optional, for FreeCAD Base)
find_package(ICU COMPONENTS uc data)

# OpenGL
find_package(OpenGL REQUIRED)

# ── Version Header ────────────────────────────────────────────────────────────
configure_file(
    "${CMAKE_SOURCE_DIR}/app/AppVersion.h.in"
    "${CMAKE_BINARY_DIR}/generated/AppVersion.h"
)
include_directories(${CMAKE_BINARY_DIR}/generated)

# ── FreeCAD Backend Modules ───────────────────────────────────────────────────
# These are built as shared libraries providing CAD backend functionality.
# TODO: Add freecad/CMakeLists.txt to build Base, App, Part, Sketcher, PartDesign
# add_subdirectory(freecad)

# ── Include Directories ───────────────────────────────────────────────────────
include_directories(
    ${OpenCASCADE_INCLUDE_DIR}
    ${Python3_INCLUDE_DIRS}
    ${Boost_INCLUDE_DIRS}
    ${EIGEN3_INCLUDE_DIR}
    ${XercesC_INCLUDE_DIRS}
    adapter/inc
    cam/inc
    nesting/inc
    util/inc
    viewport/inc
    ui/src
)

# ── Adapter Library ───────────────────────────────────────────────────────────
file(GLOB ADAPTER_HEADERS adapter/inc/*.h)
file(GLOB ADAPTER_SOURCES adapter/src/*.cpp)

# ── CAM Module ────────────────────────────────────────────────────────────────
file(GLOB CAM_HEADERS cam/inc/*.h)
file(GLOB CAM_SOURCES cam/src/*.cpp)

# ── Nesting Module ────────────────────────────────────────────────────────────
file(GLOB NESTING_HEADERS nesting/inc/*.h)
file(GLOB NESTING_SOURCES nesting/src/*.cpp)

# ── Util Module ───────────────────────────────────────────────────────────────
file(GLOB UTIL_HEADERS util/inc/*.h)

# ── Viewport Module ───────────────────────────────────────────────────────────
file(GLOB VIEWPORT_HEADERS viewport/inc/*.h)
file(GLOB VIEWPORT_SOURCES viewport/src/*.cpp)

# ── UI Bridge Sources ─────────────────────────────────────────────────────────
file(GLOB UI_SOURCES ui/src/*.cpp ui/src/*.h)

# ── Main Application ─────────────────────────────────────────────────────────
add_executable(cadnc
    app/main.cpp
    ${ADAPTER_HEADERS} ${ADAPTER_SOURCES}
    ${CAM_HEADERS} ${CAM_SOURCES}
    ${NESTING_HEADERS} ${NESTING_SOURCES}
    ${UTIL_HEADERS}
    ${VIEWPORT_HEADERS} ${VIEWPORT_SOURCES}
    ${UI_SOURCES}
)

set_target_properties(cadnc PROPERTIES OUTPUT_NAME cadnc)

target_link_libraries(cadnc PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Quick
    Qt6::Qml
    Qt6::Widgets
    Qt6::OpenGL
    Qt6::OpenGLWidgets
    Qt6::Svg
    Qt6::Xml
    OpenGL::GL
    # TODO: Link FreeCAD backend libraries when built
    # FreeCADBase FreeCADApp Part Sketcher PartDesign
)

# ── QML Resources ─────────────────────────────────────────────────────────────
file(GLOB QML_FILES ui/qml/*.qml ui/qml/components/*.qml)
file(GLOB ICON_FILES
    resources/icons/*.svg
    resources/icons/constraint/*.svg
    resources/icons/part/*.svg
    resources/icons/cam/*.svg
    resources/icons/nesting/*.svg
    resources/icons/sketch/*.svg
    resources/icons/quickaccess/*.svg
)

qt_add_resources(cadnc "qml_resources"
    PREFIX "/"
    BASE "${CMAKE_SOURCE_DIR}/ui"
    FILES ${QML_FILES}
)

qt_add_resources(cadnc "icon_resources"
    PREFIX "/"
    BASE "${CMAKE_SOURCE_DIR}"
    FILES ${ICON_FILES}
)

# ── Tests ─────────────────────────────────────────────────────────────────────
if(CADNC_BUILD_TESTS)
    enable_testing()
    # TODO: Add test subdirectories
    # add_subdirectory(tests)
endif()

# ── Install Rules ─────────────────────────────────────────────────────────────
install(TARGETS cadnc DESTINATION bin)
