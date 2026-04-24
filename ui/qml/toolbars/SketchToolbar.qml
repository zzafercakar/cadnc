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
        // Tool #2 — Sketcher_CreateLine (FreeCAD CmdSketcherCreateLine
        // at src/Mod/Sketcher/Gui/CommandCreateGeo.cpp:194). Tooltip and
        // shortcut preserved from FreeCAD's sToolTipText / sAccel.
        CadToolButton {
            iconPath: "qrc:/resources/icons/sketcher/Sketcher_CreateLine.svg"
            tipText: qsTr("Creates a line") + " (G, L)"
            shortcut: "G, L"
            isActive: activeTool === "line"
            activeColor: "#34D399"
            onClicked: toolSelected("line")
        }
        CadToolButton { iconPath: "qrc:/resources/icons/sketch/circle.svg"; tipText: "Circle (C)"; isActive: activeTool === "circle"; activeColor: "#34D399"; onClicked: toolSelected("circle") }
        // Tool #4 — Sketcher_CreateArc (FreeCAD CmdSketcherCreateArc
        // at src/Mod/Sketcher/Gui/CommandCreateGeo.cpp:330). Tooltip and
        // shortcut preserved from FreeCAD's sToolTipText / sAccel.
        CadToolButton {
            iconPath: "qrc:/resources/icons/sketcher/Sketcher_CreateArc.svg"
            tipText: qsTr("Creates an arc defined by a center point and an end point") + " (G, A)"
            shortcut: "G, A"
            isActive: activeTool === "arc"
            activeColor: "#34D399"
            onClicked: toolSelected("arc")
        }
        // Tool #5 — Sketcher_Create3PointArc (FreeCAD CmdSketcherCreate3PointArc
        // at src/Mod/Sketcher/Gui/CommandCreateGeo.cpp:362). Shares the
        // DrawSketchHandlerArc backend via ThreeRim construction method.
        CadToolButton {
            iconPath: "qrc:/resources/icons/sketcher/Sketcher_Create3PointArc.svg"
            tipText: qsTr("Creates an arc defined by 2 end points and 1 point on the arc") + " (G, 3, A)"
            shortcut: "G, 3, A"
            isActive: activeTool === "arc3point"
            activeColor: "#34D399"
            onClicked: toolSelected("arc3point")
        }
        // Tool #6 — Sketcher_CreateArcOfEllipse (FreeCAD
        // CmdSketcherCreateArcOfEllipse at CommandCreateGeo.cpp:398).
        CadToolButton {
            iconPath: "qrc:/resources/icons/sketcher/Sketcher_CreateElliptical_Arc.svg"
            tipText: qsTr("Creates an elliptical arc") + " (G, E, A)"
            shortcut: "G, E, A"
            isActive: activeTool === "arcEllipse"
            activeColor: "#34D399"
            onClicked: toolSelected("arcEllipse")
        }
        CadToolButton { iconPath: "qrc:/resources/icons/sketch/rect.svg"; tipText: "Rectangle (R)"; isActive: activeTool === "rectangle"; activeColor: "#34D399"; onClicked: toolSelected("rectangle") }
        // Tool #3 — Sketcher_CreatePolyline (FreeCAD CmdSketcherCreatePolyline
        // at src/Mod/Sketcher/Gui/CommandCreateGeo.cpp:225). Tooltip and
        // shortcut preserved from FreeCAD's sToolTipText / sAccel.
        CadToolButton {
            iconPath: "qrc:/resources/icons/sketcher/Sketcher_CreatePolyline.svg"
            tipText: qsTr("Creates a continuous polyline. Press the 'M' key to switch segment modes") + " (G, M)"
            shortcut: "G, M"
            isActive: activeTool === "polyline"
            activeColor: "#34D399"
            onClicked: toolSelected("polyline")
        }
        CadToolButton { iconPath: "qrc:/resources/icons/sketch/ellipse.svg"; tipText: "Ellipse (E)"; isActive: activeTool === "ellipse"; activeColor: "#34D399"; onClicked: toolSelected("ellipse") }
        CadToolButton { iconPath: "qrc:/resources/icons/sketch/spline.svg"; tipText: "B-Spline (S)"; isActive: activeTool === "bspline"; activeColor: "#34D399"; onClicked: toolSelected("bspline") }
        // Tool #1 — Sketcher_CreatePoint (FreeCAD CmdSketcherCreatePoint
        // at src/Mod/Sketcher/Gui/CommandCreateGeo.cpp:107). Tooltip and
        // shortcut preserved from FreeCAD's sToolTipText / sAccel.
        CadToolButton {
            iconPath: "qrc:/resources/icons/sketcher/Sketcher_CreatePoint.svg"
            tipText: qsTr("Creates a point") + " (G, Y)"
            shortcut: "G, Y"
            isActive: activeTool === "point"
            activeColor: "#34D399"
            onClicked: toolSelected("point")
        }

        Rectangle { width: 1; height: 32; color: "#CBD5E1" }

        // Modify
        CadToolButton { iconPath: "qrc:/resources/icons/sketch/trim.svg"; tipText: "Trim (T)"; isActive: activeTool === "trim"; accentColor: "#D97706"; activeColor: "#FBBF24"; onClicked: toolSelected("trim") }
        CadToolButton { iconPath: "qrc:/resources/icons/sketch/offset.svg"; tipText: "Split (W)"; isActive: activeTool === "split"; accentColor: "#D97706"; activeColor: "#FBBF24"; onClicked: toolSelected("split") }
        CadToolButton { iconPath: "qrc:/resources/icons/sketch/mirror.svg"; tipText: "Toggle Construction (G)"; accentColor: "#D97706"; onClicked: constraintRequested("toggleConstruction") }
        CadToolButton { iconPath: "qrc:/resources/icons/sketch/fillet.svg"; tipText: "Fillet (F)"; isActive: activeTool === "fillet"; accentColor: "#D97706"; activeColor: "#FBBF24"; onClicked: toolSelected("fillet") }
        CadToolButton { iconPath: "qrc:/resources/icons/sketch/chamfer.svg"; tipText: "Chamfer"; isActive: activeTool === "chamfer"; accentColor: "#D97706"; activeColor: "#FBBF24"; onClicked: toolSelected("chamfer") }
        CadToolButton { iconPath: "qrc:/resources/icons/sketch/extend.svg"; tipText: "Extend (X)"; isActive: activeTool === "extend"; accentColor: "#D97706"; activeColor: "#FBBF24"; onClicked: toolSelected("extend") }

        Rectangle { width: 1; height: 32; color: "#CBD5E1" }

        // Smart Dimension — auto type from geometry, on-canvas inline input
        CadToolButton { iconPath: "qrc:/resources/icons/constraint/distance.svg"; tipText: "Smart Dimension (D)"; isActive: activeTool === "dimension"; accentColor: "#7C3AED"; activeColor: "#A78BFA"; onClicked: toolSelected("dimension") }

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
        CadToolButton { iconPath: "qrc:/resources/icons/constraint/distance.svg"; tipText: "Distance X"; accentColor: "#7C3AED"; onClicked: constraintRequested("distanceX") }
        CadToolButton { iconPath: "qrc:/resources/icons/constraint/distance.svg"; tipText: "Distance Y"; accentColor: "#7C3AED"; onClicked: constraintRequested("distanceY") }
        CadToolButton { iconPath: "qrc:/resources/icons/constraint/radius.svg"; tipText: "Diameter"; accentColor: "#7C3AED"; onClicked: constraintRequested("diameter") }
        CadToolButton { iconPath: "qrc:/resources/icons/constraint/symmetric.svg"; tipText: "Symmetric"; accentColor: "#7C3AED"; onClicked: constraintRequested("symmetric") }
        CadToolButton { iconPath: "qrc:/resources/icons/constraint/midpoint.svg"; tipText: "Point on Object"; accentColor: "#7C3AED"; onClicked: constraintRequested("pointOnObject") }

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
