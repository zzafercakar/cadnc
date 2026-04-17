# CADNC — Sonraki Session: FreeCAD Tam Entegrasyon

## Hedef
FreeCAD'in Sketcher ve PartDesign modüllerindeki TÜM araç, fonksiyon ve yetenekleri hem backend (adapter) hem frontend (QML UI) olarak CADNC'ye entegre et.

## Mevcut Durum Özeti (2026-04-17, Faz 1 tamamlandı)

### Çalışan
- **Sketch geometri**: Line, Circle, Arc, Rectangle, Point, **Ellipse, BSpline, Polyline** — çizim + solver + render
- **Sketch constraint**: Coincident, Horizontal, Vertical, Parallel, Perpendicular, Tangent, Equal, Distance, Radius, Angle, Fixed, **DistanceX, DistanceY, Diameter, Symmetric, PointOnObject** — 16/21 constraint tipi
- **Sketch tools**: Trim, Fillet, **Chamfer (gerçek), Extend, Split, Construction Toggle** — 6/16 tool
- **Part features**: Pad, Pocket, Revolution — 3/8 sketch-based feature (Part::Extrusion fallback)
- **File I/O**: FCStd save/load, STEP/IGES/STL/BREP export
- **UI**: SketchCanvas (grid, axes, geometry render, preview, snap, inference, zoom/pan), ModelTree (delete/rename), ConstraintPanel (datum edit, driving toggle)
- **Viewport**: OCCT V3d + ViewCube + grid (closeSketch sonrası shape gösterimi)

### KRİTİK EKSİKLER

#### A. Backend Eksikleri (adapter/SketchFacade + PartFacade)

**Sketch Geometri (2 kalan):**
| Geometri | FreeCAD Sınıfı | Öncelik | Durum |
|----------|---------------|---------|-------|
| ~~Ellipse~~ | GeomEllipse | ~~YÜKSEK~~ | ✅ TAMAMLANDI |
| ArcOfEllipse | GeomArcOfEllipse | ORTA | Bekliyor |
| ~~BSpline~~ | GeomBSplineCurve | ~~YÜKSEK~~ | ✅ TAMAMLANDI |
| ~~Polyline~~ | (addLine zinciri) | ~~YÜKSEK~~ | ✅ TAMAMLANDI |
| ~~Construction toggle~~ | toggleConstruction() | ~~YÜKSEK~~ | ✅ TAMAMLANDI |
| Offset curve | GeomOffsetCurve | DÜŞÜK | Bekliyor |

**Sketch Constraint (1 kalan):**
| Constraint | Durum |
|-----------|-------|
| ~~DistanceX~~ | ✅ TAMAMLANDI |
| ~~DistanceY~~ | ✅ TAMAMLANDI |
| ~~Diameter~~ | ✅ TAMAMLANDI |
| ~~Symmetric~~ | ✅ TAMAMLANDI |
| ~~PointOnObject~~ | ✅ TAMAMLANDI |
| InternalAlignment | Tamamen eksik (BSpline internal geometry için) |

**Sketch Tools (7 kalan):**
| Tool | FreeCAD Methodu | Öncelik | Durum |
|------|----------------|---------|-------|
| ~~Extend~~ | extend() | ~~YÜKSEK~~ | ✅ TAMAMLANDI |
| ~~Split~~ | split() | ~~YÜKSEK~~ | ✅ TAMAMLANDI |
| ~~Chamfer (gerçek)~~ | fillet(...,chamfer=true) | ~~YÜKSEK~~ | ✅ TAMAMLANDI |
| ~~Construction toggle~~ | toggleConstruction() | ~~YÜKSEK~~ | ✅ TAMAMLANDI |
| Mirror copy | addSymmetric() | ORTA | Bekliyor |
| Array copy | addCopy() | ORTA | Bekliyor |
| Move geometry | moveGeometry() | ORTA | Bekliyor |
| Carbon copy | carbonCopy() | DÜŞÜK | Bekliyor |
| External geometry | addExternal() | ORTA | Bekliyor |
| Convert to NURBS | convertToNURBS() | DÜŞÜK | Bekliyor |

**PartDesign Features (kalan):**
| Kategori | Feature'lar | Öncelik | Durum |
|----------|-----------|---------|-------|
| Sketch-based | ~~Groove~~ | ~~YÜKSEK~~ | ✅ TAMAMLANDI |
| Sketch-based | Loft, Pipe/Sweep, Helix, Hole | ORTA | Bekliyor (complex multi-profile) |
| Dress-up | ~~3D Fillet, 3D Chamfer~~ (UseAllEdges) | ~~YÜKSEK~~ | ✅ TAMAMLANDI |
| Dress-up | Draft, Thickness | ORTA | Bekliyor |
| Pattern | ~~LinearPattern, PolarPattern, Mirror~~ | ~~ORTA~~ | ✅ TAMAMLANDI |
| Pattern | MultiTransform | DÜŞÜK | Bekliyor |
| Primitive | ~~Box, Cylinder, Sphere, Cone~~ | ~~ORTA~~ | ✅ TAMAMLANDI |
| Primitive | Torus, Prism, Wedge, Ellipsoid | DÜŞÜK | Bekliyor |
| Boolean | ~~Union, Cut, Common~~ | ~~YÜKSEK~~ | ✅ TAMAMLANDI |
| Datum | Plane, Line, Point, CoordinateSystem | ORTA | Bekliyor |
| Binder | ShapeBinder, SubShapeBinder | DÜŞÜK | Bekliyor |

**File I/O:**
- ~~Import STEP/IGES/BREP~~ ✅ TAMAMLANDI (TopoShape API)

#### B. Frontend Eksikleri (QML UI)

**SketchToolbar — tüm butonlar aktif:** ✅
- ~~Polyline, Ellipse, Spline, Offset, Mirror, Extend — hepsi disabled~~ → Tümü enable ve işlevsel

**PartToolbar — bağlantısız butonlar:**
- Fillet3D, Chamfer3D, Draft, Thickness — UI'da buton var ama backend yok
- LinearPattern, PolarPattern, Mirror — buton var, backend stub
- Box, Cylinder, Sphere, Cone, Torus, Prism, Wedge — buton var, backend yok
- Boolean (Union, Cut, Common) — buton var, backend yok

**ConstraintPanel:**
- Constraint tipi ikonu yok (MilCAD'de her constraint tipinin küçük Canvas ikonu var)
- Constraint filtreleme yok

**Viewport:**
- Sketch geometrisi sadece QML Canvas'ta render ediliyor, OCCT'de wireframe yok (sketch edit sırasında)
- 3D shape render sadece closeSketch sonrası
- Edge/face selection yok (3D fillet/chamfer için gerekli)

#### C. PartDesign Type Registration (BLOCKER)
- `PartDesign::Body::init()` çağrılamıyor (Python module import zinciri crash)
- Pad/Pocket/Revolution Part::Extrusion fallback ile çalışıyor
- Gerçek Body/Tip parametric chain yok

---

## Öncelik Sırası (Session İçin)

### Faz 1: Backend Tamamlama — Sketch ✅ TAMAMLANDI
1. ~~**Ellipse + BSpline geometri**~~ ✅
2. ~~**Construction toggle**~~ ✅
3. ~~**Eksik constraint tipleri**~~ ✅ (DistanceX/Y, Diameter, Symmetric, PointOnObject)
4. ~~**Extend + Split + Chamfer tools**~~ ✅
5. ~~**Polyline tool**~~ ✅

### Faz 2: Backend Tamamlama — PartDesign ✅ TAMAMLANDI
6. ~~**PartDesign type registration**~~ → workaround: direct instantiation + Part fallback ✅
7. ~~**3D Fillet/Chamfer**~~ → UseAllEdges mode ✅
8. ~~**Boolean operations**~~ → Part::Fuse/Cut/Common ✅
9. ~~**LinearPattern/PolarPattern/Mirror**~~ → PartDesign::Transformed ✅
10. ~~**Groove**~~ → PartDesign::Groove + Part::Revolution fallback ✅
11. ~~**Primitives**~~ → Part::Box/Cylinder/Sphere/Cone ✅

### Faz 3: File I/O ✅ TAMAMLANDI
12. ~~**Import STEP/IGES/BREP**~~ → CadDocument::importFrom() + UI open dialog routing ✅

### Faz 4: UI Polishing ✅ TAMAMLANDI
13. ~~**Toolbar butonlarını enable et**~~ ✅
14. ~~**Constraint ikonu**~~ → ConstraintPanel'de SVG ikonları ✅
15. **Feature editing** → ModelTree çift tıkla → parametreleri düzenle (gelecek session)

---

## Teknik Notlar

### PartDesign Type Registration Sorunu
`addObject("PartDesign::Body")` çalışmıyor çünkü `PartDesign::Body::init()` hiç çağrılmamış.
- `Base::Type::fromName("Part::Feature")` bile BAD dönüyor AMA `addObject("Sketcher::SketchObject")` çalışıyor
- FreeCAD muhtemelen addObject içinde lazy module loading yapıyor
- `PyImport_ImportModule("_PartDesign")` çağrıldığında `App::Application::destruct()` sırasında `Base::PyException` fırlatılıyor → `std::terminate`
- **Araştırma hipotezi**: `App::Application::init(argc, argv)` FreeCAD home/data path bulamayınca Python scriptleri çalıştıramıyor

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
- Her yeni adapter fonksiyona try-catch ekle (FreeCAD exception crash koruması)
