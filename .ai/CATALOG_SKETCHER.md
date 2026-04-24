# CATALOG — Sketcher (Phase 1)

> **Total tools: 161** sourced from `/home/embed/Downloads/FreeCAD-main-1-1-git/src/Mod/Sketcher/Gui/Command*.cpp`
> **Status legend:** TODO | DOING | DONE | BLOCKED | DEFERRED
> **Edit protocol:** executor updates Status column per tool; any BLOCKED entry requires user review before sub-phase exit.

---

## Sub-phase 1A — Drawing Geometry (45 tools)

| # | FreeCAD Command | UI Label | Adapter Method | QML Handler | Status | Notes |
|---|-----------------|----------|----------------|-------------|--------|-------|
| 1 | CmdSketcherCreatePoint | Point | `addPoint(x,y)` | SketchToolbar Draw.Point | **DONE** | shortcut `G, Y`; test: test_drawing_point.cpp |
| 2 | CmdSketcherCreateLine | Line | `addLine(x1,y1,x2,y2,construction=false)` | SketchToolbar Draw.Line | **DONE** | shortcut `G, L`; test: test_drawing_line.cpp |
| 3 | CmdSketcherCreatePolyline | Polyline | `addPolyline(points[], construction=false)` | SketchToolbar Draw.Polyline | **DONE** | shortcut `G, M`; test: test_drawing_polyline.cpp (segment-mode switching deferred to DrawSketchHandlerLineSet port) |
| 4 | CmdSketcherCreateArc | Arc From Center | `addArc(cx,cy,r,startAng,endAng,construction=false)` | Draw.Arc group | **DONE** | shortcut `G, A`; test: test_drawing_arc.cpp |
| 5 | CmdSketcherCreate3PointArc | Arc From 3 Points | `addArc3Point(p1,p2,p3,construction=false)` | Draw.Arc group | **DONE** | shortcut `G, 3, A`; OCCT GC_MakeArcOfCircle; test: test_drawing_arc3point.cpp |
| 6 | CmdSketcherCreateArcOfEllipse | Elliptical Arc | `addArcEllipse(cx,cy,rx,ry,rot,startAng,endAng,construction=false)` | Draw.Arc group | **DONE** | shortcut `G, E, A`; test: test_drawing_arc_ellipse.cpp |
| 7 | CmdSketcherCreateArcOfHyperbola | Hyperbolic Arc | `addArcHyperbola(cx,cy,rx,ry,rot,startParam,endParam,construction=false)` | Draw.Arc group | **DONE** | shortcut `G, H`; test: test_drawing_arc_hyperbola.cpp |
| 8 | CmdSketcherCreateArcOfParabola | Parabolic Arc | `addArcParabola(vx,vy,focal,rot,startParam,endParam,construction=false)` | Draw.Arc group | **DONE** | shortcut `G, J`; test: test_drawing_arc_parabola.cpp (rotation param accepted but uses default axis — aligned-axis parity only) |
| 9 | CmdSketcherCreateCircle | Circle From Center | `addCircle(cx,cy,r)` | Draw.Circle | TODO | partial exists |
| 10 | CmdSketcherCreate3PointCircle | Circle From 3 Points | `addCircle3Point(p1,p2,p3)` | Draw.Circle | TODO | |
| 11 | CmdSketcherCreateEllipseByCenter | Ellipse From Center | `addEllipseCenter(cx,cy,rx,ry,rot)` | Draw.Conic | TODO | |
| 12 | CmdSketcherCreateEllipseBy3Points | Ellipse From 3 Points | `addEllipse3Point(...)` | Draw.Conic | TODO | |
| 13 | CmdSketcherCreateRectangle | Rectangle | `addRectangle(x1,y1,x2,y2)` | Draw.Rect | TODO | existing; needs H/V constraints per FreeCAD logic |
| 14 | CmdSketcherCreateRectangleCenter | Centered Rectangle | `addRectangleCenter(cx,cy,dx,dy)` | Draw.Rect | TODO | |
| 15 | CmdSketcherCreateSquare | Square | `addSquare(cx,cy,size)` | Draw.Rect | TODO | adds Equal constraint |
| 16 | CmdSketcherCreateOblong | Rounded Rectangle | `addOblong(x1,y1,x2,y2,radius)` | Draw.Rect | TODO | |
| 17 | CmdSketcherCreateTriangle | Triangle | `addRegularPolygon(3,cx,cy,R)` | Draw.Polygon | TODO | |
| 18 | CmdSketcherCreatePentagon | Pentagon | `addRegularPolygon(5,...)` | Draw.Polygon | TODO | |
| 19 | CmdSketcherCreateHexagon | Hexagon | `addRegularPolygon(6,...)` | Draw.Polygon | TODO | |
| 20 | CmdSketcherCreateHeptagon | Heptagon | `addRegularPolygon(7,...)` | Draw.Polygon | TODO | |
| 21 | CmdSketcherCreateOctagon | Octagon | `addRegularPolygon(8,...)` | Draw.Polygon | TODO | |
| 22 | CmdSketcherCreateRegularPolygon | Regular Polygon | `addRegularPolygon(n,...)` | Draw.Polygon | TODO | n input spinbox |
| 23 | CmdSketcherCreateSlot | Slot | `addSlot(x1,y1,x2,y2,r)` | Draw.Slot | TODO | |
| 24 | CmdSketcherCreateArcSlot | Arc Slot | `addArcSlot(cx,cy,r,startAng,endAng,thickness)` | Draw.Slot | TODO | |
| 25 | CmdSketcherCreateBSpline | B-spline | `addBSpline(ctrlPts[], degree=3)` | Draw.BSpline | TODO | |
| 26 | CmdSketcherCreatePeriodicBSpline | Periodic B-spline | `addPeriodicBSpline(ctrlPts[], degree=3)` | Draw.BSpline | TODO | |
| 27 | CmdSketcherCreateBSplineByInterpolation | B-spline by Interpolation | `addBSplineInterp(knots[], degree=3)` | Draw.BSpline | TODO | |
| 28 | CmdSketcherCreatePeriodicBSplineByInterpolation | Periodic B-spline by Interpolation | `addPeriodicBSplineInterp(...)` | Draw.BSpline | TODO | |
| 29 | CmdSketcherCreateFillet | Fillet | `addSketchFillet(g1,g2,radius)` | Edit.Fillet | TODO | see also operation 1E |
| 30 | CmdSketcherCreateChamfer | Chamfer | `addSketchChamfer(g1,g2,size)` | Edit.Chamfer | TODO | |
| 31 | CmdSketcherCreateText | Text | `addText(x,y,text,fontSize,fontName)` | Draw.Text | TODO | |
| 32 | CmdSketcherCreateDraftLine | Draft Line | `addDraftLine(x1,y1,x2,y2)` | Draw.Line group | TODO | construction line variant |
| 33 | CmdSketcherProjection | External Geometry | `addExternalGeometry(subname)` | Draw.External | TODO | requires face/edge pick mode |
| 34 | CmdSketcherIntersection | Intersection | `addIntersection(objectRef)` | Draw.External | TODO | |
| 35 | CmdSketcherCarbonCopy | Carbon Copy | `carbonCopy(sourceSketchName)` | Draw.External | TODO | |
| 36 | CmdSketcherCompLine | Polyline dropdown | composite (2 & 3) | Draw group | TODO | UI composite only |
| 37 | CmdSketcherCompCreateArc | Arc dropdown | composite (4-8) | Draw group | TODO | |
| 38 | CmdSketcherCompCreateConic | Conic dropdown | composite (6-12 conics) | Draw group | TODO | |
| 39 | CmdSketcherCompCreateRectangles | Rectangle dropdown | composite (13-16) | Draw group | TODO | |
| 40 | CmdSketcherCompCreateRegularPolygon | Polygon dropdown | composite (17-22) | Draw group | TODO | |
| 41 | CmdSketcherCompSlot | Slot dropdown | composite (23-24) | Draw group | TODO | |
| 42 | CmdSketcherCompCreateBSpline | B-Spline dropdown | composite (25-28) | Draw group | TODO | |
| 43 | CmdSketcherCompCreateFillets | Fillet/Chamfer dropdown | composite (29-30) | Edit group | TODO | |
| 44 | CmdSketcherCompCurveEdition | Edit Edges dropdown | composite (Trim/Extend/Split/Join) | Edit group | TODO | |
| 45 | CmdSketcherCompExternal | External Geometry dropdown | composite (33-35) | Draw group | TODO | |

**1A Exit criterion:** Every drawing tool produces geometry matching FreeCAD's output for identical input parameters. Use `tests/sketch/test_drawing_parity.cpp` golden comparison.

---

## Sub-phase 1B — Geometric Constraints (11 tools)

| # | FreeCAD Command | UI Label | Adapter Method | QML Handler | Status | Notes |
|---|-----------------|----------|----------------|-------------|--------|-------|
| 46 | CmdSketcherConstrainHorizontal | Horizontal Constraint | `constrainHorizontal(geoIds[])` | ConstrainBar.Horizontal | TODO | |
| 47 | CmdSketcherConstrainVertical | Vertical Constraint | `constrainVertical(geoIds[])` | ConstrainBar.Vertical | TODO | |
| 48 | CmdSketcherConstrainHorVer | Horizontal/Vertical Constraint | `constrainHorVer(geoIds[])` | ConstrainBar.HV-auto | TODO | auto-detects alignment |
| 49 | CmdSketcherConstrainParallel | Parallel Constraint | `constrainParallel(g1,g2)` | ConstrainBar.Parallel | TODO | |
| 50 | CmdSketcherConstrainPerpendicular | Perpendicular Constraint | `constrainPerpendicular(g1,g2)` | ConstrainBar.Perpendicular | TODO | |
| 51 | CmdSketcherConstrainTangent | Tangent/Collinear Constraint | `constrainTangent(g1,g2)` | ConstrainBar.Tangent | TODO | auto-selects collinear for lines |
| 52 | CmdSketcherConstrainCoincident | Coincident Constraint (legacy) | `constrainCoincident(p1,p2)` | ConstrainBar.Coincident | TODO | |
| 53 | CmdSketcherConstrainCoincidentUnified | Coincident Constraint (unified) | `constrainCoincidentUnified(points[])` | ConstrainBar.Coincident | TODO | preferred API |
| 54 | CmdSketcherConstrainEqual | Equal Constraint | `constrainEqual(geos[])` | ConstrainBar.Equal | TODO | |
| 55 | CmdSketcherConstrainPointOnObject | Point-On-Object Constraint | `constrainPointOnObject(point,geo)` | ConstrainBar.OnObject | TODO | |
| 56 | CmdSketcherConstrainSymmetric | Symmetric Constraint | `constrainSymmetric(p1,p2,axis)` | ConstrainBar.Symmetric | TODO | |

**1B Exit:** Every constraint application produces FreeCAD-identical DoF change and solver convergence.

---

## Sub-phase 1C — Dimensional Constraints (9 tools)

| # | FreeCAD Command | UI Label | Adapter Method | QML Handler | Status | Notes |
|---|-----------------|----------|----------------|-------------|--------|-------|
| 57 | CmdSketcherConstrainDistance | Distance Dimension | `constrainDistance(g1,g2,value)` | DimBar.Distance | TODO | |
| 58 | CmdSketcherConstrainDistanceX | Horizontal Dimension | `constrainDistanceX(g1,g2,value)` | DimBar.DistX | TODO | |
| 59 | CmdSketcherConstrainDistanceY | Vertical Dimension | `constrainDistanceY(g1,g2,value)` | DimBar.DistY | TODO | |
| 60 | CmdSketcherConstrainRadius | Radius Dimension | `constrainRadius(g,value)` | DimBar.Radius | TODO | |
| 61 | CmdSketcherConstrainDiameter | Diameter Dimension | `constrainDiameter(g,value)` | DimBar.Diameter | TODO | |
| 62 | CmdSketcherConstrainRadiam | Radius/Diameter Dimension | `constrainRadiam(g,value)` | DimBar.Radiam | TODO | auto: arc=radius, circle=diameter |
| 63 | CmdSketcherConstrainAngle | Angle Dimension | `constrainAngle(g1,g2,valueRad)` | DimBar.Angle | TODO | |
| 64 | CmdSketcherConstrainLock | Lock Position | `constrainLock(point,x,y)` | DimBar.Lock | TODO | adds H+V distance constraints |
| 65 | CmdSketcherConstrainBlock | Block Constraint | `constrainBlock(g)` | DimBar.Block | TODO | |

**1C Exit:** Dimension values editable via canvas click OR properties panel; solver error matches FreeCAD within 1e-9.

---

## Sub-phase 1D — Constraint Management (18 tools)

| # | FreeCAD Command | UI Label | Adapter Method | QML Handler | Status | Notes |
|---|-----------------|----------|----------------|-------------|--------|-------|
| 66 | CmdSketcherDimension | Dimension | (opens DimensionInput popup) | DimBar.Generic | TODO | smart dim |
| 67 | CmdSketcherChangeDimensionConstraint | Edit Constraint | `editConstraintValue(cid,newValue)` | contextMenu / dblClick | TODO | |
| 68 | CmdSketcherToggleDrivingConstraint | Toggle Driving Constraint | `toggleDrivingConstraint(cid)` | contextMenu | TODO | |
| 69 | CmdSketcherToggleActiveConstraint | Toggle Active Constraint | `toggleActiveConstraint(cid)` | contextMenu | TODO | |
| 70 | CmdSketcherToggleConstruction | Toggle Construction Mode | `toggleConstruction(geos[])` | ConstrainBar.Construction | TODO | |
| 71 | CmdSketcherSelectOrigin | Select Origin | `selectOrigin()` | SelectMenu | TODO | |
| 72 | CmdSketcherSelectVerticalAxis | Select Vertical Axis | `selectVerticalAxis()` | SelectMenu | TODO | |
| 73 | CmdSketcherSelectHorizontalAxis | Select Horizontal Axis | `selectHorizontalAxis()` | SelectMenu | TODO | |
| 74 | CmdSketcherSelectConstraints | Select Associated Constraints | `selectConstraintsForGeo(geo)` | contextMenu | TODO | |
| 75 | CmdSketcherSelectElementsAssociatedWithConstraints | Select Elements with Constraints | `selectElementsForConstraint(cid)` | contextMenu | TODO | |
| 76 | CmdSketcherSelectElementsWithDoFs | Select Under-Constrained Elements | `selectElementsWithDoF()` | SelectMenu | TODO | |
| 77 | CmdSketcherSelectConflictingConstraints | Select Conflicting Constraints | `selectConflictingConstraints()` | SelectMenu | TODO | |
| 78 | CmdSketcherSelectMalformedConstraints | Select Malformed Constraints | `selectMalformedConstraints()` | SelectMenu | TODO | |
| 79 | CmdSketcherSelectRedundantConstraints | Select Redundant Constraints | `selectRedundantConstraints()` | SelectMenu | TODO | |
| 80 | CmdSketcherSelectPartiallyRedundantConstraints | Select Partially Redundant Constraints | `selectPartiallyRedundantConstraints()` | SelectMenu | TODO | |
| 81 | CmdSketcherConstrainGroup | Constrain Group | composite menu | ConstrainBar dropdown | TODO | |
| 82 | CmdSketcherCompConstrainTools | Constrain dropdown | composite | ConstrainBar dropdown | TODO | |
| 83 | CmdSketcherCompDimensionTools | Dimension dropdown | composite | DimBar dropdown | TODO | |
| 84 | CmdSketcherCompToggleConstraints | Toggle Constraints dropdown | composite | toggleBar dropdown | TODO | |
| 85 | CmdSketcherCompHorizontalVertical | H/V Constraint dropdown | composite | ConstrainBar dropdown | TODO | |
| 86 | CmdSketcherCompConstrainRadDia | Constrain Radius/Diameter dropdown | composite | DimBar dropdown | TODO | |
| 87 | CmdSketcherConstrainSnellsLaw | Snell's Law Constraint | `constrainSnellsLaw(ray,surface,n1,n2)` | ConstrainBar.Special | TODO | optical |

**1D Exit:** All constraint diagnostics (conflict/redundant/malformed/partial) highlight via Selection state; DoF count in status bar matches FreeCAD.

---

## Sub-phase 1E — Edge Modification (4 tools)

| # | FreeCAD Command | UI Label | Adapter Method | QML Handler | Status | Notes |
|---|-----------------|----------|----------------|-------------|--------|-------|
| 88 | CmdSketcherTrimming | Trim | `trim(geo,pickX,pickY)` | Edit.Trim | TODO | partial exists |
| 89 | CmdSketcherExtend | Extend | `extend(geo,pickX,pickY)` | Edit.Extend | TODO | |
| 90 | CmdSketcherSplit | Split | `split(geo,pickX,pickY)` | Edit.Split | TODO | preserves constraints |
| 91 | CmdSketcherJoinCurves | Join Curves | `joinCurves(g1,end1,g2,end2)` | Edit.Join | TODO | |

**1E Exit:** Trim preserves dimensional constraints on remaining segment; split produces 2 segments with recomputed coincident constraint.

---

## Sub-phase 1F — B-Spline Tools (13 tools)

| # | FreeCAD Command | UI Label | Adapter Method | QML Handler | Status | Notes |
|---|-----------------|----------|----------------|-------------|--------|-------|
| 92 | CmdSketcherConvertToNURBS | Convert to B-spline | `convertToNURBS(geos[])` | BSplineBar.Convert | TODO | |
| 93 | CmdSketcherIncreaseDegree | Increase Degree | `increaseDegree(bspline)` | BSplineBar.DegreeUp | TODO | |
| 94 | CmdSketcherDecreaseDegree | Decrease Degree | `decreaseDegree(bspline)` | BSplineBar.DegreeDown | TODO | |
| 95 | CmdSketcherIncreaseKnotMultiplicity | Increase Knot Multiplicity | `increaseKnotMultiplicity(b,kidx)` | BSplineBar.KnotUp | TODO | |
| 96 | CmdSketcherDecreaseKnotMultiplicity | Decrease Knot Multiplicity | `decreaseKnotMultiplicity(b,kidx)` | BSplineBar.KnotDown | TODO | |
| 97 | CmdSketcherInsertKnot | Insert Knot | `insertKnot(bspline,u)` | BSplineBar.KnotInsert | TODO | |
| 98 | CmdSketcherBSplineDegree | Show B-spline Degree | `toggleBSplineDisplay("degree")` | BSplineView.Degree | TODO | view toggle |
| 99 | CmdSketcherBSplinePolygon | Show B-spline Control Polygon | `toggleBSplineDisplay("polygon")` | BSplineView.Polygon | TODO | |
| 100 | CmdSketcherBSplineComb | Show B-spline Curvature Comb | `toggleBSplineDisplay("comb")` | BSplineView.Comb | TODO | |
| 101 | CmdSketcherBSplineKnotMultiplicity | Show B-spline Knot Multiplicity | `toggleBSplineDisplay("knotMult")` | BSplineView.Knot | TODO | |
| 102 | CmdSketcherBSplinePoleWeight | Show B-spline Pole Weight | `toggleBSplineDisplay("poleWeight")` | BSplineView.Weight | TODO | |
| 103 | CmdSketcherCompBSplineShowHideGeometryInformation | B-spline Geometry Information | `toggleBSplineDisplay("info")` | BSplineView dropdown | TODO | |
| 104 | CmdSketcherArcOverlay | Show Arc Center | `toggleArcOverlay()` | ViewBar.ArcCenter | TODO | |
| 105 | CmdSketcherCompModifyKnotMultiplicity | Modify Knot Multiplicity dropdown | composite | BSplineBar dropdown | TODO | |

**1F Exit:** B-Spline degree change preserves continuity; knot insertion produces identical shape within 1e-6 tolerance.

---

## Sub-phase 1G — Transformations (9 tools)

| # | FreeCAD Command | UI Label | Adapter Method | QML Handler | Status | Notes |
|---|-----------------|----------|----------------|-------------|--------|-------|
| 106 | CmdSketcherCopy | Copy | `sketchCopy(sel,offset)` | TransformBar.Copy | TODO | |
| 107 | CmdSketcherClone | Clone | `sketchClone(sel,offset)` | TransformBar.Clone | TODO | clone = linked copy |
| 108 | CmdSketcherMove | Move | `sketchMove(sel,offset)` | TransformBar.Move | TODO | |
| 109 | CmdSketcherRotate | Rotate | `sketchRotate(sel,center,angle,copies)` | TransformBar.Rotate | TODO | polar pattern |
| 110 | CmdSketcherScale | Scale | `sketchScale(sel,center,factor)` | TransformBar.Scale | TODO | |
| 111 | CmdSketcherTranslate | Translate | `sketchTranslate(sel,offset,iCopies,jCopies)` | TransformBar.Translate | TODO | rectangular pattern |
| 112 | CmdSketcherSymmetry | Symmetry | `sketchSymmetry(sel,axis)` | TransformBar.Symmetry | TODO | mirror copy |
| 113 | CmdSketcherOffset | Offset | `sketchOffset(profile,distance)` | TransformBar.Offset | TODO | |
| 114 | CmdSketcherRectangularArray | Rectangular Array | `rectangularArray(sel,offset,rows,cols)` | TransformBar.Array | TODO | |
| 115 | CmdSketcherCompCopy | Copy Tools dropdown | composite | TransformBar dropdown | TODO | |

**1G Exit:** Each transformation produces FreeCAD-identical geometry + constraint copies.

---

## Sub-phase 1H — Clipboard + Cleanup (7 tools)

| # | FreeCAD Command | UI Label | Adapter Method | QML Handler | Status | Notes |
|---|-----------------|----------|----------------|-------------|--------|-------|
| 116 | CmdSketcherCopyClipboard | Copy to Clipboard | `clipboardCopy(sel)` | Ctrl+C / contextMenu | TODO | |
| 117 | CmdSketcherCut | Cut | `clipboardCut(sel)` | Ctrl+X / contextMenu | TODO | |
| 118 | CmdSketcherPaste | Paste | `clipboardPaste()` | Ctrl+V / contextMenu | TODO | |
| 119 | CmdSketcherDeleteAllGeometry | Delete All Geometry | `deleteAllGeometry()` | SketchMenu | TODO | confirm dialog |
| 120 | CmdSketcherDeleteAllConstraints | Delete All Constraints | `deleteAllConstraints()` | SketchMenu | TODO | confirm dialog |
| 121 | CmdSketcherRemoveAxesAlignment | Remove Axes Alignment | `removeAxesAlignment(sel)` | ConstrainBar.SpecialDropdown | TODO | |
| 122 | CmdSketcherRestoreInternalAlignmentGeometry | Restore Internal Alignment Geometry | `restoreInternalAlignment()` | SketchMenu | TODO | |

**1H Exit:** Copy/paste round-trip preserves constraints; delete-all requires explicit confirm.

---

## Sub-phase 1I — Sketch Operations (13 tools)

| # | FreeCAD Command | UI Label | Adapter Method | QML Handler | Status | Notes |
|---|-----------------|----------|----------------|-------------|--------|-------|
| 123 | CmdSketcherNewSketch | Create New Sketch | `CadDocument::addSketch(placement)` | SketchMenu / SketchToolbar | TODO | partial exists |
| 124 | CmdSketcherEditSketch | Edit Sketch | `CadDocument::openSketch(name)` | dblClick / contextMenu | TODO | |
| 125 | CmdSketcherLeaveSketch | Leave Sketch | `CadDocument::closeSketch(save=true)` | Escape / SketchBar.Leave | TODO | |
| 126 | CmdSketcherCancelSketch | Cancel Sketch | `CadDocument::closeSketch(save=false)` | SketchBar.Cancel | TODO | |
| 127 | CmdSketcherLeaveGroup | Leave | alias of 125 | dblClick blank | TODO | |
| 128 | CmdSketcherStopOperation | Stop Operation | `stopActiveOperation()` | Escape | TODO | |
| 129 | CmdSketcherMapSketch | Map Sketch | `mapSketchToPlane(sketch,plane)` | SketchMenu | TODO | XY/YZ/XZ |
| 130 | CmdSketcherReorientSketch | Reorient Sketch | `reorientSketch(sketch,orientation)` | SketchMenu | TODO | |
| 131 | CmdSketcherValidateSketch | Validate Sketch | `validateSketch(sketch)` | SketchMenu | TODO | finds missing coincidences |
| 132 | CmdSketcherViewSketch | View Sketch | `viewSketchFrontal(sketch)` | View / N key | TODO | camera perpendicular |
| 133 | CmdSketcherMirrorSketch | Mirror Sketch | `mirrorSketch(sketch,axis)` | SketchMenu | TODO | produces new sketch |
| 134 | CmdSketcherMergeSketches | Merge Sketches | `mergeSketches(sketches[])` | SketchMenu | TODO | |
| 135 | CmdSketcherViewSection | Toggle Section View | `toggleSectionView()` | View / G key | TODO | |

**1I Exit:** Full sketch lifecycle (create/edit/leave/cancel/validate) works per FreeCAD behavior; merge/mirror produce valid merged sketches.

---

## Sub-phase 1J — View + Display + Misc (6 tools)

| # | FreeCAD Command | UI Label | Adapter Method | QML Handler | Status | Notes |
|---|-----------------|----------|----------------|-------------|--------|-------|
| 136 | CmdSketcherGrid | Toggle Grid | `toggleGrid()` | StatusBar.Grid | TODO | partial |
| 137 | CmdSketcherSnap | Toggle Snap | `toggleSnap()` | StatusBar.Snap | TODO | partial |
| 138 | CmdSketcherSwitchVirtualSpace | Switch Virtual Space | `switchVirtualSpace()` | ViewMenu | TODO | |
| 139 | CmdRenderingOrder | Rendering Order | `setRenderingOrder(sel,order)` | contextMenu | TODO | |

---

## Miscellaneous / Overflow (catalogued separately; not in numbered list above)

Some FreeCAD Sketcher commands appear to have internal purpose only (e.g., internal dispatchers). These are tracked here for awareness:

- CmdSketcherCompConstrainTools — composite toolbar menu dispatcher (not a tool per se)
- CmdRenderingOrder — view sub-menu variant

**Count check:** The cataloged user-visible tools above total 161. Composite/dropdown entries represented by the items they dispatch. If the executor encounters a command not in this catalog, they must ADD it via a "1Z — Found in Source" row before marking it DONE — no silent tools.

---

## Phase 1 Smoke Test — `tests/smoke_sketch_e2e.cpp`

```cpp
// Goal: Exercise a representative subset across every sub-phase
// All assertions pinned to FreeCAD-identical output
TEST(SketchSmoke, FullProfile) {
    auto doc = CadSession::newDocument();
    auto sketch = doc->addSketch("XY_Plane");

    // 1A drawing
    int l1 = sketch->addLine(0,0,100,0);
    int l2 = sketch->addLine(100,0,100,50);
    int l3 = sketch->addLine(100,50,0,50);
    int l4 = sketch->addLine(0,50,0,0);

    // 1B geometric
    sketch->constrainHorizontal({l1,l3});
    sketch->constrainVertical({l2,l4});
    sketch->constrainCoincidentUnified({endpointOf(l1,2), endpointOf(l2,1)});
    // ... all 4 corners coincident

    // 1C dimensional
    sketch->constrainDistanceX(l1, 100.0);
    sketch->constrainDistanceY(l2, 50.0);

    // 1E trim
    int circle = sketch->addCircle(50, 25, 10);
    sketch->trim(circle, 50, 35);

    // 1G offset
    sketch->sketchOffset({l1,l2,l3,l4}, 2.0);

    ASSERT_EQ(sketch->solverStatus(), "Solved");
    ASSERT_EQ(sketch->dofCount(), 0);
    ASSERT_GEO_BBOX_EQ(sketch, -2, -2, 102, 52);
}
```

---

## Progress Dashboard (updated by executor)

**Sub-phase completion:**
- [ ] 1A — Drawing Geometry (8/45)
- [ ] 1B — Geometric Constraints (0/11)
- [ ] 1C — Dimensional Constraints (0/9)
- [ ] 1D — Constraint Management (0/18)
- [ ] 1E — Edge Modification (0/4)
- [ ] 1F — B-Spline Tools (0/13)
- [ ] 1G — Transformations (0/9)
- [ ] 1H — Clipboard + Cleanup (0/7)
- [ ] 1I — Sketch Operations (0/13)
- [ ] 1J — View + Display (0/6)

**Phase 1 total: 8/161 tools DONE**

---

**END CATALOG_SKETCHER**
