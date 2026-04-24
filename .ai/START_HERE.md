# CADNC — Start Here

> Bu dosyayi HER oturum basinda oku. Sonra context.yaml, WORKPLAN.md ve ENGINEERING_LOG.md'yi oku.

## Proje Nedir?

CADNC, **FreeCAD'in cekirdek modullerini** (Sketcher, Part, PartDesign) CAD backend olarak kullanan,
**modern QML arayuzlu** bir masaustu CAD-CAM uygulamasidir. Geometri cekirdegi **OpenCASCADE (OCCT)**.

Onceki proje MilCAD'de sketch constraint, trim, fillet, chamfer, smart dimension konularinda
ilerleme zorlasti. FreeCAD bu alanlarda 15+ yillik olgunluga sahip — yeniden icat etmek yerine
kullanmak karari alindi.

## Mimari

```
┌──────────────────────────────────────────────────────┐
│  UI Shell (QML)                                      │
│  ui/qml/Main.qml, toolbars, panels                   │
├──────────────────────────────────────────────────────┤
│  Adapter Layer (C++)                                 │
│  adapter/inc/ — CadSession, CadDocument,             │
│                  SketchFacade, PartFacade             │
├──────────────────────────────────────────────────────┤
│  FreeCAD Modules (LGPL)                              │
│  freecad/Base, freecad/App,                          │
│  freecad/Mod/Part/App, Sketcher/App, PartDesign/App  │
├──────────────────────────────────────────────────────┤
│  OpenCASCADE (OCCT) Kernel                           │
└──────────────────────────────────────────────────────┘

Yan moduller (proprietary):
  cam/     — G-Code generation, toolpath, CODESYS post-processor
  nesting/ — Sheet nesting (BLF, BBox)
```

## Kritik Kurallar (ASLA IHLAL ETME)

1. **UI kodu FreeCAD header'i include etmemeli** — sadece adapter/ uzerinden
2. **AIS_InteractiveContext islemleri SADECE render thread'de** — UI thread'den cagirilmamali
3. **Linux'ta EGL KULLANILMAMALI** — OCCT GLX ile derlenmis
4. **FreeCAD modullerinde minimum degisiklik** — upstream uyumlulugu icin
5. **Python bagimliligi kabul edildi** — cikarilmayacak

## Dizin Yapisi

```
CADNC/
├── freecad/          # FreeCAD backend (Base, App, Part, Sketcher, PartDesign, 3rdParty)
├── adapter/          # Facade katmani (CADNC API)
│   ├── inc/          # CadSession.h, CadDocument.h, SketchFacade.h, PartFacade.h
│   └── src/          # Implementasyonlar
├── cam/              # CAM modulu (MilCAD'den)
├── nesting/          # Nesting modulu (MilCAD'den)
├── util/             # Yardimci fonksiyonlar
├── ui/               # QML UI shell
│   └── qml/          # Main.qml, toolbarlar, paneller
├── viewport/         # 3D viewport (henuz bos — Faz 5)
├── app/              # main.cpp entry point
├── resources/        # 92 SVG ikon, gorseller, logolar
├── tests/            # Unit testler
├── .ai/              # AI context (BU DOSYALAR)
└── doc/              # ARCHITECTURE.md, PRD.md, PDF referanslar
```

## Build & Run

```bash
# Configure
cmake -B build -S .

# Build
cmake --build build -j$(nproc)

# Run (Linux)
DISPLAY=:0 QT_QPA_PLATFORM=xcb ./build/cadnc

# Test
ctest --test-dir build --output-on-failure
```

## Mevcut Durum (2026-04-12)

- **Faz 0 TAMAMLANDI:** Proje iskeleti, FreeCAD modulleri kopyalandi, repo kuruldu
- **Faz 1 SIRADAKI:** FreeCAD modullerinin CMake entegrasyonu ve derlenmesi
- Adapter: skeleton (sadece TODO'lar)
- UI: minimal shell (placeholder viewport)
- CAM/Nesting: MilCAD'den tasindi, adapter entegrasyonu bekliyor
- Viewport: henuz olusturulmadi

## Gelistirme Fazlari Ozeti

| Faz | Konu | Durum |
|-----|------|-------|
| 0 | Proje iskeleti | TAMAMLANDI |
| 1 | FreeCAD build entegrasyonu | SIRADAKI |
| 2 | Adapter katmani implementasyonu | Bekliyor |
| 3 | Kritik sketch islemleri (trim, fillet, chamfer, dimension) | Bekliyor |
| 4 | 3D feature zinciri (pad, pocket, revolution, fillet3D) | Bekliyor |
| 5 | Viewport ve rendering | Bekliyor |
| 6 | CAM/Nesting entegrasyonu | Bekliyor |
| 7 | UI modernizasyonu | Bekliyor |

## Referans Kaynaklar

- **FreeCAD kaynak:** `/home/embed/Downloads/FreeCAD-main-1-1-git/`
- **MilCAD:** `/home/embed/Dev/MilCAD/` (onceki proje)
- **LibreCAD:** `/home/embed/Downloads/LibreCAD-master/` (2D CAD referansi)
- **SolveSpace:** `/home/embed/Downloads/solvespace-master/` (constraint solver ref)
- **Luban:** `/home/embed/Downloads/Luban-main/` (NFP nesting referansi)

Detayli dosya yollari icin: `.ai/REFERENCE_SOURCES.md`

## Iletisim

- Kod ve yorumlar: English
- Kullanici iletisimi: Turkish
