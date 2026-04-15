import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import "components"
import "panels"
import "toolbars"
import "popups"

ApplicationWindow {
    id: mainWindow
    title: "CADNC v" + appVersion
    width: 1280
    height: 800
    minimumWidth: 900
    minimumHeight: 600
    visible: true

    // ─── Theme Colors (Vibrant Modern) ─────────────────────────────
    readonly property color cBg:       "#EBEEF3"
    readonly property color cPanel:    "#FFFFFF"
    readonly property color cToolbar:  "#F4F5F8"
    readonly property color cBorder:   "#C8CDD6"
    readonly property color cAccent:   "#1D4ED8"
    readonly property color cText:     "#111827"
    readonly property color cTextSec:  "#4B5563"
    readonly property color cHover:    "#E0E7FF"
    readonly property color cActiveBg: "#DBEAFE"

    // ─── App State ─────────────────────────────────────────────────
    property int    currentWorkbench: 0    // 0=Part, 1=Sketch, 2=CAM, 3=Nesting
    property string currentStatus:   qsTr("Ready")
    property string activeDrawTool:  ""

    readonly property var workbenchNames: [qsTr("Part"), qsTr("Sketch"), qsTr("CAM"), qsTr("Nesting")]
    readonly property var workbenchColors: ["#1D4ED8", "#059669", "#D97706", "#7C3AED"]
    readonly property var workbenchIcons: [
        "qrc:/resources/icons/quickaccess/tab_part.svg",
        "qrc:/resources/icons/quickaccess/tab_sketch.svg",
        "qrc:/resources/icons/quickaccess/tab_cam.svg",
        "qrc:/resources/icons/quickaccess/tab_nesting.svg"
    ]

    // ─── Shortcuts ─────────────────────────────────────────────────
    Shortcut { sequence: "Escape"; context: Qt.ApplicationShortcut
               onActivated: { activeDrawTool = ""; sketchCanvas.drawing = false } }
    Shortcut { sequence: "Delete"; context: Qt.ApplicationShortcut
               onActivated: { if (cadEngine.sketchActive && sketchCanvas.selectedGeo >= 0) cadEngine.removeGeometry(sketchCanvas.selectedGeo) } }
    Shortcut { sequence: "L"; onActivated: if (cadEngine.sketchActive) activeDrawTool = "line" }
    Shortcut { sequence: "C"; onActivated: if (cadEngine.sketchActive) activeDrawTool = "circle" }
    Shortcut { sequence: "R"; onActivated: if (cadEngine.sketchActive) activeDrawTool = "rectangle" }
    Shortcut { sequence: "A"; onActivated: if (cadEngine.sketchActive) activeDrawTool = "arc" }
    Shortcut { sequence: "H"; onActivated: if (cadEngine.sketchActive && sketchCanvas.selectedGeo >= 0) cadEngine.addHorizontalConstraint(sketchCanvas.selectedGeo) }
    Shortcut { sequence: "D"; onActivated: if (cadEngine.sketchActive && sketchCanvas.selectedGeo >= 0) { dimInput.targetGeoId = sketchCanvas.selectedGeo; dimInput.open() } }

    // ─── Menu Bar ──────────────────────────────────────────────────
    menuBar: MenuBar {
        background: Rectangle {
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#F8FAFC" }
                GradientStop { position: 1.0; color: "#EFF2F7" }
            }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: mainWindow.cBorder }
        }
        delegate: MenuBarItem {
            contentItem: Text {
                text: parent.text
                font.pixelSize: 13; font.weight: Font.Medium; font.letterSpacing: 0.3
                color: parent.highlighted ? mainWindow.cAccent : mainWindow.cText
                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                color: parent.highlighted ? mainWindow.cActiveBg : "transparent"
                radius: 4
            }
            leftPadding: 12; rightPadding: 12; topPadding: 6; bottomPadding: 6
        }

        Menu {
            title: qsTr("File")
            Action { text: qsTr("New");  shortcut: "Ctrl+N"; onTriggered: cadEngine.newDocument("Untitled") }
            Action { text: qsTr("Save"); shortcut: "Ctrl+S" }
            MenuSeparator {}
            Action { text: qsTr("Exit"); shortcut: "Alt+F4"; onTriggered: Qt.quit() }
        }
        Menu {
            title: qsTr("Edit")
            Action { text: qsTr("Undo"); shortcut: "Ctrl+Z"; onTriggered: cadEngine.undo() }
            Action { text: qsTr("Redo"); shortcut: "Ctrl+Y"; onTriggered: cadEngine.redo() }
        }
        Menu {
            title: qsTr("View")
            Action { text: qsTr("Fit All");    shortcut: "F" }
            Action { text: qsTr("Top View") }
            Action { text: qsTr("Front View") }
            Action { text: qsTr("Isometric") }
            MenuSeparator {}
            Action { text: qsTr("Toggle Grid"); shortcut: "G" }
        }
        Menu {
            title: qsTr("Help")
            Action { text: qsTr("About CADNC"); onTriggered: aboutDialog.open() }
        }
    }

    // ─── Header: Quick Access + Workbench Tabs + Toolbar ───────────
    header: Column {
        width: parent ? parent.width : mainWindow.width
        spacing: 0

        // ── Quick Access Bar ────────────────────────────────────────
        Rectangle {
            width: parent.width; height: 48
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#FDFEFF" }
                GradientStop { position: 0.5; color: "#F4F7FC" }
                GradientStop { position: 1.0; color: "#EAF0F9" }
            }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: mainWindow.cBorder }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8; anchors.rightMargin: 8
                spacing: 4

                QAButton { iconName: "new";  tip: qsTr("New (Ctrl+N)");  onClicked: cadEngine.newDocument("Untitled") }
                QAButton { iconName: "save"; tip: qsTr("Save (Ctrl+S)") }
                QASep {}
                QAButton { iconName: "undo"; tip: qsTr("Undo (Ctrl+Z)"); onClicked: cadEngine.undo() }
                QAButton { iconName: "redo"; tip: qsTr("Redo (Ctrl+Y)"); onClicked: cadEngine.redo() }
                QASep {}
                QAButton { iconName: "fit";   tip: qsTr("Fit All (F)") }
                QAButton { iconName: "top";   tip: qsTr("Top View") }
                QAButton { iconName: "front"; tip: qsTr("Front View") }
                QAButton { iconName: "iso";   tip: qsTr("Isometric") }

                Item { Layout.fillWidth: true }

                // Brand
                RowLayout {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.rightMargin: 10
                    spacing: 8

                    Column {
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 1
                        Text { text: "CADNC"; color: "#1E293B"; font.pixelSize: 13; font.bold: true }
                        Text { text: "v" + appVersion; color: "#64748B"; font.pixelSize: 11 }
                    }
                }
            }
        }

        // ── Workbench Tab Bar ───────────────────────────────────────
        Rectangle {
            width: parent.width; height: 40
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#FFFFFF" }
                GradientStop { position: 1.0; color: "#F3F5F9" }
            }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: mainWindow.cBorder }

            Row {
                anchors.left: parent.left; anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Repeater {
                    model: mainWindow.workbenchNames
                    delegate: Rectangle {
                        id: wbTab
                        property bool isActive: mainWindow.currentWorkbench === index
                        property color wbColor: mainWindow.workbenchColors[index]
                        width: 130; height: 36; radius: 8

                        gradient: Gradient {
                            GradientStop { position: 0.0; color: wbTab.isActive ? Qt.rgba(wbTab.wbColor.r, wbTab.wbColor.g, wbTab.wbColor.b, 0.15)
                                                                                 : (wbTabArea.containsMouse ? Qt.rgba(wbTab.wbColor.r, wbTab.wbColor.g, wbTab.wbColor.b, 0.06) : "transparent") }
                            GradientStop { position: 1.0; color: wbTab.isActive ? Qt.rgba(wbTab.wbColor.r, wbTab.wbColor.g, wbTab.wbColor.b, 0.08)
                                                                                 : "transparent" }
                        }
                        border.color: wbTab.isActive ? Qt.rgba(wbTab.wbColor.r, wbTab.wbColor.g, wbTab.wbColor.b, 0.4) : "transparent"
                        border.width: wbTab.isActive ? 1 : 0

                        // Active underline
                        Rectangle {
                            anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width - 8; height: 3; radius: 1.5
                            color: wbTab.wbColor; visible: wbTab.isActive
                        }

                        Row {
                            anchors.centerIn: parent
                            spacing: 8

                            Image {
                                width: 18; height: 18
                                source: mainWindow.workbenchIcons[index]
                                sourceSize: Qt.size(36, 36)
                                smooth: true; mipmap: true
                                anchors.verticalCenter: parent.verticalCenter
                                opacity: wbTab.isActive ? 1.0 : 0.5
                            }

                            Text {
                                text: modelData
                                color: wbTab.isActive ? wbTab.wbColor : mainWindow.cTextSec
                                font.pixelSize: 13; font.bold: wbTab.isActive; font.letterSpacing: 0.5
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: wbTabArea; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                mainWindow.currentWorkbench = index
                                mainWindow.currentStatus = mainWindow.workbenchNames[index] + qsTr(" workbench")
                            }
                        }
                    }
                }
            }
        }

        // ── Workbench Toolbars ──────────────────────────────────────
        SketchToolbar {
            id: sketchToolbarItem
            width: parent.width
            visible: mainWindow.currentWorkbench === 1 || cadEngine.sketchActive
            activeTool: mainWindow.activeDrawTool
            selectedGeo: sketchCanvas.selectedGeo
            onToolSelected: function(t) { mainWindow.activeDrawTool = (mainWindow.activeDrawTool === t) ? "" : t }
            onConstraintRequested: function(type) {
                if (sketchCanvas.selectedGeo < 0) return
                if (type === "horizontal") cadEngine.addHorizontalConstraint(sketchCanvas.selectedGeo)
                else if (type === "vertical") cadEngine.addVerticalConstraint(sketchCanvas.selectedGeo)
            }
            onDimensionRequested: {
                if (sketchCanvas.selectedGeo >= 0) {
                    dimInput.targetGeoId = sketchCanvas.selectedGeo
                    dimInput.x = (mainWindow.width - dimInput.width) / 2
                    dimInput.y = (mainWindow.height - dimInput.height) / 2
                    dimInput.open()
                }
            }
            onExitSketch: { cadEngine.closeSketch(); mainWindow.activeDrawTool = ""; mainWindow.currentWorkbench = 0 }
        }
        PartToolbar {
            width: parent.width
            visible: mainWindow.currentWorkbench === 0 && !cadEngine.sketchActive
            onActionRequested: function(action) {
                if (action === "newSketch") {
                    cadEngine.createSketch("Sketch")
                    mainWindow.currentWorkbench = 1
                }
                mainWindow.currentStatus = action
            }
        }
        // CAM toolbar
        CAMToolbar {
            width: parent.width
            visible: mainWindow.currentWorkbench === 2 && !cadEngine.sketchActive
            onActionRequested: function(action) { mainWindow.currentStatus = "CAM: " + action }
        }
        // Nesting toolbar
        NestingToolbar {
            width: parent.width
            visible: mainWindow.currentWorkbench === 3 && !cadEngine.sketchActive
            onActionRequested: function(action) { mainWindow.currentStatus = "Nesting: " + action }
        }
    }

    // ─── Inline header button components (MilCAD style) ────────────
    component QAButton: Rectangle {
        property string iconName: ""
        property string labelText: ""
        property string tip: ""
        signal clicked()
        width: 36; height: 34; radius: 8
        gradient: Gradient {
            GradientStop { position: 0.0; color: qaArea.pressed ? "#C7DEFF" : (qaArea.containsMouse ? "#FAFCFF" : "#F7F9FC") }
            GradientStop { position: 1.0; color: qaArea.pressed ? "#98C4FF" : (qaArea.containsMouse ? "#E6F0FF" : "#EDF1F7") }
        }
        border.color: qaArea.pressed ? "#4F8FF6" : (qaArea.containsMouse ? "#7CA7F5" : "#C4CDD9")
        border.width: 1
        ToolTip.text: tip; ToolTip.visible: qaArea.containsMouse; ToolTip.delay: 500

        Rectangle {
            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
            height: parent.height / 2; radius: parent.radius
            color: Qt.rgba(1, 1, 1, qaArea.pressed ? 0.08 : 0.45)
        }
        Text {
            anchors.centerIn: parent; text: parent.labelText
            visible: parent.labelText !== ""
            font.pixelSize: 12; font.bold: true
            color: qaArea.containsMouse ? "#1D4ED8" : "#1F2A3A"
        }
        Image {
            anchors.centerIn: parent; width: 20; height: 20
            visible: parent.iconName !== ""
            source: parent.iconName !== "" ? "qrc:/resources/icons/quickaccess/" + parent.iconName + ".svg" : ""
            sourceSize: Qt.size(40, 40); smooth: true; mipmap: true
        }
        MouseArea { id: qaArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: parent.clicked() }
    }

    component QASep: Rectangle {
        width: 1; height: 22; color: mainWindow.cBorder
        Layout.leftMargin: 4; Layout.rightMargin: 4; Layout.alignment: Qt.AlignVCenter
    }

    // ─── Main Content Area ─────────────────────────────────────────
    RowLayout {
        anchors.fill: parent
        spacing: 0

        // Left panel
        ModelTreePanel {
            Layout.preferredWidth: 240; Layout.minimumWidth: 180; Layout.fillHeight: true
            onSketchDoubleClicked: function(name) { cadEngine.openSketch(name); mainWindow.currentWorkbench = 1 }
        }

        // Center — viewport / sketch canvas
        ColumnLayout {
            Layout.fillWidth: true; Layout.fillHeight: true
            spacing: 0

            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true
                color: "#E8EAF0"

                SketchCanvas {
                    id: sketchCanvas
                    anchors.fill: parent
                    tool: mainWindow.activeDrawTool
                    visible: cadEngine.sketchActive
                }

                // 3D viewport placeholder
                Rectangle {
                    anchors.fill: parent; visible: !cadEngine.sketchActive; color: "#E8EAF0"

                    Canvas {
                        anchors.fill: parent
                        onPaint: {
                            var ctx = getContext("2d"); ctx.clearRect(0, 0, width, height)
                            ctx.strokeStyle = "#C8CDD6"; ctx.lineWidth = 0.5
                            for (var x = 0; x < width; x += 40) { ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, height); ctx.stroke() }
                            for (var y = 0; y < height; y += 40) { ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(width, y); ctx.stroke() }
                        }
                    }

                    Column {
                        anchors.centerIn: parent; spacing: 12
                        Text { text: "3D Viewport"; font.pixelSize: 20; font.bold: true; color: "#6B7280"; anchors.horizontalCenter: parent.horizontalCenter }
                        Text { text: "OCCT V3d integration — Phase 5"; font.pixelSize: 13; color: "#6B7280"; anchors.horizontalCenter: parent.horizontalCenter }
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 180; height: 36; radius: 8; color: "#059669"
                            Text { anchors.centerIn: parent; text: "Create Sketch"; font.pixelSize: 13; font.bold: true; color: "white" }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: { cadEngine.createSketch("Sketch"); mainWindow.currentWorkbench = 1 } }
                        }
                    }

                    // Nav Cube
                    NavCube {
                        anchors.right: parent.right; anchors.top: parent.top
                        anchors.rightMargin: 16; anchors.topMargin: 16
                    }
                    // Axis Indicator
                    AxisIndicator {
                        anchors.left: parent.left; anchors.bottom: parent.bottom
                        anchors.leftMargin: 8; anchors.bottomMargin: 8
                    }
                }
            }

            // ── Status Bar ──────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true; height: 24
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#F8FAFC" }
                    GradientStop { position: 1.0; color: "#EFF2F7" }
                }
                Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: "#D1D9E6" }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10; anchors.rightMargin: 10
                    spacing: 10

                    // Status text
                    Text {
                        text: cadEngine.statusMessage
                        font.pixelSize: 11; color: mainWindow.cAccent
                        elide: Text.ElideRight; Layout.fillWidth: true
                    }

                    // Selection badge
                    Rectangle {
                        visible: cadEngine.sketchActive
                        width: selLabel.implicitWidth + 12; height: 18; radius: 9
                        color: "#EFF6FF"; border.width: 1; border.color: "#BFDBFE"
                        Text { id: selLabel; anchors.centerIn: parent
                               text: "Geo:" + cadEngine.sketchGeometry.length; font.pixelSize: 10; color: "#2563EB" }
                    }

                    // Solver DOF badge
                    Rectangle {
                        visible: cadEngine.sketchActive
                        width: dofLabel.implicitWidth + 12; height: 18; radius: 9
                        color: cadEngine.solverStatus === "Fully Constrained" ? "#ECFDF5" : "#FEF3C7"
                        border.width: 1; border.color: cadEngine.solverStatus === "Fully Constrained" ? "#86EFAC" : "#FDE68A"
                        Text { id: dofLabel; anchors.centerIn: parent
                               text: cadEngine.solverStatus; font.pixelSize: 10; font.bold: true
                               color: cadEngine.solverStatus === "Fully Constrained" ? "#15803D" : "#92400E" }
                    }

                    // Toggle pills
                    StatusToggle { text: "SNAP"; isOn: true }
                    StatusToggle { text: "GRID"; isOn: true }
                    StatusToggle { text: "ORTHO" }

                    // Cursor XY
                    Text {
                        visible: cadEngine.sketchActive
                        text: sketchCanvas.currentSketchX.toFixed(4) + ", " + sketchCanvas.currentSketchY.toFixed(4)
                        font.pixelSize: 10; font.family: "monospace"; color: "#6B7280"
                    }

                    // Workbench label
                    Text {
                        text: mainWindow.workbenchNames[mainWindow.currentWorkbench]
                        font.pixelSize: 11; font.bold: true
                        color: mainWindow.workbenchColors[mainWindow.currentWorkbench]
                    }
                }
            }
        }

        // Right panel
        ConstraintPanel {
            Layout.preferredWidth: 240; Layout.minimumWidth: 160; Layout.fillHeight: true
        }
    }

    // ─── Dimension Input Popup ──────────────────────────────────────
    DimensionInput {
        id: dimInput
        onValueAccepted: function(constraintType, value) {
            if (targetGeoId < 0) return
            if (constraintType === "distance") cadEngine.addDistanceConstraint(targetGeoId, value)
            else if (constraintType === "radius") cadEngine.addRadiusConstraint(targetGeoId, value)
            else if (constraintType === "angle") cadEngine.addAngleConstraint(targetGeoId, -1, value)
        }
    }

    // ─── About Dialog ───────────────────────────────────────────────
    Popup {
        id: aboutDialog
        modal: true; focus: true; padding: 0
        width: 360; height: aboutCol.implicitHeight + 24
        x: (mainWindow.width - width) / 2; y: (mainWindow.height - height) / 2
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            radius: 10; color: "#FFFFFF"; border.color: "#1D4ED8"; border.width: 2
            Rectangle { anchors.fill: parent; anchors.margins: -4; z: -1; radius: 14; color: Qt.rgba(0, 0, 0, 0.12) }
        }

        contentItem: Column {
            id: aboutCol; spacing: 0; padding: 0
            Rectangle {
                width: 360; height: 40; radius: 10; color: "#1D4ED8"
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 12; color: parent.color }
                Text { anchors.centerIn: parent; text: "About CADNC"; color: "#FFFFFF"; font.pixelSize: 15; font.bold: true }
            }
            Column {
                spacing: 8; topPadding: 14; bottomPadding: 14; leftPadding: 16; rightPadding: 16
                Text { text: "CADNC v" + appVersion; font.pixelSize: 16; font.bold: true; color: mainWindow.cAccent }
                Text { text: "FreeCAD-backed CAD-CAM Application"; font.pixelSize: 12; color: mainWindow.cTextSec }
                Text { text: "Backend: FreeCAD 1.2 (Base, App, Part, Sketcher, PartDesign)"; font.pixelSize: 11; color: "#6B7280" }
                Text { text: "UI: Qt6 Quick / QML"; font.pixelSize: 11; color: "#6B7280" }
                Text { text: "\u00A9 2026 SMB Engineering"; font.pixelSize: 11; color: "#9CA3AF" }
                Item { width: 1; height: 8 }
                Button { text: "OK"; anchors.right: parent.right; onClicked: aboutDialog.close(); highlighted: true
                         background: Rectangle { radius: 4; color: parent.down ? "#1D4ED8" : "#2563EB" }
                         contentItem: Text { text: parent.text; color: "white"; font.pixelSize: 11; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
            }
        }
    }
}
