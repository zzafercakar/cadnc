# CADNC — Sonraki Session: Bug Fix + UX Overhaul

## Hedef
Mevcut bug'ları düzelt, Pad/Pocket/Revolution akışını SolidWorks/FreeCAD gibi yap, eksik sketch araçlarını çalıştır, Smart Dimension ekle.

## Mevcut Durum (2026-04-17 Session Sonu)

### Çalışan (Backend)
- **Sketch geometri**: Line, Circle, Arc, Rectangle, Point, Ellipse, BSpline, Polyline
- **Sketch constraint**: 16 tip (Coincident, H, V, Parallel, Perp, Tangent, Equal, Distance, DistanceX/Y, Radius, Diameter, Angle, Symmetric, PointOnObject, Fixed)
- **Sketch tools**: Trim, Fillet, Chamfer, Extend, Split, Construction Toggle — **backend hazır ama UI click handler'ları düzgün çalışmıyor**
- **Part features**: Pad, Pocket, Revolution, Groove, Boolean (Fuse/Cut/Common), Primitives (Box/Cyl/Sphere/Cone), 3D Fillet/Chamfer, Patterns
- **File I/O**: FCStd save/load, STEP/IGES/BREP import/export

### KRİTİK BUG'LAR (Öncelik 1)

#### BUG-001: Grid snap ve visual grid senkron değil
**Semptom:** Çizim yaparken snap edilen nokta ile ekrandaki grid noktası farklı yerde.
**Kök sebep:** `snapToGrid()` sabit `gridSpacing=10mm` kullanıyor. Visual grid `drawGrid()` içinde zoom'a göre adaptive step hesaplıyor. `activeGridSpacing` property eklendi ama drawGrid hesaplaması repaint sırasında çalışıyor — snap fonksiyonu çağrıldığında henüz güncellenmemiş olabilir.
**Çözüm:** Grid step hesaplamasını snap fonksiyonuna taşı veya snap'ten önce hesapla. `snapToGrid` çağrılmadan hemen önce step hesaplaması yapılmalı, drawGrid'e bağımlı olmamalı.

```javascript
// snapped() fonksiyonunda, grid snap'ten önce step hesapla:
function computeGridStep() {
    var baseStep = viewScale * gridSpacing
    var step = baseStep
    if (step < 12) step = baseStep * 5
    if (step < 12) step = baseStep * 10
    if (step > 200) step = baseStep / 5
    return step / viewScale  // sketch units
}
```

#### BUG-002: Pad/Extrude garip sonuç veriyor
**Semptom:** Rectangle + Circle sketch'inde Pad çok garip 3D shape üretiyor (screenshot: tünel benzeri yapı).
**Kök sebep:** `Part::Extrusion` fallback, sketch'teki TÜM geometriyi (wire'ları) extrude ediyor. Kapalı profil seçimi yok — rectangle'ın 4 çizgisi ayrı wire'lar olarak extrude ediliyor.
**Çözüm:** 
1. PartDesign::Pad direct instantiation'ı düzgün çalışıyorsa onu kullan (Profile.setValue sketch'i alıyor, FreeCAD otomatik kapalı wire buluyor)
2. Part::Extrusion fallback'te `Solid=true` ayarı var ama sketch'ten gelen shape düzgün wire olmalı
3. **Asıl sorun**: Sketch recompute sonrası `InternalShape` property'si düzgün set edilmeli — `SketchObject::execute()` çağrılmalı

#### BUG-003: Trim/Fillet/Chamfer/Extend/Split UI'da çalışmıyor
**Semptom:** Toolbar butonlarına tıklanıyor ama araç seçilmiyor veya geometri üzerinde tıklayınca bir şey olmuyor.
**Kök sebep:** 
- **Trim:** Tool seçili ama SketchCanvas'ta `tool === "trim"` için özel handler yok — sadece `selectAt` yapıyor, `cadEngine.trimAtPoint` çağırmıyor
- **Fillet/Chamfer:** Kullanıcı vertex seçmeli (geoId + posId) ama mevcut canvas sadece geometri seçiyor, vertex seçimi yok
- **Extend:** `cadEngine.extendGeo(selectedGeo, 10.0, 2)` sabit increment kullanıyor — geometri tipine göre dinamik olmalı
- **Split:** Çalışabilir durumda ama test edilmedi
**Çözüm:**
1. Trim: tool="trim" iken click → `selectAt` ile geo bul → `cadEngine.trimAtPoint(geoId, clickX, clickY)` çağır
2. Fillet/Chamfer: Vertex proximity detection ekle — endpoint'e yakın tıklayınca posId=1(start) veya 2(end) belirle, radius için popup aç
3. Extend: Geometri tipine göre uygun increment hesapla
4. Tümü: Araç aktifken cursor değişmeli (crosshair)

### UX SORUNLARI (Öncelik 2)

#### UX-001: Pad/Pocket/Revolution akışı yanlış
**Mevcut:** Popup dialog (FeatureDialog.qml) — ortada açılıyor, sketch ComboBox'tan seçim, length girişi
**Hedef (SolidWorks/FreeCAD gibi):**
1. Sketch kapat → Part moduna geç
2. Kullanıcı Pad butonuna tıklar
3. Sol panelde (ModelTree yerine) **FeaturePanel** açılır:
   - Sketch otomatik seçili (son kapatılan)
   - Extrude yönü: ↑ veya ↓ (toggle)
   - Length girişi (TextField)
   - Simetrik checkbox
   - Through All / To Next / To Face seçenekleri
   - Preview: 3D viewport'ta yarı saydam extrude preview
4. Onay (✓) veya İptal (✗) butonları
5. Onay → feature oluşur, panel eski haline döner

**İmplementasyon:**
- `ui/qml/panels/FeatureEditPanel.qml` — Sol panelde açılan inline feature editor
- FeatureDialog popup'ları kaldırılmayacak ama varsayılan akış inline panel olacak
- `cadEngine.sketchActive` false iken ve `featureEditMode` true iken FeatureEditPanel görünecek

#### UX-002: Smart Dimension eksik
**Hedef:** Geometri seçili iken "D" tuşu veya Distance butonu → on-canvas dimension input:
1. Seçili çizgiye tıkla → çizgi üzerinde dimension label belirsin
2. Değer girişi inline (canvas üzerinde TextField)
3. Enter → constraint oluşur
4. Birden fazla geometri seçili → aralarındaki mesafe

**İmplementasyon:**
- SketchCanvas'ta `tool === "dimension"` modu
- İlk click: geometri seç
- İkinci click (opsiyonel): ikinci geometri seç (iki geometri arası mesafe)
- Canvas üzerinde floating TextField açılır
- Enter → `cadEngine.addDistanceConstraint()` veya `addAngleConstraint()` çağır

#### UX-003: Sketch modunda 3D viewport interaction
**Mevcut:** SketchCanvas z:1 ile viewport'un üstünde, tüm mouse event'leri yutuyor
**Hedef:** Sketch düzleminde 2D çalışma devam ederken, NavCube tıklanabilir olmalı (view orientation)
**Çözüm:** NavCube QML replica'yı SketchCanvas'ın üstünde (z:2) ayrı MouseArea ile koyulabilir — veya sketch modunda NavCube gizlenebilir (FreeCAD davranışı)

#### UX-004: NavCube sketch düzlemiyle senkron değil
**Semptom:** Sketch XY düzleminde (top view) açıldığında NavCube hala perspektif/isometric açıda gösteriyor. İkisi ilişkili olmalı.
**Kök sebep:** `createSketch()` içinde `viewport_->viewTop()` çağrılıyor ama:
1. OCCT AIS_ViewCube native widget'ı viewport view değişikliğiyle otomatik senkron olmayabilir (FlushViewEvents gerekli)
2. SketchCanvas visible olduğunda viewport render güncellemesi duruyor olabilir (canvas üstte, viewport altında)
**Çözüm:**
1. `createSketch` / `openSketch` sonrası viewport'a zorla view preset uygula VE `update()` çağır
2. Sketch düzlemi tipine göre (XY→Top, XZ→Front, YZ→Right) doğru view set edilmeli
3. Viewport render'ın sketch modunda da çalışmaya devam etmesi lazım (en azından NavCube + view orientation için)

### EKSİK ARAÇLAR (Öncelik 3)

#### Sketch Araçları — UI Handler Gerekli
| Araç | Backend | UI Handler | Durum |
|------|---------|------------|-------|
| Trim | ✅ `trimAtPoint` | ❌ Canvas click handler yok | Click → selectAt → trimAtPoint |
| Fillet | ✅ `filletVertex` | ❌ Vertex seçimi yok | Vertex proximity + radius popup |
| Chamfer | ✅ `chamferVertex` | ❌ Vertex seçimi yok | Vertex proximity + size popup |
| Extend | ✅ `extendGeo` | ⚠️ Sabit increment | Dinamik increment |
| Split | ✅ `splitAtPoint` | ⚠️ Basit handler var | Test et |
| Construction Toggle | ✅ `toggleConstruction` | ⚠️ Buton var | Test et |

#### Smart Dimension Sistemi
| Özellik | Durum |
|---------|-------|
| On-canvas dimension label | ❌ Yok |
| Inline value input | ❌ Yok |
| Çizgi uzunluğu | ❌ → addDistanceConstraint |
| İki nokta arası | ❌ → addDistanceConstraint (two-point) |
| Çap | ❌ → addDiameterConstraint |
| Açı | ❌ → addAngleConstraint |

### GÖRSEL İYİLEŞTİRMELER (Öncelik 4)

| İyileştirme | Detay |
|-------------|-------|
| Constraint ikonları panelde | ✅ Yapıldı (SVG ikonlar) |
| Solid metalik gri renk | ✅ Yapıldı (0.72, 0.72, 0.75) |
| Grid toggle çalışması | ⚠️ Kod eklendi ama test edilmedi |
| Feature tree çift tıkla → edit | ❌ Yok |
| 3D Pad preview (yarı saydam) | ❌ Yok |
| Constraint visualization on canvas | ❌ (H/V/= gibi küçük semboller) |

---

## Öncelik Sırası (Sonraki Session)

### Adım 1: Kritik Bug Fix
1. Grid snap/visual sync düzelt (computeGridStep fonksiyonu)
2. Pad/Extrude sonucu düzelt (SketchObject::execute + wire handling)
3. Trim/Fillet/Chamfer canvas click handler'ları yaz

### Adım 2: Pad/Feature UX Overhaul
4. FeatureEditPanel.qml oluştur (sol panel inline editor)
5. Pad akışını SolidWorks gibi yap (sketch kapat → pad buton → sol panel)
6. Pocket/Revolution/Groove da aynı panel'i kullansın

### Adım 3: Smart Dimension
7. On-canvas dimension tool (tool === "dimension")
8. Inline value input (Canvas üzerinde TextField)
9. Çizgi/Circle/Arc otomatik constraint tipi seçimi

### Adım 4: Sketch Tool Fix
10. Trim click handler → trimAtPoint(geoId, x, y)
11. Fillet/Chamfer vertex proximity detection + radius popup
12. Extend dinamik increment

---

## Teknik Notlar

### Build Komutları
```bash
cmake -B build -S .
cmake --build build -j$(nproc)
DISPLAY=:0 QT_QPA_PLATFORM=xcb ./build/cadnc
ctest --test-dir build --output-on-failure
```

### Kurallar
- UI kodu FreeCAD header include etmeyecek
- AIS_InteractiveContext işlemleri sadece render thread
- FreeCAD upstream minimum değişiklik
- Her yeni adapter fonksiyona try-catch ekle
- Solid rengi: metalik gri (0.72, 0.72, 0.75) — tüm feature tipleri için aynı
- Sketch araçları: FreeCAD SketchObject API'sini doğrudan sar, yeniden yazma
