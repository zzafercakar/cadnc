# CADNC — Adapter Wrapper Contract

> **Purpose:** Define the exact rules for wrapping FreeCAD App-level APIs in CADNC adapter/facade classes. This is the contract every facade method must comply with. Any deviation requires explicit PR-level architectural decision, not silent drift.
>
> **Audience:** Executor of FREECAD_ADOPTION_PLAN.md; all future contributors to `adapter/`.
>
> **Authority:** This contract supersedes any conflicting guidance in CLAUDE.md, WORKPLAN.md, or in-code comments. Reviewers MUST reject PRs that violate this contract.
>
> **Version:** 1.0 — 2026-04-24

---

## 1. Architectural Position

```
┌───────────────────────────────────────────────────┐
│ QML UI (Main.qml, toolbars, panels, dialogs)      │
│ — Calls: cadEngine.<method>(args)                 │
│ — Receives: Q_PROPERTY values + signals           │
├───────────────────────────────────────────────────┤
│ CadEngine (QObject, QML-exposed bridge)           │
│ — Q_INVOKABLE methods (1:1 with UI actions)       │
│ — Q_PROPERTY state mirrors (featureTree, etc.)    │
│ — Signals (featureTreeChanged, solverStatusChanged) │
├───────────────────────────────────────────────────┤
│ Facades (SketchFacade, PartFacade, CamFacade,     │
│         NestFacade) — pure C++                    │
│ — Stateless helper classes held by CadDocument    │
│ — Each method = 1 FreeCAD operation + UI-contract │
├───────────────────────────────────────────────────┤
│ CadSession / CadDocument — lifecycle owners       │
│ — Wrap App::Application, App::Document            │
│ — Own Base::Interpreter (Python VM)               │
├───────────────────────────────────────────────────┤
│ FreeCAD App modules (Base, App, Part, Sketcher,   │
│                      PartDesign, CAM)             │
│ — Untouched; we do not edit FreeCAD source        │
└───────────────────────────────────────────────────┘
```

**Invariant 1:** QML code never #includes FreeCAD headers. Ever.
**Invariant 2:** Facade methods never touch QML types beyond primitive marshalling (QString, QVariantList, int, double, bool).
**Invariant 3:** FreeCAD source is never modified. Extensions go in adapter-only subclasses if necessary.

---

## 2. Facade Method Signature Contract

### 2.1 Required Pattern

Every facade method follows this exact structure:

```cpp
// Signature — must match this pattern
[ReturnType] <Namespace>::<Method>(const <arg-types>&... args) noexcept(false);

// Body — must follow this structure
ReturnType Facade::method(args...) {
    // 1. Precondition check — throw FacadeError if invalid
    if (!document_ || !document_->isValid()) {
        throw FacadeError(FacadeError::Code::NoActiveDocument,
                          "method() requires an active document");
    }

    // 2. Transaction open (for mutating methods only)
    auto txn = document_->openTransaction("method-name");

    // 3. FreeCAD call, wrapped in exception translation
    ReturnType result;
    try {
        result = <direct FreeCAD call>;
    }
    catch (const Base::Exception& e) {
        txn.abort();
        throw FacadeError::fromFreeCADException(e);
    }
    catch (const Standard_Failure& e) {  // OCCT exception
        txn.abort();
        throw FacadeError::fromOCCTException(e);
    }
    catch (const std::exception& e) {
        txn.abort();
        throw FacadeError::fromStdException(e);
    }

    // 4. Post-condition: recompute + emit change signal
    document_->recomputeIfNeeded();
    emit document_->mutated(<object-id>);

    // 5. Commit
    txn.commit();

    return result;
}
```

### 2.2 Return Conventions

| Operation Kind | Return Type | Value |
|----------------|-------------|-------|
| Creates document object (sketch, feature, body) | `QString` | Object's `Name` property (e.g. `"Pad001"`) |
| Mutates object (constraint add, trim, pattern) | `int` | New/modified object's internal ID (geo ID, constraint ID) |
| Query (list geometries, get constraint) | `QVariantList` / `QVariantMap` | Plain data, no FreeCAD handles |
| Pure action (toggle, delete) | `void` or `bool` | `bool` = success; `void` when exceptions-only |
| Multi-result creation (pattern produces N copies) | `QStringList` | All created object names, in creation order |

**Never return raw FreeCAD pointers across the facade boundary.**
**Never return OCCT types directly to QML — always convert to QVariant** (Q_DECLARE_METATYPE not sufficient).

### 2.3 Error Handling

**Three error classes only:**

```cpp
class FacadeError : public std::runtime_error {
public:
    enum class Code {
        NoActiveDocument,
        ObjectNotFound,
        InvalidArgument,
        ConstraintConflict,
        GeometryInvalid,
        FreeCADException,  // wrapped Base::Exception
        OCCTException,     // wrapped Standard_Failure
        StdException,      // wrapped std::exception
        PythonError,       // wrapped PyErr
        Unknown
    };
    Code code() const noexcept;
    QString userMessage() const noexcept;   // translated via qsTr
    QString debugDetails() const noexcept;  // full stack trace
};
```

**Facade must NOT:**
- Call `Base::Console().Error(...)` directly — translate to FacadeError instead
- Silently swallow exceptions
- Use `assert()` for user-input validation (user input → throw; internal invariant → assert)
- Use Qt signal/slot for error propagation (facades are sync, synchronous-throw)

**CadEngine translates facade exceptions to user-visible errors:**

```cpp
// CadEngine pattern
Q_INVOKABLE bool addLine(double x1, double y1, double x2, double y2) {
    try {
        int id = sketchFacade_->addLine(x1, y1, x2, y2);
        emit sketchChanged();
        return true;
    }
    catch (const FacadeError& e) {
        lastError_ = e.userMessage();
        emit errorOccurred(lastError_);
        return false;
    }
}
```

QML receives: `bool` return + `errorOccurred(QString)` signal. QML shows toast on error.

### 2.4 Threading Rules

**Facade methods: ALWAYS called on the Qt main/UI thread.** No exceptions. This matches FreeCAD's own assumption — App module is not thread-safe.

**Recomputation: happens on main thread inside `document_->recomputeIfNeeded()`.** Heavy recomputation (large Boolean ops) is a future optimization — for now, blocking is accepted.

**3D rendering (OccViewport): already on render thread via QQuickFramebufferObject.** Facade updates `OccViewport` via its mutex-protected queue; does NOT touch AIS_InteractiveContext directly.

**Python (Base::Interpreter): main thread only. Never call Python from a worker thread.**

### 2.5 Transaction Rules

Every mutating facade method opens an undo transaction:

```cpp
auto txn = document_->openTransaction("Pad");
```

- Transaction name = user-facing operation name (appears in Undo menu)
- `txn.commit()` on success — mandatory before return
- `txn.abort()` on exception — mandatory in catch blocks
- Nested transactions: outer-wins; inner is no-op
- Batch operations (e.g., pattern of 10 copies) open ONE transaction for the whole batch

**Read-only methods (queries) do NOT open transactions.**

### 2.6 Recompute Rules

After any mutating call, the document must recompute before return:

```cpp
document_->recomputeIfNeeded();  // fast path if nothing changed; full recompute otherwise
```

**Exceptions (rare):**
- Batch inserts where each element requires recompute but you want to amortize — use `document_->suspendRecompute()` / `document_->resumeRecompute()` around the batch
- Still MUST recompute before returning to QML

**After recompute:**
- Emit `document_->mutated(objectName)` for each modified object
- Emit `CadEngine::featureTreeChanged()` if tree structure changed
- Emit `CadEngine::sketchChanged()` if inside sketch edit mode
- Emit `CadEngine::viewportDirty()` if shape bounds/geometry changed

---

## 3. Q_INVOKABLE Contract (CadEngine)

### 3.1 Method Shape

Every `Q_INVOKABLE` method on CadEngine follows:

```cpp
Q_INVOKABLE <primitive-return-type> <verb><Noun>(<primitive-args>) {
    // 1. Null document guard
    if (!document_) { return <failure-value>; }

    // 2. Dispatch to facade
    try {
        auto result = <facade>->method(args);
        // 3. Emit state-change signals
        emit <relevantSignal>();
        // 4. Return primitive
        return <marshalled-result>;
    }
    catch (const FacadeError& e) {
        lastError_ = e.userMessage();
        emit errorOccurred(lastError_);
        return <failure-value>;
    }
}
```

**No CadEngine method does:**
- Geometric math (delegate to Facade)
- Business logic (delegate to Facade)
- Direct FreeCAD calls (must go via Facade)
- Render-thread operations (goes through OccViewport API)

### 3.2 Signal Taxonomy

Canonical signals only. Do not add ad-hoc signals without contract update.

| Signal | When Emitted | Payload |
|--------|-------------|---------|
| `documentChanged()` | Document opened/closed/renamed | — |
| `documentModified(bool)` | Any mutation; true=dirty, false=saved | bool isDirty |
| `featureTreeChanged()` | Tree structure changed (add/remove/reorder) | — |
| `sketchChanged()` | Inside sketch: geometry or constraint list changed | — |
| `solverStatusChanged(QString)` | Sketch solver status update | QString status |
| `viewportDirty()` | 3D shapes need re-display | — |
| `selectionChanged()` | User selection changed | — |
| `errorOccurred(QString)` | Recoverable error with user message | QString message |

**Banned anti-patterns:**
- Signal with the same name as a slot (confuses introspection)
- Signal emitted from constructor (subscribers not yet connected)
- Emitting in a loop when batched — always batch + emit once

---

## 4. Python Embedding Contract (CamFacade)

CamFacade is the only facade that embeds Python. Rules:

### 4.1 PythonEmbed Singleton

```cpp
// adapter/inc/PythonEmbed.h
class PythonEmbed {
public:
    static PythonEmbed& instance();
    bool initialize(const QString& freecadPath);  // call once in CadSession::init
    QVariant runPy(const QString& code);          // fire-and-forget + exception
    QVariant callFunc(const QString& module,
                      const QString& func,
                      const QVariantList& args);
    bool isReady() const noexcept;
    QString lastPyError() const noexcept;
};
```

- Single global Python interpreter, owned by `CadSession`
- `initialize()` sets PYTHONPATH to include `freecad/CAM/` directories
- All Python calls go through this class — no direct `Py_*` calls in facades

### 4.2 Error Translation

Python exceptions become `FacadeError(Code::PythonError)`:

```cpp
try {
    QVariant r = PythonEmbed::instance().callFunc("Path.Op.Profile",
                                                    "Create", args);
    if (!r.isValid()) {
        throw FacadeError(FacadeError::Code::PythonError,
                          PythonEmbed::instance().lastPyError());
    }
}
catch (...) { /* same pattern as section 2.1 step 3 */ }
```

### 4.3 Python Module Loading Order

At session init, import in this order (each must succeed before next):

1. `import FreeCAD` — backend already linked
2. `import Part` — OCCT bindings
3. `import Sketcher` — solver bindings
4. `import PartDesign` — features
5. `import Path` — CAM root
6. `import Path.Op.Profile; Path.Op.Pocket; ...` — each operation module
7. `import Path.Dressup.Dogbone; ...` — each dressup
8. `import Path.Post.scripts.generic_post; ...` — each post-processor

**If any step fails:** CamFacade marks itself `available = false`; all CAM buttons ship disabled with tooltip "CAM backend failed to initialize: <error>". No silent degradation.

---

## 5. Frontend (QML) Contract

### 5.1 Directory Structure (strict)

```
ui/qml/
├── Main.qml                        # ApplicationWindow shell only
├── Theme.qml                       # singleton tokens
├── toolbars/
│   ├── SketchToolbar.qml           # Phase 1
│   ├── PartToolbar.qml             # Phase 2
│   ├── CAMToolbar.qml              # Phase 3
│   └── NestingToolbar.qml          # existing
├── panels/
│   ├── ModelTreePanel.qml
│   ├── PropertiesPanel.qml
│   ├── ConstraintPanel.qml
│   ├── SelectionPanel.qml          # NEW Phase 1D
│   ├── ElementsPanel.qml           # NEW Phase 1D
│   ├── TaskPanel.qml               # NEW — generic task dialog host
│   ├── ToolBitLibraryPanel.qml     # NEW Phase 3
│   └── GCodePreviewPanel.qml       # NEW Phase 3
├── dialogs/
│   ├── drawing/                    # Phase 1A — one QML per drawing tool param dialog
│   │   ├── LineDialog.qml, ArcDialog.qml, CircleDialog.qml, ...
│   ├── constraints/                # Phase 1C — dimensional input
│   │   ├── DistanceInput.qml, RadiusInput.qml, ...
│   ├── features/                   # Phase 2 — Pad/Pocket/Fillet/etc. TaskPanels
│   │   ├── PadTaskPanel.qml, PocketTaskPanel.qml, ...
│   ├── cam/                        # Phase 3 — Job wizard, Operation TaskPanels
│   │   ├── JobWizard.qml, ProfileTaskPanel.qml, ...
│   └── common/                     # Shared
│       ├── FilePickerDialog.qml, ConfirmDialog.qml
├── components/
│   ├── CadToolButton.qml           # every toolbar button uses this
│   ├── CadToolDropdown.qml         # every composite dropdown uses this
│   ├── RibbonGroup.qml
│   ├── NavCube.qml, AxisIndicator.qml
│   ├── StatusToggle.qml
│   └── InputField.qml              # numeric field with unit + expression eval
├── canvases/
│   └── SketchCanvas.qml            # 2D overlay for sketch edit
└── viewport/
    └── OccViewport.qml             # 3D view (wraps OccViewport C++)
```

**Rule:** Every toolbar button lives in a `CadToolButton` instance inside a `RibbonGroup`. No direct `Button {}` usage in toolbars. Ensures uniform look, accessibility, tooltip, shortcut handling.

### 5.2 CadToolButton Contract

```qml
// components/CadToolButton.qml — MANDATORY properties
CadToolButton {
    id: toolBtnId
    icon: "pad.svg"            // relative to resources/icons/<wb>/
    text: qsTr("Pad")          // visible label
    tooltip: qsTr("Extrude the selected sketch or profile and add it to the body")
    shortcut: "P, A"           // FreeCAD-equivalent shortcut (keep parity)
    enabled: cadEngine.canPad  // bound to state Q_PROPERTY
    onClicked: featureDialogs.showPad()  // delegates to dialog host
}
```

**Mandatory for every button:**
1. `icon` — SVG from resources (or FreeCAD's icon copied in — LGPL attribution)
2. `text` — wrapped in `qsTr()` for translation
3. `tooltip` — matches FreeCAD's tooltip string (parity requirement — copy from FreeCAD source `command.cpp` `sToolTipText`)
4. `shortcut` — matches FreeCAD's shortcut where defined (`sAccel`)
5. `enabled` — bound to a Q_PROPERTY that reflects availability (e.g., `canPad` is true only when an open sketch is selected)
6. `onClicked` — calls a dialog host or directly invokes `cadEngine` if the tool takes no parameters

### 5.3 TaskPanel (Dialog) Contract

Every tool that takes parameters has a TaskPanel. Rules:

```qml
// Example template
TaskPanel {
    id: padPanel
    title: qsTr("Pad parameters")
    // Every field below maps 1:1 to FreeCAD TaskPadParameters.ui field
    property string sourceFreeCADUi: "src/Mod/PartDesign/Gui/TaskPadParameters.ui"

    // Fields in same order as FreeCAD .ui
    ComboBox {
        id: typeCombo
        model: [qsTr("Dimension"), qsTr("To last"), qsTr("To first"),
                qsTr("Up to face"), qsTr("Two dimensions")]
    }
    InputField { id: length; label: qsTr("Length"); value: 10; unit: "mm" }
    CheckBox { id: reversed; text: qsTr("Reversed") }
    CheckBox { id: midplane; text: qsTr("Symmetric to plane") }
    InputField { id: length2; label: qsTr("Second length"); unit: "mm"; visible: typeCombo.currentIndex === 4 }
    InputField { id: offset; label: qsTr("Offset"); value: 0; unit: "mm" }
    // ... every FreeCAD .ui field represented ...

    // Acceptance row
    Row {
        Button { text: qsTr("OK"); onClicked: { apply(); close() } }
        Button { text: qsTr("Cancel"); onClicked: close() }
    }

    function apply() {
        const ok = cadEngine.pad(selectedSketch, length.value,
                                  typeCombo.currentIndex, midplane.checked,
                                  reversed.checked, length2.value, "" /*upToFace*/,
                                  offset.value);
        if (!ok) errorToast.show(cadEngine.lastError);
    }
}
```

**Parity rule:** Every field in `TaskPadParameters.ui` must exist in `PadTaskPanel.qml`. No field hidden, reduced, or renamed without explicit documentation.

### 5.4 Shortcut Parity

`resources/shortcuts.json` — master file mapping every FreeCAD shortcut to our handler:

```json
{
  "Sketcher_CreateLine": "L",
  "Sketcher_CreateCircle": "C",
  "Sketcher_ConstrainHorizontal": "H",
  "Sketcher_ConstrainVertical": "V",
  "PartDesign_Pad": "P, A",
  "PartDesign_Pocket": "P, O",
  ... 290+ entries ...
}
```

Phase-exit gate requires every tool's shortcut to be set identically to FreeCAD's. Deviations (if any tool has no FreeCAD shortcut) use user-preferred keys with rationale in a comment.

### 5.5 Icon Parity

`resources/icons/<wb>/<icon-name>.svg` — every tool's icon matches FreeCAD's file name:

```bash
# Phase 1 setup: bulk copy FreeCAD icons with LGPL attribution
cp /home/embed/Downloads/FreeCAD-main-1-1-git/src/Mod/Sketcher/Gui/Resources/icons/*.svg \
   /home/embed/Dev/CADNC/resources/icons/sketcher/
```

**Attribution:** `resources/icons/NOTICE.md` lists every copied icon with the source file path and LGPL-2.1+ notice. Phase 4 verifies attribution is complete.

---

## 6. Definition of Done per Tool (15-point checklist)

A tool is `DONE` if and only if ALL 15 items below are true. The executor MUST verify each and check it off in the catalog or a per-tool PR checklist.

```
[ ] 1. FreeCAD source identified: file path:line of Command registration
[ ] 2. FreeCAD behavior analyzed: documented in catalog Notes column
[ ] 3. Facade method added with signature matching § 2.1
[ ] 4. Facade method handles FacadeError::InvalidArgument for every
       argument that can be invalid (bounds, null refs, empty lists)
[ ] 5. Facade method opens transaction (if mutating) per § 2.5
[ ] 6. Facade method recomputes per § 2.6 before return
[ ] 7. Q_INVOKABLE on CadEngine follows § 3.1 pattern
[ ] 8. QML button in correct toolbar (per § 5.1) using CadToolButton (§ 5.2)
[ ] 9. Icon in resources/icons/<wb>/<name>.svg (copied from FreeCAD or custom)
[ ] 10. Tooltip string matches FreeCAD's sToolTipText (parity)
[ ] 11. Shortcut set to FreeCAD's sAccel (if defined)
[ ] 12. TaskPanel/dialog (if parameterized) mirrors every field of FreeCAD .ui
[ ] 13. Unit test added: tests/parity_suite/<wb>/test_<tool>.cpp
[ ] 14. Unit test asserts: (a) success path produces FreeCAD-equivalent output,
       (b) invalid inputs throw FacadeError with correct Code
[ ] 15. Catalog row status set to DONE with commit SHA reference
```

**Enforcement:** A PR that claims to complete a tool but fails any of these 15 items is rejected in review. Partial completion → row status `DOING` with comment listing blocking items.

---

## 7. Commit Protocol

### 7.1 Commit Cadence

**One tool per commit.** Batching tools into a single commit is permitted only for:
- Composite dropdown entries that have no standalone logic (e.g. CmdSketcherCompCreateArc is just menu, not a separate tool)
- Identical primitive variants that share 95% code (the 8 additive primitives — one commit with all 8 for efficiency, but commit message explicitly enumerates)

### 7.2 Commit Message Format

```
feat(<wb>-<sub>): <tool-name> parity [N/M]

<free-form description if needed>

FreeCAD source: src/Mod/<WB>/Gui/<Command>.cpp:<line>
Adapter method: <Facade>::<method>()
QML: ui/qml/<path>
Test: tests/parity_suite/<wb>/test_<tool>.cpp

Completed items (15/15):
  ✓ Source identified
  ✓ Behavior analyzed
  ✓ Facade method § 2.1 compliant
  ... (list all 15)

Catalog: .ai/CATALOG_<WB>.md row <N> → DONE

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
```

### 7.3 Sub-phase Completion Commit

When all tools in a sub-phase are DONE, a summary commit:

```
feat(<wb>-<sub>): sub-phase <name> complete (<M>/<M> tools)

Summary of sub-phase <1A|1B|...> completion.
All <M> tools in .ai/CATALOG_<WB>.md (sub-phase rows) marked DONE.

Smoke test: tests/smoke_<wb>_<sub>.cpp — PASSING
Build: clean (warnings: 0 new)
Lint: clang-tidy clean (per .clang-tidy policy)

Next: sub-phase <1B|...>

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
```

### 7.4 Phase Completion Tag

When a whole phase is done:

```bash
git tag -a "phase-1-sketch-parity" -m "Phase 1 complete: 161 Sketcher tools at FreeCAD parity"
git push origin phase-1-sketch-parity
```

Tags are immutable history markers. They gate the next phase start.

### 7.5 Push Frequency

- Push to origin after every sub-phase completion commit
- Never push partial/broken work
- CI must pass before push: `cmake --build build && ctest --test-dir build`

---

## 8. Roll-Forward Only Policy

**Once a tool is DONE:**
1. Its test is added to `tests/parity_suite/`
2. The test is part of the CI regression suite
3. Any future commit that breaks the test fails CI
4. A DONE tool cannot be moved back to DOING/TODO without a regression ticket

**Exception:** A tool can be moved to BLOCKED if its Python/OCCT dependency regresses (e.g., Python 3.12 breaks a script). In this case:
- Blocking cause documented in catalog
- Git issue filed
- Tool moves to BLOCKED, not DOING
- Phase is impacted only if the tool is a core-path tool

**Never silently delete tests or mark passing ones xfail.**

---

## 9. Lint / Static Analysis

### 9.1 C++ (adapter/, app/)

- **clang-tidy** per `.clang-tidy` — must pass clean on every PR
- **clang-format** per `.clang-format` — every commit
- Warnings as errors (`-Werror`) for adapter/ code

### 9.2 QML

- **qmllint** — QML files lint clean
- `qsTr()` wrapping verified by script: no hardcoded user-facing strings

### 9.3 Python (CAMScripts, posts)

- We do not modify FreeCAD Python (LGPL source). Our additions (codesys_post.py, any helper scripts):
  - **ruff** for lint
  - **mypy --strict** optional (PEP-484)
  - PEP-8 style

---

## 10. Regression & CI Contract

### 10.1 Test Suite Layout

```
tests/
├── smoke_sketch_e2e.cpp           # Phase 1 smoke — full workflow
├── smoke_part_e2e.cpp             # Phase 2 smoke
├── smoke_cam_e2e.cpp              # Phase 3 smoke
├── parity_suite/
│   ├── sketch/
│   │   ├── test_drawing_line.cpp
│   │   ├── test_drawing_arc.cpp
│   │   ├── ...                     # one per tool (161 files for Phase 1)
│   ├── part/                        # 45 files
│   └── cam/                         # 88 files
├── golden/
│   ├── part_e2e.step               # STEP golden for Phase 2 smoke
│   ├── cam_e2e_codesys.cnc         # CNC golden for Phase 3 smoke
│   └── <per-tool-golden files>     # where needed
└── CMakeLists.txt
```

### 10.2 Test Structure (every test)

```cpp
#include <gtest/gtest.h>
#include "adapter/CadSession.h"
#include "adapter/SketchFacade.h"
#include "test_helpers.h"

using namespace CADNC;

TEST(SketchDrawingLine, HappyPath) {
    auto session = CadSession::create();
    auto doc = session->newDocument("Unnamed");
    auto sketch = doc->addSketch();

    int id = sketch->addLine(0, 0, 100, 0, false);

    ASSERT_GE(id, 0);
    auto geo = sketch->geometry(id);
    ASSERT_EQ(geo.type, GeoType::LineSegment);
    ASSERT_NEAR(geo.endpoint(0).x(), 0.0, 1e-9);
    ASSERT_NEAR(geo.endpoint(1).x(), 100.0, 1e-9);
    ASSERT_FALSE(geo.isConstruction);
}

TEST(SketchDrawingLine, ConstructionMode) {
    // ... parallel for construction=true ...
}

TEST(SketchDrawingLine, InvalidDocument) {
    auto facade = SketchFacade(nullptr);  // no document
    EXPECT_THROW(facade.addLine(0, 0, 1, 1, false), FacadeError);
}
```

### 10.3 CI Pipeline (GitHub Actions, self-hosted)

```yaml
jobs:
  build_and_test:
    steps:
      - checkout
      - apt install deps  # known list
      - cmake configure
      - cmake build --parallel $(nproc)
      - ctest --output-on-failure  # fails if any test fails
      - clang-tidy --check  # warnings allowed for freecad/, not for adapter/
      - qmllint ui/qml/**/*.qml
```

**CI must pass before any merge. No overrides, no --force.**

---

## 11. Documentation per Tool

Every tool is documented in **exactly 2 places**:

1. **Catalog row** in `.ai/CATALOG_<WB>.md` — single-line summary with status
2. **In-code comment** at the Facade method — 3-line docstring:

```cpp
/// @brief Creates a line segment in the active sketch.
/// @freecad-parity CmdSketcherCreateLine (src/Mod/Sketcher/Gui/CommandCreateGeo.cpp:XX)
/// @throws FacadeError if no active sketch or invalid coordinates.
int addLine(double x1, double y1, double x2, double y2, bool construction);
```

**Banned:** multi-paragraph docstrings, tutorial comments, history comments. The catalog has history, git log has history. Comments are for contract.

---

## 12. Violation → Rejection Matrix

| Violation | Severity | Rejection Trigger |
|-----------|----------|-------------------|
| QML includes FreeCAD header | **CRITICAL** | PR rejected |
| Facade returns OCCT/FreeCAD pointer | **CRITICAL** | PR rejected |
| Facade doesn't open/commit transaction | **HIGH** | Fix required before merge |
| Facade swallows exception | **HIGH** | Fix required before merge |
| Tool DONE without test | **HIGH** | Reclassify as DOING |
| Tool DONE without 15/15 checklist | **HIGH** | Reclassify as DOING |
| Tooltip doesn't match FreeCAD | **MEDIUM** | Fix in next commit |
| Shortcut missing/different | **MEDIUM** | Fix in next commit |
| QML string not qsTr()-wrapped | **LOW** | Fix when found |
| Icon missing | **LOW** | Placeholder ok, resolve by phase exit |
| Banned commented-out code | **LOW** | Fix in next commit |
| Comment is multi-paragraph docstring | **LOW** | Trim in next commit |

---

## 13. Appendix — Facade Method Signature Examples

### SketchFacade (strict signatures)

```cpp
// Section: Drawing
int addLine(double x1, double y1, double x2, double y2, bool construction);
int addPoint(double x, double y);
int addCircle(double cx, double cy, double radius);
int addArcCenter(double cx, double cy, double radius,
                  double startAngleRad, double endAngleRad);
int addArc3Point(double x1, double y1,
                  double x2, double y2,
                  double x3, double y3);
int addRectangle(double x1, double y1, double x2, double y2);
int addBSpline(const QList<QPointF>& controlPoints, int degree = 3);

// Section: Constraints — Geometric
int constrainHorizontal(const QList<int>& geoIds);
int constrainVertical(const QList<int>& geoIds);
int constrainCoincidentUnified(const QList<SketchPoint>& points);
int constrainEqual(const QList<int>& geoIds);

// Section: Constraints — Dimensional
int constrainDistance(int geoId1, int geoId2, double value);
int constrainDistanceX(int geoId1, int geoId2, double value);
int constrainRadius(int geoId, double value);
int constrainDiameter(int geoId, double value);
int constrainAngle(int geoId1, int geoId2, double valueRadians);
int constrainLock(int pointId, double x, double y);
// ... complete list in CATALOG_SKETCHER.md ...
```

### PartFacade (strict signatures)

```cpp
QString createBody(const QString& name = "Body");
QString pad(const QString& sketchName,
             double length,
             PadType type = PadType::Dimension,
             bool midPlane = false,
             bool reversed = false,
             double length2 = 0,
             const QString& upToFace = "",
             double offset = 0);

QString fillet(const QStringList& edgeRefs, double radius);
QString linearPattern(const QStringList& features,
                      const QString& directionRef,
                      double length, int occurrences);
// ... complete list in CATALOG_PARTDESIGN.md ...

enum class PadType { Dimension, UpToLast, UpToFirst, UpToFace, TwoLengths };
enum class ChamferType { Equal, TwoDistances, DistanceAngle };
```

### CamFacade (strict signatures)

```cpp
QString createJob(const QString& baseModelName,
                   const QVariantMap& stockConfig,
                   const QString& postProcessor = "generic");

QString addProfile(const QString& jobName,
                    const QStringList& faceRefs,
                    const QVariantMap& params);

QString postProcess(const QString& jobName,
                    const QString& outputPath);

QStringList listPostProcessors();  // 35 + codesys
```

---

**END WRAPPER_CONTRACT**

*Any change to this contract requires a plan-level RFC and explicit user sign-off. The contract is the law.*
