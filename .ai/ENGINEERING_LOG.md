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
