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
    readonly property color ftSketch:    "#059669"
    readonly property color ftPad:       "#16A34A"
    readonly property color ftPocket:    "#DC2626"
    readonly property color ftRevolution:"#2563EB"
    readonly property color ftFillet:    "#7C3AED"
    readonly property color ftChamfer:   "#7C3AED"
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
        if (typeName.indexOf("Sketch") >= 0) return ftSketch
        if (typeName.indexOf("Pad") >= 0) return ftPad
        if (typeName.indexOf("Pocket") >= 0) return ftPocket
        if (typeName.indexOf("Revolution") >= 0) return ftRevolution
        if (typeName.indexOf("Fillet") >= 0) return ftFillet
        if (typeName.indexOf("Chamfer") >= 0) return ftChamfer
        return ftDefault
    }

    function featureIcon(typeName) {
        if (typeName.indexOf("Sketch") >= 0) return "\u270E"
        if (typeName.indexOf("Pad") >= 0) return "\u2B06"
        if (typeName.indexOf("Pocket") >= 0) return "\u2B07"
        if (typeName.indexOf("Revolution") >= 0) return "\u27F3"
        if (typeName.indexOf("Fillet") >= 0) return "\u25CF"
        if (typeName.indexOf("Chamfer") >= 0) return "\u25C6"
        return "\u25A0"
    }

    function shortTypeName(typeName) {
        if (typeName.indexOf("::") >= 0)
            return typeName.split("::").pop()
        return typeName
    }
}
