# CADNC Master Work Plan

## Vizyon

CODESYS SoftMotion CNC kontrol cihazlari icin G-Code ureten, modern arayuzlu bir masaustu CAD-CAM uygulamasi.

**Strateji:** FreeCAD'in olgun CAD backend'ini (Sketcher, Part, PartDesign) kullanarak kendi sketch/constraint/feature altyapimizi sifirdan yazmak yerine hazir ve test edilmis bir temele yaslanmak. Uzerine ince bir adapter katmani ve modern QML arayuzu koymak.

---

## Faz 0: Proje Iskeleti [TAMAMLANDI - 2026-04-12]

- [x] CADNC dizin yapisi olusturuldu
- [x] FreeCAD modulleri kopyalandi (Base, App, Part/App, Sketcher/App, PartDesign/App)
- [x] FreeCAD 3rdParty kopyalandi (json, PyCXX, zipios++, FastSignals)
- [x] MilCAD'den CAM modulu tasindi (26 header, 24 source)
- [x] MilCAD'den Nesting modulu tasindi (6 header, 5 source)
- [x] MilCAD'den 92 SVG ikon, utility, config tasindi
- [x] Git repo kuruldu, GitHub'a push edildi

---

## Faz 1: FreeCAD Build Entegrasyonu [TAMAMLANDI - 2026-04-14]

- [x] FreeCADBase — 8.5MB (Boost, XercesC, ZLIB, ICU, Python3, PyCXX, zipios++, FastSignals, fmt)
- [x] FreeCADApp — 24MB (FreeCADBase, Qt6::Core, Qt6::Xml, Boost::program_options, fmt)
- [x] Materials — 6.7MB (FreeCADApp, yaml-cpp)
- [x] Part — 19MB (FreeCADApp, Materials, OCCT 30+ lib, fmt)
- [x] Sketcher — 20MB (Part, Eigen3, planegcs, nlohmann-json)
- [x] PartDesign — 5.2MB (Part, Sketcher, OCCT)
- [x] PoC test: headless init → document → SketchObject → geometry + constraint → solver → BASARILI
- [x] C++20 gerekli, FreeType/harfbuzz opsiyonel (HAVE_FREETYPE guard)

---

## Faz 2: Adapter Katmani [TAMAMLANDI - 2026-04-15]

- [x] CadSession — FreeCAD Application::init(), module registration, shutdown
- [x] CadDocument — newDocument, featureTree, undo/redo, addSketch, recompute
- [x] SketchFacade — addLine/Circle/Arc/Rectangle/Point, constraints (12 type), trim, fillet, solve, geometry/constraint query
- [x] PartFacade — pad, pocket, revolution (skeleton: fillet3d, chamfer3d, patterns)
- [x] CadEngine (QObject) — QML bridge, Q_INVOKABLE methods, Q_PROPERTY for featureTree/sketchGeometry/constraints/solverStatus
- [x] Adapter test: CadSession → CadDocument → SketchFacade → solve → BASARILI
- [x] cadnc_adapter static library, cadnc executable linked

---

## Faz 3: UI Shell + Sketch Drawing [TAMAMLANDI - 2026-04-15]

- [x] Main.qml — MilCAD-style layout: Quick Access Bar + Workbench Tabs + Toolbar + Panels + Status Bar
- [x] QAButton, QASep inline components (MilCAD birebir)
- [x] Workbench tabs — Part/Sketch/CAM/Nesting with icons and accent underline
- [x] SketchToolbar — Line, Circle, Arc, Rect, Polyline, Ellipse, Spline, Point + Trim, Offset, Mirror, Fillet, Chamfer, Extend + 11 constraint buttons + solver badge
- [x] PartToolbar — ribbon groups: Features, Dress-Up, Patterns, Primitives, Boolean
- [x] CAMToolbar — ribbon groups: Setup, Operations, Post-Process + G-code/CODESYS export buttons
- [x] NestingToolbar — Parts, Sheet, Params, Nest + DXF/G-Code export buttons
- [x] ModelTreePanel — color-coded feature tree, type badges, double-click to edit
- [x] ConstraintPanel — purple theme, satisfied/delete indicators
- [x] SketchCanvas — 2D Canvas (grid, axes, geometry render, pan/zoom/select, draw tools)
- [x] NavCube — QML replica (Faz 5'te OCCT AIS_ViewCube ile degistirilecek)
- [x] AxisIndicator — MilCAD-style XYZ gizmo
- [x] DimensionInput popup — Distance/Radius/Angle selector
- [x] StatusBar — SNAP/GRID/ORTHO toggles, cursor XY, geo/constr badges, solver status
- [x] Keyboard shortcuts — L, C, R, A, H, D, Escape, Delete
- [x] Light mode viewport (#E8EAF0)

---

## Faz 4: 3D Feature Zinciri [SIRADAKI]

- [ ] Pad dialog (PartFacade.pad + UI popup)
- [ ] Pocket dialog
- [ ] Revolution dialog
- [ ] 3D Fillet/Chamfer (edge selection gerekli)
- [ ] Linear/Polar Pattern, Mirror
- [ ] Feature tree senkronizasyonu — recompute sonrasi UI guncelleme
- [ ] Undo/Redo UI entegrasyonu

---

## Faz 5: Viewport ve Rendering [BEKLIYOR]

**KRITIK: AIS_ViewCube + AIS_Triedron bu fazda native OCCT olarak gelecek**

- [ ] OCCT V3d_Viewer + QQuickFramebufferObject entegrasyonu
- [ ] TopoDS_Shape → AIS_Shape rendering
- [ ] AIS_ViewCube (native NavCube — QML replica'yi degistirecek)
- [ ] AIS_Triedron (native axis gizmo)
- [ ] Selection highlighting (AIS_InteractiveContext)
- [ ] Grid + snap (render thread'de)
- [ ] View presets (top, front, right, isometric)
- [ ] Zoom, pan, orbit
- [ ] Sketch mode 2D overlay

---

## Faz 6: CAM/Nesting Entegrasyonu [BEKLIYOR]

- [ ] CamGeometrySource adapter
- [ ] Facing, Profile, Pocket, Drill operasyonlari
- [ ] G-Code generation (CODESYS + Generic)
- [ ] Nesting (BLF, BBox, NFP)
- [ ] CamPanel — G-code preview, simulation controls, operation queue

---

## Faz 7: UI Modernizasyonu [BEKLIYOR]

- [ ] Property panel — FreeCAD property QML gosterim
- [ ] Dimension input on-canvas (MilCAD-style SmartDimension)
- [ ] File dialogs (new doc, open, save, export STEP/IGES/DXF/STL)
- [ ] Theme sistemi (dark/light toggle)
- [ ] User preferences

---

## Basari Kriterleri

| Faz | Basari Kriteri |
|-----|----------------|
| 1 | FreeCAD modulleri derleniyor, PoC sketch + constraint cozuyor |
| 2 | Adapter uzerinden sketch olustur, line ekle, dimension ver |
| 3 | UI'dan sketch ciz, constraint uygula, solver calistir |
| 4 | Tam feature zinciri: sketch → pad → fillet → pocket |
| 5 | 3D viewport'ta shape goruntuleme, secim, AIS_ViewCube |
| 6 | Sketch → Part → CAM → G-Code tam pipeline |
| 7 | Urun kalitesinde UI, tercihleri kaydet/yukle |
