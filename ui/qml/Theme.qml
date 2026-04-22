pragma Singleton
import QtQuick

/**
 * Theme — Centralized theme system for CADNC.
 * All colors, fonts, spacing, and sizing tokens live here.
 * Switch between light and dark mode via isDark property.
 *
 * Usage: Theme.bg, Theme.panel, Theme.accent, etc.
 */
QtObject {
    id: theme

    // ── Mode Toggle ────────────────────────────────────────────────
    property bool isDark: false

    // ── Surface Colors ─────────────────────────────────────────────
    readonly property color bg:          isDark ? "#1A1D23" : "#EBEEF3"
    readonly property color panel:       isDark ? "#22252B" : "#FFFFFF"
    readonly property color panelAlt:    isDark ? "#282B33" : "#F8FAFC"
    readonly property color toolbar:     isDark ? "#1E2128" : "#F4F5F8"
    readonly property color toolbarAlt:  isDark ? "#252830" : "#EDF1F7"
    readonly property color surface:     isDark ? "#2A2D35" : "#FFFFFF"
    readonly property color surfaceAlt:  isDark ? "#30333B" : "#F9FAFB"
    readonly property color viewport:    isDark ? "#2C2F38" : "#E8EAF0"

    // ── Border & Divider ───────────────────────────────────────────
    readonly property color border:      isDark ? "#3A3D45" : "#C8CDD6"
    readonly property color borderLight: isDark ? "#33363E" : "#E2E8F0"
    readonly property color divider:     isDark ? "#2E3139" : "#F3F4F6"

    // ── Text Colors ────────────────────────────────────────────────
    readonly property color text:        isDark ? "#E8EAED" : "#111827"
    readonly property color textSec:     isDark ? "#9CA3AF" : "#4B5563"
    readonly property color textTer:     isDark ? "#6B7280" : "#9CA3AF"
    readonly property color textInverse: isDark ? "#111827" : "#FFFFFF"

    // ── Primary Accent ─────────────────────────────────────────────
    readonly property color accent:      "#2563EB"
    readonly property color accentLight: isDark ? "#1E3A5F" : "#DBEAFE"
    readonly property color accentHover: isDark ? "#3B82F6" : "#1D4ED8"
    readonly property color accentText:  "#FFFFFF"

    // ── Semantic Colors ────────────────────────────────────────────
    readonly property color success:     "#16A34A"
    readonly property color successBg:   isDark ? "#14532D" : "#ECFDF5"
    readonly property color warning:     "#D97706"
    readonly property color warningBg:   isDark ? "#713F12" : "#FEF3C7"
    readonly property color danger:      "#DC2626"
    readonly property color dangerBg:    isDark ? "#7F1D1D" : "#FEF2F2"
    readonly property color info:        "#2563EB"
    readonly property color infoBg:      isDark ? "#1E3A5F" : "#EFF6FF"

    // ── Workbench Colors ───────────────────────────────────────────
    readonly property color wbPart:      "#2563EB"
    readonly property color wbSketch:    "#059669"
    readonly property color wbCam:       "#D97706"
    readonly property color wbNesting:   "#7C3AED"

    // ── Feature Type Colors ────────────────────────────────────────
    readonly property color ftSketch:    "#059669"   // teal — 2D profile
    readonly property color ftPad:       "#16A34A"   // green — additive
    readonly property color ftPocket:    "#DC2626"   // red — subtractive
    readonly property color ftRevolution:"#2563EB"   // blue — rotational
    readonly property color ftGroove:    "#F97316"   // orange — rotational-cut
    readonly property color ftFillet:    "#7C3AED"   // purple — dress-up
    readonly property color ftChamfer:   "#DB2777"   // pink — dress-up
    readonly property color ftBody:      "#1E40AF"   // deep blue — container
    readonly property color ftOrigin:    "#6B7280"   // neutral grey — origin group
    readonly property color ftPlane:     "#F59E0B"   // amber — datum plane
    readonly property color ftLine:      "#10B981"   // emerald — datum line
    readonly property color ftPoint:     "#8B5CF6"   // violet — datum point
    // Axis-specific colors to match the canvas/viewport gizmo (X=red,
    // Y=green, Z=blue). `featureColor` returns these for the three
    // App::Line children of Origin so the tree matches what the user
    // sees on the canvas.
    readonly property color ftAxisX:     "#DC2626"
    readonly property color ftAxisY:     "#16A34A"
    readonly property color ftAxisZ:     "#2563EB"
    // Plane-specific shades for the three base planes. Same hue scheme
    // but lighter so the amber reserved for user datum planes stands
    // out.
    readonly property color ftPlaneXY:   "#F59E0B"
    readonly property color ftPlaneXZ:   "#84CC16"
    readonly property color ftPlaneYZ:   "#0EA5E9"
    readonly property color ftPrimitive: "#0EA5E9"   // sky — box/cylinder/sphere
    readonly property color ftPattern:   "#EA580C"   // orange-red — pattern
    readonly property color ftBoolean:   "#0891B2"   // cyan — boolean ops
    readonly property color ftDefault:   "#64748B"

    // ── Sketch Canvas Colors ───────────────────────────────────────
    readonly property color skSelected:  "#F97316"
    readonly property color skGeo:       "#2563EB"
    readonly property color skPreview:   "#059669"
    readonly property color skGrid:      isDark ? "#3A3D45" : "#C8CDD6"
    readonly property color skAxisX:     "#F44336"
    readonly property color skAxisY:     "#4CAF50"
    readonly property color skConstruction: "#8B5CF6"

    // ── Constraint Colors ──────────────────────────────────────────
    readonly property color cstrDriving: "#7C3AED"
    readonly property color cstrRef:     "#9CA3AF"
    readonly property color cstrConflict:"#DC2626"

    // ── Interactive States ─────────────────────────────────────────
    readonly property color hover:       isDark ? "#353840" : "#E0E7FF"
    readonly property color pressed:     isDark ? "#3D4048" : "#C7D2FE"
    readonly property color selected:    isDark ? "#1E3A5F" : "#DBEAFE"
    readonly property color disabled:    isDark ? "#3A3D45" : "#E5E7EB"

    // ── Shadows ────────────────────────────────────────────────────
    readonly property color shadow:      isDark ? "#00000060" : "#0000001A"
    readonly property color shadowMed:   isDark ? "#00000080" : "#00000025"

    // ── Sizing ─────────────────────────────────────────────────────
    readonly property int headerH:       48
    readonly property int tabBarH:       40
    readonly property int toolbarH:      52
    readonly property int statusBarH:    26
    readonly property int panelW:        250
    readonly property int panelMinW:     180
    readonly property int btnSize:       36
    readonly property int btnIconSize:   20
    readonly property int radius:        8
    readonly property int radiusSm:      4
    readonly property int radiusLg:      12

    // ── Spacing ────────────────────────────────────────────────────
    readonly property int sp2: 2
    readonly property int sp4: 4
    readonly property int sp6: 6
    readonly property int sp8: 8
    readonly property int sp12: 12
    readonly property int sp16: 16

    // ── Typography ─────────────────────────────────────────────────
    readonly property int fontXs:   9
    readonly property int fontSm:   10
    readonly property int fontBase: 12
    readonly property int fontMd:   13
    readonly property int fontLg:   15
    readonly property int fontXl:   18
    readonly property string fontMono: "monospace"

    // ── Animation ──────────────────────────────────────────────────
    readonly property int animFast: 80
    readonly property int animNormal: 150
    readonly property int animSlow: 300

    // ── Helper Functions ───────────────────────────────────────────
    function featureColor(typeName) {
        // Container first — PartDesign::Body reaches both "Body" and
        // "BodyBase"; App::Origin is checked explicitly so it doesn't
        // match the "Origin" suffix some datum features carry.
        if (typeName === "PartDesign::Body" || typeName === "App::Part") return ftBody
        if (typeName === "App::Origin") return ftOrigin
        // App::Line under Origin is one of the three axes — we route by
        // the row's label in ModelTreePanel (via featureColorByLabel);
        // here we fall back to a generic emerald for anonymous lines.
        if (typeName === "App::Line"  || typeName === "PartDesign::Line")  return ftLine
        if (typeName === "App::Plane" || typeName === "PartDesign::Plane") return ftPlane
        if (typeName === "App::Point" || typeName === "PartDesign::Point") return ftPoint
        if (typeName.indexOf("Sketch") >= 0) return ftSketch
        if (typeName.indexOf("Groove") >= 0) return ftGroove
        if (typeName.indexOf("Pad") >= 0) return ftPad
        if (typeName.indexOf("Pocket") >= 0) return ftPocket
        if (typeName.indexOf("Revolution") >= 0) return ftRevolution
        if (typeName.indexOf("Fillet") >= 0) return ftFillet
        if (typeName.indexOf("Chamfer") >= 0) return ftChamfer
        if (typeName.indexOf("LinearPattern") >= 0 ||
            typeName.indexOf("PolarPattern") >= 0 ||
            typeName.indexOf("Mirrored") >= 0) return ftPattern
        if (typeName.indexOf("Fuse") >= 0 ||
            typeName.indexOf("Cut")  >= 0 ||
            typeName.indexOf("Common") >= 0) return ftBoolean
        if (typeName.indexOf("Box") >= 0 ||
            typeName.indexOf("Cylinder") >= 0 ||
            typeName.indexOf("Sphere") >= 0 ||
            typeName.indexOf("Cone") >= 0) return ftPrimitive
        return ftDefault
    }

    // Glyphs picked from Unicode block ranges that render on every major
    // platform without needing a special font. Each glyph visually hints
    // at the feature's operation (pad = up-arrow, pocket = down-arrow,
    // revolution = circular arrow, fillet = rounded corner, etc.).
    function featureIcon(typeName) {
        if (typeName === "PartDesign::Body") return "\u25A3"    // ▣ body container
        if (typeName === "App::Origin")       return "\u2316"   // ⌖ origin crosshair
        if (typeName === "App::Plane" || typeName === "PartDesign::Plane") return "\u25AD"   // ▭ plane
        if (typeName === "App::Line"  || typeName === "PartDesign::Line")  return "\u2015"   // ― line
        if (typeName === "App::Point" || typeName === "PartDesign::Point") return "\u25CF"   // ● point
        if (typeName.indexOf("Sketch") >= 0)     return "\u270E" // ✎ sketch
        if (typeName.indexOf("Groove") >= 0)     return "\u238B" // ⎋ cut-rotate
        if (typeName.indexOf("Pad") >= 0)        return "\u2B06" // ⬆ additive
        if (typeName.indexOf("Pocket") >= 0)     return "\u2B07" // ⬇ subtractive
        if (typeName.indexOf("Revolution") >= 0) return "\u27F3" // ⟳ rotational
        if (typeName.indexOf("Fillet") >= 0)     return "\u25D6" // ◖ round corner
        if (typeName.indexOf("Chamfer") >= 0)    return "\u25C6" // ◆ diamond
        if (typeName.indexOf("LinearPattern") >= 0) return "\u2630" // ☰ stacked
        if (typeName.indexOf("PolarPattern") >= 0)  return "\u273F" // ✿ radial
        if (typeName.indexOf("Mirrored") >= 0)   return "\u25D0" // ◐ half-fill
        if (typeName.indexOf("Fuse") >= 0)       return "\u29FE" // ⧾ plus boxed
        if (typeName.indexOf("Cut") >= 0)        return "\u2296" // ⊖ minus circled
        if (typeName.indexOf("Common") >= 0)     return "\u2229" // ∩ intersection
        if (typeName.indexOf("Box") >= 0)        return "\u25FC" // ◼ filled sq
        if (typeName.indexOf("Cylinder") >= 0)   return "\u25CB" // ○ circle
        if (typeName.indexOf("Sphere") >= 0)     return "\u2B24" // ⬤ filled circle
        if (typeName.indexOf("Cone") >= 0)       return "\u25B2" // ▲ triangle
        return "\u25A0"
    }

    // Label-aware color override for the axis/plane triple under Origin.
    // Same signature as featureColor but takes the row's label so the
    // tree can paint X-axis red, Y-axis green, Z-axis blue to match the
    // viewport gizmo.
    function featureColorByLabel(typeName, label) {
        var s = (label || "").toUpperCase()
        if (typeName === "App::Line" || typeName === "PartDesign::Line") {
            if (s.indexOf("X") === 0) return ftAxisX
            if (s.indexOf("Y") === 0) return ftAxisY
            if (s.indexOf("Z") === 0) return ftAxisZ
        }
        if (typeName === "App::Plane" || typeName === "PartDesign::Plane") {
            if (s.indexOf("XY") === 0) return ftPlaneXY
            if (s.indexOf("XZ") === 0) return ftPlaneXZ
            if (s.indexOf("YZ") === 0) return ftPlaneYZ
        }
        return featureColor(typeName)
    }

    // Label-aware icon for the same axis/plane triple. Uses ↔ ↕ ↨ for
    // X/Y/Z axes (horizontal / vertical / depth) and perspective-style
    // ◇ quadrilaterals for the three plane variants.
    function featureIconByLabel(typeName, label) {
        var s = (label || "").toUpperCase()
        if (typeName === "App::Line" || typeName === "PartDesign::Line") {
            if (s.indexOf("X") === 0) return "\u27A1"   // ➡ X-axis
            if (s.indexOf("Y") === 0) return "\u2B06"   // ⬆ Y-axis
            if (s.indexOf("Z") === 0) return "\u2B06"   // (Z shown with its own colour)
        }
        if (typeName === "App::Plane" || typeName === "PartDesign::Plane") {
            // ⬢ filled hexagon reads as a 3-D perspective quadrilateral
            // in the small 12px font size used in the tree.
            return "\u2B22"
        }
        return featureIcon(typeName)
    }

    function shortTypeName(typeName) {
        if (typeName.indexOf("::") >= 0)
            return typeName.split("::").pop()
        return typeName
    }
}
