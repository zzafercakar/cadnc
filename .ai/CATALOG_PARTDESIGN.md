# CATALOG — PartDesign (Phase 2)

> **Total tools: 45** (including primitive variants) — source: `/home/embed/Downloads/FreeCAD-main-1-1-git/src/Mod/PartDesign/Gui/Command*.cpp`
> **Status legend:** TODO | DOING | DONE | BLOCKED | DEFERRED
> **Prerequisite:** Phase 1 (Sketcher) must reach `Sub-phase 1I — Sketch Operations DONE` before Phase 2 starts.

---

## Sub-phase 2A — Body Management (6 tools)

| # | FreeCAD Command | UI Label | Adapter Method | QML Handler | Status | Notes |
|---|-----------------|----------|----------------|-------------|--------|-------|
| 1 | CmdPartDesignBody | New Body | `createBody(name="Body")` | PartToolbar.Body.New | TODO | auto-activates |
| 2 | CmdPartDesignMigrate | Migrate | `migrateLegacyBody()` | PartMenu.Migrate | TODO | legacy doc conversion |
| 3 | CmdPartDesignMoveTip | Set Tip | `setTip(featureName)` | contextMenu on ModelTree | TODO | |
| 4 | CmdPartDesignDuplicateSelection | Duplicate Object | `duplicateObject(name)` | contextMenu | TODO | |
| 5 | CmdPartDesignMoveFeature | Move Object To... | `moveObjectToBody(obj,targetBody)` | contextMenu | TODO | |
| 6 | CmdPartDesignMoveFeatureInTree | Move Feature After... | `moveFeatureAfter(feat,after)` | contextMenu / drag-drop | TODO | |

**2A Exit:** Multiple Bodies coexist; Tip move re-orders tree view and regenerates downstream features.

---

## Sub-phase 2B — Datum + Reference (8 tools)

| # | FreeCAD Command | UI Label | Adapter Method | QML Handler | Status | Notes |
|---|-----------------|----------|----------------|-------------|--------|-------|
| 7 | CmdPartDesignPlane | Datum Plane | `createDatumPlane(attach)` | PartToolbar.Datum.Plane | TODO | partial exists |
| 8 | CmdPartDesignLine | Datum Line | `createDatumLine(attach)` | PartToolbar.Datum.Line | TODO | |
| 9 | CmdPartDesignPoint | Datum Point | `createDatumPoint(attach)` | PartToolbar.Datum.Point | TODO | |
| 10 | CmdPartDesignCS | Local Coordinate System | `createLocalCS(attach)` | PartToolbar.Datum.CS | TODO | |
| 11 | CmdPartDesignShapeBinder | Shape Binder | `createShapeBinder(refs[])` | PartToolbar.Datum.Binder | TODO | |
| 12 | CmdPartDesignSubShapeBinder | Sub-Shape Binder | `createSubShapeBinder(refs[])` | PartToolbar.Datum.SubBinder | TODO | tracks placement; cross-doc |
| 13 | CmdPartDesignClone | Clone | `createClone(source)` | PartToolbar.Datum.Clone | TODO | parametric copy as base feature |
| 14 | CmdPartDesignCompDatums | Create Datum dropdown | composite (7-10) | PartToolbar.Datum dropdown | TODO | UI composite only |

**2B Exit:** Full attachment engine (MapMode: FlatFace / LineToPoint / OXY / ObjectXZ / etc.) per FreeCAD `Part/App/AttachExtension.cpp`; offset + rotation from reference work.

---

## Sub-phase 2C — Additive Features (13 tools: 5 primary + 8 primitives)

| # | FreeCAD Command | UI Label | Adapter Method | QML Handler | Status | Notes |
|---|-----------------|----------|----------------|-------------|--------|-------|
| 15 | CmdPartDesignPad | Pad | `pad(sketch,length,type,midPlane,reversed,upToFace,offset)` | PartToolbar.Additive.Pad | TODO | partial exists; complete Type enum |
| 16 | CmdPartDesignRevolution | Revolve | `revolve(sketch,axis,angle,midPlane,reversed)` | PartToolbar.Additive.Revolve | TODO | partial exists |
| 17 | CmdPartDesignAdditivePipe | Additive Pipe | `additivePipe(profile,spine,mode)` | PartToolbar.Additive.Pipe | TODO | sweep |
| 18 | CmdPartDesignAdditiveLoft | Additive Loft | `additiveLoft(profiles[],ruled,closed)` | PartToolbar.Additive.Loft | TODO | |
| 19 | CmdPartDesignAdditiveHelix | Additive Helix | `additiveHelix(sketch,pitch,height,angle,axis,turns)` | PartToolbar.Additive.Helix | TODO | |
| 20 | CmdPrimtiveCompAdditive | Additive Primitive dropdown | composite (21-28) | PartToolbar.Additive.Primitive | TODO | UI composite |
| 21 | (primitive) Box | Add Box | `addBox(L,W,H)` | ...Primitive.Box | TODO | |
| 22 | (primitive) Cylinder | Add Cylinder | `addCylinder(r,h)` | ...Primitive.Cylinder | TODO | |
| 23 | (primitive) Sphere | Add Sphere | `addSphere(r)` | ...Primitive.Sphere | TODO | |
| 24 | (primitive) Cone | Add Cone | `addCone(r1,r2,h)` | ...Primitive.Cone | TODO | |
| 25 | (primitive) Ellipsoid | Add Ellipsoid | `addEllipsoid(rx,ry,rz)` | ...Primitive.Ellipsoid | TODO | |
| 26 | (primitive) Torus | Add Torus | `addTorus(R,r)` | ...Primitive.Torus | TODO | |
| 27 | (primitive) Prism | Add Prism | `addPrism(sides,circumradius,h)` | ...Primitive.Prism | TODO | |
| 28 | (primitive) Wedge | Add Wedge | `addWedge(...10 params)` | ...Primitive.Wedge | TODO | |

**2C Exit:** Every additive feature has a TaskPanel with FreeCAD-identical parameter fields (not reduced); Pad Type enum covers all 5 FreeCAD modes (Dimension, UpToLast, UpToFirst, UpToFace, TwoLengths).

---

## Sub-phase 2D — Subtractive Features (13 tools: 6 primary + 8 primitives — but Hole replaces generic sub-primitive)

| # | FreeCAD Command | UI Label | Adapter Method | QML Handler | Status | Notes |
|---|-----------------|----------|----------------|-------------|--------|-------|
| 29 | CmdPartDesignPocket | Pocket | `pocket(sketch,length,type,midPlane,reversed,upToFace,offset)` | PartToolbar.Subtractive.Pocket | TODO | partial exists |
| 30 | CmdPartDesignHole | Hole | `hole(sketch,type,depth,dia,counterDia,counterDepth,threaded)` | PartToolbar.Subtractive.Hole | TODO | centers on circle sketch |
| 31 | CmdPartDesignGroove | Groove | `groove(sketch,axis,angle,midPlane,reversed)` | PartToolbar.Subtractive.Groove | TODO | |
| 32 | CmdPartDesignSubtractivePipe | Subtractive Pipe | `subtractivePipe(profile,spine,mode)` | PartToolbar.Subtractive.Pipe | TODO | |
| 33 | CmdPartDesignSubtractiveLoft | Subtractive Loft | `subtractiveLoft(profiles[],ruled,closed)` | PartToolbar.Subtractive.Loft | TODO | |
| 34 | CmdPartDesignSubtractiveHelix | Subtractive Helix | `subtractiveHelix(...)` | PartToolbar.Subtractive.Helix | TODO | |
| 35 | CmdPrimtiveCompSubtractive | Subtractive Primitive dropdown | composite | ...Subtractive.Primitive dropdown | TODO | 8 variants mirroring additive primitives |

**2D Exit:** Pocket Through-All works; Hole with counterbore/countersink/threaded params matches FreeCAD output (STEP comparison).

---

## Sub-phase 2E — Dress-up Features (4 tools)

| # | FreeCAD Command | UI Label | Adapter Method | QML Handler | Status | Notes |
|---|-----------------|----------|----------------|-------------|--------|-------|
| 36 | CmdPartDesignFillet | Fillet | `fillet(edges[],radius)` | PartToolbar.Dressup.Fillet | TODO | OCCT BRepFilletAPI_MakeFillet |
| 37 | CmdPartDesignChamfer | Chamfer | `chamfer(edges[],size,type)` | PartToolbar.Dressup.Chamfer | TODO | types: Equal / TwoDistances / DistanceAngle |
| 38 | CmdPartDesignDraft | Draft | `draft(faces[],angle,neutralPlane,reversed)` | PartToolbar.Dressup.Draft | TODO | |
| 39 | CmdPartDesignThickness | Thickness | `thickness(faces[],thick,angle,mode)` | PartToolbar.Dressup.Thickness | TODO | modes: Skin / Pipe / RectoVerso |

**2E Exit:** Edge/face selection via OccViewport picking flows into dress-up TaskPanel; variable radius fillet supported (per-edge radius list).

---

## Sub-phase 2F — Transformations (5 tools)

| # | FreeCAD Command | UI Label | Adapter Method | QML Handler | Status | Notes |
|---|-----------------|----------|----------------|-------------|--------|-------|
| 40 | CmdPartDesignMirrored | Mirror | `mirror(features[],plane)` | PartToolbar.Transform.Mirror | TODO | |
| 41 | CmdPartDesignLinearPattern | Linear Pattern | `linearPattern(features[],direction,length,N)` | PartToolbar.Transform.Linear | TODO | |
| 42 | CmdPartDesignPolarPattern | Polar Pattern | `polarPattern(features[],axis,angle,N)` | PartToolbar.Transform.Polar | TODO | |
| 43 | CmdPartDesignScaled | Scale | `scaled(features[],factor,N)` | PartToolbar.Transform.Scaled | TODO | |
| 44 | CmdPartDesignMultiTransform | Multi-Transform | `multiTransform(features[],transforms[])` | PartToolbar.Transform.Multi | TODO | chains transforms |

**2F Exit:** Mirror preserves symmetry constraint; pattern `Occurrences` param produces N copies; Multi-Transform chaining (mirror ∘ linear) produces FreeCAD-identical result.

---

## Sub-phase 2G — Boolean Operations (1 tool)

| # | FreeCAD Command | UI Label | Adapter Method | QML Handler | Status | Notes |
|---|-----------------|----------|----------------|-------------|--------|-------|
| 45 | CmdPartDesignBoolean | Boolean Operation | `booleanOperation(op,bodies[])` | PartToolbar.Boolean | TODO | op: Fuse / Cut / Common |

**2G Exit:** Two-body boolean produces correctly oriented result; self-intersection prompts error matching FreeCAD.

---

## Sub-phase 2H — Sketch Management in PartDesign (2 tools)

| # | FreeCAD Command | UI Label | Adapter Method | QML Handler | Status | Notes |
|---|-----------------|----------|----------------|-------------|--------|-------|
| 46 | CmdPartDesignNewSketch | New Sketch | (delegates to SketchFacade::NewSketch with PartDesign body context) | PartToolbar.Sketch.New | TODO | adds to active Body |
| 47 | CmdPartDesignCompSketches | Create Datum/Sketch dropdown | composite | PartToolbar dropdown | TODO | |

**2H Exit:** Sketch created with face pick auto-sets `Support` property to the picked face; sketch appears under active Body in tree.

---

## Phase 2 Smoke Test — `tests/smoke_part_e2e.cpp`

```cpp
TEST(PartSmoke, FullFeatureChain) {
    auto doc = CadSession::newDocument();
    auto body = doc->partFacade()->createBody("Body");

    // Sketch 1 on XY
    auto s1 = doc->addSketch(body, "XY_Plane");
    buildRect(s1, 100, 50);
    doc->partFacade()->pad(s1, 20, 0 /*Dim*/, 0, 0, 0, "");

    // Fillet all edges
    auto edges = doc->partFacade()->queryEdges(body, "vertical");
    doc->partFacade()->fillet(edges, 2.0);

    // Sketch 2 on top face
    auto topFace = doc->partFacade()->queryFace(body, "top");
    auto s2 = doc->addSketch(body, topFace);
    addCircle(s2, 50, 25, 5);
    doc->partFacade()->pocket(s2, 10, 0, 0, 0, 0, "");

    // Linear pattern the pocket
    doc->partFacade()->linearPattern({"Pocket"}, "X", 80, 3);

    auto shape = body->shape();
    ASSERT_TRUE(shape.isValid());
    ASSERT_EQ(shape.numSolids(), 1);
    ASSERT_NEAR(shape.volume(), expectedVolume, 1e-3);

    // Golden STEP compare
    shape.exportSTEP("/tmp/cadnc_part.step");
    ASSERT_STEP_EQ("/tmp/cadnc_part.step", "tests/golden/part_e2e.step");
}
```

---

## Progress Dashboard

**Sub-phase completion:**
- [ ] 2A — Body Management (0/6)
- [ ] 2B — Datum + Reference (0/8)
- [ ] 2C — Additive Features (0/13)
- [ ] 2D — Subtractive Features (0/13)
- [ ] 2E — Dress-up Features (0/4)
- [ ] 2F — Transformations (0/5)
- [ ] 2G — Boolean Operations (0/1)
- [ ] 2H — Sketch Management (0/2)

**Phase 2 total: 0/47 catalog rows (46 tools + 1 composite)**

> Note: Primitive variants counted individually but grouped under one UI dropdown. Effective tool count = 45 (per original scope).

---

**END CATALOG_PARTDESIGN**
