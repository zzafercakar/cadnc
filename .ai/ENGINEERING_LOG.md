# CADNC Engineering Log

## 2026-04-12: Proje Olusturma ve Mimari Kararlar

### Karar #001: FreeCAD Backend Secimi
**Problem:** MilCAD'de OCCT uzerinde kendi sketch/document/constraint/recompute altyapimizi yazmak cok ağır. Fillet, Chamfer, Trim, Smart Dimension gibi kritik islemlerde ilerleme durdu.

**Kök sebep:** Sorun OCCT'de degil. Sorun OCCT üzerindeki ust katmanlarin (constraint migration, topology naming, driven/driving datum, expression engine, recompute chain) olmamasinda.

**Karar:** FreeCAD'in App katmanlarini (Base, App, Part, Sketcher, PartDesign) CAD backend olarak kullanmak. OCCT altta kalacak. FreeCAD GUI katmanlari alinmayacak.

**Gerekce:**
- FreeCAD'in Sketcher modulu constraint migration, trim, fillet, chamfer islemlerini 15+ yildir test edilmis sekilde hallediyor
- SketchObjectConstraints.cpp tek basina 2834 satir constraint yonetimi
- SketchObjectOperations.cpp 3123 satir trim/fillet/chamfer mantigi
- planegcs solver FreeCAD icinde entegre
- PartDesign feature zinciri (Pad/Pocket/Revolution/Fillet/Chamfer) hazir

### Karar #002: Python Bagimliligi Kabul Edildi
**Problem:** FreeCAD modulleri Python3'e zorunlu olarak bagimli. Her modulde 30-80+ PyImp dosyasi var.

**Karar:** Python bagimliligi kabul edildi. Cikarma maliyeti cok yuksek.

**Sonuc:** CADNC, Python3-dev paketine bagimli olacak.

### Karar #003: MilCAD UI'dan Bagimsiz Yeni Shell
**Problem:** Mevcut MilCAD QML yapisi, eski backend varsayimlarina (SketchDocument, FeatureManager, SceneManager) gomulu.

**Karar:** MilCAD QML'den kod tasinmayacak. Yeni, sade bir QML shell sifirdan olusturulacak. Sadece ikonlar ve gorsel varliklar kopyalandi.

### Karar #004: Adapter Pattern
**Problem:** UI ile FreeCAD tipleri arasinda dogrudan baglanti olursa, FreeCAD guncellemelerinde veya UI degisikliklerinde her iki taraf da etkilenir.

**Karar:** Ince bir adapter/facade katmani (CadSession, CadDocument, SketchFacade, PartFacade) araciligiyla tum etkilesim. UI hicbir FreeCAD header'i include etmeyecek.

---

## MilCAD'den Ogrenilenler (CADNC'de Tekrarlanmamasi Gerekenler)

### Thread Safety (KRITIK)
- **Kural:** AIS_InteractiveContext islemleri SADECE render thread'de yapilmali
- **MilCAD hatasi:** selectShapeById() UI thread'den ctx->AddOrRemoveSelected() cagiriyordu
- **Cozum:** Deferred operation pattern (SceneManager::requestClearSelection gibi)
- **CADNC'de:** Viewport modulu tasarlanirken bu kural birinci gun uygulanmali

### OCCT GLX (KRITIK)
- Ubuntu'da OCCT GLX ile derlenmis, EGL desteklemiyor
- `QT_XCB_GL_INTEGRATION=xcb_glx` zorunlu (main.cpp'de var)
- EGL kullanilirsa: "OpenGl_Context::Init() FAILED" hatasi

### OccRenderer Adlandirmasi
- QQuickFramebufferObject::Renderer ile isim cakismasi olur
- Her zaman `OccRenderer` kullanilmali, `Renderer` degil

### OCCT Linking
- `${OpenCASCADE_LIBRARIES}` yerine kutuphaneler tek tek listelenmeli
- Ornek: TKernel, TKMath, TKBRep, TKGeomBase, TKG3d, TKTopAlgo, TKV3d, ...

### Qt 6.4.2 Kisitlamalari
- `<qtypes.h>` yok (Qt 6.5'te eklendi)
- Raw pointer kullanilmali signal'larda (std::unique_ptr copyable degil)

### OCC 7.6 Kisitlamalari
- `V3d_View::Subviews()` yok (OCC 7.7'de eklendi)
- Guard: `#if OCC_VERSION_HEX >= 0x070700`

---

## 2026-04-15: Faz 4-5 Tamamlandı — Feature Zinciri + OCCT Viewport

### Faz 4: 3D Feature Zinciri
- CadEngine QML'e bağlandı (main.cpp'de instance oluşturuldu, `setContextProperty("cadEngine", ...)`)
- Pad/Pocket/Revolution Q_INVOKABLE metotları CadEngine'e eklendi
- FeatureDialog.qml — tek reusable dialog, `featureType` property ile Pad/Pocket/Revolution arası geçiş
- canUndo/canRedo/sketchNames Q_PROPERTY'leri eklendi
- PartToolbar aksiyonları dialog'lara bağlandı

### Faz 5: OCCT 3D Viewport
- **OccViewport** (QQuickFramebufferObject) — QML item, mouse event'leri yakalar
- **OccRenderer** (Renderer + AIS_ViewController) — render thread'de yaşar
  - V3d_Viewer + V3d_View + AIS_InteractiveContext hierarşisi
  - AIS_ViewCube (animated, clickable, upper-right)
  - AIS_Triedron (ZBuffer, lower-left)
  - Rectangular grid (10mm, points mode)
  - 8x MSAA, gradient background, high-quality tessellation
- **GlTools** — Qt↔OCCT coordinate/button/modifier conversion
- **QtFrameBuffer** — sRGB-safe FBO wrapper (GL_FRAMEBUFFER_SRGB disabled)
- **Thread-safe shape pipeline:** mutex-protected queue, processed in render()
- **CadEngine → OccViewport:** pad/pocket/revolution sonrası `updateViewportShapes()` çağrılır

### Mimari Kararlar
- **Karar #005:** QML NavCube ve AxisIndicator replica'ları viewport visible olmadığında hala kullanılabilir (sketch mode). Native OCCT ViewCube/Triedron sadece 3D viewport'ta aktif.
- **Karar #006:** Shape display pipeline: CadDocument::getFeatureShape() → void* → TopoDS_Shape → OccViewport::displayShape() → OccRenderer queue → render() processPendingShapeOps()

---

## 2026-04-16: Adapter Hardening + UI Wiring Session

### Yapılan İşler
1. **PartFacade**: PartDesign::Pad/Pocket/Revolution kodu yazıldı + Part::Extrusion fallback
2. **Export**: `CadDocument::exportTo()` gerçek STEP/IGES/STL/BREP export (TopoShape API)
3. **Constraint UI**: 11 constraint butonu Main.qml handler'a bağlandı, two-click mekanizması
4. **Stub araçlar**: polyline/ellipse/spline/offset/mirror/extend UI'da pasifleştirildi
5. **ConstraintPanel**: Inline datum edit + driving toggle
6. **ModelTree**: Delete + Rename API ve UI bağlantısı
7. **Test**: ctest 2/2 geçiyor, adapter_test pad+export testleri içeriyor
8. **CadEngine**: addPoint, addConstraintTwoGeo metotları eklendi

### Sorun #005: PartDesign Type Registration (AÇIK)
**Semptom**: `addObject("PartDesign::Body")` başarısız — tip kayıtlı değil
**Kök sebep**: `PartDesign::Body::init()` Python module import zinciri içinde çağrılıyor. PyImport çağrıldığında App::Application::destruct() sırasında Base::PyException → std::terminate
**Workaround**: Part::Extrusion fallback ile Pad/Pocket/Revolution çalışıyor
**Etki**: Body/Tip feature chain yok, PartDesign parametric editing yok
**Not**: `Base::Type::fromName("Part::Feature")` bile BAD döndürüyor ama `addObject("Sketcher::SketchObject")` çalışıyor — FreeCAD lazy type loading kullanıyor olabilir

### closeSketch() Pipeline — ÇÖZÜLDÜ
Önceki session'da tespit edilen Sorun #001 (closeSketch recompute yapmıyor) zaten kodda düzeltilmişti.

---

## 2026-04-15: Tespit Edilen Kritik Sorunlar (Session Sonu)

### Sorun #001: closeSketch() Pipeline Kırık
**Semptom:** Sketch close yapınca geometri kayboluyor, Pad dialog sketch bulamıyor
**Kök sebep:** CadEngine::closeSketch() document recompute yapmıyor + featureTreeChanged emit etmiyor
**Çözüm:** closeSketch() → recompute() + Q_EMIT featureTreeChanged() ekle

### Sorun #002: Mouse Orbit Çalışmıyor
**Semptom:** 3D viewport'ta sağ-tık sürükleme ile döndürme yapılamıyor
**Kök sebep:** AIS_ViewController gesture mapping doğru ama mouse event → render thread pipeline doğrulanmadı
**Çözüm:** OccViewport mouse event handler'larını debug et, FlushViewEvents çağrısını doğrula

### Sorun #003: View Presets Stub
**Semptom:** Top/Front/Right/Isometric butonları hepsi aynı şeyi yapıyor
**Kök sebep:** OccViewport::viewTop/Front/Right/Isometric() hepsi fitAll() çağırıyor
**Çözüm:** Thread-safe queue ile render thread'de V3d_View::SetProj çağır

### Sorun #004: NavCube Sketch Modunda Görünüyor
**Semptom:** 2D sketch çizim modunda 3D NavCube görünüyor
**Çözüm:** SketchCanvas.qml'den NavCube'u kaldır

---

## Proje Dosya Istatistikleri (2026-04-12)

| Bolum | Dosya Sayisi | Toplam Satir |
|-------|-------------|--------------|
| freecad/Base | 173 | ~9,500 |
| freecad/App | 210 | ~50,000 |
| freecad/Mod/Part/App | 286 | ~250,000+ |
| freecad/Mod/Sketcher/App | 58 | ~48,000 |
| freecad/Mod/PartDesign/App | 80 | ~20,000 |
| freecad/3rdParty | ~50 | ~5,000 |
| cam/ | 50 | ~8,000 |
| nesting/ | 11 | ~1,500 |
| adapter/ | 5 | ~100 |
| ui/qml/ | 2 | ~150 |
| app/ | 2 | ~100 |
| **Toplam** | **~1254** | **~400,000+** |
