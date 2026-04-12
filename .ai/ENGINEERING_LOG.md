# CADNC Engineering Log

## 2026-04-12: Project Creation

### Decision: FreeCAD Backend
- MilCAD'de sketch constraint migration, trim, fillet, chamfer, smart dimension
  konularinda ilerleme zorlasiyordu.
- Temel sebep: OCCT uzerinde kendi sketch/document/constraint/recompute altyapisini
  yazmak cok agir.
- Karar: FreeCAD'in App katmanlarini CAD backend olarak kullanmak.
- FreeCAD modullerinden sadece App katmanlari alinacak (GUI katmanlari haric).

### Architecture
- FreeCAD Base + App + Part/App + Sketcher/App + PartDesign/App
- OCCT kernel olarak kaliyor
- UI: yeni QML shell (MilCAD UI'dan bagimsiz)
- Adapter katmani: UI ile FreeCAD arasinda facade

### MilCAD'den Tasinanlar
- CAM module (25 header, 24 source) — G-Code, toolpath, post-processor
- Nesting module (6 header, 5 source) — BLF, bounding box
- 92 SVG ikon
- Utility fonksiyonlar
- Build konfigurasyonu (.clang-tidy, CMakePresets.json)

### MilCAD'den Tasinmayanlar (Emekli)
- Tum geometry/ modulu (SketchDocument, entities, constraints, tools)
- core/ modulu (SceneManager, OccRenderer, FeatureManager)
- viewport/ modulu (ViewerItem)
- input/ modulu (MouseHandler, KeyboardHandler)
- third_party/planegcs/ (FreeCAD kendi planegcs'ini tasiyor)
- Tum QML dosyalari (yeni shell sifirdan)

### Critical Note: Python Dependency
- FreeCAD modulleri Python3'e bagimli
- Her modulde 30-80+ PyImp dosyasi var
- Python binding'leri cikarmak cok buyuk is yuku
- Karar: Python bagimliligi kabul edildi
