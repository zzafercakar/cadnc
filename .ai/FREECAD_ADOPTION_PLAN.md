# CADNC — FreeCAD Parity Adoption Plan

> **Architect of Record:** Claude (Opus 4.7) + zzafercakar
> **Plan Version:** 2.0 — 2026-04-24 (tightened per user review)
> **Execution Target:** Next session onwards
> **Executor Protocol:** `superpowers:executing-plans`
> **Status:** APPROVED — ready to execute
> **Companion Document:** `.ai/WRAPPER_CONTRACT.md` — strict adapter rules; MUST read before any tool implementation
> **Policy:** Strict. No looseness. Every tool meets 15-point Definition of Done (WRAPPER_CONTRACT § 6). Full frontend AND backend for every tool.

---

## 0. Guiding Principle

> **"Whatever exists in FreeCAD Sketcher, PartDesign, and CAM must exist in CADNC."**

This is a HARD GATE. No tool may be skipped, deferred indefinitely, or substituted with a stub. Every Command registered in FreeCAD's Sketcher/Gui, PartDesign/Gui, and CAM/Gui has a 1:1 QML equivalent wired to the corresponding App-level algorithm via the adapter layer.

**Corollary:** The user shall not have to bug-report missing tools. The spec is open-source FreeCAD itself. If a behavior exists in FreeCAD's source, it must exist in CADNC. Deviations require explicit architectural decision in this plan, not opportunistic omission during implementation.

---

## 1. Architecture Decision

### 1.1 Chosen Path: **QML UI + FreeCAD App-only backend (no FreeCAD Gui)**

```
┌──────────────────────────────────────────────────────────────┐
│ CADNC UI Shell (Qt6 QML)                                     │
│ ui/qml/Main.qml + workbench-specific toolbars/panels         │
│ OccViewport (OCCT AIS) for 3D; SketchCanvas (QML) for 2D     │
├──────────────────────────────────────────────────────────────┤
│ CADNC Adapter (C++)                                          │
│ adapter/: CadEngine, SketchFacade, PartFacade,               │
│           CamFacade (NEW, Python-embedded), NestFacade       │
├──────────────────────────────────────────────────────────────┤
│ FreeCAD App-level Modules (LGPL, unchanged)                  │
│ freecad/Base, App, Materials, Part/App, Sketcher/App,        │
│         PartDesign/App, CAM/App (NEW — copied from 1.2-git)  │
│ + Python scripts: CAMScripts, Path/Op, Path/Dressup,         │
│                   Path/Post/scripts (CODESYS variant added)  │
├──────────────────────────────────────────────────────────────┤
│ OpenCASCADE Kernel (OCCT)                                    │
└──────────────────────────────────────────────────────────────┘
```

### 1.2 What We Do NOT Adopt

- **FreeCAD Gui module** (`src/Gui/`) — 168K LoC; we keep our QML shell
- **Coin3D + Quarter** — we keep OCCT AIS in OccViewport
- **PySide / Pivy** — no FreeCAD Python Gui callbacks; adapter owns UI events
- **MDI architecture** — we stay single-document (SDI)

### 1.3 What We Add

- `freecad/CAM/App/` — copied from `src/Mod/CAM/App/` of `-git` tree
- `freecad/CAM/PathScripts/` (or `CAMScripts/` per 1.2 naming) — Python operation modules
- `freecad/CAM/Path/Op/` — Python operation definitions (Profile, Pocket, Drilling, etc.)
- `freecad/CAM/Path/Dressup/` — Python dressup modules
- `freecad/CAM/Path/Post/scripts/` — 35 post-processor Python scripts
- **Python embedding extension**: `adapter/src/PythonEmbed.cpp` — `Base::Interpreter` wrapper for running CAMScripts from C++

### 1.4 What We Remove

- `cam/` directory (MilCAD CAM, ~5.400 LoC) — entirely replaced by FreeCAD CAM after Phase 3 completion
- Post-Phase-3 cleanup commit deletes `cam/` and updates CMake

---

## 2. Scope Summary

| Workbench | Tool Count | Source of Truth |
|-----------|------------|-----------------|
| **Sketcher** | 161 | `.ai/CATALOG_SKETCHER.md` |
| **PartDesign** | 45 | `.ai/CATALOG_PARTDESIGN.md` |
| **CAM** | 88 + 35 posts | `.ai/CATALOG_CAM.md` |
| **Nesting** | existing (BLF, BBox) | no catalog — standalone |
| **Total user-facing tools** | **294+** | — |

---

## 3. Hard Completion Gates

Each phase has a completion gate that MUST pass before moving to the next phase. No phase exits with "TODO" or "deferred" items on its catalog.

### 3.1 Phase-Exit Checklist (every phase)

1. Every catalog row marked `DONE` (not DOING, not DEFERRED — hard DONE)
2. Per-tool 15-point DoD (WRAPPER_CONTRACT § 6) verified for every catalog row
3. Every tool has a unit test in `tests/parity_suite/<wb>/test_<tool>.cpp` — all passing
4. Phase smoke test (`tests/smoke_<wb>_e2e.cpp`) runs all tools in one scripted session — passing
5. Frontend completeness audit: every FreeCAD Command's toolbar button, menu entry, keyboard shortcut, and tooltip present and identical
6. Backend completeness audit: every Facade method follows WRAPPER_CONTRACT § 2.1 pattern exactly (manual review)
7. `clang-tidy` clean on all `adapter/` and `app/` diffs since last phase
8. `qmllint` clean on all QML diffs
9. `ctest --output-on-failure` exit code 0
10. Git tag `phase-<N>-<wb>-parity` created and pushed
11. User sign-off explicitly requested via summary report; next phase does not start without it

### 3.2 Definition of Done per Tool

**Delegated to WRAPPER_CONTRACT § 6 — the 15-point checklist is the authoritative DoD.**

Summary: A tool is DONE only when it has (1) identified FreeCAD source, (2) analyzed behavior, (3) facade method per § 2.1, (4) error handling per § 2.3, (5) transaction per § 2.5, (6) recompute per § 2.6, (7) Q_INVOKABLE per § 3.1, (8) QML button per § 5.2, (9) icon, (10) tooltip parity, (11) shortcut parity, (12) TaskPanel parity with FreeCAD .ui if applicable, (13) unit test added, (14) test asserts both success AND invalid-input paths, (15) catalog row marked DONE with commit SHA.

**Enforcement:** A PR that claims to complete a tool but fails any of these 15 items is rejected in review. Partial completion → row status `DOING` with comment listing blocking items. No silent relaxation.

---

## 4. Phase Roadmap

### Phase 0 — Discovery Consolidated **(DONE — this plan + catalogs)**

**Deliverables:**
- [x] `.ai/FREECAD_ADOPTION_PLAN.md` (this file)
- [x] `.ai/CATALOG_SKETCHER.md`
- [x] `.ai/CATALOG_PARTDESIGN.md`
- [x] `.ai/CATALOG_CAM.md`
- [x] CLAUDE.md rule "UI must not include FreeCAD headers" removed
- [x] Reference paths updated to `FreeCAD-main-1-1-git/`

### Phase 1 — Sketch Parity (161 tools)

**Goal:** Every Sketcher tool in FreeCAD works identically in CADNC. Full frontend (button + icon + tooltip + shortcut + TaskPanel) AND full backend (facade method + transaction + recompute + error handling + test).
**Duration estimate:** 4-6 sessions (tool-per-commit cadence makes it slower but safer)
**Depends on:** Phase 0
**Catalog:** `.ai/CATALOG_SKETCHER.md`
**Files modified (scope):**
- `adapter/inc/SketchFacade.h`, `adapter/src/SketchFacade.cpp` (extended)
- `adapter/inc/CadEngine.h`, `adapter/src/CadEngine.cpp` (161 new Q_INVOKABLE)
- `ui/qml/toolbars/SketchToolbar.qml` (new full layout replacing current)
- `ui/qml/panels/ConstraintPanel.qml`, `ElementsPanel.qml` (new), `SelectionPanel.qml` (new)
- `ui/qml/dialogs/drawing/*.qml` (17 drawing dialogs)
- `ui/qml/dialogs/constraints/*.qml` (dimension input dialogs)
- `ui/qml/canvases/SketchCanvas.qml` (updated for all drawing handlers)
- `resources/icons/sketcher/*.svg` (~150 icons copied from FreeCAD + attribution)
- `tests/parity_suite/sketch/test_*.cpp` (161 files, one per tool)
- `tests/smoke_sketch_e2e.cpp`

**Sub-phases (ordered by dependency):**

- **1A. Drawing Geometry (45 tools)** — Lines, arcs, circles, ellipses, conics, rectangles, polygons (3-octagon), slots, B-splines, text, draft lines, external geometry, intersection, carbon copy, and composite drop-down tools.
- **1B. Geometric Constraints (11)** — Horizontal, Vertical, HorVer, Parallel, Perpendicular, Tangent, Coincident (unified), Equal, PointOnObject, Symmetric, Block.
- **1C. Dimensional Constraints (9)** — Distance (generic + X + Y), Radius, Diameter, Radiam, Angle, Lock, Unified Dimension, Edit.
- **1D. Constraint Management (18)** — Toggle driving/active/construction; Select origin/axes/constraints/elements/DoF/conflicting/malformed/redundant/partial.
- **1E. Edge Modification (4)** — Trim, Extend, Split, Join Curves.
- **1F. B-Spline Tools (13)** — Convert to NURBS; Degree/knot multiplicity up/down; Insert knot; 7 display toggles (degree, polygon, comb, knot mult, pole weight, info, arc overlay).
- **1G. Transformations (9)** — Copy, Clone, Move, Rotate, Scale, Translate, Symmetry, Offset, Rectangular Array.
- **1H. Clipboard + Cleanup (7)** — Copy/Cut/Paste; Delete all geometry/constraints; Remove axes alignment; Restore internal alignment.
- **1I. Sketch Operations (13)** — New sketch, Edit, Leave, Cancel, Leave group, Stop operation, Map sketch, Reorient, Validate, View, Mirror sketch, Merge sketches, Toggle section view.
- **1J. View & Display (6)** — Toggle grid, Toggle snap, Switch virtual space, Rendering order, Constrain group, Snell's law.

**Phase 1 Exit Gate:**
- All 161 tools in catalog marked `DONE`
- Smoke test: draw rectangle with construction diagonal, add 6 constraints (H/V ×4, equal sides, origin-coincident), trim a segment, offset the profile — must solve to DoF=0 and render identically to FreeCAD.

### Phase 2 — Part Parity (45 tools)

**Goal:** Every PartDesign tool in FreeCAD works identically in CADNC. Full UI TaskPanels matching every field of FreeCAD's `.ui` files.
**Duration estimate:** 3-5 sessions
**Depends on:** Phase 1 complete + git tag `phase-1-sketch-parity` pushed
**Catalog:** `.ai/CATALOG_PARTDESIGN.md`
**Files modified (scope):**
- `adapter/inc/PartFacade.h`, `adapter/src/PartFacade.cpp` (extended; previously partial)
- `adapter/inc/CadEngine.h`, `.cpp` (45 new Q_INVOKABLE)
- `ui/qml/toolbars/PartToolbar.qml` (full layout replacing current)
- `ui/qml/panels/TaskPanel.qml` (new — generic task-dialog host for feature editing)
- `ui/qml/dialogs/features/*.qml` (new: PadTaskPanel, PocketTaskPanel, RevolveTaskPanel, PipeTaskPanel, LoftTaskPanel, HelixTaskPanel, HoleTaskPanel, GrooveTaskPanel, FilletTaskPanel, ChamferTaskPanel, DraftTaskPanel, ThicknessTaskPanel, MirrorTaskPanel, LinearPatternTaskPanel, PolarPatternTaskPanel, ScaledTaskPanel, MultiTransformTaskPanel, BooleanTaskPanel, DatumPlaneTaskPanel, DatumLineTaskPanel, DatumPointTaskPanel, LocalCSTaskPanel, ShapeBinderTaskPanel, SubShapeBinderTaskPanel, CloneTaskPanel, + 8 AdditivePrimitive dialogs, + 8 SubtractivePrimitive dialogs)
- `resources/icons/partdesign/*.svg` (~60 icons from FreeCAD)
- `tests/parity_suite/part/test_*.cpp` (45 files)
- `tests/smoke_part_e2e.cpp`
- `tests/golden/part_e2e.step` (golden reference file)

**Sub-phases:**

- **2A. Body Management (6)** — Body, Migrate, Set Tip, Duplicate, Move to other body, Move in tree.
- **2B. Datum + Reference (8)** — Datum plane/line/point, Local CS, Shape Binder, Sub-Shape Binder, Clone, composite Datum group.
- **2C. Additive Features (5 + 8 primitives)** — Pad, Revolve, Pipe, Loft, Helix; Additive Primitives dropdown (Box, Cylinder, Sphere, Cone, Ellipsoid, Torus, Prism, Wedge).
- **2D. Subtractive Features (6 + 8 primitives)** — Pocket, Hole, Groove, Sub-pipe, Sub-loft, Sub-helix; Subtractive Primitives dropdown (8 variants).
- **2E. Dress-up Features (4)** — Fillet, Chamfer, Draft, Thickness.
- **2F. Transformations (5)** — Mirror, Linear Pattern, Polar Pattern, Scaled, Multi-Transform.
- **2G. Boolean Operations (1)** — Boolean Operation.
- **2H. Sketch Management in PartDesign (2)** — New Sketch (on datum or face), Composite Sketch group.

**Phase 2 Exit Gate:**
- All 45 tools in catalog marked `DONE`
- Smoke test: create Body → Sketch on XY → rectangle with hole → Pad 20mm → Fillet 2mm all vertical edges → Pocket 10mm from a new sketch on top face → Linear Pattern the pocket 3× along X — result matches FreeCAD shape identically (OCCT STEP comparison).

### Phase 3 — CAM Parity (88 tools + CODESYS post)

**Goal:** Every CAM tool in FreeCAD works identically in CADNC; MilCAD CAM retired. Python embedding fully operational.
**Duration estimate:** 6-8 sessions
**Depends on:** Phase 2 complete + git tag `phase-2-part-parity` pushed
**Catalog:** `.ai/CATALOG_CAM.md`
**Files modified (scope):**
- `freecad/CAM/` (new — full copy from `-git` source; CMake integrated)
- `adapter/inc/PythonEmbed.h`, `adapter/src/PythonEmbed.cpp` (new)
- `adapter/inc/CamFacade.h`, `adapter/src/CamFacade.cpp` (rewritten — replaces MilCAD version)
- `adapter/inc/CadEngine.h`, `.cpp` (88 new Q_INVOKABLE)
- `ui/qml/toolbars/CAMToolbar.qml` (full layout replacing current stub)
- `ui/qml/panels/ToolBitLibraryPanel.qml`, `GCodePreviewPanel.qml` (new)
- `ui/qml/dialogs/cam/*.qml` (new: JobWizard, ProfileTaskPanel, PocketShapeTaskPanel, MillFacingTaskPanel, HelixTaskPanel, AdaptiveTaskPanel, SlotTaskPanel, 3DSurfaceTaskPanel, WaterlineTaskPanel, DrillingTaskPanel, ThreadMillingTaskPanel, EngraveTaskPanel, DeburrTaskPanel, VcarveTaskPanel, 3DPocketTaskPanel, ProbeTaskPanel, TappingTaskPanel, + 9 dressup dialogs, + simulation controls)
- `freecad/CAM/Path/Post/scripts/codesys_post.py` (new — CODESYS variant)
- `resources/icons/cam/*.svg` (~100 icons from FreeCAD)
- `tests/parity_suite/cam/test_*.cpp` (88 files)
- `tests/smoke_cam_e2e.cpp`
- `tests/golden/cam_e2e_codesys.cnc` (golden reference)
- `cam/` — **DELETED** in Phase 3N
- Root `CMakeLists.txt` — remove `add_subdirectory(cam)`, add `add_subdirectory(freecad/CAM)`

**Sub-phases:**

- **3A. Infrastructure (foundational, must complete first)**
  - Copy `src/Mod/CAM/App/` → `freecad/CAM/App/`; adapt CMake
  - Copy Python scripts: `CAMScripts/`, `Path/Op/`, `Path/Dressup/`, `Path/Post/scripts/`
  - Extend `adapter/` with `CamFacade.{h,cpp}` (replaces old MilCAD CamFacade)
  - Extend `adapter/` with `PythonEmbed.{h,cpp}` — `Base::Interpreter::runPy("import PathScripts.PathProfile; ...")`
  - Job persistence: `PathJob` object is a FreeCAD DocumentObject, persists via standard `.FCStd` save
  - Toolpath rendering: `PathJob.ToolPath` → `Part::TopoShape` (polyline) → OCCT `AIS_Shape` via OccViewport
  - Exit gate: `CamFacade::createJob()` invoked from QML creates a FreeCAD PathJob object in document tree visible in ModelTreePanel

- **3B. Project / Setup (7 tools)** — Job (wizard), Export Template, Sanity, ToolBit Library, ToolBit Dock, ToolBit Create, ToolBit Save.
- **3C. Tool Management (1)** — Tool Controller (assignment UI).
- **3D. 2D Operations (6)** — Profile, Pocket Shape, Mill Facing, Helix, Adaptive, Slot.
- **3E. 3D Operations (2)** — 3D Surface, Waterline. *(Note: requires OpenCamLib; Phase-exit gate permits these as "installed optional — buttons disabled if OCL absent".)*
- **3F. Drilling Operations (2)** — Drilling, Thread Milling.
- **3G. Engraving Operations (3)** — Engrave, Deburr, Vcarve.
- **3H. Other Operations (4)** — 3D Pocket, Face, Probe, Tapping.
- **3I. Dressups (9)** — Array (path), Dogbone, Boundary, Drag Knife, Lead In/Out, Ramp Entry, Tag, Axis Map, Z-Depth Correction.
- **3J. Path Modification (6)** — Copy, Array, Simple Copy, Comment, Stop, Custom.
- **3K. Simulation (5)** — Simulator GL (primary), Simulator (legacy fallback), Inspect, Select Loop, Camotics launcher.
- **3L. Post-Processing (3)** — Post Process (whole job), Post Selected, Operation Active Toggle.
- **3M. CODESYS Post Variant** — Copy `generic_post.py` → `codesys_post.py`; adapt block numbering (N-word rules), M-code differences for SoftMotion, ST program header. Test with `Profile + Pocket` operation job → CODESYS ST output that loads in SoftMotion editor.
- **3N. MilCAD Retirement** — Delete `cam/` directory; remove from `CMakeLists.txt`; remove `adapter/inc/CamFacade.h` old MilCAD binding; archive in git history via commit `chore: remove MilCAD CAM (replaced by FreeCAD CAM)`.

**Phase 3 Exit Gate:**
- All 88 CAM tools + CODESYS post in catalog marked `DONE`
- Smoke test: Open a part from Phase 2 smoke test → Create Job (stock = bbox + 5mm) → Add Profile (outer boundary, depth 20mm) → Add Pocket (the hole, depth 10mm) → Add Drilling (4 corner holes) → Post process with CODESYS → Verify ST output has proper header, block numbering, G-codes for each operation in order.

### Phase 4 — Polish + Branding

**Goal:** Production polish, FreeCAD version stamp, spec-doc consistency
**Duration estimate:** 1 session
**Depends on:** Phase 3

**Sub-phases:**

- **4A. Nesting Polish** — Review `nesting/` for any tools missing compared to FreeCAD's BIM/Nest or Luban reference. (Note: FreeCAD core has no nesting WB; our BLF+BBox is unique IP — just polish.)
- **4B. FreeCAD Version Stamp** — Bottom-right status bar QML label: `"Powered by FreeCAD 1.2 (LGPL kernel)"` with a subtle FreeCAD logo icon.
- **4C. About Dialog** — Update to display: CADNC version, FreeCAD kernel version, OCCT version, Qt version, license attribution (LGPL notices for FreeCAD, MPL for OCCT, etc.).
- **4D. Documentation Refresh** — Update `.ai/START_HERE.md`, `.ai/WORKPLAN.md`, `.ai/context.yaml` to reflect new architecture + completed phases.
- **4E. LGPL Compliance** — `LICENSE-FREECAD.txt` included in repo root + distribution; `NOTICES.md` crediting FreeCAD contributors.

---

## 5. Adapter Surface — Target Design

Per-workbench facade classes with strict responsibility:

### 5.1 `SketchFacade` (extend existing)

New methods needed (from Phase 1 catalog analysis — non-exhaustive sample):

```cpp
// Drawing (45 methods, one per drawing tool)
int addLine(double x1, double y1, double x2, double y2, bool construction = false);
int addArc(double cx, double cy, double r, double startAng, double endAng);
int addArc3Point(double x1, double y1, double x2, double y2, double x3, double y3);
int addCircle(double cx, double cy, double r);
int addCircle3Point(double x1, double y1, double x2, double y2, double x3, double y3);
int addEllipseByCenter(...);
int addEllipseBy3Points(...);
int addRectangle(...);
int addRectangleCenter(...);
int addSquare(...);
int addOblong(...);        // rounded rectangle
int addRegularPolygon(int n, ...);
int addTriangle(...);
int addPentagon(...);
int addHexagon(...);
int addHeptagon(...);
int addOctagon(...);
int addSlot(...);
int addArcSlot(...);
int addBSpline(const std::vector<QPointF>& controlPoints);
int addPeriodicBSpline(...);
int addBSplineInterpolation(...);
int addText(...);
int addDraftLine(...);
int addExternalGeometry(const QString& subname);
int addIntersection(...);
int addCarbonCopy(const QString& sourceSketch);

// Constraints — geometric (11)
int constrainHorizontal(const QList<int>& geoIds);
int constrainVertical(const QList<int>& geoIds);
int constrainHorVer(const QList<int>& geoIds);   // auto-detects
int constrainParallel(int g1, int g2);
int constrainPerpendicular(int g1, int g2);
int constrainTangent(int g1, int g2);
int constrainCoincident(int p1, int p2);         // legacy
int constrainCoincidentUnified(const QList<int>& points);
int constrainEqual(const QList<int>& geos);
int constrainPointOnObject(int point, int geo);
int constrainSymmetric(int p1, int p2, int axis);

// Constraints — dimensional (9)
int constrainDistance(int g1, int g2, double value);
int constrainDistanceX(int g1, int g2, double value);
int constrainDistanceY(int g1, int g2, double value);
int constrainRadius(int g, double value);
int constrainDiameter(int g, double value);
int constrainRadiam(int g, double value);
int constrainAngle(int g1, int g2, double valueRad);
int constrainLock(int point, double x, double y);
int constrainBlock(int g);

// Toggles (5)
void toggleConstructionMode(const QList<int>& geos);
void toggleDrivingConstraint(int cid);
void toggleActiveConstraint(int cid);

// Selection helpers (9)
QList<int> selectConstraintsForGeo(int geo);
QList<int> selectElementsForConstraint(int cid);
QList<int> selectConflictingConstraints();
QList<int> selectRedundantConstraints();
QList<int> selectPartiallyRedundantConstraints();
QList<int> selectMalformedConstraints();
QList<int> selectElementsWithDoF();
// ... origin/axis selection: engine-level

// Edge ops (4)
void trim(int geo, double pickX, double pickY);
void extend(int geo, double pickX, double pickY);
void split(int geo, double pickX, double pickY);
void joinCurves(int g1, int endpoint1, int g2, int endpoint2);

// B-spline ops (6)
void convertToNURBS(const QList<int>& geos);
void increaseDegree(int bspline);
void decreaseDegree(int bspline);
void increaseKnotMultiplicity(int bspline, int knotIndex);
void decreaseKnotMultiplicity(int bspline, int knotIndex);
void insertKnot(int bspline, double u);

// Transformations (9)
QList<int> copy(const QList<int>& selection, QPointF offset);
QList<int> clone(const QList<int>& selection, QPointF offset);
void move(const QList<int>& selection, QPointF offset);
QList<int> rotate(const QList<int>& selection, QPointF center, double angleRad, int copies = 1);
QList<int> scale(const QList<int>& selection, QPointF center, double factor);
QList<int> translate(const QList<int>& selection, QPointF offset, int iCopies, int jCopies);
QList<int> symmetry(const QList<int>& selection, int axis);
QList<int> offset(const QList<int>& profile, double distance);
QList<int> rectangularArray(const QList<int>& selection, QPointF offset, int rows, int cols);

// Clipboard (3)
void clipboardCopy(const QList<int>& selection);
void clipboardCut(const QList<int>& selection);
QList<int> clipboardPaste();

// Cleanup (4)
void deleteAllGeometry();
void deleteAllConstraints();
void removeAxesAlignment();
void restoreInternalAlignmentGeometry();

// Sketch-level ops (sketch management via CadDocument, not SketchFacade):
// validateSketch, mirrorSketch, mergeSketches, toggleSectionView
```

### 5.2 `PartFacade` (extend existing)

```cpp
// Body (6)
QString createBody(const QString& name = "Body");
void setActiveBody(const QString& name);
void migrateLegacyBody();
void setTip(const QString& featureName);
QString duplicateObject(const QString& objectName);
void moveObjectToBody(const QString& obj, const QString& targetBody);
void moveFeatureAfter(const QString& feature, const QString& after);

// Datum (8)
QString createDatumPlane(const QVariantMap& attach);  // MapMode + references
QString createDatumLine(const QVariantMap& attach);
QString createDatumPoint(const QVariantMap& attach);
QString createLocalCS(const QVariantMap& attach);
QString createShapeBinder(const QStringList& refs);
QString createSubShapeBinder(const QStringList& refs);
QString createClone(const QString& source);

// Additive — primary (5)
QString pad(const QString& sketch, double length, int midPlane = 0, int reversed = 0,
            double offset = 0, int type = 0 /*Dimension|UpToFace|UpToLast|TwoLengths*/,
            const QString& upToFace = "");
QString revolve(const QString& sketch, const QString& axis, double angle,
                bool midPlane = false, bool reversed = false);
QString additivePipe(const QString& profile, const QStringList& spine, int mode);
QString additiveLoft(const QStringList& profiles, bool ruled, bool closed);
QString additiveHelix(const QString& sketch, double pitch, double height, double angle,
                      const QString& axis, int turns);

// Additive primitives (8)
QString addBox(double L, double W, double H);
QString addCylinder(double r, double h);
QString addSphere(double r);
QString addCone(double r1, double r2, double h);
QString addEllipsoid(double rx, double ry, double rz);
QString addTorus(double R, double r);
QString addPrism(int sides, double circumradius, double h);
QString addWedge(double Xmin, double Ymin, double Zmin, double X2min, double Z2min,
                  double Xmax, double Ymax, double Zmax, double X2max, double Z2max);

// Subtractive — mirror of additive with "pocket" semantics (6 + 8 primitives)
QString pocket(const QString& sketch, double length, int type, const QString& upToFace);
QString hole(const QString& sketch, int type, double depth, double diameter,
             double counterDia, double counterDepth, bool threaded);
QString groove(const QString& sketch, const QString& axis, double angle);
QString subtractivePipe(...); QString subtractiveLoft(...); QString subtractiveHelix(...);
// Subtractive primitives: 8 methods mirroring additive ones (prefix "subtract")

// Dress-up (4)
QString fillet(const QStringList& edges, double radius);
QString chamfer(const QStringList& edges, double size, int type = 0);
QString draft(const QStringList& faces, double angle, const QString& neutralPlane, bool reversed);
QString thickness(const QStringList& faces, double thickness, double angle, int mode);

// Transformations (5)
QString mirror(const QStringList& features, const QString& plane);
QString linearPattern(const QStringList& features, const QString& direction,
                      double length, int occurrences);
QString polarPattern(const QStringList& features, const QString& axis,
                     double angle, int occurrences);
QString scaled(const QStringList& features, double factor, int occurrences);
QString multiTransform(const QStringList& features, const QVariantList& transforms);

// Boolean (1)
QString booleanOperation(const QString& op /*Fuse|Cut|Common*/, const QStringList& bodies);
```

### 5.3 `CamFacade` (NEW, Python-embedded, replaces MilCAD version)

```cpp
// Job lifecycle (7)
QString createJob(const QString& baseModel, const QVariantMap& stockCfg,
                  const QString& postProcessor = "generic");
void exportJobTemplate(const QString& job, const QString& filepath);
bool sanityCheck(const QString& job);
QString openToolBitLibrary();
QString addToolBitToJob(const QString& job, const QString& toolBitFile);
QString createToolBit(const QVariantMap& def);
void saveToolBit(const QString& toolBit, const QString& filepath);

// Tool controller (1)
QString addToolController(const QString& job, const QString& toolBit,
                          double spindleSpeed, double feedRate);

// Operations — 2D (6)
QString addProfile(const QString& job, const QStringList& faces,
                   const QVariantMap& params);
QString addPocketShape(const QString& job, const QStringList& faces,
                       const QVariantMap& params);
QString addMillFacing(const QString& job, const QVariantMap& params);
QString addHelix(const QString& job, const QStringList& features,
                 const QVariantMap& params);
QString addAdaptive(const QString& job, const QStringList& features,
                    const QVariantMap& params);
QString addSlot(const QString& job, const QVariantMap& params);

// Operations — 3D (2, OCL-dependent)
QString add3DSurface(const QString& job, const QString& model,
                     const QVariantMap& params);
QString addWaterline(const QString& job, const QString& model,
                     const QVariantMap& params);

// Operations — drilling (2)
QString addDrilling(const QString& job, const QStringList& features,
                    const QVariantMap& params);
QString addThreadMilling(const QString& job, const QStringList& features,
                         const QVariantMap& params);

// Operations — engraving (3)
QString addEngrave(const QString& job, const QString& shapeString);
QString addDeburr(const QString& job, const QStringList& edges,
                  const QVariantMap& params);
QString addVcarve(const QString& job, const QString& shapeString);

// Operations — other (4)
QString add3DPocket(const QString& job, const QStringList& faces,
                    const QVariantMap& params);
QString addFace(const QString& job, const QVariantMap& params);
QString addProbe(const QString& job, const QVariantMap& params);
QString addTapping(const QString& job, const QStringList& features,
                    const QVariantMap& params);

// Dressups (9)
QString addDressupArray(const QString& op, int rows, int cols,
                        double offsetX, double offsetY);
QString addDressupDogbone(const QString& op, int style, double size);
QString addDressupBoundary(const QString& op, const QStringList& edges);
QString addDressupDragKnife(const QString& op, double offset);
QString addDressupLeadInOut(const QString& op, int style,
                             double radius, double distance);
QString addDressupRampEntry(const QString& op, double angle);
QString addDressupTag(const QString& op, const QVariantList& tags);
QString addDressupAxisMap(const QString& op, const QString& axisA, const QString& axisB);
QString addDressupZCorrect(const QString& op, const QString& probeMap);

// Path modification (6)
QString copyOperation(const QString& op);
QString arrayOperation(const QString& op, int rows, int cols,
                        double offsetX, double offsetY);
QString simpleCopyOperation(const QString& op);
QString addComment(const QString& job, const QString& text);
QString addStop(const QString& job);
QString addCustom(const QString& job, const QString& gcode);

// Simulation (5)
void simulatorGL(const QString& job);
void simulator(const QString& job);
void inspectOperation(const QString& op);
QList<QString> selectOperationLoop(const QString& job, const QString& startOp);
void launchCamotics(const QString& job);

// Post processing (3)
QString postProcess(const QString& job, const QString& outputPath);
QString postProcessSelected(const QStringList& operations, const QString& outputPath);
void toggleOperationActive(const QString& op);

// Post processor discovery
QStringList listPostProcessors();  // returns ["generic", "linuxcnc", "fanuc_legacy", ..., "codesys"]
```

### 5.4 `NestFacade` (keep existing — unchanged)

### 5.5 `PythonEmbed` (NEW — low-level)

```cpp
class PythonEmbed {
public:
    PythonEmbed();  // initializes Base::Interpreter if not already
    void runString(const QString& code);
    QVariant runStringWithResult(const QString& code);
    void importModule(const QString& name);  // e.g. "Path.Op.Profile"
    bool isAvailable() const;
    QString lastError() const;
private:
    // wraps Base::Interpreter with Python scope tracking
};
```

---

## 6. UI / QML Plan

### 6.1 Workbench Tabs

Current QML has Part/Sketch/CAM/Nesting workbench tabs. Each tab will load a distinct **toolbar set** and context-sensitive **side panel set**:

| Tab | Toolbar Layout | Side Panels |
|-----|----------------|-------------|
| Sketch | `SketchToolbar.qml` — 10 toolbar groups (Draw, Constrain-Geo, Constrain-Dim, Edit, Trim/Extend, BSpline, Transform, Clipboard, View, Sketch) | ModelTree, Constraints, Elements, Properties |
| Part | `PartToolbar.qml` — 8 groups (Body, Datum, Additive, Subtractive, Dress-up, Transform, Boolean, Sketch) | ModelTree, Properties, TaskPanel |
| CAM | `CAMToolbar.qml` — 6 groups (Setup, Operations-2D, Operations-3D, Drilling, Dressup, Post) | ModelTree (Job tree), Operation Properties, ToolBit Library, G-code Preview |
| Nesting | `NestingToolbar.qml` (existing) | Parts, Sheet, Results |

### 6.2 Toolbar Pattern

```qml
// PartToolbar.qml
RibbonGroup {
    title: "Additive"
    CadToolButton { icon: "pad.svg"; text: qsTr("Pad"); onClicked: featureDialog.showPad() }
    CadToolButton { icon: "revolve.svg"; text: qsTr("Revolve"); onClicked: featureDialog.showRevolve() }
    CadToolButton { icon: "pipe.svg"; text: qsTr("Pipe"); onClicked: featureDialog.showPipe() }
    CadToolButton { icon: "loft.svg"; text: qsTr("Loft"); onClicked: featureDialog.showLoft() }
    CadToolButton { icon: "helix.svg"; text: qsTr("Helix"); onClicked: featureDialog.showHelix() }
    // Primitives dropdown
    CadToolDropdown { icon: "primitive.svg"; text: qsTr("Primitive")
        menu: [
            { icon: "box.svg", text: qsTr("Box"), onActivated: ... },
            ... 8 entries ...
        ]
    }
}
```

### 6.3 TaskPanel Pattern (dialog for each tool that takes parameters)

Each FreeCAD TaskDlg with a `.ui` file maps to a QML Dialog:

```qml
// PadTaskPanel.qml — mirrors FreeCAD's TaskPadParameters.ui
Dialog {
    property string sketchName
    title: qsTr("Pad parameters")
    Column {
        ComboBox { id: typeCombo; model: ["Dimension", "To last", "To first", "Up to face", "Two dimensions"] }
        DoubleSpinBox { id: length; value: 10; suffix: " mm" }
        CheckBox { id: reversed; text: qsTr("Reversed") }
        CheckBox { id: midplane; text: qsTr("Symmetric to sketch plane") }
        DoubleSpinBox { id: length2; visible: typeCombo.currentIndex === 4 }
        Button { text: qsTr("OK"); onClicked: {
            cadEngine.pad(sketchName, length.value, midplane.checked ? 1 : 0, reversed.checked ? 1 : 0, 0, typeCombo.currentIndex, "");
            close();
        }}
    }
}
```

### 6.4 Icon Policy

Every tool's icon comes from:
1. `resources/icons/<wb>/<tool>.svg` (if we already have it — 92 existing)
2. Falls back to `freecad/Sketcher/Gui/Resources/icons/` or equivalent (reference-only, copied into CADNC resources — LGPL permits use)
3. Missing icons flagged in catalog; Phase-exit gate requires all icons resolved.

---

## 7. Test Strategy

### 7.1 Per-Tool Acceptance Test

Each catalog row must have an acceptance method:
- **Unit test** (`tests/`) for algorithm-bearing tools (constraints, fillet radius, pattern copies)
- **Manual smoke** for UI-only tools (toggles, view, display)

### 7.2 Phase-Exit Smoke Tests

- **Phase 1 smoke**: `tests/smoke_sketch_e2e.cpp` — scripted sketch with all constraint types + trim + offset; `tests/smoke_sketch_manual.md` — manual click-through of every drawing tool.
- **Phase 2 smoke**: `tests/smoke_part_e2e.cpp` — scripted part with body → pad → pocket → fillet → pattern; STEP export → bit-compare to golden file.
- **Phase 3 smoke**: `tests/smoke_cam_e2e.cpp` — scripted job with Profile + Pocket + Drilling → post with CODESYS → textual compare against golden `.cnc` file.

### 7.3 Regression Harness

`tests/parity_suite/` — one subdirectory per workbench; each contains a list of `<tool>_test.cpp` files. CI runs these on every commit. Phase-exit requires 100% pass.

---

## 8. Process Requirements

### 8.1 Commit Protocol

**One tool per commit.** See WRAPPER_CONTRACT § 7.1-7.2 for the exact commit message format. Summary:

```
feat(<wb>-<sub>): <tool-name> parity [N/M]

FreeCAD source: src/Mod/<WB>/Gui/<Command>.cpp:<line>
Adapter method: <Facade>::<method>()
QML: ui/qml/<path>
Test: tests/parity_suite/<wb>/test_<tool>.cpp

Completed items (15/15):
  ✓ Source identified
  ✓ Behavior analyzed
  ✓ Facade method § 2.1 compliant
  ✓ Error handling § 2.3
  ✓ Transaction § 2.5
  ✓ Recompute § 2.6
  ✓ Q_INVOKABLE § 3.1
  ✓ QML button § 5.2
  ✓ Icon
  ✓ Tooltip (parity)
  ✓ Shortcut (parity)
  ✓ TaskPanel (if applicable, per .ui parity)
  ✓ Unit test
  ✓ Test asserts success + invalid paths
  ✓ Catalog row DONE

Catalog: .ai/CATALOG_<WB>.md row <N> → DONE

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
```

**Exception — batched commits** permitted only for:
- Composite dropdown entries (no standalone logic)
- Identical primitive variants sharing >95% code (8 additive primitives → one commit enumerating all 8)

### 8.2 Sub-phase Cadence (within each phase)

1. Executor reads the catalog section for the sub-phase
2. Executor reads WRAPPER_CONTRACT sections relevant to sub-phase type
3. For each tool:
   a. Complete all 15 DoD items per WRAPPER_CONTRACT § 6
   b. Commit (per-tool cadence — no batching except exceptions above)
   c. Update catalog row status to DONE with commit SHA
   d. Run `ctest` to verify no regression (previous tools still green)
4. At sub-phase end:
   a. Run sub-phase smoke test
   b. Frontend audit (every toolbar button present, shortcut works, tooltip correct)
   c. Backend audit (every Facade method follows § 2.1)
   d. Commit sub-phase completion (per WRAPPER_CONTRACT § 7.3)
   e. Push to origin
5. Report to user:
   ```
   Sub-phase 1A DONE: 45/45 tools
   Files changed: <list>
   Tests added: 45 (all passing)
   Commits: <SHA range>
   Next: 1B — Geometric Constraints (11 tools)
   Proceed? (waiting for OK)
   ```
6. Wait for user OK before starting next sub-phase

**User OK is required ONLY at sub-phase boundaries.** Between tools, executor proceeds autonomously per catalog order. If a tool becomes BLOCKED, executor skips to next and reports blocked tool in sub-phase summary.

### 8.3 Roll-Forward Only Policy

Per WRAPPER_CONTRACT § 8:
- DONE tools stay DONE; their tests become permanent CI gates
- A DONE tool regressing = CI fails = PR blocked
- A tool can move to BLOCKED only with external-dependency failure (Python 3.x regression, OCCT API break) — never for developer convenience
- Silent test deletions or `xfail` marks are grounds for PR rejection

### 8.4 Phase Tagging

At phase completion:
```bash
git tag -a "phase-<N>-<wb>-parity" -m "Phase <N> complete: <M> tools at FreeCAD parity"
git push origin "phase-<N>-<wb>-parity"
```

Next phase does not start until tag is pushed.

### 8.5 Frontend Completeness Audit (manual, per sub-phase)

For each sub-phase, executor performs this checklist:
- [ ] Every catalogued tool has a visible toolbar button OR menu entry
- [ ] No placeholder buttons ("TODO") shipped
- [ ] Keyboard shortcuts tested — match FreeCAD
- [ ] Tooltips match FreeCAD's `sToolTipText` (copy directly, translate via qsTr)
- [ ] Icons rendered at 16px, 24px, 32px sizes without artifacts
- [ ] TaskPanels mirror FreeCAD .ui field-for-field (compare source .ui XML to QML file)
- [ ] Context menus include all relevant tools (right-click on sketch → relevant sketch tools)
- [ ] Right-click on feature tree nodes offers FreeCAD-equivalent context actions

### 8.6 Backend Completeness Audit (manual, per sub-phase)

For each sub-phase, executor performs this checklist:
- [ ] Every Facade method follows WRAPPER_CONTRACT § 2.1 pattern exactly (grep for `auto txn = document_->openTransaction`)
- [ ] Every Facade method has matching Q_INVOKABLE bridge in CadEngine
- [ ] Every Q_INVOKABLE method handles `FacadeError` and emits `errorOccurred`
- [ ] `tests/parity_suite/<wb>/` has a test file per tool (count check: test file count == catalog row count)
- [ ] Every test asserts both happy path AND invalid-input path
- [ ] Transaction scope matches user intent (no multi-tool transactions)
- [ ] Signal emissions respect § 3.2 taxonomy — no ad-hoc signals

### 8.3 Review Checkpoints

**MANDATORY user review points:**
- End of each **phase** (Phase 1, 2, 3, 4 completion)
- When a **catalog** tool requires architectural decision (e.g., "OCL missing for Waterline — disable button or error toast?")
- When **FreeCAD source deviation** is proposed (adapter API differs from FreeCAD's Command signature in non-trivial way)

**Automatic (no review):**
- Each individual tool implementation
- Refactors internal to the adapter
- Icon placement

### 8.4 Error Recovery

If a tool's implementation proves blocking (e.g., Python script fails to load, OCCT API mismatch), the executor:
1. Marks the catalog row `BLOCKED` with a one-line reason
2. Moves to the next tool
3. At sub-phase end, produces a `BLOCKED` report for the user
4. Sub-phase cannot complete until BLOCKED items resolved or reclassified as "deferred to Phase X".

No item is ever silently dropped. Explicit BLOCKED or DEFERRED status required.

---

## 9. Risks & Mitigations

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Python embedding crash in CamFacade | Medium | High | Isolate all Python calls in try/except; Python errors become QString return values; smoke test with minimal Path ops first |
| FreeCAD CAM 1.2 API differs from our existing Part/Sketcher 1.1 code | Medium | Medium | Phase 3A first task: diff Base/App APIs between currently-integrated 1.1 source and new 1.2 source; upgrade our Base/App if needed OR keep 1.1 base + only CAM from 1.2 |
| OCL (OpenCamLib) not available on Linux | High | Low | 3D Surface + Waterline tools ship disabled with tooltip "Requires OpenCamLib — see install guide"; do not block Phase 3 exit |
| TaskDlg parameter complexity — FreeCAD .ui files have hundreds of fields | High | Medium | Port progressively: first expose critical parameters (length, reversed, midplane for Pad); secondary params (offset, draft angle) in a collapsible "Advanced" panel |
| CODESYS post variant fails SoftMotion validation | Medium | High | Obtain a reference CODESYS ST file from a known working post; use as golden; diff output line-by-line |
| 294 tools × 30min/tool = ~150 hours | Certain | — | Not a risk — a budget. Phased delivery with user review every sub-phase ensures early course correction. |
| Icon gaps — 92 existing icons, need ~294 unique | High | Low | Copy FreeCAD's SVG icons into `resources/icons/freecad/` under LGPL attribution; use ours first, fall back |

---

## 10. Success Metrics

Phase-level:
- Phase 1 complete: User can draw any 2D profile that FreeCAD Sketcher can.
- Phase 2 complete: User can model any single-body part that FreeCAD PartDesign can (multi-body delayed to Phase 5 if needed).
- Phase 3 complete: User can generate a machining job with ≥5 operations + CODESYS G-code output.
- Phase 4 complete: Status bar shows "Powered by FreeCAD 1.2", About dialog credits all libraries, LGPL notices distributed.

Project-level:
- 100% of FreeCAD's registered Commands in Sketcher + PartDesign + CAM have a corresponding CADNC tool.
- Zero silent omissions (every skipped tool has BLOCKED/DEFERRED status with rationale).
- Regression suite runs in < 10 minutes and passes 100%.

---

## 11. Next Session Startup Prompt

Use the following prompt verbatim at the start of the execution session. The prompt is self-contained — no prior conversation context needed.

---

**PROMPT (copy-paste into next session):**

> # CADNC FreeCAD Parity Execution — Session Start
>
> Bu oturumda CADNC'nin FreeCAD parity adoption planını uygulamaya başlıyoruz. Bu prompt self-contained — yukarıdaki konuşmayı bilmediğin varsayımıyla hazırlandı.
>
> ## Görev
> `.ai/FREECAD_ADOPTION_PLAN.md` v2.0'da tanımlanan **Phase 1 — Sketch Parity** çalışmasını başlat. `superpowers:executing-plans` skill'ini invoke et.
>
> ## Okuma Sırası (zorunlu — atla geç)
> 1. `/home/embed/Dev/CADNC/CLAUDE.md`
> 2. `/home/embed/Dev/CADNC/.ai/START_HERE.md`
> 3. `/home/embed/Dev/CADNC/.ai/WRAPPER_CONTRACT.md` — **adapter'ın yasa kitabı, ÖNCE oku**
> 4. `/home/embed/Dev/CADNC/.ai/FREECAD_ADOPTION_PLAN.md` v2.0 — master plan
> 5. `/home/embed/Dev/CADNC/.ai/CATALOG_SKETCHER.md` — Phase 1 checklist (161 tool)
>
> ## Başlangıç Noktası
> Phase 1, **Sub-phase 1A — Drawing Geometry (45 tools)**. Catalog'daki 1 numaralı satırdan başla (CmdSketcherCreatePoint → Point).
>
> ## İşleyiş (tembih — uyulması şart)
>
> **Her tool için** (commit-per-tool cadence):
>
> 1. FreeCAD kaynağını oku: `/home/embed/Downloads/FreeCAD-main-1-1-git/src/Mod/Sketcher/Gui/` — ilgili `Cmd*` sınıfını bul, davranışını anla. App-level algoritma için `src/Mod/Sketcher/App/` paralelini incele.
> 2. `SketchFacade::<method>()`'u WRAPPER_CONTRACT § 2.1 pattern'ine göre yaz — transaction açma/commit, exception wrap, recompute, signal emission.
> 3. `CadEngine::Q_INVOKABLE <verb><Noun>()`'u § 3.1 pattern'ine göre ekle.
> 4. QML: `ui/qml/toolbars/SketchToolbar.qml`'e `CadToolButton` ekle (§ 5.2 — icon, text, tooltip, shortcut, enabled, onClicked mandatory). Parametreli ise `ui/qml/dialogs/drawing/<Tool>Dialog.qml` oluştur.
> 5. Icon: `resources/icons/sketcher/<name>.svg` — FreeCAD'den kopyala, `resources/icons/NOTICE.md`'ye LGPL attribution ekle.
> 6. Tooltip: FreeCAD'in `sToolTipText` string'ini birebir kopyala, `qsTr()` ile wrap et.
> 7. Shortcut: FreeCAD'in `sAccel` string'ini `resources/shortcuts.json`'a kaydet.
> 8. Test: `tests/parity_suite/sketch/test_<tool>.cpp` — happy path + invalid input (WRAPPER_CONTRACT § 10.2 template).
> 9. `ctest --test-dir build` geç.
> 10. Catalog satırı DONE işaretle, commit SHA notu ekle.
> 11. Commit (WRAPPER_CONTRACT § 7.2 mesaj formatı — 15 DoD maddesi checkbox, Co-Authored-By Claude Opus 4.7).
>
> **Sub-phase sonunda** (her 10-45 tool'da bir):
>
> - Sub-phase smoke test (`tests/smoke_sketch_<sub>.cpp`) çalıştır — geçmeli.
> - Frontend audit: WRAPPER_CONTRACT § 5 denetlemesini yap.
> - Backend audit: § 2.1 pattern compliance grep kontrolü.
> - Sub-phase completion commit (WRAPPER_CONTRACT § 7.3 formatı).
> - `git push origin main`.
> - Kullanıcıya rapor: sub-phase DONE, tool sayısı, commit SHA range, next sub-phase — onay beklet.
>
> **Phase sonunda**:
> - `git tag -a phase-1-sketch-parity -m "..."` + `git push origin phase-1-sketch-parity`
> - User sign-off → Phase 2 başlangıç iznini bekle.
>
> ## Mimari Kurallar (WRAPPER_CONTRACT özeti)
>
> - **Invariant 1:** QML FreeCAD header include etmez
> - **Invariant 2:** Facade metotları OCCT/FreeCAD pointer döndürmez — primitive marshalling
> - **Invariant 3:** FreeCAD source modifiye edilmez
> - **Transaction:** Her mutating metot `document_->openTransaction("<name>")` açar, commit/abort eder
> - **Error:** Her exception `FacadeError`'a wrap edilir; CadEngine `errorOccurred(QString)` emit eder
> - **Thread:** Tüm Facade çağrıları Qt main thread'inde
> - **Dil:** Kod/yorum İngilizce, kullanıcı iletişimi Türkçe
>
> ## Başarısızlık Durumu
>
> Bir tool BLOCKED olursa: catalog'da `BLOCKED` işaretle (reason + blocking-dependency), bir sonraki tool'a geç, sub-phase raporunda listele. Silent skip/delete yasak.
>
> ## Build + Test Komutu
>
> ```bash
> cmake -B build -S . -DCMAKE_BUILD_TYPE=Debug
> cmake --build build -j$(nproc)
> ctest --test-dir build --output-on-failure
> DISPLAY=:0 QT_QPA_PLATFORM=xcb ./build/cadnc   # görsel doğrulama
> ```
>
> ## Başla
>
> TodoWrite ile ilk 5 tool'u (1-5 numaralı catalog satırı) task olarak ekle, sonra Tool #1'e başla.

---

## 12. Appendix: Directory Structure After All Phases

```
CADNC/
├── freecad/                        # FreeCAD App-only backend (no Gui)
│   ├── Base/, App/, Materials/     # (existing)
│   ├── Part/App/                   # (existing)
│   ├── Sketcher/App/               # (existing)
│   ├── PartDesign/App/             # (existing)
│   └── CAM/                        # NEW — Phase 3A
│       ├── App/                    # C++ DocumentObjects (PathJob, Toolpath, Area)
│       ├── CAMScripts/             # Python operation modules
│       ├── Path/
│       │   ├── Op/                 # Profile, Pocket, Drilling, etc. (Python)
│       │   ├── Dressup/            # Dogbone, Tag, Boundary, etc. (Python)
│       │   └── Post/
│       │       └── scripts/
│       │           ├── generic_post.py
│       │           ├── linuxcnc_post.py
│       │           ├── ... 33 more ...
│       │           └── codesys_post.py   # NEW — Phase 3M
├── adapter/
│   ├── inc/
│   │   ├── CadSession.h, CadDocument.h, CadEngine.h
│   │   ├── SketchFacade.h          # extended in Phase 1
│   │   ├── PartFacade.h            # extended in Phase 2
│   │   ├── CamFacade.h             # rewritten Phase 3A
│   │   ├── NestFacade.h            # unchanged
│   │   └── PythonEmbed.h           # NEW Phase 3A
│   └── src/  (matching .cpp files)
├── ui/qml/
│   ├── Main.qml                    # existing shell
│   ├── toolbars/
│   │   ├── SketchToolbar.qml       # 161-tool layout
│   │   ├── PartToolbar.qml         # 45-tool layout
│   │   ├── CAMToolbar.qml          # 88-tool layout
│   │   └── NestingToolbar.qml      # existing
│   ├── panels/
│   │   ├── ModelTreePanel.qml, PropertiesPanel.qml, ConstraintPanel.qml
│   │   ├── TaskPanel.qml           # NEW — generic task dialog host
│   │   ├── ToolBitLibraryPanel.qml # NEW Phase 3
│   │   └── GCodePreviewPanel.qml   # NEW Phase 3
│   └── dialogs/
│       ├── DrawingDialogs.qml      # drawing tool parameter popups
│       ├── FeatureDialogs.qml      # Pad/Pocket/etc. task panels
│       ├── CAMJobDialog.qml        # Job wizard
│       └── CAMOperationDialogs.qml # per-operation parameter panels
├── viewport/                       # (existing OccViewport — unchanged)
├── nesting/                        # (existing — Phase 4 polish)
├── resources/
│   ├── icons/                      # existing 92 + new ~200 from FreeCAD (LGPL attribution)
│   └── ...
├── tests/
│   ├── smoke_sketch_e2e.cpp, smoke_part_e2e.cpp, smoke_cam_e2e.cpp
│   ├── parity_suite/
│   │   ├── sketch/                 # per-tool tests
│   │   ├── part/
│   │   └── cam/
│   └── golden/                     # reference STEP / CNC files
├── .ai/
│   ├── FREECAD_ADOPTION_PLAN.md    # this file
│   ├── CATALOG_SKETCHER.md         # 161 rows
│   ├── CATALOG_PARTDESIGN.md       # 45 rows
│   ├── CATALOG_CAM.md              # 88 rows + post processors
│   └── (existing context.yaml, WORKPLAN.md, etc. — updated Phase 4D)
├── cam/                            # DELETED in Phase 3N (MilCAD CAM retirement)
└── CMakeLists.txt, app/main.cpp
```

---

**END OF PLAN**

*Any deviation from this plan during execution must be proposed in a comment on the relevant catalog row and approved by user before applying. The plan is the spec; the catalogs are the backlog; the commit history is the ledger.*
