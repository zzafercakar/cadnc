# Sketcher parity tests — one test_<tool>.cpp per catalog row.
#
# Populated during Phase 1 (161 Sketcher tools). Each tool's commit
# appends its test file to PARITY_SKETCH_SOURCES below.
#
# First test file lands with Tool #1 (CmdSketcherCreatePoint → addPoint);
# this CMakeLists is intentionally empty of sources in sub-phase 1-Zero.

set(PARITY_SKETCH_SOURCES
    main.cpp
    test_drawing_point.cpp         # Tool #1 — CmdSketcherCreatePoint
    # test_drawing_line.cpp        # Tool #2 (pending)
    # ... etc.
)

if(PARITY_SKETCH_SOURCES)
    add_executable(cadnc_parity_sketch_tests ${PARITY_SKETCH_SOURCES})
    target_link_libraries(cadnc_parity_sketch_tests PRIVATE cadnc_adapter)
    target_include_directories(cadnc_parity_sketch_tests PRIVATE
        ${CMAKE_SOURCE_DIR}/adapter/inc
        ${CMAKE_SOURCE_DIR}/tests/parity_suite/common
    )
    set_target_properties(cadnc_parity_sketch_tests PROPERTIES
        RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
    )
    add_test(NAME parity_sketch
        COMMAND $<TARGET_FILE:cadnc_parity_sketch_tests>
        WORKING_DIRECTORY "${CMAKE_BINARY_DIR}"
    )
endif()
