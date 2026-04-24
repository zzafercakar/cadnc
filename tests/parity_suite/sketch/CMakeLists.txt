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
    test_drawing_line.cpp          # Tool #2 — CmdSketcherCreateLine
    test_drawing_polyline.cpp      # Tool #3 — CmdSketcherCreatePolyline
    test_drawing_arc.cpp           # Tool #4 — CmdSketcherCreateArc
    test_drawing_arc3point.cpp     # Tool #5 — CmdSketcherCreate3PointArc
    test_drawing_arc_ellipse.cpp   # Tool #6 — CmdSketcherCreateArcOfEllipse
    test_drawing_arc_hyperbola.cpp # Tool #7 — CmdSketcherCreateArcOfHyperbola
    test_drawing_arc_parabola.cpp  # Tool #8 — CmdSketcherCreateArcOfParabola
    test_drawing_circle.cpp        # Tool #9 — CmdSketcherCreateCircle
    test_drawing_circle3point.cpp  # Tool #10 — CmdSketcherCreate3PointCircle
    test_drawing_ellipse.cpp       # Tool #11 — CmdSketcherCreateEllipseByCenter
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
