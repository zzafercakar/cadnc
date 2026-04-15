# SPDX-License-Identifier: LGPL-2.1-or-later
# Sketcher — SketchObject, Constraints, planegcs solver

add_library(Sketcher SHARED)

target_compile_definitions(Sketcher PRIVATE Sketcher_EXPORTS QT_NO_KEYWORDS)

target_include_directories(Sketcher
    PUBLIC "${FREECAD_SRC_DIR}"
    PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}" "${CMAKE_CURRENT_BINARY_DIR}"
)
target_include_directories(Sketcher SYSTEM PRIVATE
    ${OpenCASCADE_INCLUDE_DIR}
    ${EIGEN3_INCLUDE_DIR}
    "${FREECAD_SRC_DIR}/3rdParty"
    "${FREECAD_SRC_DIR}/3rdParty/json/single_include/nlohmann"
)

# Pre-generated Python bindings
set(GENERATED_PY_SOURCES "")
file(GLOB _sketch_pyi CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/*.pyi")
foreach(_pyi ${_sketch_pyi})
    get_filename_component(_name ${_pyi} NAME_WE)
    generate_from_py(${_name})
endforeach()

# Source files
file(GLOB Sketcher_MAIN_SRCS CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/*.cpp")
file(GLOB Sketcher_GCS_SRCS CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/planegcs/*.cpp")

# Exclude generated *Py.cpp (included via *PyImp.cpp)
set(_generated_py_cpps "")
foreach(_pyi ${_sketch_pyi})
    get_filename_component(_name ${_pyi} NAME_WE)
    list(APPEND _generated_py_cpps "${CMAKE_CURRENT_SOURCE_DIR}/${_name}Py.cpp")
endforeach()
set(Sketcher_ALL_SRCS ${Sketcher_MAIN_SRCS} ${Sketcher_GCS_SRCS})
list(REMOVE_ITEM Sketcher_ALL_SRCS ${_generated_py_cpps})

target_sources(Sketcher PRIVATE ${Sketcher_ALL_SRCS} ${GENERATED_PY_SOURCES})

target_link_libraries(Sketcher PUBLIC
    Part
    FreeCADApp
    Eigen3::Eigen
    fmt::fmt
)

target_compile_features(Sketcher PUBLIC cxx_std_20)
set_target_properties(Sketcher PROPERTIES
    POSITION_INDEPENDENT_CODE ON
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib"
)

if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    target_compile_options(Sketcher PRIVATE
        -Wno-unused-parameter -Wno-missing-field-initializers
        -Wno-deprecated-declarations -Wno-sign-compare
    )
endif()

install(TARGETS Sketcher LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR})
