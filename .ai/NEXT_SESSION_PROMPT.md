# CADNC — Sonraki Session Prompt

Aşağıdaki metni kopyala-yapıştır ile yeni session'a yapıştır:

---

Bu proje CADNC — FreeCAD'in çekirdek modüllerini (Sketcher, Part, PartDesign) CAD backend olarak kullanan, modern QML arayüzlü bir CAD-CAM uygulaması.

Öncelikle şu dosyaları oku ve proje hakkında tam bilgi edin:

- `.ai/START_HERE.md` — mimari ve kritik kurallar
- `.ai/context.yaml` — proje durumu, tech stack, modül yapısı
- `.ai/WORKPLAN.md` — detaylı geliştirme planı ve fazlar
- `.ai/ENGINEERING_LOG.md` — kararlar ve MilCAD'den öğrenilenler
- `CLAUDE.md` — Claude Code için proje talimatları

## Proje Durumu (2026-04-15)

**Tamamlanan Fazlar:**
- **Faz 0:** Proje iskeleti kuruldu
- **Faz 1:** FreeCAD 6 modül derleniyor (Base, App, Materials, Part, Sketcher, PartDesign — toplam ~83MB)
- **Faz 2:** Adapter katmanı çalışıyor (CadSession, CadDocument, SketchFacade, PartFacade, CadEngine QML bridge)
- **Faz 3:** UI shell hazır (MilCAD-tarzı toolbar'lar, 4 workbench, ModelTree, ConstraintPanel, SketchCanvas, StatusBar)

**Sıradaki Faz: Faz 4 — 3D Feature Zinciri**

Hedefler:
1. **Pad dialog** — sketch seçip pad length girişi, PartFacade.pad() çağrısı
2. **Pocket dialog** — benzer şekilde pocket oluşturma
3. **Revolution dialog** — açı girişiyle revolution
4. **Feature tree senkronizasyonu** — recompute sonrası featureTree güncelleme
5. **Undo/Redo** — UI'da tam çalışır undo/redo

**Sonrasında Faz 5 — OCCT Viewport (EN KRİTİK):**
- V3d_Viewer + QQuickFramebufferObject entegrasyonu
- AIS_ViewCube (native NavCube — QML replica'yı değiştirecek)
- AIS_Shape rendering (TopoDS_Shape görüntüleme)
- Selection, grid, snap, view presets

## Build & Run

```bash
cmake -B build -S . -DCADNC_ENABLE_FREECAD_BACKEND=ON
cmake --build build -j$(nproc)
# Run app
cd build && DISPLAY=:0 QT_QPA_PLATFORM=xcb LD_LIBRARY_PATH=lib:$LD_LIBRARY_PATH ./cadnc
# Run PoC test
cd build && LD_LIBRARY_PATH=lib:$LD_LIBRARY_PATH ./bin/poc_freecad_test
# Run adapter test
cd build && LD_LIBRARY_PATH=lib:$LD_LIBRARY_PATH ./bin/test_adapter
```

## Referans Kaynaklar
- MilCAD QML: `/home/embed/Dev/MilCAD/qml/` (özellikle Main.qml 3488 satır, tüm toolbar/panel dosyaları)
- FreeCAD kaynak: `/home/embed/Downloads/FreeCAD-main-1-1/src/`
- MilCAD viewport: `/home/embed/Dev/MilCAD/viewport/` (OCCT QQuickFramebufferObject entegrasyonu)

## Önemli Notlar
- UI kodu FreeCAD header'ı include etmemeli — sadece adapter/ üzerinden
- AIS_InteractiveContext işlemleri SADECE render thread'de — UI thread'den asla
- OCCT kütüphaneleri tek tek listelenmeli, ${OpenCASCADE_LIBRARIES} değil
- NavCube şu an QML replica — Faz 5'te OCCT AIS_ViewCube ile değiştirilecek
- Python bağımlılığı kabul edildi
- C++20 gerekli (FreeCAD 1.2)
