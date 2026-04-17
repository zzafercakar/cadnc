# CADNC — Sonraki Session İş Planı (Kapsamlı Modernizasyon)

## Tespit Edilen Kritik Sorunlar

### A. Sketch Close → Pad Pipeline (EN KRİTİK)
1. `closeSketch()` document recompute yapmıyor → FreeCAD InternalShape oluşmuyor
2. `closeSketch()` `featureTreeChanged()` emit etmiyor → UI güncellenmniyor
3. FeatureDialog sketch listesini göremiyor çünkü sinyal eksik
4. Pad/Pocket/Revolution sketch'in shape'ini bulamıyor → crash veya boş feature

### B. 3D Viewport Sorunları
1. Mouse orbit (sağ-tık döndürme) çalışmıyor — AIS_ViewController doğru bağlanmamış
2. View presets (Top/Front/Right/Isometric) hepsi aynı şeyi yapıyor (fitAll)
3. UpdateZoom metodu AIS_ViewController'da yanlış kullanılmış olabilir

### C. Sketch Canvas Sorunları
1. NavCube sketch modunda da görünüyor (2D modda olmamalı)
2. Snap sistemi yok (grid snap, geometry snap)
3. Grid size tam ayarlanabilir değil (UI kontrolü eksik)

### D. File Operations
1. New Document dialog'u yok (MilCAD'deki gibi)
2. Sketch ismi her zaman "Sketch" hardcoded — çoğul sketch desteği zayıf
3. Save/Open dosya seçildikten sonra gerçek FreeCAD save/load yapılmıyor

---

## Detaylı Görev Listesi

### Görev 1: closeSketch → Pad Pipeline Düzelt [KRİTİK]
**Dosyalar:** `CadEngine.cpp`, `SketchFacade.cpp`, `CadDocument.cpp`

- [ ] `CadEngine::closeSketch()` içinde:
  - `activeSketch_->close()` sonrası `document_->recompute()` çağır
  - `Q_EMIT featureTreeChanged()` ekle (sketchChanged yanında)
- [ ] `SketchFacade::close()` içinde validate + finalize
- [ ] `PartFacade::pad/pocket/revolution()` içinde:
  - Sketch existence kontrolü ekle
  - Hata durumunda temiz cleanup yap
  - Recompute sonrası shape varlığını doğrula
- [ ] Test: Create Sketch → Draw Rectangle → Close Sketch → Pad → 3D shape görünmeli

### Görev 2: 3D Mouse Orbit + View Presets [KRİTİK]
**Dosyalar:** `OccViewport.cpp`, `OccRenderer.cpp`

- [ ] Mouse right-drag orbit doğru çalıştığını verify et
  - AIS_ViewController'daki myMouseGestureMap binding'i kontrol et
  - Gerekirse UpdateMouseButtons çağrısını düzelt
- [ ] View presets implement et:
  - `viewTop()`: view_->SetProj(V3d_Zpos), SetUp(0,1,0)
  - `viewFront()`: view_->SetProj(V3d_Yneg), SetUp(0,0,1)
  - `viewRight()`: view_->SetProj(V3d_Xpos), SetUp(0,0,1)
  - `viewIsometric()`: view_->SetProj(V3d_XposYnegZpos), SetUp(0,0,1)
  - Her birinde queueFitAll() çağır
  - Thread-safe olmalı — view presets queue'ya eklenmeli
- [ ] Wheel zoom kontrolü: AIS_ViewController::UpdateZoom doğru mu?

### Görev 3: NavCube Sketch Modunda Gizle
**Dosyalar:** `SketchCanvas.qml`

- [ ] SketchCanvas içindeki NavCube'u `visible: false` yap veya kaldır
- [ ] AxisIndicator kalabilir (2D XY göstergesi olarak)
- [ ] Sketch modunda 2D-uygun navigasyon overlay'i ekle (zoom level göstergesi)

### Görev 4: Snap Sistemi
**Dosyalar:** `SketchCanvas.qml`, yeni: `SnapEngine.qml` veya C++ class

- [ ] Grid snap: en yakın grid noktasına snap
  - `snapToGrid(x, y)` fonksiyonu — gridSpacing'e göre yuvarla
  - SNAP toggle aktifken çizim noktalarını snap et
- [ ] Geometry snap (basit): endpoint snap
  - Mevcut geometri noktalarına snap (başlangıç/bitiş noktaları)
  - Snap göstergesi (küçük kare/daire marker)
- [ ] Snap indicator: canvas'ta snap noktasını göster
- [ ] FreeCAD pattern: SnapManager parametreleri izler (SnapToGrid, SnapToObjects)

### Görev 5: New Document Dialog
**Dosyalar:** yeni: `NewDocumentDialog.qml`, `Main.qml`

- [ ] MilCAD tarzı New Document dialog:
  - Document ismi girişi
  - Template seçimi (boş, sketch, part)
  - Varsayılan birimler (mm/inch)
- [ ] Veya basit: New tıklayınca mevcut document'ı kapat ve yeni oluştur
  - Kaydedilmemiş değişiklikler varsa "Kaydet?" dialog'u göster

### Görev 6: Sketch İsim Yönetimi
**Dosyalar:** `CadEngine.cpp`, `Main.qml`

- [ ] Auto-increment sketch ismi: Sketch, Sketch001, Sketch002, ...
  - FreeCAD zaten bunu yapıyor ama UI tarafında gösterilmeli
- [ ] `createSketch()` dönüş değerini gerçek isim olarak kullan
  - FreeCAD'in verdiği ismi (Sketch001 vb.) al ve UI'a yansıt

### Görev 7: StatusBar Toggle Bağlantıları
**Dosyalar:** `Main.qml`, `SketchCanvas.qml`, `StatusToggle.qml`

- [ ] SNAP toggle → sketch canvas snap aktif/pasif
- [ ] GRID toggle → sketch canvas grid görünürlük (YAPILDI ✓)
- [ ] ORTHO toggle → sketch canvas ortho modu (90° açıda çizim kısıtlaması)

### Görev 8: Part Workbench → Pad Flow End-to-End Test
**Test senaryosu:**
1. Uygulama aç
2. Create Sketch tıkla → Sketch workbench açılsın
3. Rectangle çiz (R tuşu + mouse)
4. Distance constraint ekle (D tuşu)
5. Close Sketch (yeşil buton)
6. Part workbench'e geç
7. Pad butonuna tıkla → FeatureDialog açılsın
8. Sketch seçilmiş olarak gelsin
9. Length gir → Create
10. 3D viewport'ta pad görünsün
11. Mouse ile döndürülebilsin (orbit)

---

## SolidWorks / Fusion 360 Referansları ile Eksik Özellikler

### Sketch Araçları (SolidWorks referans)
- [ ] Construction geometry toggle (çizgi tipini construction'a çevir)
- [ ] Centerline aracı
- [ ] Smart Dimension: on-canvas tıkla → boyut gir
- [ ] Auto-constraint: çizim sırasında otomatik H/V/Coincident önerisi
- [ ] Sketch relations (constraints) panelinde düzenleme (çift tıkla → değer değiştir)
- [ ] Point-on-object constraint
- [ ] Symmetric constraint

### Part Araçları (Fusion 360 referans)
- [ ] Feature editing: model tree'de çift tıkla → parametreleri düzenle
- [ ] Feature suppress/unsuppress (göz ikonu)
- [ ] Feature reorder (sürükle-bırak)
- [ ] Feature delete with undo

### Viewport (SolidWorks referans)
- [ ] Section view (kesit görünümü)
- [ ] Shading modes: wireframe, hidden lines, shaded, shaded with edges
- [ ] Edge highlighting on hover
- [ ] Face/Edge selection for 3D fillet/chamfer

### Genel UI (Fusion 360 referans)
- [ ] Breadcrumb: Part > Sketch1 > Line5
- [ ] Recent documents
- [ ] Splash screen
- [ ] Preferences dialog
- [ ] Progress bar for long operations

---

## Öncelik Sırası

1. **Sketch Close → Pad pipeline** (olmadan uygulama kullanılamaz)
2. **Mouse orbit** (3D viewport işe yaramaz hale geliyor)
3. **View presets** (temel viewport kullanılabilirliği)
4. **NavCube fix** (sketch modunda kafa karıştırıcı)
5. **Snap sistemi** (sketch çizimi verimsiz)
6. **New document dialog** (profesyonel UX)
7. **Sketch isim yönetimi** (çoğul sketch desteği)
8. **StatusBar toggles** (SNAP/ORTHO bağlantıları)
