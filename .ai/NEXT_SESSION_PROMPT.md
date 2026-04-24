# CADNC — Sonraki Session: Reinventing yerine FreeCAD'i Kullan

## Filozofi (BU SESSION'DA EN KRİTİK PRENSİP)

> **FreeCAD 15+ yıllık olgun bir CAD uygulaması.** Bir özellik FreeCAD'de zaten doğru çalışıyorsa, custom kod YAZMA — direkt FreeCAD'in implementasyonunu kullan veya birebir port et.

Önceki session'da bu prensip ihlal edildi: `addRectangle` adapter'da 4 line + 4 coincident yazıldı ama FreeCAD'in eklediği **2 H + 2 V constraint atlandı** → Distance constraint verince rectangle deforme oldu.

**Kural:** Yeni bir sketch işlemi yazmadan önce
`/home/embed/Downloads/FreeCAD-main-1-1-git/src/Mod/Sketcher/Gui/DrawSketchHandler*.h`
dosyalarına bak. FreeCAD nasıl yapıyor — birebir aynısını yap.

---

## Mevcut Durum (2026-04-21 Test Sonu)

### Çalışan
- Sketch geometri çizimi (Line, Circle, Arc, Rectangle, Ellipse, BSpline, Polyline)
- Constraint (16 tip)
- Trim (✓ test edildi)
- Pad delik açma (rectangle + iç circle → deliği olan katı, OCCT fallback ile)
- FeatureEditPanel (sol panel inline editor, live preview, debounced)
- Smart Dimension on-canvas TextField (UI çalışıyor ama backend deforme ediyor — aşağıda)
- NavCube sketch düzlemine senkron, sketch modunda tıklanabilir

### KRİTİK BUG'LAR (Test'ten)

#### BUG-004: Smart Dimension rectangle'ı deforme ediyor (KÖK SEBEP TESPİT EDİLDİ)
**Semptom:** Rectangle çiz → bir kenarına Distance 100 ver → rectangle yamuk olur (paralelkenar veya dörtgen).
**Kök sebep:** [adapter/src/SketchFacade.cpp:62-88](adapter/src/SketchFacade.cpp#L62-L88) `addRectangle` sadece 4 coincident constraint ekliyor. FreeCAD ise [DrawSketchHandlerRectangle.h:1658-1696](file:///home/embed/Downloads/FreeCAD-main-1-1-git/src/Mod/Sketcher/Gui/DrawSketchHandlerRectangle.h) içinde **2 horizontal + 2 vertical** (veya rotated için Parallel+Perpendicular) ekliyor.
**Çözüm:** `addRectangle` sonuna ekle:
```cpp
addHorizontal(id0); addHorizontal(id2);  // top + bottom
addVertical(id1);   addVertical(id3);    // right + left
```
Bu yapıldıktan sonra Distance verince dik açılar korunur.

#### BUG-005: Grid visual ile snap noktası farklı yerde (BUG-001 fix yetersiz)
**Semptom:** Mouse pozisyonu görünen grid noktasında ama snap edilen yer farklı. Cursor coordinate label gerçek pozisyonu gösteriyor, snap "nereye" gittiğini göstermiyor.
**Önceki fix:** [SketchCanvas.qml:38-50](ui/qml/SketchCanvas.qml#L38-L50) declarative binding eklendi ama yeterli değil. Asıl sorun: `panX/panY` zoom sırasında kayma yapıyor → grid çizimi `panX % step` offset kullanırken `snapToGrid` `Math.round(val/step)*step` mutlak konum kullanıyor. **İki farklı pozisyon referansı.**
**Çözüm yönü:** Snap'i de pan offset'i ile hizala:
```javascript
function snapToGrid(val) {
    var step = activeGridSpacing
    // Pan offset'i ile uyumlu snap
    var origin = ?  // sketch space'te grid origin
    return Math.round((val - origin) / step) * step + origin
}
```
Net çözüm için pan davranışını `drawGrid` ile karşılaştır.

#### BUG-006: Part viewport grid ile Sketch canvas grid farklı sistem
**Semptom:** Properties paneli "Grid 10mm" gösteriyor (3D viewport OCCT GridMesh) ama Sketch canvas kendi `gridSpacing: 10.0` mm'sini kullanıyor — ikisi BAĞIMSIZ. Part'ta grid değişince sketch'e yansımıyor.
**Konum:** [SketchCanvas.qml:36](ui/qml/SketchCanvas.qml#L36) `property real gridSpacing: 10.0` hardcoded.
**Çözüm:**
1. CadEngine'e `Q_PROPERTY(double gridSpacing READ gridSpacing WRITE setGridSpacing NOTIFY gridSpacingChanged)` ekle (mm cinsinden).
2. SketchCanvas'ta `gridSpacing: cadEngine.gridSpacing` olarak bind.
3. OccRenderer GridMesh adımını da aynı değere bind.
4. Properties Panel'de Grid satırını TextField yap (read-only label değil).

#### UX-005: Fillet/Chamfer arrow drag + çift tıklama edit
**Semptom:** Şu an fillet/chamfer için tek seferlik popup açılıyor. FreeCAD'de:
- Fillet uygulandıktan sonra köşede küçük bir ok beliriyor
- Ok sürüklenirse radius değişir (live)
- Çift tıklayınca değer girişi açılır
**Çözüm yönü:**
1. Fillet sonrası SketchCanvas'a "fillet handle" çiz (köşe noktasında küçük ok)
2. Mouse drag → radius güncelle (debounced solve)
3. Geometry double-click → constraint datum dimInput popup'ı

#### UX-006: Tool aktifken hover highlight yok
**Semptom:** Smart Dimension veya Trim tool aktifken mouse'u geometriye götürünce **görsel önizleme yok**. Tıklayana kadar hangi geo seçileceği belli değil.
**Çözüm:**
1. SketchCanvas'a `hoveredGeo: -1` property ekle
2. `onPositionChanged` içinde tool aktifken `selectAt`'in hover-only versiyonu (selectedGeo'yu değiştirmeden) çalıştır
3. `drawGeometry` içinde hoveredGeo için farklı renk (light orange #FCD34D) kullan

#### UX-007: Grid size editable input
**Semptom:** Properties paneli "Grid 10mm" gösteriyor ama düzenlenemez.
**Çözüm:** [PropertiesPanel.qml](ui/qml/panels/PropertiesPanel.qml)'de Grid satırını TextField yap, `cadEngine.gridSpacing` setter'ına yaz.

#### UX-009: "Create New Sketch" — Plane/Face seçimi
**Semptom:** Şu an New Sketch otomatik XY'ye oluşturuluyor; kullanıcı düzlem seçemiyor, mevcut bir yüze de sketch açamıyor.
**Hedef (FreeCAD PartDesign MapMode referansı):**
1. New Sketch butonuna basılınca dialog açılır:
   - **Default planes:** XY, XZ, YZ (3 radio/tıklanabilir görsel)
   - **On face:** "Select face..." butonu → 3D viewport'ta yüz seçimi moduna geç
   - **Custom datum plane:** Kullanıcının oluşturduğu DatumPlane'ler (Faz 4+ ileri sürüm)
2. Yüz seçiminde OCCT AIS_InteractiveContext'ten TopoDS_Face ID alınır, CadEngine'e aktarılır.
3. CadDocument::addSketch(planeType | faceRef) — face reference ise sketch Placement = face'in yerel frame'i (OCCT BRepGProp_Face normal + tangent), `MapMode=FlatFace` set.
4. Sketch editing açılınca 3D viewport'ta sketch plane vizualize edilir (ince grid overlay yüzey üstünde).
**Referans:** `/home/embed/Downloads/FreeCAD-main-1-1-git/src/Mod/PartDesign/Gui/TaskDlgFeaturePick.cpp` (plane picker), `Sketcher/App/SketchObject.cpp` Support property, `Part/App/AttachExtension.cpp` MapMode.

#### UX-010: Pad/Pocket/Revolution çift-tıkla düzenleme
**Semptom:** Feature tree'de Sketch'e çift tıklayınca sketch edit mode açılıyor; Pad/Pocket/Revolution çift tıklanınca hiçbir şey olmuyor.
**Çözüm:**
1. ModelTreePanel.qml feature satırında `onDoubleClicked` → type "Pad" ise `cadEngine.editFeature(featureName)` çağır.
2. CadEngine::editFeature: feature tipini oku → FeatureEditPanel'i panel.qml ile aç, mevcut parametreleri (Length, Reverse, Type) pre-fill et.
3. FeatureEditPanel.qml şu an sadece yaratım sırasında görünüyor — edit mode için `editingFeatureName` property ekle. Ok'a basılınca `cadEngine.updateFeature(name, params)` çağrılır.
4. CadEngine::updateFeature → PartFacade::updatePad/updatePocket/updateRevolve — FeatureBase'in `Length.setValue(new)` ile parametre değişir, `recompute()` tetiklenir.

#### UX-011: Live preview — sketch veya feature düzenlenince anında 3D güncellenir
**Semptom:** Şu an Pad length değişince Apply'a basana kadar 3D değişmiyor; sketch edit'te kapatana kadar feature eski geometri kullanıyor.
**Kök davranış:** FreeCAD `recompute()` feature zincirini topolojik sırada yeniden hesaplar. Şu an biz sadece oluştururken recompute çağırıyoruz.
**Çözüm:**
1. FeatureEditPanel'deki TextField `onTextChanged` — debounced (150ms) `cadEngine.updateFeature(...)` çağır → recompute → OccViewport displayShape ile shape'i güncelle.
2. Sketch edit mode'da her geometry/constraint değişikliği sonrası: sketch'i tüketen feature'lar varsa (featureTree traverse) recompute zinciri tetiklenir ve OccViewport tüm shape'leri yeniden render eder.
3. Performans: debounce + yalnızca değişen feature alt-ağacını recompute (FreeCAD zaten dependency graph kullanıyor — `Document::recomputeFeature(feature, true)` yalnızca gerekli olanları günceller).
4. Viewport'taki AIS_Shape güncellenince redraw zorla: `context->Redisplay(aisShape, Standard_False)` render thread'de.

#### UX-008: Pad/Pocket'e SolidWorks/FreeCAD eksiksiz feature seti
**Mevcut:** FeatureEditPanel'de sadece Length + Reverse toggle.
**Hedef (FreeCAD ParaTaskPadParameters'a göre):**

| Tip | Açıklama | Backend |
|-----|----------|---------|
| **Length** | Tek yön, verilen uzunluk | mevcut |
| **Two Lengths** | İki yöne FARKLI uzunluk (Length + Length2) | YENİ — `pad(sketch, len1, len2)` |
| **Symmetric to plane** | Sketch'in iki yanına eşit (toplam = length) | YENİ — `pad(sketch, len, true /*sym*/)` |
| **Through All** | Karşı tarafa kadar | sketch normal'i + büyük sayı |
| **To Last** | Mevcut katının son yüzeyine kadar | hesaplama gerek |
| **To First** | İlk yüzeye kadar | hesaplama gerek |
| **Up to Face** | Seçilen yüze kadar | UI'da yüz seçimi |
| **Reverse direction** | -Z yönüne | mevcut |
| **Taper Angle** | Konik açı (silindirik değil) | OCCT BRepOffsetAPI_DraftAngle |

**FeatureEditPanel UI değişikliği:**
- Type ComboBox (Length / Two Lengths / Symmetric / Through All / To Face)
- Length2 TextField (sadece Two Lengths seçiliyken görünür)
- Symmetric checkbox (yer değiştirir)
- Taper Angle slider (-45° / +45°)
- Pocket için aynı seçenekler

**Backend değişikliği:** PartFacade::pad'e overload veya struct param. OCCT prism iki yönlü için: `BRepPrimAPI_MakePrism(face, gp_Vec(0,0,len1))` + `BRepPrimAPI_MakePrism(face, gp_Vec(0,0,-len2))` → fuse.

### Kalan Eksiklikler (Düşük Öncelik)

| Sorun | Detay |
|-------|-------|
| Smart Dimension Point/Ellipse/BSpline geo'da çalışmıyor (sessizce) | Diyalog kutusu aç veya status mesaj göster |
| Slider only "mm" featureType'larında — angle için yok | Angle için 0-360 slider ekle |
| Construction toggle iyi test edilmedi | Çiz, toggle, görüntülenmeli (dashed gray) |
| addPolyline auto coincident eklemiyor mu? | FreeCAD karşılaştır |
| addBSpline poles direkt — degree=3 hardcoded | UX'te degree seçimi yok |
| 3D Pad sonucu metalik gri ama edge'ler turkuaz | Edge stil ayarı |
| Properties paneli "Backend FreeCAD 1.2" satırı | ✓ Kaldırıldı (PropertiesPanel.qml) |

---

## Öncelik Sırası

### Adım 1: addRectangle düzelt (15 dakika — en hızlı kazanç) [✓ 2026-04-21]
4 satır eklendi — `addHorizontal(id0/id2)` + `addVertical(id1/id3)`. FreeCAD `addAlignmentConstraints` Diagonal mode'a birebir port. Test gerekli: rectangle çiz → distance ver → rectangle DİK kalmalı.

### Adım 1.5: Snap auto-constraint + Smart Dimension re-apply + Hover highlight [✓ 2026-04-21]
FreeCAD'in `DrawSketchHandler::seekAutoConstraint` ve `createAutoConstraints` mekanizmasını entegre ettim:
- **BUG-007 Snap auto-constraint:** Circle/Line/Arc/Ellipse çizerken endpoint/center snap → `Coincident`, midpoint snap → `Symmetric(line.start, line.end, new.pos)`. Artık rectangle kenarındaki snap'e çizilen daire rectangle deforme olduğunda onu takip ediyor.
  - [SketchCanvas.qml](ui/qml/SketchCanvas.qml) — `snapped/findGeometrySnap` geoId+pos döndürüyor; `startSnap*` click'te yakalanıyor; `finishDrawing` `emitAutoConstraint` çağırıyor.
  - [SketchFacade](adapter/inc/SketchFacade.h) — yeni `addPointOnObject(ptGeo, ptPos, curveGeo)` ve `addSymmetric(g1, pos1, g2, pos2, g3, pos3)` (3-element).
  - [CadEngine.cpp](adapter/src/CadEngine.cpp) — `addSymmetricConstraint` ve `addPointOnObjectConstraint` düzeltildi; artık parametreleri doğru geçiriyor.
- **BUG-008 Smart Dimension re-apply:** `beginDimension` mevcut Distance/Radius/Diameter constraint'ini arıyor; varsa `applyDimension` `setDatum` çağırıyor (yeni constraint yaratmak yerine). FreeCAD'in "re-open for edit" davranışı.
- **UX-006 Hover highlight:** Dimension/Trim/Fillet/Chamfer/Extend/Split tool'larında mouse altındaki geo amber (#FCD34D) ile vurgulanıyor. FreeCAD Preselection eşdeğeri. `hoveredGeo` property + `onPositionChanged` + `drawGeometry` priorite zinciri: selected > hover > constrained > default.

### Adım 2: Grid sync + editable (1 saat)
- BUG-005 (snap/visual) ve BUG-006 (Part-Sketch grid) birlikte çözülmeli
- CadEngine.gridSpacing tek source-of-truth
- PropertiesPanel'de TextField

### Adım 3: Hover highlight (30 dakika)
- SketchCanvas içinde basit ekleme
- Tüm tool'larda çalışmalı (Trim/Fillet/Chamfer/Smart Dimension/Extend/Split)

### Adım 4: Fillet/Chamfer interactive edit (2 saat)
- Constraint datum DOM'a ek
- Canvas'a handle render
- Drag ile değiştirme

### Adım 5: Pad/Pocket complete feature set (UX-008) (3 saat)
- Type ComboBox (Length, Two Lengths, Symmetric, Through All)
- Length2 input
- Symmetric mode (mid-plane extrude)
- Taper angle (opsiyonel ileri sürüm)
- PartFacade backend extend

### Adım 6: Diğer addX fonksiyonlarını FreeCAD ile karşılaştır
- addPolyline, addBSpline, addEllipse — eksik constraint var mı kontrol et

### Adım 2: Grid sync (BUG-005 + BUG-006) [✓ 2026-04-21]
- `CadEngine::gridSpacing` Q_PROPERTY tek-kaynak, default 10mm
- `SketchCanvas.gridSpacing` → `cadEngine.gridSpacing` bind
- `OccViewport::setGridStep(mm)` → render-thread-queued OCCT `SetRectangularGridValues`
- `PropertiesPanel` Grid satırı: read-only Text → TextField (0.1–1000mm validator)
- Değişiklik hem sketch canvas'a hem 3D viewport grid'e anında yansıyor.

### Adım 7: Create New Sketch — Plane/Face seçimi (UX-009) [✓ 2026-04-21 — backend + manuel face UI]
- Default plane dialog (XY/XZ/YZ) zaten vardı
- **YENİ:** "On Face" seçeneği — mevcut solid'in face listesi ComboBox'ından seçim
- `CadDocument::addSketchOnFace(name, featureName, subElement)` — FreeCAD `Part::AttachExtension` + `Attacher::mmFlatFace` pattern'i
- `CadDocument::featureFaceNames(name)` — TopoDS Face'leri "Face1..FaceN" olarak enumerate
- `CadEngine::createSketchOnFace / featureFaces / solidFeatureNames` Q_INVOKABLE
- **Kalan:** 3D viewport'ta görsel face-pick modu (OCCT selection mode 4 + face index lookup) — manuel ComboBox seçimiyle MVP tamamlandı, görsel pick gelecek session.

### Adım 8: Feature çift-tıkla düzenleme (UX-010) [✓ 2026-04-21]
- ModelTreePanel `onDoubleClicked`: Pad/Pocket/Revolution/Groove tespiti → `featureEditRequested(name, typeName)` signal
- Main.qml signal handler → `FeatureEditPanel.openForEdit(key, name)` (featureEditMode dokunmadan)
- **FeatureEditPanel edit mode:** `editingFeatureName` property; `rebuildPreview` mevcut feature'ı in-place mutate; `cancel` orijinal değerleri restore; `apply` state'i temizler
- **PartFacade:** `getFeatureParams(name)` + `updatePad/Pocket/Revolution/Groove(name, val, reversed)` — PartDesign `Length.setValue`/`Angle.setValue` + `Reversed.setValue` + `recompute()`. Non-parametric OCCT fallback feature'lar için `editable=false` döndürülüyor.

### Adım 9: Live preview (UX-011) [✓ 2026-04-21]
- Debounce zaten `FeatureEditPanel.previewTimer` (250ms) + `onTextChanged: scheduleRebuild()` ile vardı
- Edit mode'da `rebuildPreview` → `cadEngine.updateXXX` → `document_->recompute()` → `updateViewportShapes()`
- FreeCAD dependency graph otomatik olarak yalnızca bağımlı feature'ları hesaplıyor (bizim özel optimizasyon eklememize gerek yok)

### Kalan — Sonraki Session
- **UX-008** Pad/Pocket complete feature set (Two Lengths, Symmetric, Through All, Taper Angle)
- **UX-005** Fillet/Chamfer arrow drag + double-click edit
- **UX-009 eksik kısmı:** 3D viewport görsel face-pick modu (AIS_Shape SelectionMode=4 + face index lookup + signal)
- **Adım 6:** Diğer `addX` fonksiyonlarını FreeCAD ile karşılaştır (polyline, bspline, ellipse)

---

## 2026-04-21 Test Raporu — Master Plan

Kullanıcı toplu test yaptı. Hatalar + yeni istekler:

### P0 BLOCKER — çözülmeli
- **BUG-009 Grid size değişikliği sistemin donmasına yol açıyor.** Küçük step (örn 1mm, 0.5mm) verince OCCT `SetRectangularGridValues(0,0,step,step,0)` + sabit 5000mm extent milyonlarca nokta çiziyor → freeze.
  **Çözüm:** `OccRenderer::queueGridStep`'te extent'i step'e göre adaptif yap. `extent = clamp(step*100, 200, 2000)` → en fazla 200×200 = 40k nokta. Ek olarak UI tarafında değişiklik debounced olacak.
- **BUG-010 New document → New Sketch → program crash.** `ensureBody()` fresh document'ta `new PartDesign::Body` çağırıyor, TypeId register olmamış olabilir. Ayrıca `sketchPlaneDialog.onOpened` içinde `cadEngine.solidFeatureNames()` çağırımı da şüpheli.
  **Çözüm yönü:** ensureBody'de exception handling yoksa ekle; Body yoksa createSketch body olmadan devam edebilmeli (SketchObject tek başına document'a eklenebilir). Dialog onOpened'ı guard et.

### P1 KRİTİK — kullanılabilirlik için şart
- **BUG-011 Undo/Redo çalışmıyor.** `App::Document::undo()` transaction gerektiriyor. Şu an `setUndoMode(1)` + `openTransaction/commitTransaction` çağrılmıyor.
  **Çözüm:** `CadDocument` constructor'da `doc->setUndoMode(1)`. Her user-facing mutation için `openTransaction("name")` wrap.
- **BUG-012 Rubber-band (soldan-sağa / sağdan-sola mouse drag) seçim çalışmıyor.** SketchCanvas `onPressed` → drag tespit → `onPositionChanged`'de rectangle preview → `onReleased`'de rectangle içindeki geo'ları seç (sol→sağ = tam içinde, sağ→sol = kesişenler de dahil — FreeCAD/SW pattern).
- **BUG-013 Grid görünürlük toggle çalışmıyor.** Sketch mode'da SketchCanvas.gridVisible toggle olsa bile OCCT 3D grid altta görünmeye devam ediyor. Tek-kaynak lazım: `CadEngine::gridVisible` Q_PROPERTY, hem sketchCanvas hem OccViewport buna bağlı.
- **BUG-014 Grid "gerçek grid değil" — zoom'a tepki vermiyor, aynı pixel yoğunluğu kalıyor.** Büyük ihtimalle BUG-013 ile aynı kaynak: görülen OCCT 3D grid, yakınlaşsa da world-space'de sabit kalıyor, ama kullanıcı 2D sketch canvas grid'ini görüyor sanıyor. BUG-013 çözümü bununla tetiklenir: sketch mode'da OCCT grid kapatılsın, sadece SketchCanvas.drawGrid (zoom-adaptive) görünsün.
- **BUG-015 Pad sonrası sketch düzenlendiğinde 3D obje güncellenmiyor (UX-011 kısmen çözülmedi).** Sketch edit closeSketch ile kapatılınca `document_->recompute()` + `updateViewportShapes()` yapılıyordu — ama kullanıcı "hala yansımıyor" diyor. İhtimaller:
  - `recompute` bağımlı Pad'i bulmuyor (dependency graph Body altında mı?)
  - `updateViewportShapes` Tip-logic'i yanlış feature'ı gösteriyor
  - ensureBody yoksa Pad OCCT fallback'e düşüyor → non-parametric, sketch değişikliği yansımıyor
  **Çözüm:** closeSketch sonrası sketch-bağımlı feature listesini topla ve hepsini explicit recompute et; Body-lı flow'da `body->recompute()` çağır.
- **BUG-016 Feature çift-tıkla edit açılmıyor (UX-010 kısmen çözülmedi).** Kullanıcı "Pad seçilip parametreleri değiştirilemiyor" diyor. Signal ModelTreePanel'de yayınlanıyor ama Main.qml handler hiç tetiklenmiyor olabilir — OR panel visible ama text/değer doldurulmuyor.
  **İzle:** QML console.log ekle, test sırasında çıktıyı kontrol et; MouseArea `acceptedButtons` çakışması var mı, `onDoubleClicked` tetikleniyor mu.
- **BUG-017 Fillet/Chamfer uygulandıktan sonra radius değiştirilemez.** Fillet sketch tool olduğu için constraint datum olarak Radius constraint eklenmiş olmalı. Çift tıkla constraint listesinden düzenlenebilmeli.
  **Çözüm:** SketchFacade fillet sonrası oluşan Radius constraint'i döndürsün. Canvas'da fillet arc'ına çift tıklayınca dimInput popup'ı mevcut değerle açılsın → applyDimension zaten var, sadece Arc için pre-fill yap.
- **BUG-018 Smart Dimension sol kenara verince circle takip etmedi.** Circle end-click'i rectangle köşesine snap etmişti; o snap için constraint eklenmiyor (bizim code sadece start/center için emit ediyor). Circle'ın radius endpoint'i köşeye `PointOnObject` ile bağlanmalı ki rectangle uzayınca radius da büyüsün.
  **Çözüm:** `finishDrawing` circle kolu → end snap vertex ise `PointOnObject(vertex_geo, vertex_pos, circle_geo)` ekle. (FreeCAD `CURVE` target autoConstraint'i.)

### P2 UX/Görsellik
- **UX-012 Grid size Properties panel yerine alt status bar'da olmalı** (SNAP/GRID/ORTHO yanında inline TextField). PropertiesPanel'den kaldır.
- **UX-013 Dimension visual: ince siyah çizgi + değer etiketi (FreeCAD stili).** Şu an sadece Constraints panelinde "Distance 100.00" yazıyor — canvas üstünde görsel yok. drawGeometry extend: her Distance/Radius/Diameter constraint için ince siyah çizgi + değer metni.
- **UX-014 Constraint renk semantiği:**
  - Ölçüklendirilmiş / tam sabitlenmiş geo → **yeşil** ✓ (mevcut)
  - Ölçüklendirilmemiş / serbest geo → **mavi** ✓ (mevcut)
  - Over-constrained → kırmızı ✓ (mevcut)
  - Kullanıcı belirtmemiş ama zaten doğru çalışıyor, teyit.
- **UX-015 Pad/Pocket dialog'unda Profile Sketch seçimi liste değil 3D'den tık/seç kutucuğu olmalı (SW/FreeCAD stili).** Kullanıcı Pad butonuna basıp sonra 3D viewport'tan sketch'i tıklayabilmeli. Combo kalsa bile ana method "click to select".
  Bu UX-009 görsel face-pick işiyle aynı altyapı — AIS selection mode'u + signal.
- **UX-016 Sol panelde her zaman "Origin" / "Basic Planes" klasörü görünmeli** (SolidWorks/FreeCAD pattern). XY/XZ/YZ datum plane'leri tree'de görünsün, çift-tıkla üzerinde sketch aç. FreeCAD'de "Origin" feature'ı otomatik Body ile gelir — `body->Origin` property'sini expose et.
- **UX-017 Sol panel tüm öğelere sağ-tık context menu** — FreeCAD'den al. Edit / Rename / Delete + feature-specific actions (Move Tip, Toggle visibility, Show dependencies, Copy, Paste, vb.)
- **UX-008 Pad Symmetric/Two Lengths/Through All** — önceden plana alınmıştı, hâlâ eksik.
- **UX-005 Fillet/Chamfer arrow handle + double-click edit** — önceden plana alınmıştı, BUG-017 ile birlikte.

### Yeni İstekler
- **UX-018 Her build'de versiyon numarası otomatik artacak** — CMake pre-build script, `.build_number` counter, `AppVersion.h` regenerate, QML title "CADNC v0.1.0.N".

---

## 2026-04-22 v0.1.0.6 — Test 3 Sonrası: Sketch Lifecycle + Rubber-band Scope + Datum Plane Genişleme

Kullanıcı üçüncü tur test yaptı. 13 sorun ortaya çıktı, 11 tanesi bu oturumda kapandı.

### P0 Kritik State & Logic

- **createSketch lifecycle** [CadEngine::createSketch / createSketchOnFace](adapter/src/CadEngine.cpp): Önceki aktif sketch kapatılmadan yenisi açılıyordu → SketchFacade raw pointer eski objeye referans veriyor → yeni sketch'te çizim sessizce eski sketch'e düşüyordu. User'ın "yeni sketch → circle/rectangle çalışmıyor" bug'ı. Fix: her iki create fonksiyonunun başına `if (activeSketch_) closeSketch();`.
- **sketchPlaneDialog DatumPlane'leri listelemiyor** [CadEngine::availableSketchPlanes / createSketchOnPlane](adapter/src/CadEngine.cpp) + [Main.qml sketchPlaneDialog Repeater](ui/qml/Main.qml): Dialog artık XY/XZ/YZ + kullanıcı yarattığı her PartDesign::Plane'i tek bir liste olarak gösteriyor. Datum planes amber vurgulu; base planes axis renkleri. Tıklanınca `createSketchOnPlane` attach uygular. [CadDocument::addSketchOnPlane](adapter/src/CadDocument.cpp) — mmFlatFace + sub="" ile plane'i direkt support yapıyor.
- **Renk: Redundant + DoF=0 yeşil kalsın** [CadEngine::solve](adapter/src/CadEngine.cpp): Solver "Redundant" ve DoF=0 ise `"Fully Constrained (Redundant)"` döndürüyor; [drawGeometry](ui/qml/SketchCanvas.qml) `indexOf("Fully Constrained")==0` ile başlayanları yeşil boyuyor. Geometri artık doğru renkte (redundant'da turuncu değil, yeşil + warning badge).
- **Rubber-band hiçbir şey seçmiyor** [SketchCanvas.qml onReleased](ui/qml/SketchCanvas.qml): `geoIdsInRect` MouseArea scope'undaydı ama `canvas.geoIdsInRect(...)` olarak çağrılıyordu → undefined → boş selection. Fix: `drawArea.geoIdsInRect(...)`.
- **Document rename kendi kendine "Body"'ye dönüyor** [ModelTreePanel.qml docRenameField](ui/qml/panels/ModelTreePanel.qml): Inline rename state TextField'ın kendi `visible` property'sine bağlıydı → focus loss sırasında race. Fix: panel-level `renamingDocument` bool + `commit()` helper + `Qt.callLater(forceActiveFocus)`.
- **Expand/collapse caret inert** [ModelTreePanel.qml delegate](ui/qml/panels/ModelTreePanel.qml): Outer row MouseArea caret MouseArea'yı swallow ediyordu. Fix: caret Rectangle'a `z: 5` + `hoverEnabled` + cursor feedback.

### P1 İşlevsel Genişletme

- **Datum Plane dialog** [Main.qml datumPlaneDialog](ui/qml/Main.qml): Mode tab selector ("Base plane" | "On face"). Base: reference plane + offset + RotX/RotY (derece cinsinden tilt). Face: solid feature combo → face combo → normal yönünde offset. Backend: [CadDocument::addDatumPlaneRotated / addDatumPlaneOnFace](adapter/src/CadDocument.cpp) — AttachmentOffset placement rotation + mmFlatFace + sub="FaceN".
- **Tree Body row "+"** [ModelTreePanel.qml](ui/qml/panels/ModelTreePanel.qml): Body satırının sağında "+" quick-action button (Body tipinde satırlarda görünür). Tıklanınca bodyQuickMenu popup (New Sketch… / Add Datum Plane…). Right-click menüsü aynı aksiyonları tüm satırlarda sunuyor.
- **Quick-Access Bar New Sketch** [Main.qml toolbar](ui/qml/Main.qml): Üst toolbar'da kalıcı New Sketch butonu (pencil icon) — sketchPlaneDialog açıyor. Tree'deki kalıcı buton + context menu ile birlikte üç eşdeğer giriş noktası.
- **Double-click dimension editor** [SketchCanvas.qml MouseArea::onDoubleClicked](ui/qml/SketchCanvas.qml): Line/Arc/Circle üstünde çift tıklama Smart Dimension popup'ı açıyor. Fillet arc'ı da dahil (Radius constraint pre-fill, setDatum ile direkt değişiklik).
- **SMB logo orijinal** [Main.qml brand](ui/qml/Main.qml): Fake SVG yerine orijinal `smb_logo.png` (MilCAD'den kopya). `sourceSize.height: 32` + mipmap ile retina.

### P2 Görsel İyileştirmeler

- **Axis/Plane renk + ikon** [Theme.qml](ui/qml/Theme.qml): Yeni `featureColorByLabel` ve `featureIconByLabel` fonksiyonları — X-axis kırmızı ➡, Y-axis yeşil ⬆, Z-axis mavi ⬆; XY-plane amber ⬢, XZ-plane açık yeşil ⬢, YZ-plane sky ⬢. ModelTreePanel artık label'a göre çağırıyor — viewport gizmo ile uyumlu.

### Ertelendi (bir sonraki session)

- **Fillet/chamfer sonrası kaybolan Distance constraint'ler için phantom dashed preservation**: FreeCAD'in fillet op'u Distance constraint'leri silince DoF artıyor → renk mavi oluyor. Çözüm: fillet öncesi snapshot + trim edilen kenarlara yeni uzunluklarıyla Distance reassign (gerçek değerleri koruyarak); UI'da eski değere dashed iz.
- **Body/Plane için 3D SVG ikonlar**: Şu anda Unicode glyph'ler (⬢ ▣) kullanılıyor — yeterli. İleri versiyonda resources/icons/tree/ altına SVG ikonlar eklenebilir.
- **Dimension drag handles**: Label'lar canvas-level — ayrı Item overlay + drag + per-constraint offset persistence gerektiriyor.
- **Pad closed-region pick + sarı face highlight**: Sketch içinde kapalı alan detection + pick + padEx regionIndex parametresi.

---

## 2026-04-21 v0.1.0.5 — Toplu Test 2 Sonrası: Semantik Fix + File Dialogs + Tree Enrichment

Kullanıcı ikinci tur test yaptı. 11 sorun açtı, 9 tanesi bu oturumda tamamlandı.

### P0 Semantik & State Hatalar ı

- **Renk ters** [SketchCanvas](ui/qml/SketchCanvas.qml) + [SketchFacade::solve](adapter/src/SketchFacade.cpp): FreeCAD'in `SketchObject::solve` DoF≠0 için de 0 döndürüyor (=Solved). Bu yüzden boş sketch bile yeşil görünüyordu. Fix: `getLastDoF()`'u kontrol ediyoruz; DoF=0 olduğunda `SolveResult::Solved`, aksi halde `UnderConstrained`. drawGeometry `status==="Fully Constrained"` kontrolüne göre yeşil (DoF=0) / mavi (DoF>0) / kırmızı (over/conflicting) / amber (redundant) boyuyor.
- **Rubber-band select** [SketchCanvas.qml:geoIdsInRect](ui/qml/SketchCanvas.qml): Lines için segment-rect intersection testi eklendi (Cohen-Sutherland tarzı), böylece line'ın uçları kutu dışında olsa bile crossing kutusunda yakalanıyor. Ayrıca `selectedGeos = picked.slice()` ile yeni array referansı oluşturup QML property change signal'ını force ediyoruz.
- **Chamfer ölçüsü** [SketchFacade::chamfer](adapter/src/SketchFacade.cpp): Yeni segment geoId'sini tespit edip otomatik `addDistance(gid, len)` ekliyor — artık Smart Dimension Chamfer line'ını da edit edebiliyor.
- **Ctrl+Z sonrası fillet/chamfer bozulması, yeni sketch sonrası draw bozulması**: Her ikisinin kök sebebi aynı — [CadDocument::ensureBody](adapter/src/CadDocument.cpp) Body pointer'ını cache'liyordu. Ctrl+Z Body'yi silerse dangling pointer kalıyordu. Fix: cache kaldırıldı, her ensureBody çağrısı doc'u taze scan ediyor.

### File Dialogs Rebranding + Multi-Format

- [Main.qml:openDialog/saveDialog/exportDialog](ui/qml/Main.qml): "FreeCAD project" label'ı "CADNC project" oldu; `.cadnc` native uzantı eklendi (içerik FCStd zip). Nameset DXF/DWG/OBJ/PLY/STEP/STP/IGES/IGS/IGUS/BREP/STL içeriyor. Save dialog şimdi tek yerden hem project hem geometry export yapıyor.
- [CadDocument::exportTo](adapter/src/CadDocument.cpp) → native (`.cadnc`/`.fcstd`), STEP/IGES/BREP/STL (existing), **OBJ** (yeni — OCCT BRepMesh_IncrementalMesh + Wavefront writer), **DXF** (yeni — OCCT BRepAdaptor_Curve + GCPnts_TangentialDeflection örnekleme, R12 ASCII LINE entities). DWG → DXF fallback warning mesajıyla.

### Tree + Document Rename

- [ModelTreePanel](ui/qml/panels/ModelTreePanel.qml): Document header'ında "Untitled" yerine inline double-click rename (default label "Body"). [CadEngine::renameDocument](adapter/src/CadEngine.cpp) FreeCAD `Document::Label` property'sini set ediyor.
- Header'a kalıcı "New Sketch" pencil button (sketchPlaneDialog açıyor).
- Context menu'ye "New Sketch…" ve "Add Datum Plane…" eklendi (feature tipine bağlı değil, her satırda çıkıyor).
- **Custom datum planes**: [CadDocument::addDatumPlane](adapter/src/CadDocument.cpp) PartDesign::Plane factory + Attacher::mmObjectXY/XZ/YZ + offset. Main.qml'de `datumPlaneDialog` yeni bir Popup. Plane oluşturulduğunda Body altında görünüyor, double-click → sketch.

### Visual Polish

- [Theme.qml](ui/qml/Theme.qml): featureColor + featureIcon zenginleştirildi. Body (▣ deep blue), Origin (⌖ grey), Plane (▭ amber), Line (― emerald), Point (● violet), Primitives (◼○⬤▲ sky), Patterns (☰✿◐ orange), Booleans (⧾⊖∩ cyan), Groove (⎋ orange). Her feature tipi kendi renk + glyph'i alıyor.
- [Main.qml brand row](ui/qml/Main.qml): SMB logosu sağ üstte (qrc:/resources/logos/smb_logo.svg — CMakeLists'e `resources/logos/` eklendi).

### Ertelendi (sonraki tur)
- **Pad closed-region pick** + sarı face highlight: sketch içindeki kapalı alanları canvas'ta hover'da sarı göster + tıklanabilir yap + padEx `regionIndex` parametresi. (Scope: bir face detection pass + SketchCanvas hit-test + PadOptions.regionIndex.)
- **Dimension drag handles**: Distance/Radius/Diameter etiketi mouse ile sürüklenebilir + canvas item olarak overlay + constraint'e `labelOffsetX/Y` meta-property olarak kaydetme.

---

## 2026-04-21 v0.1.0.4 — UX Paketi: Tree Hierarchy + Pad Rich API + Dimension Visuals + Context Menu

Aynı oturumda v0.1.0.3 sonrası UX açıklarını da tamamladım. Tek session'da 4 P0/P1 bug + 4 UX mini-epic.

### UX-016 — ModelTree hierarchical + plane double-click → sketch
- [CadDocument::featureTree](adapter/src/CadDocument.cpp) her FeatureInfo'ya `parent` alanı (App::GroupExtension::getGroupOfObject) → CadEngine QVariantMap'e "parent" key.
- [ModelTreePanel.qml](ui/qml/panels/ModelTreePanel.qml) `flattenedTree()` fonksiyonu, expand/collapse state + depth tracking. Body/Origin varsayılan açık, kullanıcı caret (▾/▸) veya double-click ile toggle ediyor.
- App::Plane double-click → `planeDoubleClicked(name, planeType)` signal → Main.qml `cadEngine.createSketch("Sketch", planeType)`. SolidWorks/FreeCAD paritesi.

### UX-008 — Pad/Pocket rich feature set
Backend: [PartFacade](adapter/inc/PartFacade.h) `PadOptions` struct (length, length2, reversed, sideType, method) + `padEx/pocketEx/updatePadEx/updatePocketEx`. FeatureExtrude'un `SideType` (One side / Two sides / Symmetric) ve `Type` (Length / ThroughAll) enumerasyonları direkt geçiriliyor. getFeatureParams artık p.length2, p.sideType, p.method'u da döndürüyor.

Frontend: [FeatureEditPanel.qml](ui/qml/panels/FeatureEditPanel.qml) Side + Method ComboBox'ları, Two sides seçildiğinde görünen Length2 TextField. Live preview (debounced 250ms) rich API'yi kullanıyor, cancel state tam restore ediyor.

Test [17] ile doğrulandı: `sideType='Two sides' method='Length' len=8.00 len2=4.00`.

### UX-013 — On-canvas dimension visuals
[SketchCanvas.qml](ui/qml/SketchCanvas.qml) `drawDimensions()` pass:
- Line + Distance → paralel offset leader + iki uçta arrowhead + merkezde pill background + "%.2f" etiket.
- Circle/Arc + Radius → 30° (veya arc midpoint) yönünde leader + "R%.2f" etiket. Diameter ise "Ø%.2f".
- DistanceX / DistanceY de destekli.
Etiket pill'leri beyaz fill + siyah stroke — FreeCAD ve SolidWorks stilinin birleşimi. Zoom-invariant (fixed pixel offset).

### UX-017 — Tree context menu zenginleştirildi
- Feature tipine göre ilk aksiyon: "Edit Sketch" / "Edit Feature…" / "Start Sketch on this Plane"
- "Hide" / "Show" toggle — [CadEngine::toggleFeatureVisibility](adapter/src/CadEngine.cpp) → `Visibility` property → `updateViewportShapes` invisible feature'ları atlıyor.
- Rename / Delete — Body ve Origin children disabled (link resolution bozulmasın).
- Delete'te dependent warning Dialog: `cadEngine.featureDependents(name)` çağrısı → Pad→Fillet zinciri kırılacaksa kullanıcıya onay sorar.

### Eklenen Test Regressions
[tests/test_adapter.cpp](tests/test_adapter.cpp) test [14-17]:
```
[14] BUG-010/015/016: Pad type='PartDesign::Pad' editable=yes length=5.00
[15] Pad updated OK, new length=12.50
[16] BUG-017: fillet arc=4, constraints 8→10 (delta=2), Radius id=9 value=4.00
[17] UX-008 Pad rich: sideType='Two sides' method='Length' len=8.00 len2=4.00
```

ctest 2/2 geçiyor. cadnc binary link temiz.

### Kalan (UX ikincil, bir sonraki session için)
- **UX-005** Fillet/Chamfer interaktif handle — arc üzerinde sürüklenebilir ok, live radius update.
- **UX-015** 3D'den sketch pick — FeatureEditPanel'de "Click to select sketch" butonu + AIS selection mode.
- **UX-009 tamamlama** — görsel face-pick (AIS selection mode 4 + signal).
- **BUG-018-B** Smart Dimension snap-pick edge case re-test.
- **UX-008 kalan** — Taper Angle (PartDesign TaperAngle property), Up to Face (face picker gerekli).
- **Adım 6** — addPolyline/BSpline/Ellipse auto-constraint denkliği FreeCAD ile karşılaştır.

---

## 2026-04-21 v0.1.0.3 — P0/P1 Body + PartDesign Zinciri Düzeltmesi

### Kök Neden: `_PartDesign` modülü Python'da `PartDesign` olarak alias'lanmamıştı

İki zincirleme hata aynı noktada birleşiyordu:

1. **Factory çağrı patlaması**
   `doc->addObject("PartDesign::Body", "Body")` içinde
   `Base::Type::getTypeIfDerivedFrom(name, …, loadModule=true)` çağrılıyor.
   Bu fonksiyon `Interpreter().loadModule("PartDesign")` tetikliyor. Bizde
   inittab yalnızca `_PartDesign` altında kayıtlı; Python-tarafı `PartDesign`
   paketi yok → `Base::PyException("No module named 'PartDesign'")` fırlatıyor.
   FreeCAD normalde `InitGui.py`'daki Python sarıcı paketi yükler; headless
   çalıştığımız için bu mevcut değildi.

2. **Pointer-path addObject `setupObject`'i atlıyor**
   Eski kod `new PartDesign::Body()` + `doc->addObject(body, name)` kullanıyordu.
   Bu overload `_addObject`'i `DoSetup` flag'i olmadan çağırır → `setupObject()`
   çalışmaz → `OriginGroupExtension::onExtendedSetupObject()` çalışmaz → Origin
   yaratılmaz. İlk recompute'ta `Body::execute()` → `getOrigin()` null → exception
   → terminate.

### Çözüldü

- **BUG-010** fresh-document crash'i: [CadSession.cpp](adapter/src/CadSession.cpp)
  `App::Application::init` sonrası `import Part / Sketcher / Materials /
  _PartDesign` + `sys.modules['PartDesign'] = sys.modules['_PartDesign']` alias.
  Tüm C++ tip init'ları çalışıyor, factory `PartDesign` adını bulabiliyor.
- **Body setupObject** [CadDocument.cpp](adapter/src/CadDocument.cpp):
  `Base::Type::fromName("PartDesign::Body")` (importModule'ü bypass eden
  yol) + `createInstance` + `doc->addObject(obj, name)` + **manuel extension
  setup**: `obj->setupObject()` protected olduğu için
  `getExtensionsDerivedFromType<DocumentObjectExtension>()` iterasyonu +
  her extension'ın public `onExtendedSetupObject()`'u çağrılıyor.
  `PartFacade::findOrCreateBody()` de aynı yöntemi kullanıyor.
- **BUG-015**: Body + PartDesign::Pad garanti olduğu için FreeCAD dependency
  graph çalışıyor; sketch edit closeSketch sonrası `doc->recompute()` Pad'i
  de tetikliyor. Test 14-15 ile doğrulandı.
- **BUG-016**: `getFeatureParams` artık `editable=true` + `typeName="PartDesign::Pad"`
  döndürüyor — FeatureEditPanel `openForEdit` başarıyla açılıyor.
- **BUG-017** fillet radius: [SketchFacade.cpp](adapter/src/SketchFacade.cpp)
  `SketchObject::fillet` yalnızca Tangent+Coincident ekliyor; şimdi yeni arc
  geoId'sini tespit edip `addRadius(arcGid, radius)` ile otomatik Radius
  constraint kuruyoruz. Smart Dimension (`beginDimension` Arc'ı radius kind'a
  map ediyor + `findExistingDimension` Radius constraint'i buluyor) → pre-fill
  edilmiş değerle TextField açılıyor, Enter `setDatum` çağırıyor.

### Test Doğrulaması
`tests/test_adapter.cpp`'ye 3 yeni regression bloğu:
```
[14] BUG-010/015/016: Pad type='PartDesign::Pad' editable=yes length=5.00
[15] Pad updated OK, new length=12.50
[16] BUG-017: fillet arc=4, constraints 8→10 (delta=2)
     Radius constraint id=9 value=4.00 driving=yes
```

### Bundan Sonra (UX odak)
- **UX-005** Fillet interactive handle (köşede sürüklenebilir ok)
- **UX-008** Pad/Pocket Symmetric / TwoLengths / ThroughAll / Taper
- **UX-013** Dimension görsel etiket (ince siyah çizgi + değer)
- **UX-015** Sketch pick 3D'den (list yerine)
- **UX-016** Origin + datum planes zaten var, sadece ModelTree expand-able yapılmalı
- **UX-017** Tree context menü genişletme
- **UX-009** görsel face-pick (AIS selection mode 4)
- BUG-018-B Smart Dimension re-apply snap pick edge case

---

## 2026-04-21 v0.1.0.2 — Toplu Test Sonrası Fix'ler

Kullanıcı v0.1.0.1 build'ini test etti. Yeni tur düzeltmeler:

### Çözüldü
- **BUG-009 Grid freeze** [OccRenderer.cpp] `extent = clamp(step*100, 200, 2000)` adaptive. Küçük step'te max ~40k nokta kalıyor, freeze yok.
- **BUG-011 Undo/Redo hiç çalışmıyordu** [CadDocument.cpp] `setUndoMode(1)` + `setMaxUndoStackSize(100)`. `openTransaction/commitTransaction` yardımcıları eklendi.
- **BUG-011-B Undo bir seferde N işlem geri alıyordu** [CadEngine.cpp] — trim/fillet/chamfer/extend/split/remove*/pocket/revolution/groove/updateXXX/deleteFeature için TxScope eksikti, FreeCAD hepsini tek auto-tx'te birleştiriyordu. TxScope artık tüm mutation Q_INVOKABLE method'larını sarıyor → her işlem ayrı undo adımı.
- **BUG-011-C Ctrl+Z / Ctrl+Y shortcut'ları çalışmıyordu** [CadEngine.h] — `canUndo/canRedo` NOTIFY sadece `featureTreeChanged`'di; sketch mutation'larında tetiklenmiyordu → QML Action.enabled stale kalıyor → shortcut disabled. Yeni `undoStateChanged` signal ve her TxScope commit'te emit.
- **BUG-012 Rubber-band selection yoktu** [SketchCanvas.qml] — sol→sağ (mavi dolgu) tam içinde, sağ→sol (yeşil dashed) crossing. `selectedGeos[]` array'i çoklu seçim tutar.
- **BUG-013/014 Grid on/off ve görsel mismatch** — v0.1.0.1'de hâlâ eksikti; `CadEngine.gridVisible` Q_PROPERTY unified source, SketchCanvas binding + OccRenderer queueGridVisible. **v0.1.0.2'de ek:** OccViewport sketch mode'da OCCT 3D grid'ini **her zaman** kapatıyor (`userWantsGrid_` saklı kalır, part moduna dönüldüğünde restore edilir). Bu sayede sketch canvas'ı ile OCCT grid'inin farklı koordinat sistemlerinde overlap'leşme problemi bitti.
- **BUG-018 Circle radius rectangle köşesini takip etmiyordu** [SketchCanvas.qml] finishDrawing circle end-snap endpoint ise `PointOnObject(vertex, pos, circle)` emit ediyor (FreeCAD CURVE auto-constraint path). `addPointOnObjectConstraint` düzeltildi (position parametresi aktarılıyor).
- **UX-012 Grid size status bar'a taşındı** — PropertiesPanel'den çıkarıldı, SNAP/GRID/ORTHO yanında inline TextField (GRID toggle açıkken görünür, 0.5–1000mm validator).
- **UX-018 Version auto-bump** — `cmake/BumpBuildNumber.cmake` + `cadnc_bump_build_number` ALL-target her build'de `build/.build_number` sayacını artırıyor, `AppVersion.h`'i `"0.1.0.N"` formatında regenerate ediyor. `set_property(OBJECT_DEPENDS)` ile main.cpp otomatik recompile. Sağ üstte "CADNC v0.1.0.N" görünüyor.

### Hâlâ Eksik (sırayla Sonraki Session'a)

#### P0 — Blocker

**BUG-010: New Document → New Sketch crash**
- **Semptom:** File→New ile yeni doc, sonra Create Sketch butonuna bas → program çöküyor.
- **Kök Sebep Hipotezi:** `CadDocument::Impl::ensureBody()` içinde `new PartDesign::Body()` + `doc->addObject(body, "Body")` — fresh document'ta TypeId register'ı tam olmayabilir. Veya `sketchPlaneDialog.onOpened` handler'ında `cadEngine.solidFeatureNames()` çağrısı.
- **Araştırma:** Crash handler zaten var (main.cpp SIGSEGV backtrace). Reproduce et, stderr'de backtrace'i oku. `PartDesign::Body` olmayan dokümanda SketchObject standalone eklenebilir mi? (CadDocument::addSketch'te `if (body) body->addObject(obj);` zaten guard'lı ama `ensureBody()` kendisi patlıyor olabilir.)
- **Çözüm yönü:**
  1. `ensureBody()`'de `try/catch(...)` ekle (zaten var ama `new PartDesign::Body()` constructor'ı atarsa catch'e düşmeden önce crash olabilir — `Base::Exception`'a göre daraltmak yerine genişlet).
  2. Body assertion FreeCAD Python-module-less ortamda kaçınılmazsa, sketch'i **Body dışında** ekle (standalone sketch → Pad OCCT fallback'i ile çalışır).
  3. Dialog onOpened guard: `if (!cadEngine.hasDocument) return`.

#### P1 — Broken Core Features

**BUG-015: Sketch düzenlenince Pad 3D'ye yansımıyor (UX-011 kısmen)**
- **Semptom:** Pad oluştur → ModelTree'den sketch'e çift-tıkla → sketch edit → geo değiştir → close → 3D obje hâlâ eski geometri.
- **Araştırma:** `closeSketch` içinde `document_->recompute()` + `updateViewportShapes()` çağrılıyor ama FreeCAD dependency graph Body olmayan (OCCT fallback) dokümanda Pad'i sketch'e bağımlı olarak görmüyor. Pad'in `Profile` property'si sketch'e link olsa bile, fallback `Part::Feature` transient shape tutuyor, recompute tetiklenmiyor.
- **Çözüm yönü:**
  1. `closeSketch` sonrası feature tree'yi tara: Profile property'si değişen sketch'i işaret eden her feature için explicit `doc->recomputeFeature(feat, true)` çağır.
  2. Eğer fallback path ise (non-parametric Part::Feature), Pad'i yeniden yaratıp eskisini sil (isim değişikliği olacak, downstream feature'lar için sorun).
  3. **İdeal:** ensureBody() kararlı çalışsın, Pad her zaman PartDesign::Pad olsun (BUG-010 çözümüyle bağlantılı).

**BUG-016: Pad/Pocket parametreleri düzenlenemez**
- **Semptom:** ModelTree'den Pad'e çift-tıkla → FeatureEditPanel açılmıyor veya boş.
- **Araştırma:** ModelTreePanel `onDoubleClicked` → Pad type algılıyorsa `featureEditRequested(name, typeName)` emit ediyor. Main.qml handler `featureEditPanel.openForEdit(key, name)` çağırıyor. openForEdit `cadEngine.getFeatureParams(name)` ile parametreleri alıyor. Sorun muhtemelen:
  1. `getFeatureParams` OCCT fallback Pad için `editable=false` döndürüyor → openForEdit false dönüyor → panel açılmıyor.
  2. VEYA panel açılıyor ama `hasDocument` Connection'ı `!hasDocument` görünce cancel ediyor.
- **Çözüm yönü:**
  1. Fallback Pad için de editable yapılabilir mi? Hayır, shape static. **Asıl çözüm: BUG-010 çözüldüğünde Body + PartDesign::Pad garanti olur, editable=true olur.**
  2. QML `console.log` debug + test et. Alternatif: fallback Pad için "Delete & recreate" fallback mantığı.

**BUG-017: Fillet/Chamfer sonrası radius/size düzenlenemez**
- **Semptom:** Fillet uygula → o köşede arc görünür → radius constraint listede yok veya düzenlenebilir değil.
- **Kök Sebep:** FreeCAD `SketchObject::fillet` Radius constraint ekliyor (kanıt: FreeCAD GUI'de fillet sonrası arc'a tıklayınca radius düzenlenebilir). Bizim adapter'da bu constraint görünmüyor veya Smart Dimension tool'u Arc'ı tanımıyor.
- **Çözüm:**
  1. SketchFacade::fillet dönüş değeri Radius constraint id'sini döndürsün.
  2. SketchCanvas.qml `beginDimension` — `g.type === "Arc"` için `findExistingDimension(geoId, "radius")` zaten çalışmalı. Test et.
  3. Canvas'a fillet arc üzerinde çift-tık → dimInput popup açılsın (mevcut Smart Dimension flow'unu kullan).

**BUG-018-B: Smart Dimension re-apply snap pick'te**
- İlk test'te: `Smart Dimension ile bir defa 50 ölçüsü verdim. Daha sonra aynı araçla tekrar 100 ölçüsü verdim ama hiçbir şey değişmedi.` — setDatum fix'i (dimExistingId) uygulandı, yeniden test et.

#### P2 — UX / Görsellik

**UX-005: Fillet/Chamfer interaktif handle + çift-tıkla edit**
- Fillet arc'ında köşede küçük ok ikonu, mouse drag → radius live update.
- Double-click → constraint dimInput popup (BUG-017 ile aynı altyapı).

**UX-008: Pad/Pocket eksiksiz feature seti**
- Type ComboBox: Length / Two Lengths / Symmetric / Through All / Up to Face.
- Symmetric: sketch düzleminin iki yanına eşit extrude (FreeCAD `Midplane=true` PartDesign::Pad).
- Two Lengths: Length + Length2 (FreeCAD `Type="TwoLengths"`, `Length2` property).
- Through All: FreeCAD `Type="ThroughAll"`.
- Up to Face: 3D'den yüz seç (UX-015 ile aynı altyapı).
- Taper Angle: OCCT `BRepOffsetAPI_DraftAngle` veya FreeCAD `TaperAngle` property.

**UX-013: Dimension görsel etiket (ince siyah çizgi + değer)**
- FreeCAD stili offset çizgi + arrow + değer metni.
- SketchCanvas.drawGeometry için yeni pass: her Distance/Radius/Diameter constraint için çizgi hesapla (geo bbox + offset mesafe).
- Constraint pozisyonu kullanıcı-editable (drag ile taşınabilir) — FreeCAD'de bu `DrawingConstraint`'in `LabelPosition` property'siyle yapılıyor.

**UX-015: Pad/Pocket dialog'unda sketch pick 3D'den (list yerine)**
- FeatureEditPanel'de ComboBox yerine "Click to select sketch" buton.
- Tıklayınca 3D viewport selection mode'a girer (UX-009 görsel face-pick ile aynı altyapı).
- Sketch tıklandığında combo güncellenir.

**UX-016: Sol panelde "Origin" klasörü + temel yüzeyler**
- Her dokümanda otomatik Origin feature (FreeCAD `App::Origin`).
- ModelTreePanel içinde expand-able: XY, XZ, YZ datum planes.
- Çift-tıkla → o plane üstünde sketch oluştur.
- **Gereksinim:** Body oluşturulmalı (BUG-010 ile bağlantılı). FreeCAD Body constructor otomatik Origin ekliyor.

**UX-017: Sağ-tık context menu tree için zenginleştir**
- Tree item tipine göre:
  - Sketch: Edit, Rename, Delete, Attach to face, Export DXF
  - Pad/Pocket/etc: Edit, Toggle suppress, Move Tip above/below, Delete, Copy geometry
  - Origin plane: Start Sketch, Show/Hide
- FreeCAD'in PartDesign Gui menülerini referans al.

**UX-009 tamamlama: Görsel 3D face-pick**
- OCCT selection mode 4 (`TopAbs_FACE`).
- OccRenderer: `queueFacePickMode(bool)` + klik'te `context->SelectDetected()` → owner'ın shape'i Face ise parent feature ve face index bul.
- Signal: `OccViewport::facePicked(QString featureName, int faceIndex)` → Main.qml → `cadEngine.createSketchOnFace(...)`.

#### Mevcut Kalan (eski plandan)
- **Adım 6:** Diğer `addX` fonksiyonlarını FreeCAD ile karşılaştır (polyline auto-coincident, bspline degree options, ellipse axis constraints).

---

## Bir Sonraki Session Prompt (hazır — kopyalayıp yapıştırılabilir)

```
Proje: CADNC. Başlangıç adımları:
1. Read .ai/START_HERE.md
2. Read .ai/NEXT_SESSION_PROMPT.md — "2026-04-22 v0.1.0.6 — Test 3" bölümü en son durum.
3. Read .ai/WORKPLAN.md + .ai/ENGINEERING_LOG.md

Mevcut build: v0.1.0.6 (temiz, ctest 2/2 geçiyor).

ÖNCEKİ OTURUM TAMAMLANANLAR (test 3 sonrası):
- createSketch → önceden aktif sketch closeSketch'leniyor.
- sketchPlaneDialog artık custom DatumPlane'leri de listeliyor.
- Redundant + DoF=0 geometri yeşil görünüyor.
- Rubber-band seçim scope bug'ı (drawArea.geoIdsInRect) düzeltildi.
- Document rename self-revert bug'ı (panel.renamingDocument property) düzeltildi.
- Expand/collapse caret (z:5) artık tıklanabilir.
- Datum Plane dialog: Base/Face mode tab + RotX/RotY açı + face reference.
- "+" quick-action button Body row'unda.
- Üst toolbar'da kalıcı New Sketch butonu.
- Double-click geometry → Smart Dimension popup (fillet arc dahil).
- SMB logo orijinal PNG.
- X/Y/Z-axis + XY/XZ/YZ-plane label-aware renkler & ikonlar.

SIRADAKİ ÖNCELİK:

1. **Fillet/Chamfer sonrası kaybolan Distance constraint'ler**
   - FreeCAD fillet op'u rectangle kenarlarının Distance constraint'lerini siliyor → DoF artıyor → geometri mavi.
   - Fix: SketchFacade::fillet öncesi "etkilenen edge'lere ait Distance ID + value" snapshot → fillet sonrası yeni edge'lere aynı value'yla yeniden addDistance → phantom dashed visual (kullanıcı yeniden oynamak için).
   - Ayrıca: silinen constraint'in label pozisyonunu kesik çizgi + "ghost" renkle drawDimensions'a ek pass ile göster.

2. **Pad closed-region pick + sarı face highlight**
   - SketchCanvas'a face-detection pass (wires → closed loops → regions)
   - Hover'da region sarı fill; tıklamada region index seçimi
   - padEx'a regionIndex ekleme; makePrismFeature o face'i extrude etsin

3. **Dimension drag handles**
   - drawDimensions label'larını ayrı Item overlay'e çıkar
   - MouseArea + drag.target + per-constraint offset persistence (YAML yan dosya ya da FreeCAD expression)

4. **Body/Plane SVG ikonlar**
   - resources/icons/tree/body.svg, plane.svg — 3D perspektif
   - Theme.featureIconByLabel SVG path döndürsün
   - ModelTreePanel Text yerine Image component

5. **UX-005 Fillet interactive handle**
   - Arc üstünde sürüklenebilir ok ikonu
   - Drag → setDatum(radiusConstraintId, newR) live

Test öncesi ön-doğrulama:
  cmake --build build -j$(nproc) && cd build && ctest --output-on-failure
```

ÖNCEKİ OTURUM TAMAMLANANLAR:
- Renk semantiği tersti → DoF kontrolü (solver Solved + DoF=0 olmalı).
- Rubber-band seçmiyordu → segment-rect intersection + yeni array referansı.
- Chamfer ölçüsü yoktu → yeni segment'e otomatik Distance constraint.
- Ctrl+Z + yeni sketch bozulması → Body pointer cache kaldırıldı.
- Save/Open "FreeCAD project" label'ı "CADNC project" oldu; DXF/OBJ backend desteği eklendi.
- Document row "Untitled" yerine inline rename (default "Body").
- Sol panel header'a kalıcı New Sketch button + right-click "Add Datum Plane".
- addDatumPlane backend + Main.qml datumPlaneDialog.
- Tree ikonları + renkleri feature tipine göre özgül (Body/Origin/Plane/Line/Point/Primitives/Booleans/Patterns/Groove).
- SMB logosu sağ üstte.

SIRADAKİ ÖNCELİK:
1. **Pad closed-region pick + sarı face highlight**
   - SketchCanvas'a face-detection pass: wires → closed loops → regions.
   - Hover'da her region sarı fill (rgba(255,200,50,0.15)); tıklamada region index seçimi.
   - FeatureEditPanel Pad mode: sketch seçilince region listesi görünsün; seçilen region padEx'a `regionIndex` olarak geçsin.
   - Backend: PartFacade::padEx PadOptions'a `regionIndex` eklenmeli, makePrismFeature sadece o face'i extrude etmeli.
2. **Dimension drag handles** — Distance/Radius/Diameter etiketi mouse drag ile taşınabilir olsun.
   - drawDimensions label'larını ayrı QML Item'lara çıkar (MouseArea + drag.target).
   - Per-constraint `labelOffsetX/Y` persistence (YAML yan dosya veya FreeCAD Label property'de JSON).
3. **UX-005 Fillet interactive handle** — arc üstünde sürüklenebilir ok; drag → `setDatum(radiusConstraintId, newR)` live.
4. **UX-015 Sketch pick 3D'den** — FeatureEditPanel'de "Click to select sketch" button + AIS selection mode + signal.
5. **Adım 6** — addPolyline/BSpline/Ellipse auto-constraint FreeCAD karşılaştırması.

Test öncesi ön-doğrulama komutu:
  cmake --build build -j$(nproc) && cd build && ctest --output-on-failure
```

---

## Teknik Referanslar

### Build
```bash
cmake --build build -j$(nproc)
ctest --test-dir build --output-on-failure
DISPLAY=:0 QT_QPA_PLATFORM=xcb ./build/cadnc
```

### FreeCAD Reference (her zaman önce buna bak)
```
/home/embed/Downloads/FreeCAD-main-1-1-git/src/Mod/Sketcher/Gui/DrawSketchHandler*.h
/home/embed/Downloads/FreeCAD-main-1-1-git/src/Mod/Sketcher/App/SketchObject.cpp
```

### Kurallar (Hatırlatma)
- UI kodu FreeCAD header include etmeyecek
- AIS_InteractiveContext işlemleri sadece render thread
- **YENİ KURAL: Bir sketch işlemi adapter'a yazılmadan önce FreeCAD'in implementasyonu okunacak**
- Solid rengi: metalik gri (0.72, 0.72, 0.75)
- Sketch tools: SketchObject API'sini doğrudan sar, OWN logic ekleme
