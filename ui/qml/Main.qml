import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

import CADNC.Viewport 1.0

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
    color: Theme.bg

    // ─── App State ─────────────────────────────────────────────────
    property int    currentWorkbench: 0    // 0=Part, 1=Sketch, 2=CAM, 3=Nesting
    property string currentStatus:   qsTr("Ready")
    property string activeDrawTool:  ""

    readonly property var workbenchNames:  [qsTr("Part"), qsTr("Sketch"), qsTr("CAM"), qsTr("Nesting")]
    readonly property var workbenchColors: [Theme.wbPart, Theme.wbSketch, Theme.wbCam, Theme.wbNesting]
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
                GradientStop { position: 0.0; color: Theme.isDark ? "#2A2D35" : "#F8FAFC" }
                GradientStop { position: 1.0; color: Theme.isDark ? "#22252B" : "#EFF2F7" }
            }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.border }
        }
        delegate: MenuBarItem {
            contentItem: Text {
                text: parent.text
                font.pixelSize: Theme.fontMd; font.weight: Font.Medium; font.letterSpacing: 0.3
                color: parent.highlighted ? Theme.accent : Theme.text
                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                color: parent.highlighted ? Theme.accentLight : "transparent"
                radius: Theme.radiusSm
            }
            leftPadding: 12; rightPadding: 12; topPadding: 6; bottomPadding: 6
        }

        Menu {
            title: qsTr("File")
            Action {
                text: qsTr("New")
                shortcut: "Ctrl+N"
                onTriggered: requestNew()
            }
            Action {
                text: qsTr("Open...")
                shortcut: "Ctrl+O"
                onTriggered: openDialog.open()
            }
            Action {
                text: qsTr("Save")
                shortcut: "Ctrl+S"
                enabled: cadEngine.hasDocument
                onTriggered: {
                    if (cadEngine.documentPath !== "")
                        cadEngine.saveDocument()
                    else
                        saveDialog.open()
                }
            }
            Action {
                text: qsTr("Save As...")
                shortcut: "Ctrl+Shift+S"
                enabled: cadEngine.hasDocument
                onTriggered: saveDialog.open()
            }
            Action {
                text: qsTr("Close")
                enabled: cadEngine.hasDocument
                onTriggered: {
                    cadEngine.closeDocument()
                    mainWindow.title = "CADNC v" + appVersion
                }
            }
            MenuSeparator {}
            Menu {
                title: qsTr("Export")
                enabled: cadEngine.hasDocument
                Action { text: "STEP (.step)"; onTriggered: { exportDialog.open() } }
                Action { text: "IGES (.iges)"; onTriggered: { exportDialog.open() } }
                Action { text: "STL (.stl)"; onTriggered: { exportDialog.open() } }
                Action { text: "BREP (.brep)"; onTriggered: { exportDialog.open() } }
            }
            MenuSeparator {}
            Action { text: qsTr("Exit"); shortcut: "Alt+F4"; onTriggered: Qt.quit() }
        }
        Menu {
            title: qsTr("Edit")
            Action { text: qsTr("Undo"); shortcut: "Ctrl+Z"; enabled: cadEngine.canUndo; onTriggered: cadEngine.undo() }
            Action { text: qsTr("Redo"); shortcut: "Ctrl+Y"; enabled: cadEngine.canRedo; onTriggered: cadEngine.redo() }
        }
        Menu {
            title: qsTr("View")
            Action { text: qsTr("Fit All");    shortcut: "F";    onTriggered: occViewport.fitAll() }
            Action { text: qsTr("Top View");   onTriggered: occViewport.viewTop() }
            Action { text: qsTr("Front View"); onTriggered: occViewport.viewFront() }
            Action { text: qsTr("Isometric");  onTriggered: occViewport.viewIsometric() }
            MenuSeparator {}
            Action {
                text: Theme.isDark ? qsTr("Light Mode") : qsTr("Dark Mode")
                shortcut: "Ctrl+T"
                onTriggered: Theme.isDark = !Theme.isDark
            }
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
            width: parent.width; height: Theme.headerH
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.isDark ? "#2E3139" : "#FDFEFF" }
                GradientStop { position: 0.5; color: Theme.toolbar }
                GradientStop { position: 1.0; color: Theme.toolbarAlt }
            }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.border }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8; anchors.rightMargin: 8
                spacing: 4

                QAButton { iconName: "new";  tip: qsTr("New (Ctrl+N)");  onClicked: requestNew() }
                QAButton { iconName: "save"; tip: qsTr("Save (Ctrl+S)"); onClicked: saveDialog.open() }
                QASep {}
                QAButton { iconName: "undo"; tip: qsTr("Undo (Ctrl+Z)"); opacity: cadEngine.canUndo ? 1.0 : 0.4; onClicked: cadEngine.undo() }
                QAButton { iconName: "redo"; tip: qsTr("Redo (Ctrl+Y)"); opacity: cadEngine.canRedo ? 1.0 : 0.4; onClicked: cadEngine.redo() }
                QASep {}
                QAButton { iconName: "fit";   tip: qsTr("Fit All (F)");  onClicked: occViewport.fitAll() }
                QAButton { iconName: "top";   tip: qsTr("Top View");   onClicked: occViewport.viewTop() }
                QAButton { iconName: "front"; tip: qsTr("Front View"); onClicked: occViewport.viewFront() }
                QAButton { iconName: "iso";   tip: qsTr("Isometric");  onClicked: occViewport.viewIsometric() }

                Item { Layout.fillWidth: true }

                // Dark mode toggle
                Rectangle {
                    width: 32; height: 32; radius: Theme.radius
                    color: themeToggleArea.containsMouse ? Theme.hover : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: Theme.isDark ? "\u2600" : "\u263E"  // sun/moon
                        font.pixelSize: 16
                    }
                    MouseArea {
                        id: themeToggleArea; anchors.fill: parent
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: Theme.isDark = !Theme.isDark
                    }
                    ToolTip.text: Theme.isDark ? "Light Mode (Ctrl+T)" : "Dark Mode (Ctrl+T)"
                    ToolTip.visible: themeToggleArea.containsMouse; ToolTip.delay: 500
                }

                QASep {}

                // Brand
                RowLayout {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.rightMargin: 10; spacing: 8

                    Column {
                        Layout.alignment: Qt.AlignVCenter; spacing: 1
                        Text { text: "CADNC"; color: Theme.text; font.pixelSize: 13; font.bold: true }
                        Text { text: "v" + appVersion; color: Theme.textTer; font.pixelSize: 11 }
                    }
                }
            }
        }

        // ── Workbench Tab Bar ───────────────────────────────────────
        Rectangle {
            width: parent.width; height: Theme.tabBarH
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.panel }
                GradientStop { position: 1.0; color: Theme.panelAlt }
            }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.border }

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
                        width: 130; height: 34; radius: Theme.radius

                        gradient: Gradient {
                            GradientStop { position: 0.0; color: wbTab.isActive ? Qt.rgba(wbTab.wbColor.r, wbTab.wbColor.g, wbTab.wbColor.b, 0.15)
                                                                                 : (wbTabArea.containsMouse ? Qt.rgba(wbTab.wbColor.r, wbTab.wbColor.g, wbTab.wbColor.b, 0.06) : "transparent") }
                            GradientStop { position: 1.0; color: wbTab.isActive ? Qt.rgba(wbTab.wbColor.r, wbTab.wbColor.g, wbTab.wbColor.b, 0.08) : "transparent" }
                        }
                        border.color: wbTab.isActive ? Qt.rgba(wbTab.wbColor.r, wbTab.wbColor.g, wbTab.wbColor.b, 0.4) : "transparent"
                        border.width: wbTab.isActive ? 1 : 0

                        Rectangle {
                            anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width - 8; height: 3; radius: 1.5
                            color: wbTab.wbColor; visible: wbTab.isActive
                        }

                        Row {
                            anchors.centerIn: parent; spacing: 8

                            Image {
                                width: 18; height: 18
                                source: mainWindow.workbenchIcons[index]
                                sourceSize: Qt.size(36, 36); smooth: true; mipmap: true
                                anchors.verticalCenter: parent.verticalCenter
                                opacity: wbTab.isActive ? 1.0 : 0.5
                            }

                            Text {
                                text: modelData
                                color: wbTab.isActive ? wbTab.wbColor : Theme.textSec
                                font.pixelSize: Theme.fontMd; font.bold: wbTab.isActive; font.letterSpacing: 0.5
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: wbTabArea; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: mainWindow.currentWorkbench = index
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
                var geo = sketchCanvas.selectedGeo
                if (type === "horizontal") cadEngine.addHorizontalConstraint(geo)
                else if (type === "vertical") cadEngine.addVerticalConstraint(geo)
                else if (type === "parallel") cadEngine.addConstraintTwoGeo("parallel", geo)
                else if (type === "perpendicular") cadEngine.addConstraintTwoGeo("perpendicular", geo)
                else if (type === "tangent") cadEngine.addConstraintTwoGeo("tangent", geo)
                else if (type === "equal") cadEngine.addConstraintTwoGeo("equal", geo)
                else if (type === "fixed") cadEngine.addFixedConstraint(geo)
                else if (type === "coincident") cadEngine.addConstraintTwoGeo("coincident", geo)
                else if (type === "distance" || type === "radius" || type === "angle") {
                    dimInput.targetGeoId = geo
                    dimInput.presetType = type
                    dimInput.x = (mainWindow.width - dimInput.width) / 2
                    dimInput.y = (mainWindow.height - dimInput.height) / 2
                    dimInput.open()
                }
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
                    if (!cadEngine.hasDocument) cadEngine.newDocument("Untitled")
                    sketchPlaneDialog.open()
                } else if (action === "pad") {
                    padDialog.open()
                } else if (action === "pocket") {
                    pocketDialog.open()
                } else if (action === "revolve") {
                    revolveDialog.open()
                } else {
                    mainWindow.currentStatus = action
                }
            }
        }
        CAMToolbar {
            width: parent.width
            visible: mainWindow.currentWorkbench === 2 && !cadEngine.sketchActive
            onActionRequested: function(action) {
                if (action === "exportGCode") {
                    camExportDialog.open()
                } else if (action === "exportCodeSys") {
                    camCodesysExportDialog.open()
                } else {
                    mainWindow.currentStatus = "CAM: " + action
                }
            }
        }
        NestingToolbar {
            width: parent.width
            visible: mainWindow.currentWorkbench === 3 && !cadEngine.sketchActive
            onActionRequested: function(action) {
                if (action === "runNesting") {
                    var result = cadEngine.nestRun(1)
                    mainWindow.currentStatus = "Nesting: " + result.totalPlaced + " placed, " + Math.round(result.utilization * 100) + "% utilization"
                } else if (action === "optimize") {
                    cadEngine.nestSetRotation(1)  // quadrant rotation
                    var result2 = cadEngine.nestRun(1)
                    mainWindow.currentStatus = "Optimized: " + result2.totalPlaced + " placed, " + Math.round(result2.utilization * 100) + "% utilization"
                } else {
                    mainWindow.currentStatus = "Nesting: " + action
                }
            }
        }
    }

    // ─── Inline header button components ───────────────────────────
    component QAButton: Rectangle {
        property string iconName: ""
        property string labelText: ""
        property string tip: ""
        signal clicked()
        width: 36; height: 34; radius: Theme.radius
        gradient: Gradient {
            GradientStop { position: 0.0; color: qaArea.pressed ? Theme.pressed : (qaArea.containsMouse ? Theme.hover : Theme.toolbar) }
            GradientStop { position: 1.0; color: qaArea.pressed ? Theme.pressed : (qaArea.containsMouse ? Theme.hover : Theme.toolbarAlt) }
        }
        border.color: qaArea.pressed ? Theme.accent : (qaArea.containsMouse ? Theme.border : Theme.borderLight)
        border.width: 1
        ToolTip.text: tip; ToolTip.visible: qaArea.containsMouse; ToolTip.delay: 500

        Rectangle {
            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
            height: parent.height / 2; radius: parent.radius
            color: Qt.rgba(1, 1, 1, Theme.isDark ? 0.04 : (qaArea.pressed ? 0.08 : 0.45))
        }
        Text {
            anchors.centerIn: parent; text: parent.labelText
            visible: parent.labelText !== ""
            font.pixelSize: 12; font.bold: true; color: Theme.text
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
        width: 1; height: 22; color: Theme.border
        Layout.leftMargin: 4; Layout.rightMargin: 4; Layout.alignment: Qt.AlignVCenter
    }

    // ─── Main Content Area ─────────────────────────────────────────
    RowLayout {
        anchors.fill: parent
        spacing: 0

        // Left panel — Model Tree
        ModelTreePanel {
            Layout.preferredWidth: Theme.panelW; Layout.minimumWidth: Theme.panelMinW; Layout.fillHeight: true
            onSketchDoubleClicked: function(name) { cadEngine.openSketch(name); mainWindow.currentWorkbench = 1 }
        }

        // Center — viewport / sketch canvas
        ColumnLayout {
            Layout.fillWidth: true; Layout.fillHeight: true
            spacing: 0

            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true
                color: Theme.viewport

                // 3D viewport — ALWAYS visible (OCCT ViewCube, grid, shapes)
                OccViewport {
                    id: occViewport
                    objectName: "occViewport"
                    anchors.fill: parent
                    sketchMode: cadEngine.sketchActive

                    // "Create Sketch" overlay button (only when no features exist)
                    Rectangle {
                        anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottomMargin: 40
                        width: 180; height: 36; radius: Theme.radius
                        color: Theme.success
                        visible: cadEngine.featureTree.length === 0 && !cadEngine.sketchActive
                        Text { anchors.centerIn: parent; text: "Create Sketch"; font.pixelSize: 13; font.bold: true; color: "white" }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: sketchPlaneDialog.open() }
                    }

                    // Right-click context menu (only in 3D mode, not sketch mode)
                    TapHandler {
                        enabled: !cadEngine.sketchActive
                        acceptedButtons: Qt.RightButton
                        onTapped: function(eventPoint) {
                            viewportMenu.popup(eventPoint.position.x, eventPoint.position.y)
                        }
                    }
                }

                // Sketch canvas — transparent overlay on top of 3D viewport
                SketchCanvas {
                    id: sketchCanvas
                    anchors.fill: parent
                    tool: mainWindow.activeDrawTool
                    visible: cadEngine.sketchActive
                    z: 1  // above OccViewport
                }
            }

            // ── Status Bar ──────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true; height: Theme.statusBarH
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.toolbar }
                    GradientStop { position: 1.0; color: Theme.toolbarAlt }
                }
                Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: Theme.border }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10; anchors.rightMargin: 10
                    spacing: 10

                    // Status text
                    Text {
                        text: cadEngine.statusMessage
                        font.pixelSize: 11; color: Theme.accent
                        elide: Text.ElideRight; Layout.fillWidth: true
                    }

                    // Geometry badge
                    Rectangle {
                        visible: cadEngine.sketchActive
                        width: selLabel.implicitWidth + 12; height: 18; radius: 9
                        color: Theme.infoBg; border.width: 1; border.color: Theme.accentLight
                        Text { id: selLabel; anchors.centerIn: parent
                               text: "Geo:" + cadEngine.sketchGeometry.length; font.pixelSize: 10; color: Theme.accent }
                    }

                    // Solver DOF badge
                    Rectangle {
                        visible: cadEngine.sketchActive
                        width: dofLabel.implicitWidth + 12; height: 18; radius: 9
                        color: cadEngine.solverStatus === "Fully Constrained" ? Theme.successBg : Theme.warningBg
                        border.width: 1
                        border.color: cadEngine.solverStatus === "Fully Constrained"
                            ? Qt.rgba(Theme.success.r, Theme.success.g, Theme.success.b, 0.4)
                            : Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.4)
                        Text { id: dofLabel; anchors.centerIn: parent
                               text: cadEngine.solverStatus; font.pixelSize: 10; font.bold: true
                               color: cadEngine.solverStatus === "Fully Constrained" ? Theme.success : Theme.warning }
                    }

                    StatusToggle { text: "SNAP"; isOn: sketchCanvas.snapEnabled; onToggled: sketchCanvas.snapEnabled = !sketchCanvas.snapEnabled }
                    StatusToggle { text: "GRID"; isOn: sketchCanvas.gridVisible; onToggled: sketchCanvas.gridVisible = !sketchCanvas.gridVisible }
                    StatusToggle { text: "ORTHO" }

                    // Cursor XY
                    Text {
                        visible: cadEngine.sketchActive
                        text: sketchCanvas.currentSketchX.toFixed(4) + ", " + sketchCanvas.currentSketchY.toFixed(4)
                        font.pixelSize: 10; font.family: Theme.fontMono; color: Theme.textTer
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

        // Right panel — Properties + Constraints (context-sensitive)
        Rectangle {
            Layout.preferredWidth: 240
            Layout.maximumWidth: 280
            Layout.minimumWidth: 160
            Layout.fillHeight: true
            color: Theme.panel
            border.width: 1
            border.color: Theme.border

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // Show constraints when sketch is active
                ConstraintPanel {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: cadEngine.sketchActive
                }

                // Show properties when not in sketch mode
                PropertiesPanel {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: !cadEngine.sketchActive
                }
            }
        }
    }

    // ─── Popups ────────────────────────────────────────────────────
    DimensionInput {
        id: dimInput
        onValueAccepted: function(constraintType, value) {
            if (targetGeoId < 0) return
            if (constraintType === "distance") cadEngine.addDistanceConstraint(targetGeoId, value)
            else if (constraintType === "radius") cadEngine.addRadiusConstraint(targetGeoId, value)
            else if (constraintType === "angle") cadEngine.addAngleConstraint(targetGeoId, -1, value)
        }
    }

    FeatureDialog {
        id: padDialog; featureType: "pad"
        onFeatureCreated: function(name) { mainWindow.currentStatus = "Pad created: " + name }
    }
    FeatureDialog {
        id: pocketDialog; featureType: "pocket"
        onFeatureCreated: function(name) { mainWindow.currentStatus = "Pocket created: " + name }
    }
    FeatureDialog {
        id: revolveDialog; featureType: "revolve"
        onFeatureCreated: function(name) { mainWindow.currentStatus = "Revolution created: " + name }
    }

    // ─── File Dialogs ──────────────────────────────────────────────
    FileDialog {
        id: openDialog
        title: "Open File"
        nameFilters: [
            "All supported (*.FCStd *.step *.stp *.iges *.igs *.brep *.stl)",
            "FreeCAD project (*.FCStd)",
            "STEP (*.step *.stp)",
            "IGES (*.iges *.igs)",
            "BREP (*.brep)",
            "STL (*.stl)",
            "All files (*)"
        ]
        fileMode: FileDialog.OpenFile
        onAccepted: {
            var path = selectedFile.toString().replace("file://", "")
            if (cadEngine.openDocument(path)) {
                mainWindow.title = "CADNC v" + appVersion + " — " + path.split("/").pop()
            }
        }
    }

    FileDialog {
        id: saveDialog
        title: "Save As"
        nameFilters: ["FreeCAD project (*.FCStd)", "All files (*)"]
        fileMode: FileDialog.SaveFile
        onAccepted: {
            var path = selectedFile.toString().replace("file://", "")
            if (cadEngine.saveDocumentAs(path)) {
                mainWindow.title = "CADNC v" + appVersion + " — " + path.split("/").pop()
            }
        }
    }

    FileDialog {
        id: exportDialog
        title: "Export"
        nameFilters: [
            "STEP (*.step *.stp)",
            "IGES (*.iges *.igs)",
            "STL (*.stl)",
            "BREP (*.brep)"
        ]
        fileMode: FileDialog.SaveFile
        onAccepted: {
            var path = selectedFile.toString().replace("file://", "")
            cadEngine.exportDocument(path)
        }
    }

    FileDialog {
        id: camExportDialog
        title: "Export G-Code"
        nameFilters: ["G-Code files (*.nc *.gcode *.tap)", "All files (*)"]
        fileMode: FileDialog.SaveFile
        onAccepted: {
            var path = selectedFile.toString().replace("file://", "")
            if (cadEngine.camExportGCode(path, false))
                mainWindow.currentStatus = "G-Code exported: " + path
            else
                mainWindow.currentStatus = "G-Code export failed"
        }
    }

    FileDialog {
        id: camCodesysExportDialog
        title: "Export CODESYS G-Code"
        nameFilters: ["G-Code files (*.nc *.gcode)", "All files (*)"]
        fileMode: FileDialog.SaveFile
        onAccepted: {
            var path = selectedFile.toString().replace("file://", "")
            if (cadEngine.camExportGCode(path, true))
                mainWindow.currentStatus = "CODESYS G-Code exported: " + path
            else
                mainWindow.currentStatus = "CODESYS G-Code export failed"
        }
    }

    // ─── Viewport Context Menu ─────────────────────────────────────
    Menu {
        id: viewportMenu
        MenuItem { text: "Fit All"; onTriggered: occViewport.fitAll() }
        MenuSeparator {}
        MenuItem { text: "Top View"; onTriggered: occViewport.viewTop() }
        MenuItem { text: "Front View"; onTriggered: occViewport.viewFront() }
        MenuItem { text: "Right View"; onTriggered: occViewport.viewRight() }
        MenuItem { text: "Isometric"; onTriggered: occViewport.viewIsometric() }
        MenuSeparator {}
        MenuItem { text: "Create Sketch"; onTriggered: sketchPlaneDialog.open() }
    }

    // ─── New Document Dialog (MilCAD-style 3-option popup) ────────────
    function requestNew() {
        newDocDialog.open()
    }

    Popup {
        id: newDocDialog
        modal: true; focus: true; padding: 0
        width: 420; height: newDocCol.implicitHeight + 24
        x: (mainWindow.width - width) / 2; y: (mainWindow.height - height) / 2
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            radius: Theme.radiusLg; color: Theme.panel
            border.color: Theme.accent; border.width: 2
            Rectangle { anchors.fill: parent; anchors.margins: -4; z: -1; radius: 16; color: Theme.shadow }
        }

        contentItem: Column {
            id: newDocCol; spacing: 0; padding: 0

            // Title bar
            Rectangle {
                width: 420; height: 44; radius: Theme.radiusLg; color: Theme.accent
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 14; color: parent.color }
                Text { anchors.centerIn: parent; text: qsTr("New Document"); color: "#FFFFFF"; font.pixelSize: 16; font.bold: true; font.letterSpacing: 0.5 }
            }

            // Options
            Column {
                spacing: 6; topPadding: 14; bottomPadding: 14; leftPadding: 16; rightPadding: 16

                // Part option
                NewDocOption {
                    symbol: "\u2B22"; symbolColor: Theme.wbPart
                    title: qsTr("Part"); subtitle: qsTr("A 3D representation of a single design component")
                    onClicked: {
                        cadEngine.newDocument("Untitled")
                        mainWindow.currentWorkbench = 0
                        mainWindow.title = "CADNC v" + appVersion + " \u2014 Untitled"
                        occViewport.viewIsometric()
                        newDocDialog.close()
                    }
                }

                // Drawing (Sketch) option
                NewDocOption {
                    symbol: "\u25AD"; symbolColor: Theme.wbSketch
                    title: qsTr("Drawing"); subtitle: qsTr("A 2D engineering drawing / sketch")
                    onClicked: {
                        cadEngine.newDocument("Untitled")
                        mainWindow.title = "CADNC v" + appVersion + " \u2014 Untitled"
                        newDocDialog.close()
                        sketchPlaneDialog.open()
                    }
                }

                // Assembly option (disabled)
                NewDocOption {
                    symbol: "\u2699"; symbolColor: Theme.textTer
                    title: qsTr("Assembly"); subtitle: qsTr("A 3D arrangement of parts (coming soon)")
                    enabled: false; opacity: 0.5
                }

                // Cancel
                Item {
                    width: 388; height: 36
                    Button {
                        anchors.right: parent.right; text: qsTr("Cancel"); flat: true; font.pixelSize: 11
                        onClicked: newDocDialog.close()
                    }
                }
            }
        }
    }

    // Reusable option row component for NewDocDialog
    component NewDocOption: Rectangle {
        property string symbol: ""
        property color symbolColor: Theme.accent
        property string title: ""
        property string subtitle: ""
        signal clicked()

        width: 388; height: 64; radius: Theme.radius
        color: ndArea.containsMouse ? Theme.hover : Theme.surfaceAlt
        border.color: ndArea.containsMouse ? Theme.accent : Theme.borderLight
        border.width: ndArea.containsMouse ? 2 : 1

        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14; spacing: 14

            Rectangle {
                width: 42; height: 42; radius: Theme.radius
                color: Qt.rgba(symbolColor.r, symbolColor.g, symbolColor.b, 0.12)
                Layout.alignment: Qt.AlignVCenter
                Text { anchors.centerIn: parent; text: symbol; color: symbolColor; font.pixelSize: 22; font.bold: true }
            }

            Column {
                Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter; spacing: 2
                Text { text: title; color: Theme.text; font.pixelSize: 14; font.bold: true }
                Text { text: subtitle; color: Theme.textSec; font.pixelSize: 11; width: parent.width; elide: Text.ElideRight }
            }
        }

        MouseArea {
            id: ndArea; anchors.fill: parent; hoverEnabled: true
            cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (parent.enabled) parent.clicked()
        }
    }

    // ─── Sketch Plane Selection Dialog ──────────────────────────────
    Popup {
        id: sketchPlaneDialog
        modal: true; focus: true; padding: 0
        width: 300; height: spCol.implicitHeight + 24
        x: (mainWindow.width - width) / 2; y: (mainWindow.height - height) / 2
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            radius: Theme.radiusLg; color: Theme.panel
            border.color: Theme.wbSketch; border.width: 2
            Rectangle { anchors.fill: parent; anchors.margins: -4; z: -1; radius: 16; color: Theme.shadow }
        }

        contentItem: Column {
            id: spCol; spacing: 0; padding: 0

            // Title bar
            Rectangle {
                width: 300; height: 40; radius: Theme.radiusLg; color: Theme.wbSketch
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 12; color: parent.color }
                Text { anchors.centerIn: parent; text: qsTr("Select Sketch Plane"); color: "#FFFFFF"; font.pixelSize: 14; font.bold: true }
            }

            Column {
                spacing: 6; topPadding: 12; bottomPadding: 12; leftPadding: 14; rightPadding: 14

                Text { text: qsTr("Choose the plane to sketch on:"); color: Theme.textSec; font.pixelSize: 12; bottomPadding: 4 }

                Repeater {
                    model: [
                        { label: "XY Plane", desc: qsTr("Top view (Z up)"),   plane: 0, color: "#2563EB" },
                        { label: "XZ Plane", desc: qsTr("Front view (Y up)"), plane: 1, color: "#16A34A" },
                        { label: "YZ Plane", desc: qsTr("Side view (X up)"),  plane: 2, color: "#DC2626" }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        width: 272; height: 44; radius: Theme.radiusSm
                        color: spArea.containsMouse ? Theme.hover : Theme.surfaceAlt
                        border.color: spArea.containsMouse ? modelData.color : Theme.borderLight
                        border.width: spArea.containsMouse ? 2 : 1

                        Row {
                            anchors.fill: parent; anchors.leftMargin: 10; spacing: 8

                            // Color accent bar
                            Rectangle {
                                width: 4; height: 24; radius: 2; color: modelData.color
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                Text { text: modelData.label; color: Theme.text; font.pixelSize: 13; font.bold: true }
                                Text { text: modelData.desc; color: Theme.textTer; font.pixelSize: 10 }
                            }
                        }

                        MouseArea {
                            id: spArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                sketchPlaneDialog.close()
                                cadEngine.createSketch("Sketch", modelData.plane)
                                mainWindow.currentWorkbench = 1
                            }
                        }
                    }
                }
            }
        }
    }

    // ─── About Dialog ───────────────────────────────────────────────
    Popup {
        id: aboutDialog
        modal: true; focus: true; padding: 0
        width: 380; height: aboutCol.implicitHeight + 24
        x: (mainWindow.width - width) / 2; y: (mainWindow.height - height) / 2
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            radius: Theme.radiusLg; color: Theme.panel
            border.color: Theme.accent; border.width: 2
            Rectangle { anchors.fill: parent; anchors.margins: -4; z: -1; radius: 16; color: Theme.shadow }
        }

        contentItem: Column {
            id: aboutCol; spacing: 0; padding: 0
            Rectangle {
                width: 380; height: 44; radius: Theme.radiusLg; color: Theme.accent
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 14; color: parent.color }
                Text { anchors.centerIn: parent; text: "About CADNC"; color: "#FFFFFF"; font.pixelSize: 16; font.bold: true }
            }
            Column {
                spacing: 8; topPadding: 16; bottomPadding: 16; leftPadding: 20; rightPadding: 20
                Text { text: "CADNC v" + appVersion; font.pixelSize: 18; font.bold: true; color: Theme.accent }
                Text { text: "FreeCAD-backed CAD-CAM Application"; font.pixelSize: 13; color: Theme.textSec }
                Item { width: 1; height: 4 }
                Text { text: "Backend: FreeCAD 1.2 (Base, App, Part, Sketcher, PartDesign)"; font.pixelSize: 11; color: Theme.textTer }
                Text { text: "Viewport: OCCT V3d (8x MSAA, ViewCube, Grid)"; font.pixelSize: 11; color: Theme.textTer }
                Text { text: "UI: Qt6 Quick / QML"; font.pixelSize: 11; color: Theme.textTer }
                Text { text: "\u00A9 2026 SMB Engineering"; font.pixelSize: 11; color: Theme.textTer }
                Item { width: 1; height: 8 }
                Button { text: "OK"; anchors.right: parent.right; onClicked: aboutDialog.close(); highlighted: true
                         background: Rectangle { radius: Theme.radiusSm; color: parent.down ? Theme.accentHover : Theme.accent }
                         contentItem: Text { text: parent.text; color: "white"; font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
            }
        }
    }
}
