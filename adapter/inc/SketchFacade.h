#pragma once

/**
 * @file SketchFacade.h
 * @brief Facade for FreeCAD Sketcher operations.
 *
 * Wraps FreeCAD SketchObject to provide sketch creation, geometry addition,
 * constraint management, and sketch tool operations (trim, fillet, chamfer)
 * without exposing FreeCAD internals to the UI.
 */

#include <memory>
#include <string>
#include <vector>

namespace CADNC {

/// Simple 2D point for passing geometry data across the facade boundary
struct Point2D {
    double x = 0.0;
    double y = 0.0;
};

/// Constraint type enum — mirrors Sketcher::ConstraintType without exposing it
enum class ConstraintType {
    Coincident,
    Horizontal,
    Vertical,
    Parallel,
    Perpendicular,
    Tangent,
    Equal,
    Symmetric,
    Distance,
    DistanceX,
    DistanceY,
    Angle,
    Radius,
    Diameter,
    PointOnObject,
    Fixed,
};

/// Geometry info returned from the sketch (no OCCT types leak out)
struct GeoInfo {
    int id = -1;
    std::string type;       // "Line", "Circle", "Arc", "Point", "Ellipse", "BSpline"
    bool construction = false;

    // Line endpoints
    Point2D start, end;

    // Circle/Arc/Ellipse center + radius
    Point2D center;
    double radius = 0.0;

    // Arc angles (radians)
    double startAngle = 0.0;
    double endAngle = 0.0;

    // Ellipse-specific
    double majorRadius = 0.0;
    double minorRadius = 0.0;
    double angle = 0.0;         // major axis rotation

    // BSpline-specific
    std::vector<Point2D> poles;
    int degree = 0;
};

/// Constraint info returned from the sketch
struct ConstraintInfo {
    int id = -1;
    ConstraintType type = ConstraintType::Coincident;
    double value = 0.0;
    bool isDriving = true;
    int firstGeoId = -1;
    int secondGeoId = -1;
};

/// Solve result from the constraint solver
enum class SolveResult {
    Solved,         // fully constrained
    UnderConstrained,
    OverConstrained,
    Conflicting,
    Redundant,
    SolverError,
};

class SketchFacade {
public:
    explicit SketchFacade(void* sketchObject); // opaque — SketchObject*
    ~SketchFacade();

    // non-copyable
    SketchFacade(const SketchFacade&) = delete;
    SketchFacade& operator=(const SketchFacade&) = delete;

    // ── Geometry operations ─────────────────────────────────────────
    int addLine(Point2D p1, Point2D p2, bool construction = false);
    int addCircle(Point2D center, double radius, bool construction = false);
    int addArc(Point2D center, double radius,
               double startAngle, double endAngle, bool construction = false);
    int addRectangle(Point2D p1, Point2D p2, bool construction = false);
    int addPoint(Point2D p, bool construction = false);
    int addEllipse(Point2D center, double majorRadius, double minorRadius,
                   double angle = 0.0, bool construction = false);
    int addBSpline(const std::vector<Point2D>& poles, int degree = 3,
                   bool periodic = false, bool construction = false);
    int addPolyline(const std::vector<Point2D>& points, bool construction = false);

    void removeGeometry(int geoId);

    // ── Constraints ─────────────────────────────────────────────────
    int addConstraint(ConstraintType type, int firstGeo, int secondGeo = -1,
                      double value = 0.0);
    int addCoincident(int geo1, int pos1, int geo2, int pos2);
    int addDistance(int geoId, double distance);
    int addRadius(int geoId, double radius);
    int addAngle(int geo1, int geo2, double angle);
    int addHorizontal(int geoId);
    int addVertical(int geoId);
    int addFixed(int geoId);

    /// Point-on-curve (posId for the point — 1/2/3, curve side is edge with PointPos::none)
    int addPointOnObject(int pointGeo, int pointPos, int curveGeo);

    /// Symmetric constraint with 3 elements:
    ///   Symmetric(g1.pos1, g2.pos2, g3.pos3) — g3 sits on the symmetry axis of g1↔g2.
    /// Used for "snap vertex to midpoint of a line" (line.start, line.end, vertex.mid).
    int addSymmetric(int g1, int pos1, int g2, int pos2, int g3, int pos3);

    void removeConstraint(int constraintId);
    void setDatum(int constraintId, double value);
    void toggleDriving(int constraintId);

    // ── Sketch tools ────────────────────────────────────────────────
    int trim(int geoId, Point2D point);
    /// Fillet at vertex: geoId identifies the geometry, posId the PointPos (1=start, 2=end)
    int fillet(int geoId, int posId, double radius);
    /// Chamfer at vertex (placeholder — uses fillet internally)
    int chamfer(int geoId, int posId, double size);
    int extend(int geoId, double increment, int endPointPos);
    int split(int geoId, Point2D point);
    int toggleConstruction(int geoId);

    // ── Solver ──────────────────────────────────────────────────────
    SolveResult solve();
    /// Degrees of freedom remaining after the last solve. 0 means the
    /// sketch is fully constrained; >0 means under-constrained. Returns
    /// -1 if the query fails. Used by the UI to colour geometry blue
    /// (DOF>0) vs. green (DOF=0).
    int dof() const;

    // ── Query ───────────────────────────────────────────────────────
    std::vector<GeoInfo> geometry() const;
    std::vector<ConstraintInfo> constraints() const;
    int geometryCount() const;
    int constraintCount() const;

    // ── Lifecycle ───────────────────────────────────────────────────
    /// Close the sketch (validates, updates shape)
    void close();

    /// Returns 0=XY, 1=XZ, 2=YZ based on the sketch's stored Placement.
    /// -1 if the sketch is not on a standard plane.
    int planeType() const;

private:
    struct Impl;
    std::unique_ptr<Impl> impl_;
};

} // namespace CADNC
