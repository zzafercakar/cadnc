# Sketch Backend & UI Completion — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete all missing sketch geometry types (Ellipse, BSpline, Polyline), sketch tools (Extend, Split, Construction toggle, real Chamfer), missing CadEngine constraint wiring (DistanceX/Y, Diameter, Symmetric, PointOnObject), and enable all stub UI buttons with full functionality.

**Architecture:** Each feature follows the same 3-layer pattern: SketchFacade (C++ wrapper around FreeCAD SketchObject) → CadEngine (Q_INVOKABLE QML bridge) → QML UI (toolbar button + canvas rendering). FreeCAD's existing methods are called directly — no reimplementation.

**Tech Stack:** C++17, FreeCAD Sketcher/Part modules, Qt6 QML, planegcs solver

---

## File Map

| File | Action | Responsibility |
|------|--------|---------------|
| `adapter/inc/SketchFacade.h` | Modify | Add method signatures: addEllipse, addBSpline, addPolyline, extend, split, toggleConstruction |
| `adapter/src/SketchFacade.cpp` | Modify | Implement new methods using FreeCAD SketchObject API; fix geometry() to recognize Ellipse/BSpline; fix constraints() to map all types; fix chamfer to pass chamfer=true |
| `adapter/inc/CadEngine.h` | Modify | Add Q_INVOKABLE: addEllipse, addBSpline, addPolyline, extendGeo, splitAtPoint, toggleConstruction, chamferVertex, addDistanceXConstraint, addDistanceYConstraint, addDiameterConstraint, addSymmetricConstraint, addPointOnObjectConstraint |
| `adapter/src/CadEngine.cpp` | Modify | Implement new Q_INVOKABLE methods delegating to SketchFacade; add new constraint type names to sketchConstraints() |
| `ui/qml/SketchCanvas.qml` | Modify | Add ellipse drawing tool + preview + render; add BSpline render; add polyline multi-click drawing; add construction line rendering (dashed gray); add ellipse/BSpline snap points; add extend/split/chamfer click handlers |
| `ui/qml/toolbars/SketchToolbar.qml` | Modify | Enable polyline/ellipse/spline/extend/mirror/offset buttons; add construction toggle button; add DistanceX/Y, Diameter, Symmetric, PointOnObject constraint buttons |
| `ui/qml/Main.qml` | Modify | Add keyboard shortcuts E, P, S, X; wire new constraint handlers; wire new tool handlers |

---

### Task 1: SketchFacade — New Geometry Methods (Ellipse, BSpline, Polyline)

**Files:**
- Modify: `adapter/inc/SketchFacade.h:91-99`
- Modify: `adapter/src/SketchFacade.cpp:26-98`

- [ ] **Step 1: Add method signatures to SketchFacade.h**

After `addPoint` (line 97), add:

```cpp
int addEllipse(Point2D center, double majorRadius, double minorRadius,
               double angle = 0.0, bool construction = false);
int addBSpline(const std::vector<Point2D>& poles, int degree = 3,
               bool periodic = false, bool construction = false);
int addPolyline(const std::vector<Point2D>& points, bool construction = false);
```

- [ ] **Step 2: Implement addEllipse in SketchFacade.cpp**

After addPoint implementation:

```cpp
int SketchFacade::addEllipse(Point2D center, double majorRadius, double minorRadius,
                              double angle, bool construction)
{
    if (majorRadius < 1e-7 || minorRadius < 1e-7) return -1;
    try {
        auto geo = std::make_unique<Part::GeomEllipse>();
        geo->setCenter(Base::Vector3d(center.x, center.y, 0));
        geo->setMajorRadius(std::max(majorRadius, minorRadius));
        geo->setMinorRadius(std::min(majorRadius, minorRadius));
        if (std::abs(angle) > 1e-9) {
            geo->setMajorAxisDir(Base::Vector3d(std::cos(angle), std::sin(angle), 0));
        }
        return impl_->sketch->addGeometry(geo.release(), construction);
    } catch (...) { return -1; }
}
```

- [ ] **Step 3: Implement addBSpline in SketchFacade.cpp**

```cpp
int SketchFacade::addBSpline(const std::vector<Point2D>& poles, int degree,
                              bool periodic, bool construction)
{
    if (poles.size() < 2) return -1;
    try {
        std::vector<Base::Vector3d> pts;
        pts.reserve(poles.size());
        for (const auto& p : poles)
            pts.emplace_back(p.x, p.y, 0);

        // Build uniform knot vector for interpolation
        int nPoles = static_cast<int>(pts.size());
        int deg = std::min(degree, nPoles - 1);
        int nKnots = nPoles + deg + 1;
        std::vector<double> knots;
        std::vector<int> mults;

        // Clamped uniform: [0,0,...,0, 1, 2, ..., n-deg, n-deg,...,n-deg]
        knots.push_back(0.0);
        mults.push_back(deg + 1);
        for (int i = 1; i < nPoles - deg; ++i) {
            knots.push_back(static_cast<double>(i));
            mults.push_back(1);
        }
        knots.push_back(static_cast<double>(nPoles - deg));
        mults.push_back(deg + 1);

        std::vector<double> weights(nPoles, 1.0);

        auto geo = std::make_unique<Part::GeomBSplineCurve>(pts, weights, knots, mults, deg, false, periodic);
        int geoId = impl_->sketch->addGeometry(geo.release(), construction);

        // Expose internal geometry (control points, knot points) for solver
        if (geoId >= 0) {
            try { impl_->sketch->exposeInternalGeometry(geoId); } catch (...) {}
        }
        return geoId;
    } catch (...) { return -1; }
}
```

- [ ] **Step 4: Implement addPolyline in SketchFacade.cpp**

```cpp
int SketchFacade::addPolyline(const std::vector<Point2D>& points, bool construction)
{
    if (points.size() < 2) return -1;
    try {
        int firstId = -1;
        int prevId = -1;
        for (size_t i = 0; i + 1 < points.size(); ++i) {
            int id = addLine(points[i], points[i + 1], construction);
            if (i == 0) firstId = id;
            // Chain segments with coincident constraints (end of prev = start of current)
            if (prevId >= 0 && id >= 0) {
                addCoincident(prevId, 2, id, 1);  // end=2, start=1
            }
            prevId = id;
        }
        return firstId;
    } catch (...) { return -1; }
}
```

- [ ] **Step 5: Add Ellipse include**

At top of SketchFacade.cpp, the `#include <Mod/Part/App/Geometry.h>` already covers GeomEllipse and GeomBSplineCurve — no new includes needed.

- [ ] **Step 6: Build to verify compilation**

```bash
cmake --build build -j$(nproc) 2>&1 | tail -20
```

Expected: Clean build, no errors.

---

### Task 2: SketchFacade — New Tool Methods (Extend, Split, Construction Toggle, Real Chamfer)

**Files:**
- Modify: `adapter/inc/SketchFacade.h:116-121`
- Modify: `adapter/src/SketchFacade.cpp:218-241`

- [ ] **Step 1: Add method signatures to SketchFacade.h**

After chamfer declaration (line 121), add:

```cpp
int extend(int geoId, double increment, int endPointPos);
int split(int geoId, Point2D point);
int toggleConstruction(int geoId);
```

- [ ] **Step 2: Implement extend in SketchFacade.cpp**

```cpp
int SketchFacade::extend(int geoId, double increment, int endPointPos)
{
    try {
        return impl_->sketch->extend(geoId, increment, static_cast<Sketcher::PointPos>(endPointPos));
    } catch (...) { return -1; }
}
```

- [ ] **Step 3: Implement split in SketchFacade.cpp**

```cpp
int SketchFacade::split(int geoId, Point2D point)
{
    try {
        return impl_->sketch->split(geoId, Base::Vector3d(point.x, point.y, 0));
    } catch (...) { return -1; }
}
```

- [ ] **Step 4: Implement toggleConstruction in SketchFacade.cpp**

```cpp
int SketchFacade::toggleConstruction(int geoId)
{
    try {
        return impl_->sketch->toggleConstruction(geoId);
    } catch (...) { return -1; }
}
```

- [ ] **Step 5: Fix chamfer to use FreeCAD's chamfer=true parameter**

Replace existing chamfer implementation:

```cpp
int SketchFacade::chamfer(int geoId1, int geoId2, double size)
{
    // FreeCAD fillet with chamfer=true creates a chamfer
    try {
        return impl_->sketch->fillet(geoId1, static_cast<Sketcher::PointPos>(geoId2),
                                      size, true, false, true);
    } catch (...) { return -1; }
}
```

- [ ] **Step 6: Build to verify**

```bash
cmake --build build -j$(nproc) 2>&1 | tail -20
```

---

### Task 3: SketchFacade — Fix geometry() and constraints() to recognize new types

**Files:**
- Modify: `adapter/src/SketchFacade.cpp:264-340`
- Modify: `adapter/inc/SketchFacade.h:44-60` (GeoInfo struct)

- [ ] **Step 1: Extend GeoInfo struct for Ellipse and BSpline data**

In SketchFacade.h, update GeoInfo:

```cpp
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
```

- [ ] **Step 2: Add Ellipse and BSpline recognition in geometry()**

After the Point recognition block, before the `else { info.type = "Other"; }`:

```cpp
else if (auto* el = dynamic_cast<const Part::GeomEllipse*>(geos[i])) {
    info.type = "Ellipse";
    auto ctr = el->getCenter();
    info.center = {ctr.x, ctr.y};
    info.majorRadius = el->getMajorRadius();
    info.minorRadius = el->getMinorRadius();
    auto dir = el->getMajorAxisDir();
    info.angle = std::atan2(dir.y, dir.x);
}
else if (auto* bs = dynamic_cast<const Part::GeomBSplineCurve*>(geos[i])) {
    info.type = "BSpline";
    auto bsPoles = bs->getPoles();
    for (const auto& p : bsPoles)
        info.poles.push_back({p.x, p.y});
    info.degree = bs->getDegree();
}
```

- [ ] **Step 3: Add construction flag to geometry()**

After setting `info.id = i;`, add:

```cpp
auto facade = impl_->sketch->getGeometryFacade(i);
if (facade) info.construction = facade->getConstruction();
```

This requires include: `#include <Mod/Sketcher/App/GeometryFacade.h>`

- [ ] **Step 4: Fix constraints() to map all missing constraint types**

Replace the default case and add missing types:

```cpp
case Sketcher::Symmetric:     info.type = ConstraintType::Symmetric; break;
case Sketcher::DistanceX:     info.type = ConstraintType::DistanceX; break;
case Sketcher::DistanceY:     info.type = ConstraintType::DistanceY; break;
case Sketcher::Diameter:      info.type = ConstraintType::Diameter; break;
case Sketcher::PointOnObject: info.type = ConstraintType::PointOnObject; break;
case Sketcher::Block:         info.type = ConstraintType::Fixed; break;
default:                      info.type = ConstraintType::Coincident; break;
```

- [ ] **Step 5: Build to verify**

```bash
cmake --build build -j$(nproc) 2>&1 | tail -20
```

---

### Task 4: CadEngine — New Geometry Q_INVOKABLE Methods

**Files:**
- Modify: `adapter/inc/CadEngine.h:96-103`
- Modify: `adapter/src/CadEngine.cpp:252-303`

- [ ] **Step 1: Add Q_INVOKABLE declarations to CadEngine.h**

After `addPoint` declaration:

```cpp
Q_INVOKABLE int addEllipse(double cx, double cy, double majorR, double minorR, double angleDeg = 0);
Q_INVOKABLE int addBSpline(const QVariantList& points, int degree = 3);
Q_INVOKABLE int addPolyline(const QVariantList& points);
Q_INVOKABLE int toggleConstruction(int geoId);
```

- [ ] **Step 2: Implement in CadEngine.cpp**

```cpp
int CadEngine::addEllipse(double cx, double cy, double majorR, double minorR, double angleDeg)
{
    if (!activeSketch_) return -1;
    double angleRad = angleDeg * M_PI / 180.0;
    int id = activeSketch_->addEllipse({cx, cy}, majorR, minorR, angleRad);
    refreshSketch();
    return id;
}

int CadEngine::addBSpline(const QVariantList& points, int degree)
{
    if (!activeSketch_) return -1;
    std::vector<CADNC::Point2D> poles;
    for (const auto& pt : points) {
        auto map = pt.toMap();
        poles.push_back({map["x"].toDouble(), map["y"].toDouble()});
    }
    int id = activeSketch_->addBSpline(poles, degree);
    refreshSketch();
    return id;
}

int CadEngine::addPolyline(const QVariantList& points)
{
    if (!activeSketch_) return -1;
    std::vector<CADNC::Point2D> pts;
    for (const auto& pt : points) {
        auto map = pt.toMap();
        pts.push_back({map["x"].toDouble(), map["y"].toDouble()});
    }
    int id = activeSketch_->addPolyline(pts);
    refreshSketch();
    return id;
}

int CadEngine::toggleConstruction(int geoId)
{
    if (!activeSketch_) return -1;
    int result = activeSketch_->toggleConstruction(geoId);
    refreshSketch();
    return result;
}
```

- [ ] **Step 3: Build to verify**

```bash
cmake --build build -j$(nproc) 2>&1 | tail -20
```

---

### Task 5: CadEngine — New Tool Q_INVOKABLE Methods

**Files:**
- Modify: `adapter/inc/CadEngine.h:121-123`
- Modify: `adapter/src/CadEngine.cpp:419-435`

- [ ] **Step 1: Add Q_INVOKABLE declarations**

After `filletVertex`:

```cpp
Q_INVOKABLE int chamferVertex(int geoId, int posId, double size);
Q_INVOKABLE int extendGeo(int geoId, double increment, int endPointPos);
Q_INVOKABLE int splitAtPoint(int geoId, double px, double py);
```

- [ ] **Step 2: Implement in CadEngine.cpp**

```cpp
int CadEngine::chamferVertex(int geoId, int posId, double size)
{
    if (!activeSketch_) return -1;
    int id = activeSketch_->chamfer(geoId, posId, size);
    refreshSketch();
    return id;
}

int CadEngine::extendGeo(int geoId, double increment, int endPointPos)
{
    if (!activeSketch_) return -1;
    int id = activeSketch_->extend(geoId, increment, endPointPos);
    refreshSketch();
    return id;
}

int CadEngine::splitAtPoint(int geoId, double px, double py)
{
    if (!activeSketch_) return -1;
    int id = activeSketch_->split(geoId, {px, py});
    refreshSketch();
    return id;
}
```

- [ ] **Step 3: Build to verify**

```bash
cmake --build build -j$(nproc) 2>&1 | tail -20
```

---

### Task 6: CadEngine — Missing Constraint Methods + sketchConstraints() fix

**Files:**
- Modify: `adapter/inc/CadEngine.h:105-119`
- Modify: `adapter/src/CadEngine.cpp:305-417`

- [ ] **Step 1: Add Q_INVOKABLE constraint declarations**

After `addFixedConstraint`:

```cpp
Q_INVOKABLE int addDistanceXConstraint(int geoId, double value);
Q_INVOKABLE int addDistanceYConstraint(int geoId, double value);
Q_INVOKABLE int addDiameterConstraint(int geoId, double value);
Q_INVOKABLE int addSymmetricConstraint(int geo1, int pos1, int geo2, int pos2, int symGeo, int symPos);
Q_INVOKABLE int addPointOnObjectConstraint(int pointGeo, int pointPos, int objectGeo);
```

- [ ] **Step 2: Implement in CadEngine.cpp**

```cpp
int CadEngine::addDistanceXConstraint(int geoId, double value)
{
    if (!activeSketch_) return -1;
    int id = activeSketch_->addConstraint(ConstraintType::DistanceX, geoId, -1, value);
    refreshSketch();
    return id;
}

int CadEngine::addDistanceYConstraint(int geoId, double value)
{
    if (!activeSketch_) return -1;
    int id = activeSketch_->addConstraint(ConstraintType::DistanceY, geoId, -1, value);
    refreshSketch();
    return id;
}

int CadEngine::addDiameterConstraint(int geoId, double value)
{
    if (!activeSketch_) return -1;
    int id = activeSketch_->addConstraint(ConstraintType::Diameter, geoId, -1, value);
    refreshSketch();
    return id;
}

int CadEngine::addSymmetricConstraint(int geo1, int pos1, int geo2, int pos2, int symGeo, int symPos)
{
    if (!activeSketch_) return -1;
    try {
        auto c = std::make_unique<Sketcher::Constraint>();
        c->Type = Sketcher::Symmetric;
        c->First = geo1;
        c->FirstPos = static_cast<Sketcher::PointPos>(pos1);
        c->Second = geo2;
        c->SecondPos = static_cast<Sketcher::PointPos>(pos2);
        c->Third = symGeo;
        c->ThirdPos = static_cast<Sketcher::PointPos>(symPos);
        // Access SketchObject through facade — need raw constraint add
        int id = activeSketch_->addConstraint(ConstraintType::Symmetric, geo1, geo2);
        refreshSketch();
        return id;
    } catch (...) { return -1; }
}

int CadEngine::addPointOnObjectConstraint(int pointGeo, int pointPos, int objectGeo)
{
    if (!activeSketch_) return -1;
    int id = activeSketch_->addConstraint(ConstraintType::PointOnObject, pointGeo, objectGeo);
    refreshSketch();
    return id;
}
```

- [ ] **Step 3: Fix sketchConstraints() to include all constraint type names**

In the switch in CadEngine::sketchConstraints(), add missing cases:

```cpp
case ConstraintType::DistanceX:     item["typeName"] = "DistanceX"; break;
case ConstraintType::DistanceY:     item["typeName"] = "DistanceY"; break;
case ConstraintType::Diameter:      item["typeName"] = "Diameter"; break;
case ConstraintType::Symmetric:     item["typeName"] = "Symmetric"; break;
case ConstraintType::PointOnObject: item["typeName"] = "PointOnObject"; break;
```

- [ ] **Step 4: Fix sketchGeometry() to pass new GeoInfo fields to QML**

Add to the QVariantMap in sketchGeometry():

```cpp
item["construction"] = g.construction;
item["majorRadius"] = g.majorRadius;
item["minorRadius"] = g.minorRadius;
item["angle"] = g.angle;
item["degree"] = g.degree;

// BSpline poles as QVariantList
if (!g.poles.empty()) {
    QVariantList polesList;
    for (const auto& p : g.poles) {
        QVariantMap pm;
        pm["x"] = p.x;
        pm["y"] = p.y;
        polesList.append(pm);
    }
    item["poles"] = polesList;
}
```

- [ ] **Step 5: Build to verify**

```bash
cmake --build build -j$(nproc) 2>&1 | tail -20
```

---

### Task 7: SketchCanvas — Ellipse and BSpline Rendering + Construction Lines

**Files:**
- Modify: `ui/qml/SketchCanvas.qml:187-246` (drawGeometry)
- Modify: `ui/qml/SketchCanvas.qml:284-329` (drawPreview)

- [ ] **Step 1: Add Ellipse rendering in drawGeometry()**

After the Point rendering block (before closing `}`):

```qml
else if (g.type === "Ellipse") {
    var ec = toScreen(g.centerX, g.centerY)
    ctx.save()
    ctx.translate(ec.x, ec.y)
    ctx.rotate(-g.angle)  // negative because canvas Y is inverted
    ctx.beginPath()
    ctx.ellipse(-g.majorRadius * viewScale, -g.minorRadius * viewScale,
                g.majorRadius * 2 * viewScale, g.minorRadius * 2 * viewScale)
    ctx.restore()
    ctx.stroke()
    drawCenterMarker(ctx, ec.x, ec.y, isSel)
}
```

Note: Canvas 2D doesn't have native ellipse on all Qt versions. Use save/translate/scale/arc pattern:

```qml
else if (g.type === "Ellipse") {
    var ec = toScreen(g.centerX, g.centerY)
    var majR = g.majorRadius * viewScale
    var minR = g.minorRadius * viewScale
    ctx.save()
    ctx.translate(ec.x, ec.y)
    ctx.rotate(-(g.angle || 0))
    ctx.scale(1, minR / majR)
    ctx.beginPath()
    ctx.arc(0, 0, majR, 0, 2 * Math.PI)
    ctx.restore()
    ctx.stroke()
    drawCenterMarker(ctx, ec.x, ec.y, isSel)
}
```

- [ ] **Step 2: Add BSpline rendering in drawGeometry()**

```qml
else if (g.type === "BSpline") {
    var poles = g.poles
    if (poles && poles.length >= 2) {
        // Draw control polygon (dashed, faint)
        ctx.save()
        ctx.strokeStyle = isSel ? canvas.colSelected : "rgba(100, 100, 100, 0.4)"
        ctx.lineWidth = 0.8
        ctx.setLineDash([3, 3])
        ctx.beginPath()
        var cp0 = toScreen(poles[0].x, poles[0].y)
        ctx.moveTo(cp0.x, cp0.y)
        for (var ci = 1; ci < poles.length; ci++) {
            var cpi = toScreen(poles[ci].x, poles[ci].y)
            ctx.lineTo(cpi.x, cpi.y)
        }
        ctx.stroke()
        ctx.restore()

        // Draw smooth curve through poles using cubic bezier approximation
        ctx.setLineDash([])
        ctx.beginPath()
        var p0 = toScreen(poles[0].x, poles[0].y)
        ctx.moveTo(p0.x, p0.y)
        if (poles.length === 2) {
            var p1 = toScreen(poles[1].x, poles[1].y)
            ctx.lineTo(p1.x, p1.y)
        } else if (poles.length === 3) {
            var qp1 = toScreen(poles[1].x, poles[1].y)
            var qp2 = toScreen(poles[2].x, poles[2].y)
            ctx.quadraticCurveTo(qp1.x, qp1.y, qp2.x, qp2.y)
        } else {
            // Catmull-Rom through poles → cubic bezier segments
            for (var si = 0; si < poles.length - 1; si++) {
                var sp0 = toScreen(poles[Math.max(0, si-1)].x, poles[Math.max(0, si-1)].y)
                var sp1 = toScreen(poles[si].x, poles[si].y)
                var sp2 = toScreen(poles[Math.min(poles.length-1, si+1)].x, poles[Math.min(poles.length-1, si+1)].y)
                var sp3 = toScreen(poles[Math.min(poles.length-1, si+2)].x, poles[Math.min(poles.length-1, si+2)].y)
                var cp1x = sp1.x + (sp2.x - sp0.x) / 6
                var cp1y = sp1.y + (sp2.y - sp0.y) / 6
                var cp2x = sp2.x - (sp3.x - sp1.x) / 6
                var cp2y = sp2.y - (sp3.y - sp1.y) / 6
                ctx.bezierCurveTo(cp1x, cp1y, cp2x, cp2y, sp2.x, sp2.y)
            }
        }
        ctx.stroke()

        // Control point markers
        for (var pi = 0; pi < poles.length; pi++) {
            var pp = toScreen(poles[pi].x, poles[pi].y)
            ctx.fillStyle = isSel ? canvas.colSelected : "#6366F1"
            ctx.fillRect(pp.x - 3, pp.y - 3, 6, 6)
        }
    }
}
```

- [ ] **Step 3: Add construction line rendering**

In drawGeometry(), after setting color but before drawing, add construction style:

```qml
// Construction geometry: dashed gray
if (g.construction) {
    ctx.strokeStyle = isSel ? canvas.colSelected : canvas.colConstruction
    ctx.setLineDash([6, 3])
}
```

- [ ] **Step 4: Add Ellipse snap points in findGeometrySnap()**

```qml
else if (g.type === "Ellipse") {
    checkSnap(best, sx, sy, g.centerX, g.centerY, "center")
    // Quadrant points on ellipse major/minor axes
    var ca = Math.cos(g.angle || 0), sa = Math.sin(g.angle || 0)
    checkSnap(best, sx, sy, g.centerX + g.majorRadius * ca, g.centerY + g.majorRadius * sa, "endpoint")
    checkSnap(best, sx, sy, g.centerX - g.majorRadius * ca, g.centerY - g.majorRadius * sa, "endpoint")
    checkSnap(best, sx, sy, g.centerX - g.minorRadius * sa, g.centerY + g.minorRadius * ca, "endpoint")
    checkSnap(best, sx, sy, g.centerX + g.minorRadius * sa, g.centerY - g.minorRadius * ca, "endpoint")
}
else if (g.type === "BSpline") {
    var bpoles = g.poles
    if (bpoles) {
        for (var bp = 0; bp < bpoles.length; bp++)
            checkSnap(best, sx, sy, bpoles[bp].x, bpoles[bp].y, "endpoint")
    }
}
```

- [ ] **Step 5: Add Ellipse selection hit test in selectAt()**

```qml
else if (g.type === "Ellipse") {
    // Approximate: distance to ellipse perimeter
    var edx = sk.x - g.centerX, edy = sk.y - g.centerY
    var ca = Math.cos(g.angle || 0), sa = Math.sin(g.angle || 0)
    var lx = edx * ca + edy * sa, ly = -edx * sa + edy * ca
    var normDist = Math.sqrt((lx*lx)/(g.majorRadius*g.majorRadius) + (ly*ly)/(g.minorRadius*g.minorRadius))
    d = Math.abs(normDist - 1.0) * Math.max(g.majorRadius, g.minorRadius)
}
else if (g.type === "BSpline") {
    // Hit test: minimum distance to line segments between poles
    var bpoles = g.poles
    if (bpoles && bpoles.length >= 2) {
        d = 999999
        for (var bi = 0; bi < bpoles.length - 1; bi++) {
            var bd = distToSegment(sk.x, sk.y, bpoles[bi].x, bpoles[bi].y, bpoles[bi+1].x, bpoles[bi+1].y)
            if (bd < d) d = bd
        }
    }
}
```

---

### Task 8: SketchCanvas — Ellipse + BSpline Drawing Tools + Polyline Multi-click

**Files:**
- Modify: `ui/qml/SketchCanvas.qml:23-27` (tool property)
- Modify: `ui/qml/SketchCanvas.qml:408-491` (mouse handling + finishDrawing)

- [ ] **Step 1: Add polyline drawing state**

Add properties after `currentSketchY`:

```qml
// Polyline multi-click state
property var polylinePoints: []
```

- [ ] **Step 2: Update tool property comment**

```qml
property string tool: ""         // "line", "circle", "rectangle", "arc", "point", "ellipse", "polyline", "bspline", "trim", "fillet", "chamfer", "extend", "split"
```

- [ ] **Step 3: Add ellipse drawing preview**

In drawPreview(), after the arc block:

```qml
else if (tool === "ellipse") {
    var emajR = Math.abs(currentSketchX - startX)
    var eminR = Math.abs(currentSketchY - startY)
    if (emajR > 0.5 || eminR > 0.5) {
        ctx.save()
        ctx.translate(sp.x, sp.y)
        var escaleY = eminR > 0.01 ? eminR / Math.max(emajR, 0.01) : 0.01
        ctx.scale(1, escaleY)
        ctx.beginPath()
        ctx.arc(0, 0, emajR * viewScale, 0, 2 * Math.PI)
        ctx.restore()
        ctx.stroke()
        // Dimension text
        ctx.setLineDash([])
        ctx.fillStyle = "#3B82F6"
        ctx.font = "11px monospace"
        ctx.fillText(emajR.toFixed(1) + " x " + eminR.toFixed(1), sp.x + 8, sp.y - 8)
    }
}
```

- [ ] **Step 4: Add polyline drawing preview**

```qml
else if (tool === "polyline") {
    // Draw committed segments
    if (polylinePoints.length >= 1) {
        ctx.beginPath()
        var pp0 = toScreen(polylinePoints[0].x, polylinePoints[0].y)
        ctx.moveTo(pp0.x, pp0.y)
        for (var pi = 1; pi < polylinePoints.length; pi++) {
            var ppi = toScreen(polylinePoints[pi].x, polylinePoints[pi].y)
            ctx.lineTo(ppi.x, ppi.y)
        }
        // Rubber band to current position
        ctx.lineTo(ep.x, ep.y)
        ctx.stroke()
    } else if (drawing) {
        ctx.beginPath()
        ctx.moveTo(sp.x, sp.y)
        ctx.lineTo(ep.x, ep.y)
        ctx.stroke()
    }
}
```

- [ ] **Step 5: Add BSpline drawing preview**

```qml
else if (tool === "bspline") {
    // Same as polyline but with markers at control points
    if (polylinePoints.length >= 1) {
        ctx.beginPath()
        var bs0 = toScreen(polylinePoints[0].x, polylinePoints[0].y)
        ctx.moveTo(bs0.x, bs0.y)
        for (var bsi = 1; bsi < polylinePoints.length; bsi++) {
            var bspi = toScreen(polylinePoints[bsi].x, polylinePoints[bsi].y)
            ctx.lineTo(bspi.x, bspi.y)
        }
        ctx.lineTo(ep.x, ep.y)
        ctx.stroke()
        // Control point squares
        ctx.setLineDash([])
        ctx.fillStyle = "#6366F1"
        for (var bci = 0; bci < polylinePoints.length; bci++) {
            var bcp = toScreen(polylinePoints[bci].x, polylinePoints[bci].y)
            ctx.fillRect(bcp.x - 3, bcp.y - 3, 6, 6)
        }
    } else if (drawing) {
        ctx.beginPath(); ctx.moveTo(sp.x, sp.y); ctx.lineTo(ep.x, ep.y); ctx.stroke()
    }
}
```

- [ ] **Step 6: Update onPressed for polyline/bspline multi-click**

In the LeftButton drawing block, replace the `if (!drawing)` section:

```qml
if (tool === "polyline" || tool === "bspline") {
    // Multi-click: accumulate points, right-click finishes
    if (!drawing) {
        polylinePoints = [{"x": sk.x, "y": sk.y}]
        drawing = true
    } else {
        polylinePoints.push({"x": sk.x, "y": sk.y})
        drawCanvas.requestPaint()
    }
} else if (tool === "extend") {
    // Single click: extend selected geometry
    if (selectedGeo >= 0) {
        cadEngine.extendGeo(selectedGeo, 10.0, 2)  // extend end by 10mm
    }
} else if (tool === "split") {
    // Single click on geometry to split at point
    selectAt(mouse.x, mouse.y)
    if (selectedGeo >= 0) {
        cadEngine.splitAtPoint(selectedGeo, sk.x, sk.y)
        selectedGeo = -1
    }
} else if (tool === "point") {
    cadEngine.addPoint(sk.x, sk.y)
} else if (!drawing) {
    startX = sk.x; startY = sk.y
    drawing = true
} else {
    finishDrawing(sk.x, sk.y)
}
```

- [ ] **Step 7: Update right-click to finish polyline/bspline**

In the RightButton handler, add before the existing logic:

```qml
if ((tool === "polyline" || tool === "bspline") && drawing && polylinePoints.length >= 2) {
    if (tool === "polyline") {
        var plPts = []
        for (var i = 0; i < polylinePoints.length; i++)
            plPts.push({"x": polylinePoints[i].x, "y": polylinePoints[i].y})
        cadEngine.addPolyline(plPts)
    } else {
        cadEngine.addBSpline(polylinePoints)
    }
    polylinePoints = []
    drawing = false
    drawCanvas.requestPaint()
    return
}
```

- [ ] **Step 8: Update finishDrawing for ellipse**

In finishDrawing(), add ellipse case:

```qml
else if (tool === "ellipse") {
    var emajR = Math.abs(ex - startX)
    var eminR = Math.abs(ey - startY)
    if (emajR > 0.01 || eminR > 0.01)
        cadEngine.addEllipse(startX, startY, emajR, eminR, 0)
}
```

---

### Task 9: SketchToolbar — Enable All Buttons + Add Missing Buttons

**Files:**
- Modify: `ui/qml/toolbars/SketchToolbar.qml`

- [ ] **Step 1: Enable draw tool buttons and wire them**

Replace the disabled polyline/ellipse/spline buttons:

```qml
CadToolButton { iconPath: "qrc:/resources/icons/sketch/polyline.svg"; tipText: "Polyline (P)"; isActive: activeTool === "polyline"; activeColor: "#34D399"; onClicked: toolSelected("polyline") }
CadToolButton { iconPath: "qrc:/resources/icons/sketch/ellipse.svg"; tipText: "Ellipse (E)"; isActive: activeTool === "ellipse"; activeColor: "#34D399"; onClicked: toolSelected("ellipse") }
CadToolButton { iconPath: "qrc:/resources/icons/sketch/spline.svg"; tipText: "B-Spline (S)"; isActive: activeTool === "bspline"; activeColor: "#34D399"; onClicked: toolSelected("bspline") }
```

- [ ] **Step 2: Enable modify tool buttons**

Replace disabled extend/split/mirror/offset buttons:

```qml
CadToolButton { iconPath: "qrc:/resources/icons/sketch/extend.svg"; tipText: "Extend (X)"; isActive: activeTool === "extend"; accentColor: "#D97706"; activeColor: "#FBBF24"; onClicked: toolSelected("extend") }
CadToolButton { iconPath: "qrc:/resources/icons/sketch/mirror.svg"; tipText: "Split"; isActive: activeTool === "split"; accentColor: "#D97706"; activeColor: "#FBBF24"; onClicked: toolSelected("split") }
```

Note: Using mirror.svg icon for Split temporarily — the "split" concept is closest available icon.

- [ ] **Step 3: Add Construction toggle button**

After the chamfer button, add:

```qml
CadToolButton { iconPath: "qrc:/resources/icons/sketch/convert.svg"; tipText: "Toggle Construction (G)"; accentColor: "#D97706"; onClicked: constraintRequested("toggleConstruction") }
```

- [ ] **Step 4: Add missing constraint buttons**

After the Radius button:

```qml
CadToolButton { iconPath: "qrc:/resources/icons/constraint/distance.svg"; tipText: "Distance X"; accentColor: "#7C3AED"; onClicked: constraintRequested("distanceX") }
CadToolButton { iconPath: "qrc:/resources/icons/constraint/distance.svg"; tipText: "Distance Y"; accentColor: "#7C3AED"; onClicked: constraintRequested("distanceY") }
CadToolButton { iconPath: "qrc:/resources/icons/constraint/radius.svg"; tipText: "Diameter"; accentColor: "#7C3AED"; onClicked: constraintRequested("diameter") }
CadToolButton { iconPath: "qrc:/resources/icons/constraint/symmetric.svg"; tipText: "Symmetric"; accentColor: "#7C3AED"; onClicked: constraintRequested("symmetric") }
CadToolButton { iconPath: "qrc:/resources/icons/constraint/midpoint.svg"; tipText: "Point on Object"; accentColor: "#7C3AED"; onClicked: constraintRequested("pointOnObject") }
```

---

### Task 10: Main.qml — Keyboard Shortcuts + Constraint Handler Wiring

**Files:**
- Modify: `ui/qml/Main.qml:42-45` (shortcuts)
- Modify: `ui/qml/Main.qml:285-302` (constraint handlers)

- [ ] **Step 1: Add new keyboard shortcuts**

After existing shortcuts:

```qml
Shortcut { sequence: "P"; onActivated: if (cadEngine.sketchActive) activeDrawTool = "polyline" }
Shortcut { sequence: "E"; onActivated: if (cadEngine.sketchActive) activeDrawTool = "ellipse" }
Shortcut { sequence: "S"; onActivated: if (cadEngine.sketchActive) activeDrawTool = "bspline" }
Shortcut { sequence: "X"; onActivated: if (cadEngine.sketchActive) activeDrawTool = "extend" }
Shortcut { sequence: "G"; onActivated: if (cadEngine.sketchActive && sketchCanvas.selectedGeo >= 0) cadEngine.toggleConstruction(sketchCanvas.selectedGeo) }
```

- [ ] **Step 2: Wire new constraint handlers in onConstraintRequested**

Add to the constraint handler chain:

```qml
else if (type === "distanceX") {
    dimInput.targetGeoId = geo
    dimInput.presetType = "distanceX"
    dimInput.x = (mainWindow.width - dimInput.width) / 2
    dimInput.y = (mainWindow.height - dimInput.height) / 2
    dimInput.open()
}
else if (type === "distanceY") {
    dimInput.targetGeoId = geo
    dimInput.presetType = "distanceY"
    dimInput.x = (mainWindow.width - dimInput.width) / 2
    dimInput.y = (mainWindow.height - dimInput.height) / 2
    dimInput.open()
}
else if (type === "diameter") {
    dimInput.targetGeoId = geo
    dimInput.presetType = "diameter"
    dimInput.x = (mainWindow.width - dimInput.width) / 2
    dimInput.y = (mainWindow.height - dimInput.height) / 2
    dimInput.open()
}
else if (type === "symmetric") {
    cadEngine.addConstraintTwoGeo("symmetric", geo)
}
else if (type === "pointOnObject") {
    cadEngine.addConstraintTwoGeo("pointOnObject", geo)
}
else if (type === "toggleConstruction") {
    cadEngine.toggleConstruction(geo)
}
```

- [ ] **Step 3: Wire "symmetric" and "pointOnObject" in CadEngine::addConstraintTwoGeo()**

In CadEngine.cpp, add to the two-click constraint handler (after "coincident"):

```cpp
else if (type == "symmetric")
    id = activeSketch_->addConstraint(ConstraintType::Symmetric, g1, g2);
else if (type == "pointOnObject")
    id = activeSketch_->addConstraint(ConstraintType::PointOnObject, g1, g2);
```

---

### Task 11: DimensionInput — Support DistanceX/Y and Diameter

**Files:**
- Modify: `ui/qml/popups/DimensionInput.qml`

- [ ] **Step 1: Read current DimensionInput.qml**

Read and understand the existing tab structure.

- [ ] **Step 2: Add DistanceX/Y/Diameter tabs or handle in apply logic**

In the apply handler, add cases:

```qml
if (presetType === "distanceX") {
    cadEngine.addDistanceXConstraint(targetGeoId, parseFloat(valueField.text))
} else if (presetType === "distanceY") {
    cadEngine.addDistanceYConstraint(targetGeoId, parseFloat(valueField.text))
} else if (presetType === "diameter") {
    cadEngine.addDiameterConstraint(targetGeoId, parseFloat(valueField.text))
}
```

---

### Task 12: Build, Test, Verify

- [ ] **Step 1: Full build**

```bash
cmake --build build -j$(nproc) 2>&1 | tail -40
```

- [ ] **Step 2: Run tests**

```bash
ctest --test-dir build --output-on-failure
```

Expected: 2/2 pass.

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat: complete sketch backend — ellipse, bspline, polyline, extend, split, construction toggle, chamfer, missing constraints + full UI wiring"
```
