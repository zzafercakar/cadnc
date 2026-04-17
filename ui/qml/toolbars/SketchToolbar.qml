import QtQuick
import QtQuick.Layouts
import "../components"

Rectangle {
    id: toolbar
    height: 48

    property string activeTool: ""
    property int selectedGeo: -1

    signal toolSelected(string tool)
    signal constraintRequested(string type)
    signal dimensionRequested()
    signal exitSketch()

    gradient: Gradient {
        GradientStop { position: 0.0; color: "#F0F4F8" }
        GradientStop { position: 0.4; color: "#E8ECF2" }
        GradientStop { position: 1.0; color: "#DDE3EA" }
    }
    border.width: 1; border.color: "#B0B8C4"

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10; anchors.rightMargin: 10
        spacing: 4

        CadToolButton { iconPath: "qrc:/resources/icons/sketch/exit_sketch.svg"; tipText: "Close Sketch"; accentColor: "#16A34A"; activeColor: "#15803D"; isActive: true; onClicked: exitSketch() }

        Rectangle { width: 1; height: 32; color: "#CBD5E1" }

        // Draw
        CadToolButton { iconPath: "qrc:/resources/icons/sketch/line.svg"; tipText: "Line (L)"; isActive: activeTool === "line"; activeColor: "#34D399"; onClicked: toolSelected("line") }
        CadToolButton { iconPath: "qrc:/resources/icons/sketch/circle.svg"; tipText: "Circle (C)"; isActive: activeTool === "circle"; activeColor: "#34D399"; onClicked: toolSelected("circle") }
        CadToolButton { iconPath: "qrc:/resources/icons/sketch/arc.svg"; tipText: "Arc (A)"; isActive: activeTool === "arc"; activeColor: "#34D399"; onClicked: toolSelected("arc") }
        CadToolButton { iconPath: "qrc:/resources/icons/sketch/rect.svg"; tipText: "Rectangle (R)"; isActive: activeTool === "rectangle"; activeColor: "#34D399"; onClicked: toolSelected("rectangle") }
        CadToolButton { iconPath: "qrc:/resources/icons/sketch/polyline.svg"; tipText: "Polyline (not implemented)"; isDisabled: true; activeColor: "#34D399" }
        CadToolButton { iconPath: "qrc:/resources/icons/sketch/ellipse.svg"; tipText: "Ellipse (not implemented)"; isDisabled: true; activeColor: "#34D399" }
        CadToolButton { iconPath: "qrc:/resources/icons/sketch/spline.svg"; tipText: "Spline (not implemented)"; isDisabled: true; activeColor: "#34D399" }
        CadToolButton { iconPath: "qrc:/resources/icons/sketch/point.svg"; tipText: "Point"; isActive: activeTool === "point"; activeColor: "#34D399"; onClicked: toolSelected("point") }

        Rectangle { width: 1; height: 32; color: "#CBD5E1" }

        // Modify
        CadToolButton { iconPath: "qrc:/resources/icons/sketch/trim.svg"; tipText: "Trim (T)"; isActive: activeTool === "trim"; accentColor: "#D97706"; activeColor: "#FBBF24"; onClicked: toolSelected("trim") }
        CadToolButton { iconPath: "qrc:/resources/icons/sketch/offset.svg"; tipText: "Offset (not implemented)"; isDisabled: true; accentColor: "#D97706" }
        CadToolButton { iconPath: "qrc:/resources/icons/sketch/mirror.svg"; tipText: "Mirror (not implemented)"; isDisabled: true; accentColor: "#D97706" }
        CadToolButton { iconPath: "qrc:/resources/icons/sketch/fillet.svg"; tipText: "Fillet (F)"; isActive: activeTool === "fillet"; accentColor: "#D97706"; activeColor: "#FBBF24"; onClicked: toolSelected("fillet") }
        CadToolButton { iconPath: "qrc:/resources/icons/sketch/chamfer.svg"; tipText: "Chamfer (uses fillet)"; isActive: activeTool === "chamfer"; accentColor: "#D97706"; activeColor: "#FBBF24"; onClicked: toolSelected("chamfer") }
        CadToolButton { iconPath: "qrc:/resources/icons/sketch/extend.svg"; tipText: "Extend (not implemented)"; isDisabled: true; accentColor: "#D97706" }

        Rectangle { width: 1; height: 32; color: "#CBD5E1" }

        // Constraints
        CadToolButton { iconPath: "qrc:/resources/icons/constraint/coincident.svg"; tipText: "Coincident"; accentColor: "#7C3AED"; onClicked: constraintRequested("coincident") }
        CadToolButton { iconPath: "qrc:/resources/icons/constraint/horiz.svg"; tipText: "Horizontal (H)"; accentColor: "#7C3AED"; onClicked: constraintRequested("horizontal") }
        CadToolButton { iconPath: "qrc:/resources/icons/constraint/vert.svg"; tipText: "Vertical (V)"; accentColor: "#7C3AED"; onClicked: constraintRequested("vertical") }
        CadToolButton { iconPath: "qrc:/resources/icons/constraint/parallel.svg"; tipText: "Parallel"; accentColor: "#7C3AED"; onClicked: constraintRequested("parallel") }
        CadToolButton { iconPath: "qrc:/resources/icons/constraint/perp.svg"; tipText: "Perpendicular"; accentColor: "#7C3AED"; onClicked: constraintRequested("perpendicular") }
        CadToolButton { iconPath: "qrc:/resources/icons/constraint/tangent.svg"; tipText: "Tangent"; accentColor: "#7C3AED"; onClicked: constraintRequested("tangent") }
        CadToolButton { iconPath: "qrc:/resources/icons/constraint/equal.svg"; tipText: "Equal"; accentColor: "#7C3AED"; onClicked: constraintRequested("equal") }
        CadToolButton { iconPath: "qrc:/resources/icons/constraint/fixed.svg"; tipText: "Fixed"; accentColor: "#7C3AED"; onClicked: constraintRequested("fixed") }
        CadToolButton { iconPath: "qrc:/resources/icons/constraint/distance.svg"; tipText: "Distance (D)"; accentColor: "#7C3AED"; onClicked: constraintRequested("distance") }
        CadToolButton { iconPath: "qrc:/resources/icons/constraint/angle.svg"; tipText: "Angle"; accentColor: "#7C3AED"; onClicked: constraintRequested("angle") }
        CadToolButton { iconPath: "qrc:/resources/icons/constraint/radius.svg"; tipText: "Radius"; accentColor: "#7C3AED"; onClicked: constraintRequested("radius") }

        Item { Layout.fillWidth: true }

        // Solver badge — compact, ellipsis if space is tight
        Rectangle {
            Layout.minimumWidth: 60
            Layout.maximumWidth: statusLabel.implicitWidth + 16
            Layout.preferredWidth: statusLabel.implicitWidth + 16
            height: 24; radius: 12
            color: cadEngine.solverStatus === "Fully Constrained" ? "#ECFDF5" : "#FEF3C7"
            border.width: 1; border.color: cadEngine.solverStatus === "Fully Constrained" ? "#86EFAC" : "#FDE68A"
            clip: true
            Text { id: statusLabel; anchors.centerIn: parent; text: cadEngine.solverStatus; font.pixelSize: 11; font.bold: true
                   color: cadEngine.solverStatus === "Fully Constrained" ? "#15803D" : "#92400E"
                   elide: Text.ElideRight; width: parent.width - 12 }
        }
    }
}
