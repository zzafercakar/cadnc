cmake_minimum_required(VERSION 3.22)
project(CADNC VERSION 0.1.0 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

option(CADNC_ENABLE_ASAN "Enable AddressSanitizer" OFF)
option(CADNC_ENABLE_TSAN "Enable ThreadSanitizer" OFF)
option(CADNC_ENABLE_UBSAN "Enable UndefinedBehaviorSanitizer" OFF)
option(CADNC_ENABLE_COVERAGE "Enable code coverage (gcov/lcov)" OFF)
option(CADNC_BUILD_TESTS "Build unit tests" ON)
option(CADNC_ENABLE_FREECAD_BACKEND "Enable FreeCAD backend integration" ON)

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

find_package(Qt6 6.2 REQUIRED COMPONENTS Core Gui Quick Qml QuickControls2 Widgets OpenGL OpenGLWidgets Svg Xml)
find_package(OpenGL REQUIRED)

if(UNIX AND NOT APPLE AND NOT OpenCASCADE_DIR AND EXISTS "/usr/lib/x86_64-linux-gnu/cmake/opencascade")
    set(OpenCASCADE_DIR "/usr/lib/x86_64-linux-gnu/cmake/opencascade"
        CACHE PATH "OpenCASCADE CMake config path" FORCE)
endif()
find_package(OpenCASCADE REQUIRED COMPONENTS
    FoundationClasses
    ModelingData
    ModelingAlgorithms
    Visualization
    ApplicationFramework
    DataExchange
)

if(CADNC_ENABLE_FREECAD_BACKEND)
    include(FetchContent)

    find_package(Python3 REQUIRED COMPONENTS Development Interpreter)
    find_package(ZLIB REQUIRED)

    # --- Boost (header-only is enough for FreeCAD Base/App) ---
    # Boost — need header-only + filesystem, program_options, regex components
    find_package(Boost REQUIRED COMPONENTS filesystem program_options regex)

    # --- XercesC ---
    find_package(XercesC QUIET)
    if(NOT XercesC_FOUND)
        message(STATUS "XercesC not found — fetching via FetchContent")
        FetchContent_Declare(
            XercesC
            GIT_REPOSITORY https://github.com/apache/xerces-c.git
            GIT_TAG        v3.2.5
            GIT_SHALLOW    TRUE
        )
        set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
        FetchContent_MakeAvailable(XercesC)
        set(XercesC_INCLUDE_DIRS "${xercesc_SOURCE_DIR}/src" "${xercesc_BINARY_DIR}/src")
        set(XercesC_LIBRARIES xerces-c)
    endif()

    # --- Eigen3 (header-only) ---
    find_package(Eigen3 QUIET)
    if(NOT Eigen3_FOUND)
        message(STATUS "Eigen3 not found — fetching via FetchContent")
        FetchContent_Declare(
            Eigen3
            GIT_REPOSITORY https://gitlab.com/libeigen/eigen.git
            GIT_TAG        3.4.0
            GIT_SHALLOW    TRUE
        )
        set(EIGEN_BUILD_DOC OFF CACHE BOOL "" FORCE)
        set(BUILD_TESTING OFF CACHE BOOL "" FORCE)
        set(EIGEN_BUILD_PKGCONFIG OFF CACHE BOOL "" FORCE)
        FetchContent_MakeAvailable(Eigen3)
    endif()

    # --- ICU (optional) ---
    find_package(ICU COMPONENTS uc data)

    # --- yaml-cpp (required by Material module) ---
    find_package(yaml-cpp QUIET)
    if(NOT yaml-cpp_FOUND)
        message(STATUS "yaml-cpp not found — fetching via FetchContent")
        FetchContent_Declare(
            yaml-cpp
            GIT_REPOSITORY https://github.com/jbeder/yaml-cpp.git
            GIT_TAG        0.8.0
            GIT_SHALLOW    TRUE
        )
        set(YAML_CPP_BUILD_TESTS OFF CACHE BOOL "" FORCE)
        set(YAML_CPP_BUILD_TOOLS OFF CACHE BOOL "" FORCE)
        FetchContent_MakeAvailable(yaml-cpp)
    endif()

    # --- Freetype (optional, for Part text features) ---
    find_package(Freetype QUIET)

    # FreeCAD modules — builds FreeCADBase, FreeCADApp, Part, Sketcher, PartDesign
    add_subdirectory(freecad)
endif()

configure_file(
    "${CMAKE_SOURCE_DIR}/app/AppVersion.h.in"
    "${CMAKE_BINARY_DIR}/generated/AppVersion.h"
    @ONLY
)

file(GLOB ADAPTER_HEADERS CONFIGURE_DEPENDS adapter/inc/*.h)
file(GLOB ADAPTER_SOURCES CONFIGURE_DEPENDS adapter/src/*.cpp)
file(GLOB CAM_HEADERS CONFIGURE_DEPENDS cam/inc/*.h)
file(GLOB CAM_SOURCES CONFIGURE_DEPENDS cam/src/*.cpp)
file(GLOB NESTING_HEADERS CONFIGURE_DEPENDS nesting/inc/*.h)
file(GLOB NESTING_SOURCES CONFIGURE_DEPENDS nesting/src/*.cpp)
file(GLOB UTIL_HEADERS CONFIGURE_DEPENDS util/inc/*.h)
file(GLOB UTIL_SOURCES CONFIGURE_DEPENDS util/src/*.cpp)
file(GLOB VIEWPORT_HEADERS CONFIGURE_DEPENDS viewport/inc/*.h)
file(GLOB VIEWPORT_SOURCES CONFIGURE_DEPENDS viewport/src/*.cpp)
file(GLOB UI_SOURCES CONFIGURE_DEPENDS ui/src/*.cpp ui/src/*.h)
file(GLOB QML_FILES CONFIGURE_DEPENDS
    ui/qml/*.qml
    ui/qml/components/*.qml
    ui/qml/panels/*.qml
    ui/qml/toolbars/*.qml
    ui/qml/popups/*.qml
    ui/qml/*.js
)
file(GLOB ICON_FILES CONFIGURE_DEPENDS
    resources/icons/*.svg
    resources/icons/constraint/*.svg
    resources/icons/part/*.svg
    resources/icons/cam/*.svg
    resources/icons/nesting/*.svg
    resources/icons/sketch/*.svg
    resources/icons/quickaccess/*.svg
)

add_executable(cadnc
    app/main.cpp
    ${CAM_HEADERS}
    ${CAM_SOURCES}
    ${NESTING_HEADERS}
    ${NESTING_SOURCES}
    ${UTIL_HEADERS}
    ${UTIL_SOURCES}
    ${VIEWPORT_HEADERS}
    ${VIEWPORT_SOURCES}
    ${UI_SOURCES}
)

set_target_properties(cadnc PROPERTIES OUTPUT_NAME cadnc)

target_include_directories(cadnc PRIVATE
    "${CMAKE_BINARY_DIR}/generated"
    adapter/inc
    cam/inc
    nesting/inc
    util/inc
    viewport/inc
    ui/src
)

target_include_directories(cadnc SYSTEM PRIVATE
    ${OpenCASCADE_INCLUDE_DIR}
)

target_link_libraries(cadnc PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Quick
    Qt6::Qml
    Qt6::QuickControls2
    Qt6::Widgets
    Qt6::OpenGL
    Qt6::OpenGLWidgets
    Qt6::Svg
    Qt6::Xml
    OpenGL::GL
    ${OpenCASCADE_FoundationClasses_LIBRARIES}
    ${OpenCASCADE_ModelingData_LIBRARIES}
    ${OpenCASCADE_ModelingAlgorithms_LIBRARIES}
    ${OpenCASCADE_Visualization_LIBRARIES}
    ${OpenCASCADE_ApplicationFramework_LIBRARIES}
    ${OpenCASCADE_DataExchange_LIBRARIES}
)

if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    target_compile_options(cadnc PRIVATE -Wall -Wextra -Wpedantic)
endif()

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

if(CADNC_ENABLE_FREECAD_BACKEND)
    message(STATUS "FreeCAD backend integration is enabled")

    # ── Adapter library — bridges UI ↔ FreeCAD ──────────────────────
    add_library(cadnc_adapter STATIC ${ADAPTER_HEADERS} ${ADAPTER_SOURCES})
    target_include_directories(cadnc_adapter PUBLIC adapter/inc)
    target_include_directories(cadnc_adapter PRIVATE
        "${CMAKE_SOURCE_DIR}/freecad"
    )
    target_include_directories(cadnc_adapter SYSTEM PRIVATE
        ${OpenCASCADE_INCLUDE_DIR}
        ${EIGEN3_INCLUDE_DIR}
    )
    target_link_libraries(cadnc_adapter PUBLIC
        PartDesign Sketcher Part Materials FreeCADApp FreeCADBase
    )
    target_compile_definitions(cadnc_adapter PRIVATE QT_NO_KEYWORDS)
    target_compile_features(cadnc_adapter PUBLIC cxx_std_20)

    # Link adapter into main application
    target_link_libraries(cadnc PRIVATE cadnc_adapter)

    # ── Adapter test ────────────────────────────────────────────────
    add_executable(test_adapter tests/test_adapter.cpp)
    target_link_libraries(test_adapter PRIVATE cadnc_adapter)
    target_include_directories(test_adapter PRIVATE adapter/inc)
    set_target_properties(test_adapter PROPERTIES
        RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
    )

    # ── PoC test ────────────────────────────────────────────────────
    add_executable(poc_freecad_test tests/poc_freecad_test.cpp)
    target_link_libraries(poc_freecad_test PRIVATE
        PartDesign
        Sketcher
        Part
        Materials
        FreeCADApp
        FreeCADBase
    )
    target_include_directories(poc_freecad_test PRIVATE
        "${CMAKE_SOURCE_DIR}/freecad"
    )
    target_include_directories(poc_freecad_test SYSTEM PRIVATE
        ${OpenCASCADE_INCLUDE_DIR}
        ${EIGEN3_INCLUDE_DIR}
    )
    target_compile_definitions(poc_freecad_test PRIVATE QT_NO_KEYWORDS)
    set_target_properties(poc_freecad_test PROPERTIES
        RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
    )
endif()

if(CADNC_BUILD_TESTS)
    enable_testing()
    # add_subdirectory(tests)
endif()

install(TARGETS cadnc DESTINATION bin)
