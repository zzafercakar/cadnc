#pragma once

/**
 * @file SketchFacade.h
 * @brief Facade for FreeCAD Sketcher operations.
 *
 * Wraps FreeCAD SketchObject to provide sketch creation, geometry addition,
 * constraint management, and sketch tool operations (trim, fillet, chamfer)
 * without exposing FreeCAD internals to the UI.
 */

namespace CADNC {

class SketchFacade {
public:
    SketchFacade();
    ~SketchFacade();

    // Sketch lifecycle
    // TODO: createSketch(), closeSketch()

    // Geometry operations
    // TODO: addLine(), addCircle(), addArc(), addRectangle(), addSpline()

    // Constraints
    // TODO: addDimensionConstraint(), addCoincidentConstraint(), etc.

    // Sketch tools
    // TODO: trim(), fillet(), chamfer(), split(), extend()

    // Solver
    // TODO: solve(), getDOF()
};

} // namespace CADNC
