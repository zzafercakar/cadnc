#pragma once

/**
 * @file PartFacade.h
 * @brief Facade for FreeCAD PartDesign operations.
 *
 * Wraps FreeCAD PartDesign features (Pad, Pocket, Fillet, Chamfer,
 * Revolution, Loft, Sweep, Pattern, Mirror) without exposing FreeCAD
 * internals to the UI.
 */

namespace CADNC {

class PartFacade {
public:
    PartFacade();
    ~PartFacade();

    // Feature creation
    // TODO: pad(), pocket(), revolution(), groove()
    // TODO: fillet(), chamfer(), draft(), thickness()
    // TODO: linearPattern(), polarPattern(), mirror()
    // TODO: loft(), sweep()

    // Boolean operations
    // TODO: fuse(), cut(), common()
};

} // namespace CADNC
