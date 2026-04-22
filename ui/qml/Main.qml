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
    // When non-empty, the left panel becomes a SolidWorks-style FeatureEditPanel
    // ("pad" | "pocket" | "revolve" | "groove"). Live-previews the feature.
    property string featureEditMode: ""
    // When true, the left panel swaps to the DatumPlanePanel task editor.
    // Docked instead of a floating Popup so a viewport click (for face pick)
    // doesn't dismiss it.
    property bool datumPlaneEditMode: false

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
               onActivated: { activeDrawTool = ""; sketchCanvas.drawing = false; sketchCanvas.cancelDimension() } }
    Shortcut { sequence: "Delete"; context: Qt.ApplicationShortcut
               onActivated: { if (cadEngine.sketchActive && sketchCanvas.selectedGeo >= 0) cadEngine.removeGeometry(sketchCanvas.selectedGeo) } }
    Shortcut { sequence: "L"; onActivated: if (cadEngine.sketchActive) activeDrawTool = "line" }
    Shortcut { sequence: "C"; onActivated: if (cadEngine.sketchActive) activeDrawTool = "circle" }
    Shortcut { sequence: "R"; onActivated: if (cadEngine.sketchActive) activeDrawTool = "rectangle" }
    Shortcut { sequence: "A"; onActivated: if (cadEngine.sketchActive) activeDrawTool = "arc" }
    Shortcut { sequence: "P"; onActivated: if (cadEngine.sketchActive) activeDrawTool = "polyline" }
    Shortcut { sequence: "E"; onActivated: if (cadEngine.sketchActive) activeDrawTool = "ellipse" }
    Shortcut { sequence: "S"; onActivated: if (cadEngine.sketchActive) activeDrawTool = "bspline" }
    Shortcut { sequence: "X"; onActivated: if (cadEngine.sketchActive) activeDrawTool = "extend" }
    Shortcut { sequence: "W"; onActivated: if (cadEngine.sketchActive) activeDrawTool = "split" }
    Shortcut { sequence: "T"; onActivated: if (cadEngine.sketchActive) activeDrawTool = "trim" }
    Shortcut { sequence: "F"; onActivated: if (cadEngine.sketchActive) activeDrawTool = "fillet" }
    Shortcut { sequence: "G"; onActivated: if (cadEngine.sketchActive && sketchCanvas.selectedGeo >= 0) cadEngine.toggleConstruction(sketchCanvas.selectedGeo) }
    Shortcut { sequence: "H"; onActivated: if (cadEngine.sketchActive && sketchCanvas.selectedGeo >= 0) cadEngine.addHorizontalConstraint(sketchCanvas.selectedGeo) }
    Shortcut { sequence: "D"; onActivated: if (cadEngine.sketchActive) activeDrawTool = "dimension" }

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
                QAButton { iconName: "save"; tip: qsTr("Save (Ctrl+S)");
                           onClicked: {
                               if (!cadEngine.hasDocument) return
                               // Mirror the Ctrl+S action: overwrite the backing
                               // file silently if we have one, otherwise prompt.
                               if (cadEngine.documentPath !== "")
                                   cadEngine.saveDocument()
                               else
                                   saveDialog.open()
                           } }
                QASep {}
                // Always-available "New Sketch" button — user asked for
                // a permanent entry point in the top toolbar in addition
                // to the tree's pencil button.
                QAButton { iconName: "sketch"; tip: qsTr("New Sketch");
                           onClicked: sketchPlaneDialog.open() }
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

                // Brand — SMB logo + product name/version
                RowLayout {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.rightMargin: 10; spacing: 8

                    Image {
                        // Original SMB logo (440x436 PNG from MilCAD). At
                        // a 32px render target with mipmap the result
                        // looked washed out; we now:
                        //   - bump the display to 40px so fine strokes
                        //     (the swirl blades) still resolve,
                        //   - pre-render at 2x the display size via
                        //     sourceSize so the downsample happens once
                        //     at load time, not every paint,
                        //   - disable mipmap (which would linear-blur
                        //     further) and rely on `smooth` for the
                        //     single high-quality downsample.
                        id: smbLogo
                        source: "qrc:/resources/logos/smb_logo.png"
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 40
                        Layout.alignment: Qt.AlignVCenter
                        sourceSize: Qt.size(80, 80)
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        mipmap: false
                        asynchronous: false
                    }

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
                else if (type === "distanceX" || type === "distanceY" || type === "diameter") {
                    dimInput.targetGeoId = geo
                    dimInput.presetType = type
                    dimInput.x = (mainWindow.width - dimInput.width) / 2
                    dimInput.y = (mainWindow.height - dimInput.height) / 2
                    dimInput.open()
                }
                else if (type === "symmetric") {
                    cadEngine.addConstraintTwoGeo("symmetric", geo)
                }
                else if (type === "pointOnObject") {
                    cadEngine.addConstraintTwoGeo("pointOnObject", geo)
                }
                else if (type === "toggleConstruction") {
                    cadEngine.toggleConstruction(geo)
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
            onExitSketch: {
                cadEngine.closeSketch()
                mainWindow.activeDrawTool = ""
                mainWindow.currentWorkbench = 0
            }
        }
        PartToolbar {
            width: parent.width
            visible: mainWindow.currentWorkbench === 0 && !cadEngine.sketchActive
            onActionRequested: function(action) {
                if (action === "newSketch") {
                    if (!cadEngine.hasDocument) cadEngine.newDocument("Untitled")
                    sketchPlaneDialog.open()
                } else if (action === "pad") {
                    if (cadEngine.sketchNames.length === 0) { padDialog.open(); return }
                    mainWindow.featureEditMode = "pad"
                } else if (action === "pocket") {
                    if (cadEngine.sketchNames.length === 0) { pocketDialog.open(); return }
                    mainWindow.featureEditMode = "pocket"
                } else if (action === "revolve") {
                    if (cadEngine.sketchNames.length === 0) { revolveDialog.open(); return }
                    mainWindow.featureEditMode = "revolve"
                } else if (action === "groove") {
                    if (cadEngine.sketchNames.length === 0) { grooveDialog.open(); return }
                    mainWindow.featureEditMode = "groove"
                } else if (action === "box") {
                    boxDialog.primitiveType = "box"; boxDialog.open()
                } else if (action === "cylinder") {
                    boxDialog.primitiveType = "cylinder"; boxDialog.open()
                } else if (action === "sphere") {
                    boxDialog.primitiveType = "sphere"; boxDialog.open()
                } else if (action === "cone") {
                    boxDialog.primitiveType = "cone"; boxDialog.open()
                } else if (action === "union") {
                    boolDialog.booleanType = "fuse"; boolDialog.open()
                } else if (action === "cut") {
                    boolDialog.booleanType = "cut"; boolDialog.open()
                } else if (action === "intersect") {
                    boolDialog.booleanType = "common"; boolDialog.open()
                } else if (action === "fillet3d") {
                    dressUpDialog.dressUpType = "fillet"; dressUpDialog.open()
                } else if (action === "chamfer3d") {
                    dressUpDialog.dressUpType = "chamfer"; dressUpDialog.open()
                } else if (action === "linearPattern") {
                    var tree = cadEngine.featureTree
                    if (tree.length > 0) cadEngine.linearPattern(tree[tree.length-1].name, 100, 3)
                } else if (action === "polarPattern") {
                    var tree2 = cadEngine.featureTree
                    if (tree2.length > 0) cadEngine.polarPattern(tree2[tree2.length-1].name, 360, 6)
                } else if (action === "mirror") {
                    var tree3 = cadEngine.featureTree
                    if (tree3.length > 0) cadEngine.mirrorFeature(tree3[tree3.length-1].name)
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

        // Left panel — model tree, OR feature edit panel during pad/pocket/etc.
        Item {
            Layout.preferredWidth: Theme.panelW
            Layout.minimumWidth: Theme.panelMinW
            Layout.fillHeight: true

            ModelTreePanel {
                anchors.fill: parent
                visible: mainWindow.featureEditMode === ""
                       && featureEditPanel.editingFeatureName === ""
                       && !mainWindow.datumPlaneEditMode
                onSketchDoubleClicked: function(name) { cadEngine.openSketch(name); mainWindow.currentWorkbench = 1 }
                onFeatureEditRequested: function(name, typeName) {
                    // Map PartDesign type → FeatureEditPanel featureType key.
                    // openForEdit() drives visibility via its editingFeatureName
                    // property — we do NOT flip featureEditMode (that is the
                    // create-new flow and would stomp the edit state).
                    var key = typeName.indexOf("Pad") >= 0      ? "pad"
                            : typeName.indexOf("Pocket") >= 0   ? "pocket"
                            : typeName.indexOf("Revolution") >= 0 ? "revolve"
                            : typeName.indexOf("Groove") >= 0   ? "groove"
                            : ""
                    if (key !== "") featureEditPanel.openForEdit(key, name)
                }
                // UX-016: double-click a datum plane under Origin to start a
                // sketch on it. `planeType` is the 0/1/2 index expected by
                // CadEngine::createSketch (XY/XZ/YZ respectively).
                onPlaneDoubleClicked: function(name, planeType) {
                    cadEngine.createSketch("Sketch", planeType)
                    mainWindow.currentWorkbench = 1
                }
                // Header button + context menu "New Sketch"
                onNewSketchRequested: sketchPlaneDialog.open()
                // Right-click → "Add Datum Plane…" — swap the tree for the
                // DatumPlanePanel task editor. Previously opened the modal
                // Popup which closed on any viewport click.
                onNewDatumPlaneRequested: {
                    mainWindow.datumPlaneEditMode = true
                    datumPlanePanel.open()
                }
            }

            FeatureEditPanel {
                id: featureEditPanel
                anchors.fill: parent
                // Visible for either the create flow (driven by featureEditMode)
                // or the edit flow (driven by editingFeatureName).
                visible: mainWindow.featureEditMode !== "" || featureEditPanel.editingFeatureName !== ""
                onAccepted: { mainWindow.featureEditMode = "" }
                onCancelled: { mainWindow.featureEditMode = "" }
            }

            DatumPlanePanel {
                id: datumPlanePanel
                anchors.fill: parent
                visible: mainWindow.datumPlaneEditMode
                onAccepted:  { mainWindow.datumPlaneEditMode = false }
                onCancelled: { mainWindow.datumPlaneEditMode = false }
            }

            // Open the panel in create mode whenever featureEditMode becomes
            // non-empty. The guard avoids re-opening create mode over an active
            // edit session.
            Connections {
                target: mainWindow
                function onFeatureEditModeChanged() {
                    if (mainWindow.featureEditMode !== "" &&
                        featureEditPanel.editingFeatureName === "")
                        featureEditPanel.openFor(mainWindow.featureEditMode)
                }
            }
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
                    // GRID toggle now drives CadEngine's single source of truth,
                    // which fans out to both the sketch canvas and the 3D OCCT
                    // viewer grid (BUG-013).
                    StatusToggle { text: "GRID"; isOn: cadEngine.gridVisible; onToggled: cadEngine.gridVisible = !cadEngine.gridVisible }
                    // Inline grid size input (UX-012) — editable next to GRID.
                    // Only shown when grid is on to avoid a phantom input.
                    Rectangle {
                        visible: cadEngine.gridVisible
                        Layout.preferredWidth: gridStepField.implicitWidth + 24
                        Layout.preferredHeight: 18
                        radius: 4
                        color: gridStepField.activeFocus ? Theme.panelAlt : "transparent"
                        border.width: 1
                        border.color: gridStepField.activeFocus ? Theme.accent : Theme.borderLight
                        Row {
                            anchors.centerIn: parent; spacing: 2
                            TextField {
                                id: gridStepField
                                width: 44
                                height: 16
                                padding: 0
                                font.pixelSize: 10; font.family: Theme.fontMono
                                horizontalAlignment: Text.AlignRight
                                selectByMouse: true
                                text: cadEngine.gridSpacing.toFixed(cadEngine.gridSpacing < 10 ? 1 : 0)
                                validator: DoubleValidator { bottom: 0.5; top: 1000.0; decimals: 2 }
                                background: Item {}
                                onEditingFinished: {
                                    var v = parseFloat(text)
                                    if (!isNaN(v)) cadEngine.gridSpacing = v
                                }
                            }
                            Text {
                                text: "mm"
                                font.pixelSize: 9; color: Theme.textTer
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
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
                    onFeatureEditRequested: function(name, typeName) {
                        // Same routing the ModelTreePanel uses — map to the
                        // FeatureEditPanel key and pop the inline editor.
                        var key = typeName.indexOf("Pad") >= 0      ? "pad"
                                : typeName.indexOf("Pocket") >= 0   ? "pocket"
                                : typeName.indexOf("Revolution") >= 0 ? "revolve"
                                : typeName.indexOf("Groove") >= 0   ? "groove"
                                : ""
                        if (key !== "") featureEditPanel.openForEdit(key, name)
                    }
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
            else if (constraintType === "distanceX") cadEngine.addDistanceXConstraint(targetGeoId, value)
            else if (constraintType === "distanceY") cadEngine.addDistanceYConstraint(targetGeoId, value)
            else if (constraintType === "diameter") cadEngine.addDiameterConstraint(targetGeoId, value)
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
    FeatureDialog {
        id: grooveDialog; featureType: "groove"
        onFeatureCreated: function(name) { mainWindow.currentStatus = "Groove created: " + name }
    }
    PrimitiveDialog {
        id: boxDialog; primitiveType: "box"
        onFeatureCreated: function(name) { mainWindow.currentStatus = "Primitive created: " + name }
    }
    BooleanDialog {
        id: boolDialog; booleanType: "fuse"
        onFeatureCreated: function(name) { mainWindow.currentStatus = "Boolean: " + name }
    }
    DressUpDialog {
        id: dressUpDialog; dressUpType: "fillet"
        onFeatureCreated: function(name) { mainWindow.currentStatus = "Dress-up: " + name }
    }

    // ─── File Dialogs ──────────────────────────────────────────────
    // User-visible filter labels avoid product branding ("FreeCAD
    // project") per user feedback — the ".cadnc" extension is just the
    // FCStd binary written under a neutral name so a brand-agnostic CAD
    // label makes the format ladder read cleanly.
    FileDialog {
        id: openDialog
        title: "Open File"
        nameFilters: [
            "All supported (*.cadnc *.FCStd *.step *.stp *.iges *.igs *.igus *.brep *.stl *.dxf *.dwg *.obj *.ply)",
            "CADNC project (*.cadnc *.FCStd)",
            "STEP (*.step *.stp)",
            "IGES (*.iges *.igs *.igus)",
            "BREP (*.brep)",
            "STL (*.stl)",
            "DXF / DWG (*.dxf *.dwg)",
            "OBJ (*.obj)",
            "PLY (*.ply)",
            "All files (*)"
        ]
        fileMode: FileDialog.OpenFile
        onAccepted: {
            var path = selectedFile.toString().replace("file://", "")
            var ext = path.split(".").pop().toLowerCase()
            // Native project formats go through openDocument; everything
            // else imports shapes into the current doc.
            if (ext === "fcstd" || ext === "cadnc") {
                if (cadEngine.openDocument(path))
                    mainWindow.title = "CADNC v" + appVersion + " — " + path.split("/").pop()
            } else {
                if (cadEngine.importFile(path))
                    mainWindow.title = "CADNC v" + appVersion + " — " + path.split("/").pop()
            }
        }
    }

    FileDialog {
        id: saveDialog
        title: "Save As"
        // Keep native project as the ONLY primary save target. Geometry-only
        // formats (STEP, IGES, STL, DXF, OBJ) are available from File →
        // Export instead, which routes to `exportDialog` and then to
        // `cadEngine.exportDocument`. Mixing them in Save confused users who
        // expected "Save" to preserve the parametric model.
        nameFilters: [
            "CADNC project (*.cadnc *.FCStd)",
            "All files (*)"
        ]
        fileMode: FileDialog.SaveFile
        defaultSuffix: "cadnc"
        onAccepted: {
            var path = selectedFile.toString().replace("file://", "")
            var ext = path.split(".").pop().toLowerCase()
            // Treat any name with no recognised extension as native — the
            // FileDialog's defaultSuffix also adds .cadnc when the user
            // leaves the box empty.
            if (ext !== "cadnc" && ext !== "fcstd") {
                path += ".cadnc"; ext = "cadnc"
            }
            if (cadEngine.saveDocumentAs(path))
                mainWindow.title = "CADNC v" + appVersion + " — " + path.split("/").pop()
        }
    }

    FileDialog {
        id: exportDialog
        title: "Export"
        nameFilters: [
            "STEP (*.step *.stp)",
            "IGES (*.iges *.igs)",
            "STL (*.stl)",
            "BREP (*.brep)",
            "DXF (*.dxf)",
            "OBJ (*.obj)",
            "All files (*)"
        ]
        // FileDialog's own defaultSuffix would only fire when the filename has
        // NO extension at all; users who type "part" with filter "IGES" get
        // "part.iges" via this handler, and users who type "part.garbage"
        // with filter "IGES" get their garbage ext kept (explicit override).
        fileMode: FileDialog.SaveFile
        defaultSuffix: "step"
        onAccepted: {
            var path = selectedFile.toString().replace("file://", "")
            var knownExts = ["step", "stp", "iges", "igs", "stl", "brep",
                             "brp", "dxf", "dwg", "obj", "ply"]
            var lastDot = path.lastIndexOf(".")
            var ext = lastDot >= 0 ? path.substring(lastDot + 1).toLowerCase() : ""
            // If the user left it extensionless OR picked something
            // unrecognised, force it to match the active filter so the file
            // round-trips through Open without surprise.
            if (knownExts.indexOf(ext) < 0) {
                var filterExt = "step"
                var f = selectedNameFilter.name || ""
                if (f.indexOf("IGES") >= 0) filterExt = "iges"
                else if (f.indexOf("STL")  >= 0) filterExt = "stl"
                else if (f.indexOf("BREP") >= 0) filterExt = "brep"
                else if (f.indexOf("DXF")  >= 0) filterExt = "dxf"
                else if (f.indexOf("OBJ")  >= 0) filterExt = "obj"
                path = (lastDot >= 0 ? path.substring(0, lastDot) : path) + "." + filterExt
            }
            if (cadEngine.exportDocument(path))
                mainWindow.currentStatus = "Exported: " + path
            else
                mainWindow.currentStatus = "Export failed"
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
        width: 320; height: spCol.implicitHeight + 24
        x: (mainWindow.width - width) / 2; y: (mainWindow.height - height) / 2
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        // Refresh face list whenever the dialog opens in case features changed
        onOpened: {
            faceFeatureCombo.currentIndex =
                cadEngine.solidFeatureNames && cadEngine.solidFeatureNames().length > 0 ? 0 : -1
            refreshFaceList()
        }

        function refreshFaceList() {
            var feats = cadEngine.solidFeatureNames()
            if (faceFeatureCombo.currentIndex < 0 || feats.length === 0) {
                faceCombo.model = []
                return
            }
            faceCombo.model = cadEngine.featureFaces(feats[faceFeatureCombo.currentIndex])
            faceCombo.currentIndex = faceCombo.model.length > 0 ? 0 : -1
        }

        background: Rectangle {
            radius: Theme.radiusLg; color: Theme.panel
            border.color: Theme.wbSketch; border.width: 2
            Rectangle { anchors.fill: parent; anchors.margins: -4; z: -1; radius: 16; color: Theme.shadow }
        }

        contentItem: Column {
            id: spCol; spacing: 0; padding: 0

            // Title bar
            Rectangle {
                width: 320; height: 40; radius: Theme.radiusLg; color: Theme.wbSketch
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 12; color: parent.color }
                Text { anchors.centerIn: parent; text: qsTr("Select Sketch Plane"); color: "#FFFFFF"; font.pixelSize: 14; font.bold: true }
            }

            Column {
                spacing: 6; topPadding: 12; bottomPadding: 12; leftPadding: 14; rightPadding: 14

                Text { text: qsTr("Choose the plane to sketch on:"); color: Theme.textSec; font.pixelSize: 12; bottomPadding: 4 }

                // Combined plane list — three base planes + every user-
                // authored PartDesign::Plane in the tree. cadEngine.
                // availableSketchPlanes() returns both in a single list so
                // the user's datum planes show up next to XY/XZ/YZ.
                Repeater {
                    model: {
                        // Refresh each time the dialog opens. Base entries
                        // get axis colors; datums get amber.
                        var base = cadEngine.availableSketchPlanes()
                        var enriched = []
                        for (var i = 0; i < base.length; i++) {
                            var e = base[i]
                            var colour, desc
                            if (e.name === "__XY__") { colour = "#DC2626"; desc = qsTr("Top view (Z up)") }
                            else if (e.name === "__XZ__") { colour = "#16A34A"; desc = qsTr("Front view (Y up)") }
                            else if (e.name === "__YZ__") { colour = "#2563EB"; desc = qsTr("Side view (X up)") }
                            else { colour = "#F59E0B"; desc = qsTr("Custom datum plane") }
                            enriched.push({
                                name: e.name, label: e.label,
                                desc: desc, color: colour, type: e.type
                            })
                        }
                        return enriched
                    }
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        width: 292; height: 44; radius: Theme.radiusSm
                        color: spArea.containsMouse ? Theme.hover : Theme.surfaceAlt
                        border.color: spArea.containsMouse ? modelData.color : Theme.borderLight
                        border.width: spArea.containsMouse ? 2 : 1

                        Row {
                            anchors.fill: parent; anchors.leftMargin: 10; spacing: 8

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
                                cadEngine.createSketchOnPlane("Sketch", modelData.name)
                                mainWindow.currentWorkbench = 1
                            }
                        }
                    }
                }

                // ── Divider ──────────────────────────────────────────
                Rectangle {
                    visible: cadEngine.solidFeatureNames().length > 0
                    width: 292; height: 1; color: Theme.divider
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                // ── On Face section ──────────────────────────────────
                // Only shown once a solid exists — lets the user attach a new
                // sketch to an existing face. FreeCAD AttachExtension handles
                // the placement calculation automatically on recompute.
                Column {
                    visible: cadEngine.solidFeatureNames().length > 0
                    spacing: 4; width: 292

                    Text { text: qsTr("Or sketch on an existing face:")
                           color: Theme.textSec; font.pixelSize: 12; topPadding: 4 }

                    Row {
                        spacing: 6; width: parent.width
                        ComboBox {
                            id: faceFeatureCombo
                            width: 150
                            model: cadEngine.solidFeatureNames()
                            onActivated: sketchPlaneDialog.refreshFaceList()
                        }
                        ComboBox {
                            id: faceCombo
                            width: 130
                        }
                    }

                    Rectangle {
                        width: parent.width; height: 36; radius: Theme.radiusSm
                        color: Theme.wbSketch
                        opacity: (faceFeatureCombo.currentIndex >= 0 && faceCombo.currentIndex >= 0) ? 1.0 : 0.5
                        Text {
                            anchors.centerIn: parent
                            text: qsTr("Sketch on Face")
                            color: "white"; font.pixelSize: 12; font.bold: true
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            enabled: faceFeatureCombo.currentIndex >= 0 && faceCombo.currentIndex >= 0
                            onClicked: {
                                var feats = cadEngine.solidFeatureNames()
                                var fname = feats[faceFeatureCombo.currentIndex]
                                var fsub  = faceCombo.model[faceCombo.currentIndex]
                                sketchPlaneDialog.close()
                                if (cadEngine.createSketchOnFace("Sketch", fname, fsub))
                                    mainWindow.currentWorkbench = 1
                            }
                        }
                    }
                }
            }
        }
    }

    // ─── Datum Plane dialog (REMOVED — replaced by DatumPlanePanel) ──
    // The old Popup dismissed on any viewport click which made face-picking
    // impossible. The task editor now lives in the left column; see
    // DatumPlanePanel.qml and the `datumPlaneEditMode` flag.
    Popup {
        id: datumPlaneDialog
        visible: false
        enabled: false    // kept only as a placeholder; never shown
        modal: true; focus: true; padding: 0
        width: 360; height: dpCol.implicitHeight + 24
        x: (mainWindow.width - width) / 2; y: (mainWindow.height - height) / 2
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        property string mode: "base"     // "base" | "face"
        property int baseIdx: 0          // 0=XY 1=XZ 2=YZ
        property double offsetMm: 10.0
        property double rotXDeg: 0.0
        property double rotYDeg: 0.0
        property string faceFeature: ""
        property string faceSub: ""

        onOpened: {
            // Refresh solid feature combo in case features changed.
            var feats = cadEngine.solidFeatureNames()
            dpFeatureCombo.model = feats
            dpFeatureCombo.currentIndex = feats.length > 0 ? 0 : -1
            dpRefreshFaces()
        }

        function dpRefreshFaces() {
            if (dpFeatureCombo.currentIndex < 0) {
                dpFaceCombo.model = []
                return
            }
            var feats = dpFeatureCombo.model
            dpFaceCombo.model = cadEngine.featureFaces(feats[dpFeatureCombo.currentIndex])
            dpFaceCombo.currentIndex = dpFaceCombo.model.length > 0 ? 0 : -1
        }

        background: Rectangle {
            radius: Theme.radiusLg; color: Theme.panel
            border.color: Theme.wbPart; border.width: 2
            Rectangle { anchors.fill: parent; anchors.margins: -4; z: -1; radius: 16; color: Theme.shadow }
        }

        contentItem: Column {
            id: dpCol; spacing: 0; padding: 0
            Rectangle {
                width: 360; height: 40; radius: Theme.radiusLg; color: Theme.wbPart
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 12; color: parent.color }
                Text { anchors.centerIn: parent; text: qsTr("New Datum Plane"); color: "#FFFFFF"; font.pixelSize: 14; font.bold: true }
            }
            Column {
                spacing: 8; topPadding: 12; bottomPadding: 12; leftPadding: 14; rightPadding: 14
                width: 360

                // Mode tab selector
                Row {
                    spacing: 6; width: 332
                    Repeater {
                        model: [
                            { key: "base", label: qsTr("Base plane") },
                            { key: "face", label: qsTr("On face") }
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            width: 163; height: 28; radius: 4
                            color: datumPlaneDialog.mode === modelData.key
                                   ? Theme.wbPart : Theme.surfaceAlt
                            border.color: datumPlaneDialog.mode === modelData.key
                                   ? Theme.wbPart : Theme.border
                            border.width: 1
                            Text {
                                anchors.centerIn: parent
                                text: modelData.label
                                font.pixelSize: 11; font.bold: true
                                color: datumPlaneDialog.mode === modelData.key
                                       ? "white" : Theme.text
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: datumPlaneDialog.mode = modelData.key
                            }
                        }
                    }
                }

                // ── Base plane mode ────────────────────────────────
                Column {
                    visible: datumPlaneDialog.mode === "base"
                    spacing: 8; width: 332
                    Text { text: qsTr("Reference plane:"); font.pixelSize: 11; color: Theme.textSec }
                    ComboBox {
                        width: 332
                        model: ["XY", "XZ", "YZ"]
                        currentIndex: datumPlaneDialog.baseIdx
                        onActivated: datumPlaneDialog.baseIdx = currentIndex
                    }

                    Text { text: qsTr("Offset (mm):"); font.pixelSize: 11; color: Theme.textSec }
                    TextField {
                        width: 332
                        text: datumPlaneDialog.offsetMm.toString()
                        font.pixelSize: 13; font.family: "monospace"
                        validator: DoubleValidator { decimals: 4 }
                        onTextChanged: {
                            var v = parseFloat(text)
                            if (!isNaN(v)) datumPlaneDialog.offsetMm = v
                        }
                    }

                    // Tilt angles — optional, default 0. Each axis rotates
                    // the plane around its reference's local X/Y.
                    Row {
                        spacing: 6; width: 332
                        Column {
                            spacing: 2; width: 163
                            Text { text: qsTr("Rot X (°):"); font.pixelSize: 11; color: Theme.textSec }
                            TextField {
                                width: parent.width
                                text: datumPlaneDialog.rotXDeg.toString()
                                font.pixelSize: 13; font.family: "monospace"
                                validator: DoubleValidator { decimals: 3 }
                                onTextChanged: {
                                    var v = parseFloat(text)
                                    if (!isNaN(v)) datumPlaneDialog.rotXDeg = v
                                }
                            }
                        }
                        Column {
                            spacing: 2; width: 163
                            Text { text: qsTr("Rot Y (°):"); font.pixelSize: 11; color: Theme.textSec }
                            TextField {
                                width: parent.width
                                text: datumPlaneDialog.rotYDeg.toString()
                                font.pixelSize: 13; font.family: "monospace"
                                validator: DoubleValidator { decimals: 3 }
                                onTextChanged: {
                                    var v = parseFloat(text)
                                    if (!isNaN(v)) datumPlaneDialog.rotYDeg = v
                                }
                            }
                        }
                    }
                }

                // ── Face mode ────────────────────────────────────────
                Column {
                    visible: datumPlaneDialog.mode === "face"
                    spacing: 6; width: 332
                    Text { text: qsTr("Feature:"); font.pixelSize: 11; color: Theme.textSec }
                    ComboBox {
                        id: dpFeatureCombo
                        width: 332
                        onActivated: datumPlaneDialog.dpRefreshFaces()
                    }
                    Text { text: qsTr("Face:"); font.pixelSize: 11; color: Theme.textSec }
                    ComboBox {
                        id: dpFaceCombo
                        width: 332
                    }
                    Text { text: qsTr("Offset along normal (mm):"); font.pixelSize: 11; color: Theme.textSec }
                    TextField {
                        width: 332
                        text: datumPlaneDialog.offsetMm.toString()
                        font.pixelSize: 13; font.family: "monospace"
                        validator: DoubleValidator { decimals: 4 }
                        onTextChanged: {
                            var v = parseFloat(text)
                            if (!isNaN(v)) datumPlaneDialog.offsetMm = v
                        }
                    }
                }

                Row {
                    spacing: 6; width: 332
                    Button {
                        text: qsTr("Cancel"); width: 163
                        onClicked: datumPlaneDialog.close()
                    }
                    Button {
                        text: qsTr("Add"); width: 163; highlighted: true
                        onClicked: {
                            if (datumPlaneDialog.mode === "base") {
                                cadEngine.addDatumPlaneRotated(
                                    datumPlaneDialog.baseIdx,
                                    datumPlaneDialog.offsetMm,
                                    datumPlaneDialog.rotXDeg,
                                    datumPlaneDialog.rotYDeg,
                                    "DatumPlane")
                            } else if (datumPlaneDialog.mode === "face") {
                                if (dpFeatureCombo.currentIndex >= 0 &&
                                    dpFaceCombo.currentIndex >= 0) {
                                    var feats = dpFeatureCombo.model
                                    cadEngine.addDatumPlaneOnFace(
                                        feats[dpFeatureCombo.currentIndex],
                                        dpFaceCombo.model[dpFaceCombo.currentIndex],
                                        datumPlaneDialog.offsetMm,
                                        "DatumPlane")
                                }
                            }
                            datumPlaneDialog.close()
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
