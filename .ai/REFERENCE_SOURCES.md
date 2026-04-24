# CADNC Reference Sources & File Paths

Bu dosya, projenin yaslandigi tum acik kaynak ve dahili kaynaklarin dosya yollarini,
modul yapilarini ve onemli dosyalari kayit altina alir.

---

## 1. FreeCAD Kaynak Kodu

**Konum:** `/home/embed/Downloads/FreeCAD-main-1-1-git/`
**Versiyon:** FreeCAD 1.2.0-dev
**Lisans:** LGPL-2.1-or-later
**Kullanim:** CAD backend — Base, App, Part, Sketcher, PartDesign modulleri dogrudan projeye kopyalandi

### 1.1 Base Modulu (Math, I/O, Type System, Python)
**Kaynak:** `/home/embed/Downloads/FreeCAD-main-1-1-git/src/Base/`
**Hedef:** `freecad/Base/` (173 dosya)

Kritik dosyalar:
- `Vector3D.cpp/h` (539/288 satir) — 3D vektor
- `Matrix.cpp/h` (1033/444) — Matris islemleri
- `Rotation.cpp/h` (1103/198) — Quaternion rotasyon
- `Placement.cpp/h` (228/121) — Pozisyon + rotasyon
- `Type.cpp/h` (249/201) — RTTI tip sistemi
- `BaseClass.cpp/h` (111/241) — Tum FreeCAD nesnelerinin base class'i
- `Console.cpp/h` (824/1048) — Konsol I/O
- `Exception.cpp/h` (622/568) — Exception sistemi
- `Reader.cpp/h` (728/417) — Dokuman okuma
- `Writer.cpp/h` (442/331) — Dokuman yazma
- `Persistence.cpp/h` (232/170) — Serializasyon arayuzu
- `Quantity.cpp/h` — Fiziksel birim sistemi
- `Unit.cpp/h` — Birim tanimlari
- `UnitsApi.cpp/h` — Birim API'si
- `Parameter.cpp/h` — Parametre yonetimi
- `Interpreter.cpp/h` — Python yorumlayici entegrasyonu
- `PyObjectBase.cpp/h` — Python base nesne

### 1.2 App Modulu (Document, Property, Expression, Transaction)
**Kaynak:** `/home/embed/Downloads/FreeCAD-main-1-1-git/src/App/`
**Hedef:** `freecad/App/` (210 dosya, 4.5 MB)

Dokuman yonetimi:
- `Document.cpp/h` (4024/1489) — Ana dokuman sinifi
- `DocumentObject.cpp/h` (1611/1366) — Dokumandaki nesnelerin base class'i
- `DocumentObserver.cpp/h` (1062/658) — Observer pattern

Property sistemi:
- `Property.cpp/h` (442/1145) — Base property
- `PropertyStandard.cpp/h` (3671/1347) — String, int, float, bool
- `PropertyLinks.cpp/h` (6020/1658) — Nesne baglantilari
- `PropertyGeo.cpp/h` (1328/580) — Geometrik property'ler
- `PropertyContainer.cpp/h` (650/853) — Property container
- `PropertyExpressionEngine.cpp/h` (1198/376) — Expression motoru
- `PropertyUnits.cpp/h` (873/926) — Birimli property'ler

Expression sistemi:
- `Expression.cpp/h` (3790/581) — Expression parser/evaluator
- `ExpressionTokenizer.cpp/h` (157/54) — Tokenizer
- `ExpressionParser.h` (690) — Parser tanimlari

Transaction sistemi:
- `Transactions.cpp/h` (558/349) — Undo/redo
- `TransactionalObject.cpp/h` (53/73) — Transactional base

Extension sistemi:
- `Extension.cpp/h` (233/368) — Extension base
- `ExtensionContainer.cpp/h` (521/353) — Extension container
- `GeoFeatureGroupExtension.cpp/h` (568/160) — Geometrik gruplama

Feature siniflar:
- `GeoFeature.cpp/h` (360/217) — Geometrik feature base
- `FeaturePython.cpp/h` (770/461) — Python feature

### 1.3 Part/App Modulu (TopoShape, Geometry, Features)
**Kaynak:** `/home/embed/Downloads/FreeCAD-main-1-1-git/src/Mod/Part/App/`
**Hedef:** `freecad/Mod/Part/App/` (286 dosya, 4.5 MB)

Ana siniflar:
- `TopoShape.cpp` (~157K satir) — OCCT TopoDS_Shape wrapper
- `TopoShapeExpansion.cpp` (~210K satir) — Shape operasyonlari
- `Geometry.cpp` (~246K satir) — Geometri siniflarilari (dev dosya)
- `Geometry2d.cpp/h` — 2D geometri
- `PartFeature.cpp/h` (11573) — Part feature base
- `Part2DObject.cpp/h` — 2D part nesnesi

Feature siniflar:
- `FeatureExtrusion.cpp/h` (523) — Extrusion
- `FeatureRevolution.cpp/h` (243) — Revolution
- `FeatureFillet.cpp/h` (131) — 3D Fillet
- `FeatureChamfer.cpp/h` (125) — 3D Chamfer
- `FeaturePartBoolean.cpp/h` (185) — Boolean base
- `FeaturePartFuse.cpp/h` (229) — Fuse/union
- `FeaturePartCut.cpp/h` — Cut
- `FeaturePartCommon.cpp/h` (174) — Common/intersection
- `FeatureMirroring.cpp/h` (361) — Mirror
- `FeatureOffset.cpp/h` (176) — Offset
- `FeatureScale.cpp/h` (185) — Scale

Yardimci siniflar:
- `Attacher.cpp/h` (19491) — Geometri baglama sistemi
- `FaceMaker.cpp/h` — Yuz olusturma
- `WireJoiner.cpp/h` — Tel birlestirme
- `modelRefine.cpp/h` — Shape refinement
- `ExtrusionHelper.cpp/h` — Extrusion yardimcilari

### 1.4 Sketcher/App Modulu (SketchObject, Constraints, planegcs)
**Kaynak:** `/home/embed/Downloads/FreeCAD-main-1-1-git/src/Mod/Sketcher/App/`
**Hedef:** `freecad/Mod/Sketcher/App/` (58 dosya, 1.9 MB)

**BU MODUL EN KRITIK OLANDIR — MilCAD'deki tum sketch sorunlarini cozer.**

Ana siniflar:
- `SketchObject.cpp/h` (2231/1295) — Ana sketch nesnesi
- `Sketch.cpp/h` (5772/898) — Sketch geometri container
- `SketchObjectConstraints.cpp` (2834) — Constraint yonetimi
- `SketchObjectGeometry.cpp` (1762) — Geometri yonetimi
- `SketchObjectOperations.cpp` (3123) — Trim, fillet, chamfer, split islemleri
- `SketchObjectExternal.cpp` (2956) — Dis geometri referanslari
- `SketchAnalysis.cpp/h` (1039/212) — Sketch analiz

Constraint sistemi:
- `Constraint.cpp/h` (701/288) — Constraint sinifi
- `PropertyConstraintList.cpp/h` (645/187) — Constraint list property

Geometry facade:
- `GeometryFacade.cpp/h` (207/463) — Geometri erisim arayuzu
- `ExternalGeometryFacade.cpp/h` (192/331) — Dis geometri arayuzu
- `SolverGeometryExtension.cpp/h` (174/505) — Solver entegrasyonu
- `GeoList.cpp/h` (460/275) — Geometri listesi
- `GeoEnum.cpp/h` — Geometri numaralandirma

planegcs (Geometric Constraint Solver):
- `planegcs/GCS.cpp/h` (5818/702) — Ana constraint solver
- `planegcs/Constraints.cpp/h` (3232/1400) — Constraint tanimlari
- `planegcs/Geo.cpp/h` (1147/416) — Geometrik primitifler
- `planegcs/SubSystem.cpp/h` (349/97) — Alt sistem cozucu
- `planegcs/qp_eq.cpp/h` (74/34) — QP esitlik cozucu
- `planegcs/Util.h` (42) — Yardimci fonksiyonlar

### 1.5 PartDesign/App Modulu (Parametrik Feature Modelleme)
**Kaynak:** `/home/embed/Downloads/FreeCAD-main-1-1-git/src/Mod/PartDesign/App/`
**Hedef:** `freecad/Mod/PartDesign/App/` (80 dosya)

Body ve Feature base:
- `Body.cpp/h` (623/~300) — Body container
- `Feature.cpp/h` (605/~250) — Feature base sinifi
- `FeatureBase.cpp/h` — Feature base yardimcilari
- `FeatureAddSub.cpp/h` (195/~150) — Add/subtract base
- `FeatureSketchBased.cpp/h` (1520/~400) — Sketch-tabanli feature base
- `FeatureDressUp.cpp/h` (~500/~180) — Dress-up base (fillet, chamfer, draft)
- `FeatureTransformed.cpp/h` (471/~200) — Transform base (pattern, mirror)

Sketch-tabanli feature'lar:
- `FeatureExtrude.cpp/h` (1006/~200) — Extrusion (Pad'in ic implementasyonu)
- `FeaturePad.cpp/h` (113/~130) — Pad feature
- `FeaturePocket.cpp/h` (138/~130) — Pocket feature
- `FeatureRevolved.cpp/h` (~500/~200) — Revolution
- `FeatureGroove.cpp/h` (~200/~130) — Groove (subtractive revolution)
- `FeatureLoft.cpp/h` (420/~150) — Loft
- `FeaturePipe.cpp/h` (759/~200) — Sweep/Pipe
- `FeatureHelix.cpp/h` (858/~200) — Helix

Dress-up feature'lar:
- `FeatureFillet.cpp/h` (~300/~130) — 3D Fillet
- `FeatureChamfer.cpp/h` (~400/~150) — 3D Chamfer
- `FeatureDraft.cpp/h` (~500/~160) — Draft angle
- `FeatureThickness.cpp/h` (~300/~130) — Shell/thickness

Pattern feature'lar:
- `FeatureLinearPattern.cpp/h` (591/~200) — Lineer pattern
- `FeaturePolarPattern.cpp/h` (394/~180) — Polar pattern
- `FeatureMultiTransform.cpp/h` (~300/~140) — Coklu transform
- `FeatureMirrored.cpp/h` (~300/~140) — Mirror
- `FeatureScaled.cpp/h` (~200/~140) — Scale

Boolean & diger:
- `FeatureBoolean.cpp/h` (~300/~150) — Boolean islemler
- `FeatureHole.cpp/h` (2724/~400) — Hole (karisik)
- `FeaturePrimitive.cpp/h` (827/~400) — Primitif sekiller
- `FeatureRefine.cpp/h` (~200/~130) — Refinement

Datum feature'lar:
- `DatumPlane.cpp/h` (108/~100) — Referans duzlem
- `DatumLine.cpp/h` (95/~100) — Referans cizgi
- `DatumPoint.cpp/h` (84/~100) — Referans nokta
- `DatumCS.cpp/h` (119/~100) — Koordinat sistemi

Diger:
- `ShapeBinder.cpp/h` (1291/~250) — Shape binding
- `Measure.cpp/h` — Olcum

### 1.6 3rdParty Kutuphaneler
**Kaynak:** `/home/embed/Downloads/FreeCAD-main-1-1-git/src/3rdParty/`
**Hedef:** `freecad/3rdParty/`

Kopyalananlar:
- `json/` — nlohmann JSON (header-only)
- `PyCXX/` — Python C++ bindings

Kopyalanmayanlar (ihtiyac olursa alinabilir):
- `OndselSolver/` — Constraint solver (bos dizin, external olarak alinabilir)
- `3Dconnexion/` — 3D mouse (simdilik gereksiz)
- `salomesmesh/` — FEM mesh (gereksiz)
- `libE57Format/` — Point cloud (gereksiz)
- `libkdtree/` — KD-tree (gereksiz)
- `GSL/` — GNU Scientific Library
- `FastSignals/` — Signal/slot
- `zipios++/` — ZIP handling

---

## 2. MilCAD Kaynak Kodu

**Konum:** `/home/embed/Dev/MilCAD/`
**Versiyon:** 0.8.0
**Lisans:** Proprietary
**Durum:** Aktif gelistirme (bazilar CADNC'ye tasindi, gerisi orada devam ediyor)

### 2.1 CADNC'ye Tasinan Moduller

CAM Modulu (dogrudan kopyalandi):
- `cam/inc/` (26 header) → `cam/inc/`
- `cam/src/` (24 source) → `cam/src/`
- Icerik: Operation (Facing, Profile, Pocket, Drill, Adaptive, Engrave, Helix, Slot),
  GCodeGenerator, GCodeParser, GCodeBlock, PostProcessor, GenericPostProcessor,
  CodesysPostProcessor, CodesysStExporters, Toolpath, ToolpathOptimizer, ToolpathRenderer,
  TspSolver, CamJob, CamGeometrySource, CamSimulator, DexelStockSimulator,
  StockVisualization, Tooling

Nesting Modulu (dogrudan kopyalandi):
- `nesting/inc/` (6 header) → `nesting/inc/`
- `nesting/src/` (5 source) → `nesting/src/`
- Icerik: NestTypes, NestJob, BottomLeftFillNester, BoundingBoxNester, NestingEngine, ProfileImporter

Utility (dogrudan kopyalandi):
- `util/inc/CoordinateMapper.h` → `util/inc/`
- `util/inc/Helpers.h` → `util/inc/`

Gorseller (dogrudan kopyalandi):
- `resources/icons/` (92 SVG) → `resources/icons/`
- `resources/image-*.png` (4 adet) → `resources/images/`
- `resources/smb_logo.*` (3 adet) → `resources/logos/`

Config (adapte edilerek kopyalandi):
- `.clang-tidy` → `.clang-tidy`
- `CMakePresets.json` → `CMakePresets.json` (MILCAD → CADNC)

Dokumantasyon:
- `doc/*.pdf` (4 adet) → `doc/`
- `.ai/PRD.md` → `doc/PRD.md`
- `qml/translation.js` → `ui/qml/translation.js`

### 2.2 CADNC'ye Tasinmayan (Emekli) MilCAD Dosyalari

**geometry/ modulu** (tum dosyalar — FreeCAD devralacak):
- Sketch entities: SketchEntity, SketchLine, SketchArc, SketchCircle, SketchEllipse, SketchSpline, SketchRectangle, SketchPolygon
- Constraints: SketchConstraint + 16 alt tip, ConstraintFactory
- Solver: GcsAdapter, SketchSolver, SketchDofAnalyzer
- Document: SketchDocument, SketchSnapshot
- Services: SketchEditService, SketchMeasurementService, SketchSelectionService
- Tools: SketchTrimTool, SketchFilletTool, SketchChamferTool, SketchSplitTool, SketchExtendTool, SketchOffsetTool
- Drawing: DrawingTool, DrawingStrategy, DrawingStrategies, DrawingTypes
- Shape: Shape, ShapeFactory, WireBuilder, FaceBuilder, ShapeRefine
- Features: PadFeature, PocketFeature, RevolutionFeature, FilletFeature, ChamferFeature, ShellFeature, LoftFeature, SweepFeature, LinearPatternFeature, CircularPatternFeature, MirrorFeature, DraftFeature, MultiTransformFeature
- Diger: Feature (base), PersistentSubshapeRef, PersistentFaceRef, ProfileRef, SketchScalePolicy

**core/ modulu** (tum dosyalar):
- Command, FeatureManager, FileManager, FrameBuffer, GlTools, OccRenderer, SceneManager, WorkbenchManager, PartEditService

**viewport/ modulu** (tum dosyalar):
- ViewerItem (6000+ satir god class), GridManager, SnapManager, SnapMarkerPresenter, InferenceLinePresenter

**input/ modulu**: MouseHandler, KeyboardHandler
**ui/ modulu**: PreviewOverlay
**third_party/planegcs/**: FreeCAD kendi planegcs'ini tasiyor
**qml/ dosyalari**: Tum QML dosyalari (yeni shell sifirdan)

### 2.3 MilCAD Referans Bilgiler (Yeni Projede Isimize Yarayacak)

MilCAD'den ogrenilenler:
- Thread safety: AIS_InteractiveContext islemleri render thread'de olmali
- OCCT GLX: Linux'ta EGL kullanilmamali, QT_XCB_GL_INTEGRATION=xcb_glx
- OccRenderer adlandirmasi: QQuickFramebufferObject::Renderer ile cakismayi onler
- OCCT linking: ${OpenCASCADE_LIBRARIES} yerine tek tek listelenmeli
- Qt 6.4.2: <qtypes.h> yok (6.5'te eklendi)
- OCC 7.6: V3d_View::Subviews() yok (7.7'de eklendi)
- Raw pointer signals: std::unique_ptr Qt signal'larda kullanilamaz

MilCAD test durumu (referans):
- 521 test, 448 geciyor (7 Clone fragility)
- Test altyapisi: Google Test 1.17.0

---

## 3. Diger Acik Kaynak Referans Projeler

Tum projeler `/home/embed/Downloads/` altinda mevcut:

### 3.1 FreeCAD (ikinci kopya)
- **Konum:** `/home/embed/Downloads/FreeCAD-main/` (4407 dosya)
- **Kullanim:** Ek referans, karsilastirma

### 3.2 LibreCAD
- **Konum:** `/home/embed/Downloads/LibreCAD-master/` (1496 dosya)
- **Lisans:** GPLv2
- **Kullanim:** 2D CAD referansi — snap UX, action factory, DXF workflow
- **Davranis referansi — kod kopyalanmaz**

### 3.3 SolveSpace
- **Konum:** `/home/embed/Downloads/solvespace-master/` (148 dosya)
- **Lisans:** GPLv3
- **Kullanim:** Constraint solver davranisi, trim/fillet/chamfer mantigi
- **Davranis referansi — kod kopyalanmaz**

### 3.4 OpenSCAD
- **Konum:** `/home/embed/Downloads/openscad-master/` (329 dosya)
- **Lisans:** GPLv2
- **Kullanim:** Parametrik tasarim, expression/evaluation graph
- **Davranis referansi**

### 3.5 Luban
- **Konum:** `/home/embed/Downloads/Luban-main/`
- **Lisans:** MIT (muhtemelen)
- **Kullanim:** JavaScript-tabanli CAM, NFP nesting referansi
- **Ozellikle:** Nesting Faz 6'da NFP algoritmasi icin referans

### 3.6 Geom
- **Konum:** `/home/embed/Downloads/geom-master/` (210 dosya)
- **Kullanim:** Geometri kutuphanesi referansi

### 3.7 MilCAD Linux
- **Konum:** `/home/embed/Downloads/milcad-linux/`
- **Kullanim:** MilCAD'in Linux uyumlu referans kopyasi

---

## 4. Lisans Uyumluluk Matrisi

| Kaynak | Lisans | Dogrudan Kod Kullanimi | Davranis Referansi |
|--------|--------|------------------------|-------------------|
| FreeCAD | LGPL-2.1 | EVET (modüller kopyalandi) | EVET |
| LibreCAD | GPLv2 | HAYIR | EVET |
| SolveSpace | GPLv3 | HAYIR | EVET |
| OpenSCAD | GPLv2 | HAYIR | EVET |
| Luban | MIT | Dikkatli | EVET |
| MilCAD | Proprietary | EVET (kendi kodumuz) | EVET |
