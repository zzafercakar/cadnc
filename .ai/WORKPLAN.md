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

## Faz 4: 3D Feature Zinciri [TAMAMLANDI - 2026-04-15]

- [x] CadEngine QML'e bağlandı (main.cpp'de instance oluşturuldu, QML context'e expose edildi)
- [x] Pad dialog (FeatureDialog.qml — sketch seçimi + length girişi + PartFacade.pad çağrısı)
- [x] Pocket dialog (aynı FeatureDialog, featureType="pocket")
- [x] Revolution dialog (aynı FeatureDialog, featureType="revolve")
- [x] CadEngine'e pad/pocket/revolution Q_INVOKABLE metotları eklendi
- [x] CadEngine'e canUndo/canRedo/sketchNames Q_PROPERTY eklendi
- [x] Feature tree senkronizasyonu — featureTreeChanged sinyali ile otomatik güncelleme
- [x] Undo/Redo UI entegrasyonu — opacity ile disabled durumu gösterimi
- [x] PartToolbar aksiyonları dialog'lara bağlandı
- [ ] 3D Fillet/Chamfer (edge selection gerekli — Faz 5 viewport sonrası)
- [ ] Linear/Polar Pattern, Mirror (PartFacade'de TODO)

---

## Faz 5: Viewport ve Rendering [TAMAMLANDI - 2026-04-15]

- [x] OCCT V3d_Viewer + QQuickFramebufferObject entegrasyonu (OccViewport + OccRenderer)
- [x] TopoDS_Shape → AIS_Shape rendering (CadEngine → OccViewport → OccRenderer pipeline)
- [x] AIS_ViewCube (native OCCT — upper-right, animated, clickable)
- [x] AIS_Triedron (native ZBuffer triedron — lower-left)
- [x] Selection highlighting (AIS_InteractiveContext, deferred to render thread)
- [x] Rectangular grid (Aspect_GDM_Points, 10mm spacing)
- [x] Zoom (wheel), pan (middle-drag), orbit (right-drag) via AIS_ViewController
- [x] GlTools utility (Qt↔OCCT coordinate conversion, modifier/button mapping)
- [x] QtFrameBuffer (sRGB-safe FBO wrapper)
- [x] Thread-safe shape operations (mutex-protected queue, processed in render())
- [x] CadEngine → OccViewport pipeline (pad/pocket/revolution → auto-display in 3D)
- [x] Gradient background, 8x MSAA, high-quality tessellation
- [ ] View presets (top, front, right, isometric — ViewCube handles this, dedicated buttons pending)
- [ ] Sketch mode 2D overlay (future enhancement)

---

## Faz 6: CAM/Nesting Entegrasyonu [TAMAMLANDI - 2026-04-15]

- [x] CamFacade adapter — CAM operations bridge (Profile, Pocket, Drill, Facing)
- [x] NestFacade adapter — Nesting operations bridge (BLF, BBox algorithms)
- [x] CadEngine CAM Q_INVOKABLE metotları (setStock, addTool, addController, addProfile, addPocket, addDrill, addFacing, generateGCode, exportGCode)
- [x] CadEngine Nesting Q_INVOKABLE metotları (addPart, clearParts, setSheet, setPartGap, setEdgeGap, setRotation, run)
- [x] G-Code generation — Fanuc + LinuxCNC/CODESYS post-processors
- [x] G-Code export — file dialog integration (standard + CODESYS)
- [x] CAM toolbar actions connected (export G-Code, CODESYS export)
- [x] Nesting toolbar actions connected (run nesting, optimize with rotation)
- [x] CAM/Nesting modules compiled into cadnc_adapter static library
- [ ] CamPanel — G-code preview (gelecekte)
- [ ] Nesting visualization — visual part placement on sheet (gelecekte)
- [ ] Tool path visualization in viewport (gelecekte)

---

## Faz 7: UI Modernizasyonu [TAMAMLANDI - 2026-04-15]

- [x] Theme.qml singleton — centralized dark/light tema sistemi (100+ semantic color token)
- [x] PropertiesPanel — feature parametre görüntüleme (document info, sketch stats, display settings)
- [x] ModelTreePanel — gelişmiş: context menu (Edit/Rename/Delete), selection highlight, document origin row, type badge, footer count
- [x] ConstraintPanel — tema entegrasyonu, gelişmiş görünüm
- [x] File dialogs — Open (FCStd/STEP/IGES), Save (FCStd), Export (STEP/IGES/STL/DXF)
- [x] Viewport context menu — right-click: Fit All, view presets, Create Sketch
- [x] Dark/Light mode toggle — header button + Ctrl+T shortcut + View menu
- [x] Menu bar — gelişmiş: Export submenu, enabled/disabled undo/redo, theme toggle
- [x] Quick Access Bar — tema uyumlu, dark mode destekli
- [x] Status Bar — gelişmiş badges (solver, geo count), tema uyumlu
- [x] About Dialog — gelişmiş: viewport bilgisi eklendi
- [x] All panels — context-sensitive: sketch mode → Constraints + Properties, part mode → Properties only
- [ ] Dimension input on-canvas (SmartDimension — gelecekte)
- [ ] User preferences dialog (gelecekte)

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
