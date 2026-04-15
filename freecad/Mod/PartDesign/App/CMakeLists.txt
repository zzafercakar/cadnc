# SPDX-License-Identifier: LGPL-2.1-or-later
# PartDesign — parametric feature modeling (Pad, Pocket, Revolution, Fillet, etc.)

add_library(PartDesign SHARED)

target_compile_definitions(PartDesign PRIVATE PartDesign_EXPORTS QT_NO_KEYWORDS)

target_include_directories(PartDesign
    PUBLIC "${FREECAD_SRC_DIR}"
    PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}" "${CMAKE_CURRENT_BINARY_DIR}"
)
target_include_directories(PartDesign SYSTEM PRIVATE
    ${OpenCASCADE_INCLUDE_DIR}
    "${FREECAD_SRC_DIR}/3rdParty/json/single_include/nlohmann"
)

# Pre-generated Python bindings
set(GENERATED_PY_SOURCES "")
file(GLOB _pd_pyi CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/*.pyi")
foreach(_pyi ${_pd_pyi})
    get_filename_component(_name ${_pyi} NAME_WE)
    generate_from_py(${_name})
endforeach()

# Source files
file(GLOB PartDesign_ALL_SRCS CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/*.cpp")

# Exclude generated *Py.cpp
set(_generated_py_cpps "")
foreach(_pyi ${_pd_pyi})
    get_filename_component(_name ${_pyi} NAME_WE)
    list(APPEND _generated_py_cpps "${CMAKE_CURRENT_SOURCE_DIR}/${_name}Py.cpp")
endforeach()
list(REMOVE_ITEM PartDesign_ALL_SRCS ${_generated_py_cpps})

target_sources(PartDesign PRIVATE ${PartDesign_ALL_SRCS} ${GENERATED_PY_SOURCES})

target_link_libraries(PartDesign PUBLIC
    Part
    Sketcher
    FreeCADApp
    fmt::fmt
)

target_compile_features(PartDesign PUBLIC cxx_std_20)
set_target_properties(PartDesign PROPERTIES
    POSITION_INDEPENDENT_CODE ON
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib"
)

if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    target_compile_options(PartDesign PRIVATE
        -Wno-unused-parameter -Wno-missing-field-initializers
        -Wno-deprecated-declarations -Wno-sign-compare
    )
endif()

install(TARGETS PartDesign LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR})
