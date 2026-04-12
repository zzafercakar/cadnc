# CADNC

A modern CAD-CAM desktop application built on FreeCAD's core modules with a Qt6 QML interface.

## Architecture

- **Backend**: FreeCAD App/Part/Sketcher/PartDesign modules
- **Kernel**: OpenCASCADE (OCCT)
- **UI**: Qt6 Quick / QML
- **CAM**: Custom toolpath generation and G-Code output
- **Nesting**: Sheet nesting optimization

## Build

### Prerequisites (Ubuntu)

```bash
sudo apt install python3-dev libboost-all-dev libxerces-c-dev zlib1g-dev \
    libicu-dev opencascade-dev qt6-declarative-dev qt6-declarative-dev-tools \
    libeigen3-dev libfreetype-dev libgl-dev libglx-dev qt6-svg-dev libqt6svg6
```

### Build & Run

```bash
cmake -B build -S .
cmake --build build -j$(nproc)
DISPLAY=:0 QT_QPA_PLATFORM=xcb ./build/cadnc
```

## Project Structure

```
CADNC/
├── freecad/      # FreeCAD backend modules (LGPL)
├── adapter/      # Facade layer (FreeCAD → CADNC API)
├── cam/          # CAM: toolpath, G-Code, post-processing
├── nesting/      # Sheet nesting algorithms
├── ui/           # QML UI shell
├── viewport/     # 3D viewport
├── app/          # Application entry point
├── resources/    # Icons, images
├── tests/        # Unit tests
└── doc/          # Documentation
```

## License

FreeCAD modules: LGPL-2.1-or-later (see `freecad/LICENSE`)
Application code: Proprietary
