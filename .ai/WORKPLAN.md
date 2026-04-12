# CADNC Work Plan

## Faz 0: Proje Iskeleti (Current)
- [x] Klasor yapisi olustur
- [x] FreeCAD modullerini kopyala (Base, App, Part, Sketcher, PartDesign)
- [x] MilCAD varliklarini tasi (CAM, nesting, util, ikonlar)
- [x] Yeni dosyalari olustur (CMake, adapter, UI shell, main.cpp)
- [x] Git repo kur ve GitHub'a bagla

## Faz 1: FreeCAD Build Entegrasyonu
- [ ] freecad/CMakeLists.txt yaz (Base, App, Part, Sketcher, PartDesign derleme)
- [ ] Python binding'leri test et
- [ ] FreeCAD modullerini basariyla derle
- [ ] Basit PoC: FreeCAD document olustur, sketch ekle, shape al

## Faz 2: Adapter Katmani
- [ ] CadSession: FreeCAD App initialization
- [ ] CadDocument: Document create/save/load
- [ ] SketchFacade: SketchObject wrapper
- [ ] PartFacade: PartDesign feature wrapper
- [ ] SelectionFacade: Selection model
- [ ] PropertyFacade: Property binding for QML

## Faz 3: Kritik Sketch Islemleri
- [ ] Line, Circle, Arc cizimi
- [ ] Smart Dimension (driving/driven)
- [ ] Trim
- [ ] Fillet (2D)
- [ ] Chamfer (2D)
- [ ] Constraint goruntuleme

## Faz 4: 3D Feature Zinciri
- [ ] Pad (extrude)
- [ ] Pocket
- [ ] Revolution
- [ ] 3D Fillet
- [ ] 3D Chamfer
- [ ] Feature tree senkronizasyonu

## Faz 5: Viewport ve Rendering
- [ ] OCCT viewer entegrasyonu
- [ ] Selection highlighting
- [ ] Grid ve snap sistemi
- [ ] Sketch mode rendering

## Faz 6: CAM/Nesting Entegrasyonu
- [ ] CAM adapter (geometry source baglantisi)
- [ ] Nesting adapter (profile import baglantisi)
- [ ] G-Code generation test

## Faz 7: UI Modernizasyonu
- [ ] Toolbar ve panel tasarimi
- [ ] Theme sistemi
- [ ] Keyboard shortcut sistemi
- [ ] User preferences
