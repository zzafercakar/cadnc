#pragma once

/**
 * @file PartFacade.h
 * @brief Facade for FreeCAD PartDesign operations.
 *
 * Wraps FreeCAD PartDesign features (Pad, Pocket, Fillet, Chamfer,
 * Revolution, Loft, Sweep, Pattern, Mirror) without exposing FreeCAD
 * internals to the UI.
 */

#include <memory>
#include <string>
#include <vector>

namespace CADNC {

class PartFacade {
public:
    explicit PartFacade(void* document); // opaque — App::Document*
    ~PartFacade();

    PartFacade(const PartFacade&) = delete;
    PartFacade& operator=(const PartFacade&) = delete;

    // ── Sketch-based features ───────────────────────────────────────
    /// Extrude a sketch (Pad). Returns feature name.
    std::string pad(const std::string& sketchName, double length);
    std::string pocket(const std::string& sketchName, double depth);
    std::string revolution(const std::string& sketchName, double angleDeg);

    // ── Dress-up features ───────────────────────────────────────────
    std::string fillet(const std::vector<std::string>& edgeRefs, double radius);
    std::string chamfer(const std::vector<std::string>& edgeRefs, double size);

    // ── Pattern features ────────────────────────────────────────────
    std::string linearPattern(const std::string& featureName,
                              double dirX, double dirY, double dirZ,
                              double length, int occurrences);
    std::string polarPattern(const std::string& featureName,
                             double axisX, double axisY, double axisZ,
                             double angleDeg, int occurrences);
    std::string mirror(const std::string& featureName,
                       double planeNormX, double planeNormY, double planeNormZ);

    // ── Groove (subtractive revolution) ────────────────────────────
    std::string groove(const std::string& sketchName, double angleDeg);

    // ── Boolean operations ─────────────────────────────────────────
    std::string booleanFuse(const std::string& baseName, const std::string& toolName);
    std::string booleanCut(const std::string& baseName, const std::string& toolName);
    std::string booleanCommon(const std::string& baseName, const std::string& toolName);

    // ── Primitives (Part module) ───────────────────────────────────
    std::string addBox(double length, double width, double height);
    std::string addCylinder(double radius, double height, double angle = 360.0);
    std::string addSphere(double radius);
    std::string addCone(double radius1, double radius2, double height);

    // ── Dress-up (all edges) ──────────────────────────────────────
    std::string filletAll(const std::string& featureName, double radius);
    std::string chamferAll(const std::string& featureName, double size);

private:
    struct Impl;
    std::unique_ptr<Impl> impl_;
};

} // namespace CADNC
