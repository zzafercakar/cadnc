# CADNC — Sonraki Session: FreeCAD Tam Entegrasyon

## Hedef
FreeCAD'in Sketcher ve PartDesign modüllerindeki TÜM araç, fonksiyon ve yetenekleri hem backend (adapter) hem frontend (QML UI) olarak CADNC'ye entegre et.

## Mevcut Durum Özeti (2026-04-17)

### Çalışan
- **Sketch geometri**: Line, Circle, Arc, Rectangle, Point — çizim + solver + render
- **Sketch constraint**: Coincident, Horizontal, Vertical, Parallel, Perpendicular, Tangent, Equal, Distance, Radius, Angle, Fixed — 11/21 constraint tipi
- **Sketch tools**: Trim, Fillet — 2/16 tool
- **Part features**: Pad, Pocket, Revolution — 3/8 sketch-based feature (Part::Extrusion fallback)
- **File I/O**: FCStd save/load, STEP/IGES/STL/BREP export
- **UI**: SketchCanvas (grid, axes, geometry render, preview, snap, inference, zoom/pan), ModelTree (delete/rename), ConstraintPanel (datum edit, driving toggle)
- **Viewport**: OCCT V3d + ViewCube + grid (closeSketch sonrası shape gösterimi)

### KRİTİK EKSİKLER

#### A. Backend Eksikleri (adapter/SketchFacade + PartFacade)

**Sketch Geometri (6 eksik):**
| Geometri | FreeCAD Sınıfı | Öncelik |
|----------|---------------|---------|
| Ellipse | GeomEllipse | YÜKSEK |
| ArcOfEllipse | GeomArcOfEllipse | ORTA |
| BSpline | GeomBSplineCurve | YÜKSEK |
| Polyline | (addLine zinciri) | YÜKSEK |
| Construction toggle | toggleConstruction() | YÜKSEK |
| Offset curve | GeomOffsetCurve | DÜŞÜK |

**Sketch Constraint (10 eksik CadEngine methodu):**
| Constraint | Durum |
|-----------|-------|
| DistanceX | Facade'de var, CadEngine'de yok |
| DistanceY | Facade'de var, CadEngine'de yok |
| Diameter | Facade'de var, CadEngine'de yok |
| Symmetric | Facade'de var, CadEngine'de yok |
| PointOnObject | Facade'de var, CadEngine'de yok |
| InternalAlignment | Tamamen eksik |

**Sketch Tools (14 eksik):**
| Tool | FreeCAD Methodu | Öncelik |
|------|----------------|---------|
| Extend | extend() | YÜKSEK |
| Split | split() | YÜKSEK |
| Chamfer (gerçek) | fillet(...,chamfer=true) | YÜKSEK |
| Mirror copy | addSymmetric() | ORTA |
| Array copy | addCopy() | ORTA |
| Move geometry | moveGeometry() | ORTA |
| Construction toggle | toggleConstruction() | YÜKSEK |
| Carbon copy | carbonCopy() | DÜŞÜK |
| External geometry | addExternal() | ORTA |
| Convert to NURBS | convertToNURBS() | DÜŞÜK |

**PartDesign Features (20+ eksik):**
| Kategori | Feature'lar | Öncelik |
|----------|-----------|---------|
| Sketch-based | Groove, Loft, Pipe/Sweep, Helix, Hole | YÜKSEK |
| Dress-up | 3D Fillet, 3D Chamfer, Draft, Thickness | YÜKSEK |
| Pattern | LinearPattern, PolarPattern, Mirror, MultiTransform | ORTA |
| Primitive | Box, Cylinder, Sphere, Cone, Torus, Prism, Wedge, Ellipsoid | ORTA |
| Boolean | Union, Cut, Common | YÜKSEK |
| Datum | Plane, Line, Point, CoordinateSystem | ORTA |
| Binder | ShapeBinder, SubShapeBinder | DÜŞÜK |

**File I/O (3 eksik):**
- Import STEP/IGES/BREP (sadece FCStd load var)

#### B. Frontend Eksikleri (QML UI)

**SketchToolbar — stub butonlar (pasifleştirilmiş):**
- Polyline, Ellipse, Spline, Offset, Mirror, Extend — hepsi disabled

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

### Faz 1: Backend Tamamlama — Sketch
1. **Ellipse + BSpline geometri** → SketchFacade + CadEngine + SketchCanvas render
2. **Construction toggle** → SketchFacade.toggleConstruction + UI toggle
3. **Eksik constraint tipleri** → DistanceX/Y, Diameter, Symmetric, PointOnObject CadEngine'e
4. **Extend + Split tools** → SketchFacade + CadEngine + toolbar enable
5. **Polyline tool** → SketchCanvas multi-point line chain

### Faz 2: Backend Tamamlama — PartDesign  
6. **PartDesign type registration çöz** → Body/Tip chain
7. **3D Fillet/Chamfer** → edge selection + PartFacade implement + CadEngine wire
8. **Boolean operations** → Union/Cut/Common
9. **LinearPattern/PolarPattern/Mirror** → CadEngine wire (PartFacade stub'lar var)
10. **Groove, Loft, Pipe, Helix** → PartFacade + CadEngine + FeatureDialog

### Faz 3: File I/O
11. **Import STEP/IGES/BREP** → CadDocument.importFrom() + UI open dialog

### Faz 4: UI Polishing
12. **Toolbar butonlarını enable et** — backend hazır olanları aç
13. **Constraint ikonu** → ConstraintPanel'de MilCAD tarzı küçük Canvas ikonları
14. **Feature editing** → ModelTree'de çift tıkla → parametreleri düzenle dialog

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
