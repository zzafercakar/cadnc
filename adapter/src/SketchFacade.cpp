#include "SketchFacade.h"

#include <Base/Vector3D.h>
#include <Mod/Sketcher/App/SketchObject.h>
#include <Mod/Sketcher/App/Constraint.h>
#include <Mod/Sketcher/App/GeoEnum.h>
#include <Mod/Part/App/Geometry.h>

#include <memory>
#include <cmath>

namespace CADNC {

struct SketchFacade::Impl {
    Sketcher::SketchObject* sketch = nullptr;
};

SketchFacade::SketchFacade(void* sketchObject)
    : impl_(std::make_unique<Impl>())
{
    impl_->sketch = static_cast<Sketcher::SketchObject*>(sketchObject);
}

SketchFacade::~SketchFacade() = default;

// ── Geometry ────────────────────────────────────────────────────────

int SketchFacade::addLine(Point2D p1, Point2D p2, bool construction)
{
    try {
        auto geo = std::make_unique<Part::GeomLineSegment>();
        geo->setPoints(Base::Vector3d(p1.x, p1.y, 0), Base::Vector3d(p2.x, p2.y, 0));
        return impl_->sketch->addGeometry(geo.release(), construction);
    } catch (...) { return -1; }
}

int SketchFacade::addCircle(Point2D center, double radius, bool construction)
{
    if (radius < 1e-7) return -1;  // reject degenerate
    try {
        auto geo = std::make_unique<Part::GeomCircle>();
        geo->setCenter(Base::Vector3d(center.x, center.y, 0));
        geo->setRadius(radius);
        return impl_->sketch->addGeometry(geo.release(), construction);
    } catch (...) { return -1; }
}

int SketchFacade::addArc(Point2D center, double radius,
                         double startAngle, double endAngle, bool construction)
{
    if (radius < 1e-7) return -1;  // reject degenerate
    try {
        auto geo = std::make_unique<Part::GeomArcOfCircle>();
        geo->setCenter(Base::Vector3d(center.x, center.y, 0));
        geo->setRadius(radius);
        geo->setRange(startAngle, endAngle, true);
        return impl_->sketch->addGeometry(geo.release(), construction);
    } catch (...) { return -1; }
}

int SketchFacade::addRectangle(Point2D p1, Point2D p2, bool construction)
{
    // Reject degenerate rectangle (zero area causes solver issues)
    if (std::abs(p1.x - p2.x) < 1e-7 || std::abs(p1.y - p2.y) < 1e-7)
        return -1;

    try {
        // Rectangle = 4 lines + 4 coincident constraints
        int id0 = addLine(p1, {p2.x, p1.y}, construction);
        int id1 = addLine({p2.x, p1.y}, p2, construction);
        int id2 = addLine(p2, {p1.x, p2.y}, construction);
        int id3 = addLine({p1.x, p2.y}, p1, construction);

        if (id0 < 0 || id1 < 0 || id2 < 0 || id3 < 0)
            return id0;  // partial — skip constraints

        // Close corners with coincident constraints
        addCoincident(id0, 2, id1, 1); // end of L0 = start of L1
        addCoincident(id1, 2, id2, 1);
        addCoincident(id2, 2, id3, 1);
        addCoincident(id3, 2, id0, 1);

        return id0;
    } catch (...) {
        return -1;
    }
}

int SketchFacade::addPoint(Point2D p, bool construction)
{
    auto geo = std::make_unique<Part::GeomPoint>(Base::Vector3d(p.x, p.y, 0));
    return impl_->sketch->addGeometry(geo.release(), construction);
}

void SketchFacade::removeGeometry(int geoId)
{
    try { impl_->sketch->delGeometry(geoId); } catch (...) {}
}

// ── Constraints ─────────────────────────────────────────────────────

static Sketcher::ConstraintType toSketcherType(ConstraintType t)
{
    switch (t) {
        case ConstraintType::Coincident:    return Sketcher::Coincident;
        case ConstraintType::Horizontal:    return Sketcher::Horizontal;
        case ConstraintType::Vertical:      return Sketcher::Vertical;
        case ConstraintType::Parallel:      return Sketcher::Parallel;
        case ConstraintType::Perpendicular: return Sketcher::Perpendicular;
        case ConstraintType::Tangent:       return Sketcher::Tangent;
        case ConstraintType::Equal:         return Sketcher::Equal;
        case ConstraintType::Symmetric:     return Sketcher::Symmetric;
        case ConstraintType::Distance:      return Sketcher::Distance;
        case ConstraintType::DistanceX:     return Sketcher::DistanceX;
        case ConstraintType::DistanceY:     return Sketcher::DistanceY;
        case ConstraintType::Angle:         return Sketcher::Angle;
        case ConstraintType::Radius:        return Sketcher::Radius;
        case ConstraintType::Diameter:      return Sketcher::Diameter;
        case ConstraintType::PointOnObject: return Sketcher::PointOnObject;
        case ConstraintType::Fixed:         return Sketcher::Block;
        default:                            return Sketcher::None;
    }
}

int SketchFacade::addConstraint(ConstraintType type, int firstGeo, int secondGeo, double value)
{
    try {
        auto c = std::make_unique<Sketcher::Constraint>();
        c->Type = toSketcherType(type);
        c->setElement(0, Sketcher::GeoElementId(firstGeo, Sketcher::PointPos::none));
        if (secondGeo >= 0) {
            c->setElement(1, Sketcher::GeoElementId(secondGeo, Sketcher::PointPos::none));
        }
        if (value != 0.0) c->setValue(value);
        return impl_->sketch->addConstraint(c.release());
    } catch (...) { return -1; }
}

int SketchFacade::addCoincident(int geo1, int pos1, int geo2, int pos2)
{
    try {
        auto c = std::make_unique<Sketcher::Constraint>();
        c->Type = Sketcher::Coincident;
        c->setElement(0, Sketcher::GeoElementId(geo1, static_cast<Sketcher::PointPos>(pos1)));
        c->setElement(1, Sketcher::GeoElementId(geo2, static_cast<Sketcher::PointPos>(pos2)));
        return impl_->sketch->addConstraint(c.release());
    } catch (...) { return -1; }
}

int SketchFacade::addDistance(int geoId, double distance)
{
    auto c = std::make_unique<Sketcher::Constraint>();
    c->Type = Sketcher::Distance;
    c->setElement(0, Sketcher::GeoElementId(geoId, Sketcher::PointPos::start));
    c->setElement(1, Sketcher::GeoElementId(geoId, Sketcher::PointPos::end));
    c->setValue(distance);
    return impl_->sketch->addConstraint(c.release());
}

int SketchFacade::addRadius(int geoId, double radius)
{
    auto c = std::make_unique<Sketcher::Constraint>();
    c->Type = Sketcher::Radius;
    c->setElement(0, Sketcher::GeoElementId(geoId, Sketcher::PointPos::none));
    c->setValue(radius);
    return impl_->sketch->addConstraint(c.release());
}

int SketchFacade::addAngle(int geo1, int geo2, double angle)
{
    auto c = std::make_unique<Sketcher::Constraint>();
    c->Type = Sketcher::Angle;
    c->setElement(0, Sketcher::GeoElementId(geo1, Sketcher::PointPos::none));
    c->setElement(1, Sketcher::GeoElementId(geo2, Sketcher::PointPos::none));
    c->setValue(angle);
    return impl_->sketch->addConstraint(c.release());
}

int SketchFacade::addHorizontal(int geoId)
{
    auto c = std::make_unique<Sketcher::Constraint>();
    c->Type = Sketcher::Horizontal;
    c->setElement(0, Sketcher::GeoElementId(geoId, Sketcher::PointPos::none));
    return impl_->sketch->addConstraint(c.release());
}

int SketchFacade::addVertical(int geoId)
{
    auto c = std::make_unique<Sketcher::Constraint>();
    c->Type = Sketcher::Vertical;
    c->setElement(0, Sketcher::GeoElementId(geoId, Sketcher::PointPos::none));
    return impl_->sketch->addConstraint(c.release());
}

int SketchFacade::addFixed(int geoId)
{
    auto c = std::make_unique<Sketcher::Constraint>();
    c->Type = Sketcher::Block;
    c->setElement(0, Sketcher::GeoElementId(geoId, Sketcher::PointPos::none));
    return impl_->sketch->addConstraint(c.release());
}

void SketchFacade::removeConstraint(int constraintId)
{
    try { impl_->sketch->delConstraint(constraintId); } catch (...) {}
}

void SketchFacade::setDatum(int constraintId, double value)
{
    try { impl_->sketch->setDatum(constraintId, value); } catch (...) {}
}

void SketchFacade::toggleDriving(int constraintId)
{
    try { impl_->sketch->toggleDriving(constraintId); } catch (...) {}
}

// ── Sketch tools ────────────────────────────────────────────────────

int SketchFacade::trim(int geoId, Point2D point)
{
    try {
        return impl_->sketch->trim(geoId, Base::Vector3d(point.x, point.y, 0));
    } catch (...) { return -1; }
}

int SketchFacade::fillet(int geoId1, int geoId2, double radius)
{
    // FreeCAD fillet on a vertex identified by geoId + PointPos
    try {
        return impl_->sketch->fillet(geoId1, static_cast<Sketcher::PointPos>(geoId2), radius);
    } catch (...) { return -1; }
}

int SketchFacade::chamfer(int geoId1, int geoId2, double size)
{
    // SketchObject has no direct chamfer — use fillet as placeholder
    try {
        return impl_->sketch->fillet(geoId1, static_cast<Sketcher::PointPos>(geoId2), size);
    } catch (...) { return -1; }
}

// ── Solver ──────────────────────────────────────────────────────────

SolveResult SketchFacade::solve()
{
    try {
        int result = impl_->sketch->solve();
        switch (result) {
            case 0:  return SolveResult::Solved;
            case -1: return SolveResult::SolverError;
            case -2: return SolveResult::Redundant;
            case -3: return SolveResult::Conflicting;
            case -4: return SolveResult::OverConstrained;
            default: return SolveResult::UnderConstrained;
        }
    } catch (...) {
        return SolveResult::SolverError;
    }
}

// ── Query ───────────────────────────────────────────────────────────

std::vector<GeoInfo> SketchFacade::geometry() const
{
    std::vector<GeoInfo> result;
    const auto& geos = impl_->sketch->getInternalGeometry();

    for (int i = 0; i < static_cast<int>(geos.size()); ++i) {
        GeoInfo info;
        info.id = i;

        if (auto* ls = dynamic_cast<const Part::GeomLineSegment*>(geos[i])) {
            info.type = "Line";
            auto p1 = ls->getStartPoint();
            auto p2 = ls->getEndPoint();
            info.start = {p1.x, p1.y};
            info.end = {p2.x, p2.y};
        }
        else if (auto* c = dynamic_cast<const Part::GeomCircle*>(geos[i])) {
            info.type = "Circle";
            auto ctr = c->getCenter();
            info.center = {ctr.x, ctr.y};
            info.radius = c->getRadius();
        }
        else if (auto* a = dynamic_cast<const Part::GeomArcOfCircle*>(geos[i])) {
            info.type = "Arc";
            auto ctr = a->getCenter();
            info.center = {ctr.x, ctr.y};
            info.radius = a->getRadius();
            double s, e;
            a->getRange(s, e, true);
            info.startAngle = s;
            info.endAngle = e;
        }
        else if (dynamic_cast<const Part::GeomPoint*>(geos[i])) {
            info.type = "Point";
            auto loc = dynamic_cast<const Part::GeomPoint*>(geos[i])->getPoint();
            info.center = {loc.x, loc.y};
        }
        else {
            info.type = "Other";
        }

        result.push_back(std::move(info));
    }
    return result;
}

std::vector<ConstraintInfo> SketchFacade::constraints() const
{
    std::vector<ConstraintInfo> result;
    const auto& constrs = impl_->sketch->Constraints.getValues();

    for (int i = 0; i < static_cast<int>(constrs.size()); ++i) {
        ConstraintInfo info;
        info.id = i;
        info.value = constrs[i]->getValue();
        info.isDriving = constrs[i]->isDriving;
        info.firstGeoId = constrs[i]->getGeoId(0);
        info.secondGeoId = constrs[i]->getGeoId(1);

        // Map type back
        switch (constrs[i]->Type) {
            case Sketcher::Coincident:    info.type = ConstraintType::Coincident; break;
            case Sketcher::Distance:      info.type = ConstraintType::Distance; break;
            case Sketcher::Radius:        info.type = ConstraintType::Radius; break;
            case Sketcher::Horizontal:    info.type = ConstraintType::Horizontal; break;
            case Sketcher::Vertical:      info.type = ConstraintType::Vertical; break;
            case Sketcher::Angle:         info.type = ConstraintType::Angle; break;
            case Sketcher::Perpendicular: info.type = ConstraintType::Perpendicular; break;
            case Sketcher::Parallel:      info.type = ConstraintType::Parallel; break;
            case Sketcher::Tangent:       info.type = ConstraintType::Tangent; break;
            case Sketcher::Equal:         info.type = ConstraintType::Equal; break;
            default:                      info.type = ConstraintType::Coincident; break;
        }
        result.push_back(std::move(info));
    }
    return result;
}

int SketchFacade::geometryCount() const
{
    return static_cast<int>(impl_->sketch->getInternalGeometry().size());
}

int SketchFacade::constraintCount() const
{
    return static_cast<int>(impl_->sketch->Constraints.getValues().size());
}

void SketchFacade::close()
{
    try { impl_->sketch->solve(); } catch (...) {}
}

} // namespace CADNC
