# CADNC Master Work Plan

## Vizyon

CODESYS SoftMotion CNC kontrol cihazlari icin G-Code ureten, modern arayuzlu bir masaustu CAD-CAM uygulamasi.

**Strateji:** FreeCAD'in olgun CAD backend'ini (Sketcher, Part, PartDesign) kullanarak kendi sketch/constraint/feature altyapimizi sifirdan yazmak yerine hazir ve test edilmis bir temele yaslanmak. Uzerine ince bir adapter katmani ve modern QML arayuzu koymak.

**Onceki proje (MilCAD) neden terk edildi:**
- OCCT uzerinde kendi sketch document, constraint migration, recompute altyapisini yazmak cok agir
- Fillet, Chamfer, Trim, Smart Dimension gibi kritik islemlerde ilerleme durdu
- Constraint remap, topology naming, driven/driving datum, expression engine eksik
- FreeCAD bu alanlarda 15+ yillik olgunluga sahip — yeniden icat etmek yerine kullanmak mantikli

---

## Faz 0: Proje Iskeleti [TAMAMLANDI - 2026-04-12]

- [x] CADNC dizin yapisi olusturuldu
- [x] FreeCAD modulleri kopyalandi (Base, App, Part/App, Sketcher/App, PartDesign/App)
- [x] FreeCAD 3rdParty kopyalandi (json, PyCXX)
- [x] MilCAD'den CAM modulu tasindi (26 header, 24 source)
- [x] MilCAD'den Nesting modulu tasindi (6 header, 5 source)
- [x] MilCAD'den 92 SVG ikon, utility, config tasindi
- [x] Adapter iskeleti olusturuldu (CadSession, CadDocument, SketchFacade, PartFacade)
- [x] Minimal UI shell olusturuldu (Main.qml)
- [x] main.cpp (crash handler, GLX, Qt6 Quick)
- [x] CMakeLists.txt, CMakePresets.json, .gitignore, .clang-tidy
- [x] .ai/ context sistemi, doc/ARCHITECTURE.md, README.md
- [x] .vscode/ (launch.json, settings.json), .github/workflows/build.yml
- [x] Git repo kuruldu, GitHub'a push edildi (https://github.com/zzafercakar/cadnc)

---

## Faz 1: FreeCAD Build Entegrasyonu [SIRADAKI]

**Amac:** FreeCAD modullerini CADNC icinde basariyla derlemek.

### Adim 1.1: freecad/CMakeLists.txt
- [ ] FreeCADBase kutuphanesini derle (src/Base/ kaynakları)
  - Bagimliliklar: Boost, XercesC, ZLIB, ICU, Python3, PyCXX
  - Cikti: libFreeCADBase.so
- [ ] FreeCADApp kutuphanesini derle (src/App/ kaynakları)
  - Bagimliliklar: FreeCADBase, Qt6::Core, Qt6::Xml
  - Cikti: libFreeCADApp.so
- [ ] Part modulunu derle
  - Bagimliliklar: FreeCADApp, OCCT kutuphaneleri, FreeType
  - Cikti: libPart.so
- [ ] Sketcher modulunu derle
  - Bagimliliklar: Part, Eigen3, planegcs
  - Cikti: libSketcher.so
- [ ] PartDesign modulunu derle
  - Bagimliliklar: Part, Sketcher
  - Cikti: libPartDesign.so

### Adim 1.2: Python Entegrasyonu
- [ ] Python3 embedding test (Py_Initialize / Py_Finalize)
- [ ] PyCXX binding'lerin derlenmesini dogrula
- [ ] PyImp dosyalarinin moc/generate akisini kur

### Adim 1.3: PoC (Proof of Concept)
- [ ] Basit test programi yaz:
  1. FreeCAD Base/App baslat
  2. Yeni document olustur
  3. SketchObject ekle
  4. Line + Circle geometri ekle
  5. Distance constraint uygula
  6. Solver calistir
  7. Sonuc TopoDS_Shape'i al
  8. Konsola geometri bilgisi yazdir
- [ ] PoC basariyla calisiyor

### Teknik Notlar:
- FreeCAD Base: Expression parser icin lex/yacc uretilmis dosyalar var (Expression.lex.c, Expression.tab.c)
- FreeCAD App: ~210 dosya, 4.5 MB kaynak
- Part/App: Geometry.cpp tek basina 245K+ satir (OCCT wrapper'lari)
- Python ZORUNLU: Her modulde 30-80+ PyImp dosyasi var, cikarilmasi pratik degil
- OCCT kutuphaneleri tek tek listelenmeli: TKernel, TKMath, TKBRep, TKGeomBase, TKG3d, TKTopAlgo, TKV3d, ...

---

## Faz 2: Adapter Katmani

**Amac:** UI'nin FreeCAD tiplerini gormeden CAD islemleri yapabilecegi ince facade katmani.

### Adim 2.1: CadSession
- [ ] FreeCAD::Base::Console baslat
- [ ] FreeCAD::App::Application::init() (headless mode)
- [ ] Shutdown/cleanup

### Adim 2.2: CadDocument
- [ ] Document create (App::Document wrapper)
- [ ] Document save/load (.FCStd formatinda)
- [ ] Feature tree query (nesne listesi, tipleri, isimleri)
- [ ] Undo/Redo (Transaction sistemi)

### Adim 2.3: SketchFacade
- [ ] createSketch(plane) — SketchObject olustur
- [ ] addLine(p1, p2), addCircle(center, radius), addArc(...)
- [ ] addConstraint(type, params) — tum constraint tipleri
- [ ] setDatum(constraintId, value) — dimension deger degistirme
- [ ] setDriving/setDriven — driving/driven toggle
- [ ] trim(geoId, point), fillet(geoId1, geoId2, radius), chamfer(...)
- [ ] solve() — solver calistir, DOF dondur
- [ ] getGeometry() — geometri listesi (QML'e uygun DTO'lar)
- [ ] getConstraints() — constraint listesi
- [ ] closeSketch() — sketch'i kapat, shape dondur

### Adim 2.4: PartFacade
- [ ] pad(sketchId, length) — Pad feature
- [ ] pocket(sketchId, length) — Pocket feature
- [ ] revolution(sketchId, angle) — Revolution
- [ ] fillet3D(edgeRefs, radius) — 3D Fillet
- [ ] chamfer3D(edgeRefs, size) — 3D Chamfer
- [ ] linearPattern(...), polarPattern(...), mirror(...)
- [ ] loft(...), sweep(...)
- [ ] getShape() — sonuc TopoDS_Shape

### Adim 2.5: SelectionFacade
- [ ] select(objectId, subElement) — nesne/alt-eleman secimi
- [ ] getSelection() — secili nesneler
- [ ] clearSelection()

### Adim 2.6: PropertyFacade
- [ ] getProperties(objectId) — property listesi
- [ ] setProperty(objectId, name, value) — property degistir
- [ ] QML Q_PROPERTY binding'leri

---

## Faz 3: Kritik Sketch Islemleri

**Amac:** FreeCAD Sketcher uzerinden temel sketch akisini calistirmak.

- [ ] Line, Circle, Arc, Rectangle cizim arayuzu
- [ ] Smart Dimension — driving/driven, expression destegi
- [ ] Trim — FreeCAD SketchObject::trim() uzerinden
- [ ] 2D Fillet — FreeCAD SketchObject::fillet() uzerinden
- [ ] 2D Chamfer — FreeCAD SketchObject::chamfer() uzerinden
- [ ] Constraint goruntuleme (coincident, horizontal, vertical, distance, angle, radius, ...)
- [ ] DOF coloring (fully constrained = yesil, under-constrained = mavi, over = kirmizi)
- [ ] Undo/Redo sketch islemlerinde

**Neden bu faz kritik:**
Bu islemler MilCAD'de en cok sorun cikaran noktadir.
FreeCAD'in SketchObject'i constraint migration, topology remap, datum management konularini
15 yildir test edilmis sekilde hallediyor. Biz sadece facade uzerinden cagiracagiz.

---

## Faz 4: 3D Feature Zinciri

- [ ] Pad (SketchObject -> PartDesign::Pad)
- [ ] Pocket (PartDesign::Pocket)
- [ ] Revolution (PartDesign::Revolution)
- [ ] 3D Fillet (PartDesign::Fillet)
- [ ] 3D Chamfer (PartDesign::Chamfer)
- [ ] Draft, Thickness/Shell
- [ ] Linear Pattern, Polar Pattern, Mirror
- [ ] Loft, Sweep
- [ ] Feature tree UI senkronizasyonu (ModelTreePanel.qml)
- [ ] Recompute zinciri test

---

## Faz 5: Viewport ve Rendering

- [ ] OCCT V3d_Viewer + QQuickFramebufferObject entegrasyonu
- [ ] Shape rendering (FreeCAD'den alinan TopoDS_Shape -> AIS_Shape)
- [ ] Selection highlighting (AIS_InteractiveContext)
- [ ] Grid ve snap sistemi
- [ ] Sketch mode rendering (2D constraint overlay)
- [ ] View presets (top, front, right, isometric)
- [ ] Zoom, pan, orbit

**Kritik kural:** Tum AIS_InteractiveContext islemleri render thread'de olmali. UI thread'den asla cagirilmamali. MilCAD'den ogrenilenler: SceneManager deferred ops pattern kullanilmali.

---

## Faz 6: CAM/Nesting Entegrasyonu

- [ ] CamGeometrySource adapter'ini yeni backend'e bagla
- [ ] ProfileImporter adapter'ini yeni backend'e bagla
- [ ] Facing, Profile, Pocket, Drill operasyonlarini test et
- [ ] G-Code generation (CODESYS + Generic)
- [ ] Nesting algoritmalarini test et (BLF, BBox)
- [ ] NFP (No-Fit Polygon) nesting ekle (Luban referansi)

---

## Faz 7: UI Modernizasyonu

- [ ] Toolbar tasarimi (sketch, part, cam, nesting workbench'leri)
- [ ] Property panel — FreeCAD property'lerini QML'de goster/duzenle
- [ ] Constraint panel — constraint listesi, driving/driven toggle
- [ ] Dimension input popup
- [ ] Theme sistemi (dark/light)
- [ ] Keyboard shortcut framework
- [ ] File dialogs (new, open, save, export)
- [ ] User preferences

---

## Basari Kriterleri

Her faz sonunda somut, test edilebilir bir cikti uretilmeli:

| Faz | Basari Kriteri |
|-----|----------------|
| 1 | FreeCAD modulleri derleniyor, PoC sketch + constraint cozuyor |
| 2 | Adapter uzerinden sketch olustur, line ekle, dimension ver, pad yap |
| 3 | UI'dan sketch ciz, trim/fillet/chamfer uygula, smart dimension |
| 4 | Tam feature zinciri: sketch -> pad -> fillet -> pocket |
| 5 | 3D viewport'ta shape goruntuleme, secim, manipulasyon |
| 6 | Sketch -> Part -> CAM -> G-Code tam pipeline |
| 7 | Urun kalitesinde UI, tercihleri kaydet/yukle |

---

## Risk ve Dikkat Edilecekler

1. **Python bagimliligi:** FreeCAD modulleri Python zorunlu kiliyor. Kabul edildi.
2. **Build karmasikligi:** FreeCAD 5 modul + 3rdParty = buyuk derleme. Incremental build onemli.
3. **Thread safety:** AIS_InteractiveContext UI thread'den cagrilmamali (MilCAD'den ogrenilen).
4. **OCCT GLX:** Linux'ta EGL kullanilmamali. QT_XCB_GL_INTEGRATION=xcb_glx zorunlu.
5. **FreeCAD upstream degisiklikleri:** Modullerde minimum degisiklik yaparak upgrade kolayligi sagla.
6. **LGPL uyumlulugu:** FreeCAD modulleri LGPL. Adapter + UI proprietary kalabilir ama linkleme kuralina dikkat.
