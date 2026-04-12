cmake_minimum_required(VERSION 3.22)
project(CADNC VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
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
option(CADNC_ENABLE_FREECAD_BACKEND "Enable FreeCAD backend integration" OFF)

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
    find_package(Python3 REQUIRED COMPONENTS Development Interpreter)
    find_package(Boost REQUIRED)
    find_package(Eigen3 REQUIRED)
    find_package(XercesC REQUIRED)
    find_package(ZLIB REQUIRED)
    find_package(ICU COMPONENTS uc data)
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
file(GLOB QML_FILES CONFIGURE_DEPENDS ui/qml/*.qml ui/qml/components/*.qml ui/qml/*.js)
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
    ${ADAPTER_HEADERS}
    ${ADAPTER_SOURCES}
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
    # add_subdirectory(freecad)
endif()

if(CADNC_BUILD_TESTS)
    enable_testing()
    # add_subdirectory(tests)
endif()

install(TARGETS cadnc DESTINATION bin)
