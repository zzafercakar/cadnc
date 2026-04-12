# CADNC — Claude Code Project Instructions

## First Steps (Every Session)

1. Read `.ai/START_HERE.md`
2. Read `.ai/context.yaml` — full project state
3. Read `.ai/WORKPLAN.md` — current phase and next actions
4. Check `.ai/ENGINEERING_LOG.md` for known issues

## Project Overview

CADNC is a CAD-CAM desktop application using FreeCAD's core modules (Base, App, Part, Sketcher, PartDesign) as CAD backend with a modern Qt6 QML UI.

## Architecture

```
UI Shell (QML) → Adapter Layer (C++) → FreeCAD Modules → OCCT Kernel
                                     → CAM Module
                                     → Nesting Module
```

## Critical Rules

- UI code MUST NOT include FreeCAD headers — use adapter/ facades only
- AIS_InteractiveContext operations ONLY in render thread — never UI thread
- Linux: NEVER use EGL — OCCT compiled with GLX
- OCCT libraries must be listed individually, not via ${OpenCASCADE_LIBRARIES}
- FreeCAD modules: minimal modifications — preserve upstream compatibility
- Python dependency accepted — do not attempt to remove

## Build

```bash
cmake -B build -S .
cmake --build build -j$(nproc)
DISPLAY=:0 QT_QPA_PLATFORM=xcb ./build/cadnc
```

## Coding Standards

- Language: C++17
- Code/comments: English
- User communication: Turkish
- Namespace: CADNC
- Classes: PascalCase, variables: camelCase, members: trailing_underscore_
- Module layout: inc/ (headers), src/ (sources)
- Every important operation: inline comment explaining why

## Reference Sources

Detailed file paths in `.ai/REFERENCE_SOURCES.md`:
- FreeCAD: `/home/embed/Downloads/FreeCAD-main-1-1/`
- MilCAD: `/home/embed/Dev/MilCAD/`
- LibreCAD, SolveSpace, Luban: `/home/embed/Downloads/`
