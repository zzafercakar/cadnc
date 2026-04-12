# CADNC — Start Here

## What is CADNC?

A desktop CAD-CAM application that uses **FreeCAD's core modules** as its CAD backend
and provides a **modern QML-based UI**. The geometry kernel is **OpenCASCADE (OCCT)**.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│  UI Shell (QML)                                     │
│  - Main.qml, toolbars, panels                       │
├─────────────────────────────────────────────────────┤
│  Adapter Layer (C++)                                │
│  - CadSession, CadDocument, SketchFacade, PartFacade│
├─────────────────────────────────────────────────────┤
│  FreeCAD Modules (LGPL)                             │
│  - Base, App, Part, Sketcher, PartDesign            │
├─────────────────────────────────────────────────────┤
│  OpenCASCADE (OCCT) Kernel                          │
└─────────────────────────────────────────────────────┘

Side modules (proprietary):
  - CAM: G-Code generation, toolpath, post-processing
  - Nesting: Sheet nesting algorithms
```

## Key Design Principles

1. **UI never touches FreeCAD types directly** — always through adapter facades
2. **FreeCAD modules are used as-is** — minimal modifications to enable upgrades
3. **OCCT remains the geometry kernel** — FreeCAD wraps it, we don't replace it
4. **CAM and Nesting are independent** — pluggable, not tied to FreeCAD

## Directory Structure

```
CADNC/
├── freecad/          # FreeCAD backend (Base, App, Part, Sketcher, PartDesign)
├── adapter/          # Facade layer (CADNC API)
├── cam/              # CAM module (MilCAD origin)
├── nesting/          # Nesting module (MilCAD origin)
├── ui/               # QML UI shell
├── viewport/         # 3D viewport
├── app/              # Entry point (main.cpp)
├── resources/        # Icons, images, logos
├── tests/            # Unit tests
├── .ai/              # AI context files
└── doc/              # Documentation
```

## Build & Run

```bash
cmake -B build -S . && cmake --build build -j$(nproc)
DISPLAY=:0 QT_QPA_PLATFORM=xcb ./build/cadnc
```

## Development Phases

1. **Faz 0** (current): Project skeleton, copy assets, setup repo
2. **Faz 1**: Wire FreeCAD module build (CMake integration)
3. **Faz 2**: Implement adapter facades (SketchFacade, PartFacade)
4. **Faz 3**: Critical sketch operations (dimension, trim, fillet, chamfer)
5. **Faz 4**: 3D features (pad, pocket, fillet3D, chamfer3D)
6. **Faz 5**: Viewport and rendering
7. **Faz 6**: CAM/nesting integration with new backend

## Communication

- Code and comments: English
- User communication: Turkish
