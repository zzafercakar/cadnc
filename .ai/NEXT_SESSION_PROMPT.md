# CADNC — Ilk Oturum Prompt'u

Asagidaki metni yeni workspace'te ilk mesaj olarak kullan:

---

Bu proje CADNC — FreeCAD'in cekirdek modullerini (Sketcher, Part, PartDesign) CAD backend olarak kullanan, modern QML arayuzlu bir CAD-CAM uygulamasi.

Oncelikle su dosyalari oku ve proje hakkinda tam bilgi edin:
1. `.ai/START_HERE.md` — mimari ve kritik kurallar
2. `.ai/context.yaml` — proje durumu, tech stack, modul yapisi
3. `.ai/WORKPLAN.md` — detayli gelistirme plani ve fazlar
4. `.ai/ENGINEERING_LOG.md` — kararlar ve MilCAD'den ogrenilen dersler
5. `.ai/REFERENCE_SOURCES.md` — tum kaynak dosya yollari (FreeCAD, MilCAD, LibreCAD, SolveSpace)
6. `CLAUDE.md` — Claude Code icin proje talimatlari

Proje durumu:
- Faz 0 TAMAMLANDI: Proje iskeleti kuruldu, FreeCAD modulleri kopyalandi (Base, App, Part/App, Sketcher/App, PartDesign/App), MilCAD'den CAM/nesting/ikonlar tasindi
- Faz 1 SIRADAKI: FreeCAD modullerinin CMake build entegrasyonu

Siradaki gorev: Faz 1'e basla — freecad/CMakeLists.txt dosyasini yazarak FreeCAD Base, App, Part, Sketcher ve PartDesign modullerini sirayla derleyebilecek CMake konfigurasyonunu olustur. Ilk hedef: FreeCADBase kutuphanesini basariyla derlemek.

FreeCAD kaynaklari zaten freecad/ dizininde. Orijinal FreeCAD CMake dosyalari referans olarak /home/embed/Downloads/FreeCAD-main-1-1/src/ altinda mevcut.

---
