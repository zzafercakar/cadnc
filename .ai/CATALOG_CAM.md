# CATALOG — CAM (Phase 3)

> **Total tools: 88** C++/Python commands + **35 post-processors** — source: `/home/embed/Downloads/FreeCAD-main-1-1-git/src/Mod/CAM/`
> **Status legend:** TODO | DOING | DONE | BLOCKED | DEFERRED
> **Prerequisite:** Phase 2 complete (solid parts required for meaningful CAM tests)
> **Infrastructure note:** Sub-phase 3A (Python embedding + CAM module copy) MUST complete before any tool implementation in 3B-3N.

---

## Sub-phase 3A — Infrastructure (foundational, must complete first)

Not a tool list — setup work. Single commit at end.

### 3A Checklist
- [ ] Copy `/home/embed/Downloads/FreeCAD-main-1-1-git/src/Mod/CAM/App/*` → `/home/embed/Dev/CADNC/freecad/CAM/App/`
- [ ] Copy Python: `Path/Op/`, `Path/Dressup/`, `Path/Post/scripts/`, `CAMScripts/` (if present)
- [ ] Write `freecad/CAM/CMakeLists.txt` modeled on `freecad/Part/App/CMakeLists.txt`
- [ ] Create `adapter/inc/PythonEmbed.h` + `adapter/src/PythonEmbed.cpp`
- [ ] Extend `Base::Interpreter` init in `CadSession::initialize()` to add `PathScripts` on `sys.path`
- [ ] Create `adapter/inc/CamFacade.h` + `.cpp` (new, replaces MilCAD CamFacade)
- [ ] First smoke: `PythonEmbed::runString("import PathScripts.PathProfile")` — success
- [ ] First end-to-end: `CamFacade::createJob(solidBodyName, {}, "generic")` creates a FreeCAD `Path::Job` DocumentObject visible in ModelTreePanel

### 3A Exit Gate
A `Path::Job` exists in the document tree after `createJob()`; `.FCStd` save/reopen preserves it.

---

## Sub-phase 3B — Project / Setup (7 tools)

| # | FreeCAD Command | UI Label | Adapter Method | QML Handler | Status | Notes |
|---|-----------------|----------|----------------|-------------|--------|-------|
| 1 | CAM_Job | Job | `createJob(baseModel,stockCfg,post)` | CAMToolbar.Setup.Job | TODO | wizard: select model → stock (bbox+offset / solid / cylinder) → post |
| 2 | CAM_ExportTemplate | Export Template | `exportJobTemplate(job,path)` | contextMenu on Job | TODO | JSON export |
| 3 | CAM_Sanity | Sanity Check | `sanityCheck(job)` | Job contextMenu | TODO | validates tools+speeds |
| 4 | CAM_ToolBitLibraryOpen | Toolbit Library Manager | `openToolBitLibrary()` | CAMToolbar.Setup.ToolLibrary | TODO | dock panel |
| 5 | CAM_ToolBitDock | Add Toolbit | `addToolBitToJob(job,toolFile)` | ToolLibrary panel | TODO | |
| 6 | CAM_ToolBitCreate | New Toolbit | `createToolBit(def)` | ToolLibrary.New | TODO | default endmill |
| 7 | CAM_ToolBitSave | Save Toolbit | `saveToolBit(tb,path)` | ToolLibrary contextMenu | TODO | |

**3B Exit:** Job wizard end-to-end creates a Job with stock + post-processor + one tool bit, visible in tree.

---

## Sub-phase 3C — Tool Management (1 tool)

| # | FreeCAD Command | UI Label | Adapter Method | QML Handler | Status | Notes |
|---|-----------------|----------|----------------|-------------|--------|-------|
| 8 | Tool Controller | Tool Controller | `addToolController(job,tb,rpm,feed)` | Job.contextMenu.AddTC | TODO | enforces tool → speeds linkage |

---

## Sub-phase 3D — 2D Operations (6 tools)

| # | FreeCAD Command | UI Label | Adapter Method | QML Handler | Status | Notes |
|---|-----------------|----------|----------------|-------------|--------|-------|
| 9 | CAM_Profile | Profile | `addProfile(job,faces,params)` | CAMToolbar.Op2D.Profile | TODO | outer/inner/edge |
| 10 | CAM_Pocket_Shape | Pocket Shape | `addPocketShape(job,faces,params)` | CAMToolbar.Op2D.PocketShape | TODO | |
| 11 | CAM_MillFacing | Mill Facing | `addMillFacing(job,params)` | CAMToolbar.Op2D.Face | TODO | stock top surface |
| 12 | CAM_Helix | Helix | `addHelix(job,features,params)` | CAMToolbar.Op2D.Helix | TODO | helical entry |
| 13 | CAM_Adaptive | Adaptive | `addAdaptive(job,features,params)` | CAMToolbar.Op2D.Adaptive | TODO | HSM clearing |
| 14 | CAM_Slot | Slot | `addSlot(job,params)` | CAMToolbar.Op2D.Slot | TODO | |

**3D Exit:** Each 2D op produces toolpath segments visible in OccViewport; G-code preview shows expected XY/Z moves.

---

## Sub-phase 3E — 3D Operations (2 tools, OCL-dependent)

| # | FreeCAD Command | UI Label | Adapter Method | QML Handler | Status | Notes |
|---|-----------------|----------|----------------|-------------|--------|-------|
| 15 | CAM_Surface | 3D Surface | `add3DSurface(job,model,params)` | CAMToolbar.Op3D.Surface | TODO | requires OpenCamLib |
| 16 | CAM_Waterline | Waterline | `addWaterline(job,model,params)` | CAMToolbar.Op3D.Waterline | TODO | requires OpenCamLib |

**3E Exit Gate Relaxation:** If OCL is not installed, buttons ship DISABLED with tooltip "Requires OpenCamLib (optional dependency)". Does not block Phase 3 exit. Catalog rows marked DEFERRED with explicit "OCL-optional" label.

---

## Sub-phase 3F — Drilling Operations (2 tools)

| # | FreeCAD Command | UI Label | Adapter Method | QML Handler | Status | Notes |
|---|-----------------|----------|----------------|-------------|--------|-------|
| 17 | CAM_Drilling | Drilling | `addDrilling(job,features,params)` | CAMToolbar.Drill.Drilling | TODO | G81/G82/G83 cycles |
| 18 | CAM_ThreadMilling | Thread Milling | `addThreadMilling(job,features,params)` | CAMToolbar.Drill.Thread | TODO | |

---

## Sub-phase 3G — Engraving Operations (3 tools)

| # | FreeCAD Command | UI Label | Adapter Method | QML Handler | Status | Notes |
|---|-----------------|----------|----------------|-------------|--------|-------|
| 19 | CAM_Engrave | Engrave | `addEngrave(job,shapeString)` | CAMToolbar.Engrave.Engrave | TODO | around Draft text |
| 20 | CAM_Deburr | Deburr | `addDeburr(job,edges,params)` | CAMToolbar.Engrave.Deburr | TODO | |
| 21 | CAM_Vcarve | Vcarve | `addVcarve(job,shapeString)` | CAMToolbar.Engrave.Vcarve | TODO | medial line |

---

## Sub-phase 3H — Other Operations (4 tools)

| # | FreeCAD Command | UI Label | Adapter Method | QML Handler | Status | Notes |
|---|-----------------|----------|----------------|-------------|--------|-------|
| 22 | CAM_Pocket3D | 3D Pocket | `add3DPocket(job,faces,params)` | CAMToolbar.Op3D.Pocket | TODO | |
| 23 | CAM_MillFace | Face (legacy) | alias of CAM_MillFacing | (same as #11) | TODO | Python alias |
| 24 | CAM_Probe | Probe | `addProbe(job,params)` | CAMToolbar.Other.Probe | TODO | probe grid |
| 25 | CAM_Tapping | Tapping | `addTapping(job,features,params)` | CAMToolbar.Drill.Tapping | TODO | G84 |

---

## Sub-phase 3I — Dressups (9 tools)

| # | FreeCAD Command | UI Label | Adapter Method | QML Handler | Status | Notes |
|---|-----------------|----------|----------------|-------------|--------|-------|
| 26 | CAM_DressupArray | Array (dressup) | `addDressupArray(op,rows,cols,dx,dy)` | Operation contextMenu.Dressup.Array | TODO | array a toolpath |
| 27 | CAM_DressupDogbone | Dogbone | `addDressupDogbone(op,style,size)` | ...Dressup.Dogbone | TODO | internal corner compensation |
| 28 | CAM_DressupPathBoundary | Boundary | `addDressupBoundary(op,edges)` | ...Dressup.Boundary | TODO | |
| 29 | CAM_DressupDragKnife | Drag Knife | `addDressupDragKnife(op,offset)` | ...Dressup.DragKnife | TODO | |
| 30 | CAM_DressupLeadInOut | Lead In/Out | `addDressupLeadInOut(op,style,r,dist)` | ...Dressup.LeadInOut | TODO | arc/line/perpendicular/tangent/arc3d |
| 31 | CAM_DressupRampEntry | Ramp Entry | `addDressupRampEntry(op,angle)` | ...Dressup.Ramp | TODO | |
| 32 | CAM_DressupTag | Tag | `addDressupTag(op,tags[])` | ...Dressup.Tag | TODO | hold-down tags |
| 33 | CAM_DressupAxisMap | Axis Map | `addDressupAxisMap(op,axisA,axisB)` | ...Dressup.AxisMap | TODO | |
| 34 | CAM_DressupZCorrect | Z Depth Correction | `addDressupZCorrect(op,probeMap)` | ...Dressup.ZCorrect | TODO | |

**3I Exit:** Each dressup modifies its parent Operation's toolpath; G-code reflects the dressup action.

---

## Sub-phase 3J — Path Modification (6 tools)

| # | FreeCAD Command | UI Label | Adapter Method | QML Handler | Status | Notes |
|---|-----------------|----------|----------------|-------------|--------|-------|
| 35 | CAM_OperationCopy | Copy | `copyOperation(op)` | Operation contextMenu | TODO | linked tool controller |
| 36 | CAM_Array | Array (op) | `arrayOperation(op,rows,cols,dx,dy)` | Operation contextMenu | TODO | distinct from dressup Array |
| 37 | CAM_SimpleCopy | Simple Copy | `simpleCopyOperation(op)` | Operation contextMenu | TODO | |
| 38 | CAM_Comment | Comment | `addComment(job,text)` | CAMToolbar.Supplement.Comment | TODO | non-cutting |
| 39 | CAM_Stop | Stop | `addStop(job)` | CAMToolbar.Supplement.Stop | TODO | M0 |
| 40 | CAM_Custom | Custom | `addCustom(job,gcode)` | CAMToolbar.Supplement.Custom | TODO | raw G-code snippet |

---

## Sub-phase 3K — Simulation (5 tools)

| # | FreeCAD Command | UI Label | Adapter Method | QML Handler | Status | Notes |
|---|-----------------|----------|----------------|-------------|--------|-------|
| 41 | CAM_SimulatorGL | Simulator GL | `simulatorGL(job)` | CAMToolbar.Sim.SimGL | TODO | OpenGL renderer |
| 42 | CAM_Simulator | Simulator (legacy) | `simulator(job)` | CAMToolbar.Sim.SimLegacy | TODO | fallback |
| 43 | CAM_Inspect | Inspect | `inspectOperation(op)` | Operation.contextMenu | TODO | G-code panel |
| 44 | CAM_SelectLoop | Select Loop | `selectOperationLoop(job,startOp)` | Job contextMenu | TODO | |
| 45 | CAM_Camotics | Camotics | `launchCamotics(job)` | CAMToolbar.Sim.Camotics | TODO | external launcher; check `which camotics` |

**3K Exit:** SimulatorGL shows cut material animation; Inspect opens a read-only G-code preview.

---

## Sub-phase 3L — Post Processing (3 tools)

| # | FreeCAD Command | UI Label | Adapter Method | QML Handler | Status | Notes |
|---|-----------------|----------|----------------|-------------|--------|-------|
| 46 | CAM_Post | Post Process | `postProcess(job,outputPath)` | CAMToolbar.Post.Run | TODO | whole job |
| 47 | CAM_PostSelected | Post Selected | `postProcessSelected(ops[],outputPath)` | Operation contextMenu | TODO | |
| 48 | CAM_OpActiveToggle | Active Toggle | `toggleOperationActive(op)` | Operation contextMenu | TODO | exclude from post |

---

## Sub-phase 3M — CODESYS Post Variant

NOT a tool — integration task.

### 3M Checklist
- [ ] Copy `freecad/CAM/Path/Post/scripts/generic_post.py` → `codesys_post.py`
- [ ] Identify CODESYS-specific diffs:
  - [ ] Block numbering (CODESYS typically does not use N-words; plain sequential lines)
  - [ ] G-code vocabulary — M30 vs CODESYS `M02` program-end; spindle M3/M4/M5
  - [ ] Coordinate declaration (CODESYS SoftMotion uses ST program with `SMC_OutQueue`; may require wrapper)
  - [ ] Feedrate units (mm/min standard — confirm CODESYS SoftMotion expects same)
  - [ ] Program header/footer template — SoftMotion expects function block with structured text surrounding G-code
- [ ] Produce reference output file from a known-good SoftMotion example
- [ ] Register `codesys` in post-processor enum (`CamFacade::listPostProcessors()`)
- [ ] Expose in Job wizard dropdown
- [ ] Smoke test: 3-op job → CODESYS post → output runs through CODESYS editor syntax check

### 3M Exit Gate
Output ST file loads into CODESYS IDE (or confirmed via documented syntax rules) without parse errors; G-code body matches FreeCAD generic output within documented CODESYS overrides.

---

## Sub-phase 3N — MilCAD Retirement

NOT a tool — cleanup task.

### 3N Checklist
- [ ] Verify Phase 3B-3M complete; MilCAD CAM no longer referenced
- [ ] `rm -rf cam/`
- [ ] Remove `add_subdirectory(cam)` from root `CMakeLists.txt`
- [ ] Remove old `adapter/inc/CamFacade.h` (replaced by new Phase 3A version)
- [ ] Remove MilCAD icon set from `resources/icons/cam/` (replace with FreeCAD icons)
- [ ] Commit: `chore: retire MilCAD CAM — FreeCAD CAM parity achieved`

### 3N Exit Gate
Build succeeds without `cam/` directory; no references to `MilCAD` remain in code (grep clean).

---

## Post-Processor Registry (informational — not implementation rows)

All 35 posts from `freecad/CAM/Path/Post/scripts/` are made available in Job wizard dropdown. No implementation work — they ship as Python files.

**Modern posts:**
- generic_post, linuxcnc_post, mach3_mach4_post, grbl_post, marlin_post, opensbp_post, smoothie_post, masso_g3_post, centroid_post, rrf_legacy_post, svg_post, dxf_post, fanuc_legacy_post

**Legacy posts (archived but available):**
- 21 `*_legacy_post.py` files — heidenhain, estlcam, fablin, dynapath (×3), wedm, nccad, philips, uccnc, jtech, KineticNCBeamicon2, fangling, snapmaker, rml, kept for compatibility

**Special:**
- generic_plasma_post (plasma cutting)
- **codesys_post** (NEW — Phase 3M)

---

## Phase 3 Smoke Test — `tests/smoke_cam_e2e.cpp`

```cpp
TEST(CamSmoke, FullJobWithCODESYS) {
    // Prerequisite: part.step from Phase 2 smoke
    auto doc = CadSession::openDocument("tests/golden/part_e2e.FCStd");
    auto body = doc->bodies().first();

    // Job
    auto job = doc->camFacade()->createJob(
        body->name(), {{"stock","bbox"}, {"offset",5.0}}, "codesys");

    // Profile op (outer boundary)
    auto outerFaces = body->faces("outer-boundary");
    doc->camFacade()->addProfile(job, outerFaces, {{"depth",20.0}, {"stepdown",5.0}});

    // Pocket op (the hole)
    auto holeFace = body->face("hole");
    doc->camFacade()->addPocketShape(job, {holeFace}, {{"depth",10.0}});

    // Drilling op (4 corner holes)
    auto cornerHoles = body->features("corner-holes");
    doc->camFacade()->addDrilling(job, cornerHoles, {{"type","G83"}, {"peck",2.0}});

    // Post
    QString output;
    ASSERT_TRUE(doc->camFacade()->postProcess(job, "/tmp/out.cnc"));
    QFile f("/tmp/out.cnc"); f.open(QIODevice::ReadOnly);
    output = f.readAll();

    // CODESYS-specific assertions
    ASSERT_TRUE(output.contains("(* Generated by CADNC *)"));
    ASSERT_FALSE(output.contains("N10 "));  // CODESYS: no N-words
    ASSERT_TRUE(output.contains("G83"));    // drilling cycle present
    ASSERT_TRUE(output.contains("M30"));    // program end
}
```

---

## Progress Dashboard

**Sub-phase completion:**
- [ ] 3A — Infrastructure (foundational setup)
- [ ] 3B — Project / Setup (0/7)
- [ ] 3C — Tool Management (0/1)
- [ ] 3D — 2D Operations (0/6)
- [ ] 3E — 3D Operations (0/2, OCL-optional)
- [ ] 3F — Drilling Operations (0/2)
- [ ] 3G — Engraving Operations (0/3)
- [ ] 3H — Other Operations (0/4)
- [ ] 3I — Dressups (0/9)
- [ ] 3J — Path Modification (0/6)
- [ ] 3K — Simulation (0/5)
- [ ] 3L — Post Processing (0/3)
- [ ] 3M — CODESYS Post Variant (infrastructure)
- [ ] 3N — MilCAD Retirement (cleanup)

**Phase 3 total: 0/48 tool rows (+ infrastructure + retirement)**

---

**END CATALOG_CAM**
