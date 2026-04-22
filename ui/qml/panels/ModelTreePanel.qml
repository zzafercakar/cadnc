import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".."

/**
 * ModelTreePanel — Left sidebar feature tree (SolidWorks/Fusion 360 style).
 * Color-coded features, visibility toggles, context menus, inline editing.
 */
Rectangle {
    id: panel
    color: Theme.panel
    border.width: 1
    border.color: Theme.border

    signal sketchDoubleClicked(string name)
    // Feature edit request — emitted when an editable PartDesign feature
    // (Pad / Pocket / Revolution / Groove) is double-clicked. Main.qml maps
    // the typeName to a featureType ("pad" etc.) and opens the edit panel.
    signal featureEditRequested(string name, string typeName)
    // Emitted when user double-clicks a datum plane (XY/XZ/YZ_Plane under
    // Origin). Main.qml routes this to `cadEngine.createSketch(name, plane)`.
    signal planeDoubleClicked(string name, int planeType)
    // Emitted by the persistent "New Sketch" button in the header.
    // Main.qml opens its sketchPlaneDialog so the user can pick XY/XZ/YZ
    // or an existing face/datum plane.
    signal newSketchRequested()
    // Emitted when the user requests a custom datum plane via the tree
    // context menu (right-click → "Add Datum Plane"). Main.qml routes
    // to cadEngine.addDatumPlane with a sensible default offset.
    signal newDatumPlaneRequested()

    property int selectedIndex: -1

    // Track which container (Body/Origin) is expanded. Keys are the group's
    // internal name; value is true when its children are visible. Both
    // groups default to expanded so the user sees the full hierarchy.
    property var expanded: ({})
    // Document-header inline rename state. Kept at panel level so the
    // Text / TextField swap doesn't race the TextField's own `visible`
    // property (which was the root of the "Body reverts" bug).
    property bool renamingDocument: false

    // Flatten the feature tree respecting expand/collapse state. Each entry
    // carries its own indent depth so the delegate can position it without
    // rebuilding the list on every paint.
    function flattenedTree() {
        var raw = cadEngine.featureTree
        if (!raw || raw.length === 0) return []

        // Index by parent for O(n) walk
        var byParent = {}
        for (var i = 0; i < raw.length; i++) {
            var p = raw[i].parent || ""
            if (!byParent[p]) byParent[p] = []
            byParent[p].push(raw[i])
        }

        function isContainer(typeName) {
            return typeName.indexOf("Body") >= 0 || typeName.indexOf("Origin") >= 0
        }

        var result = []
        function walk(parentName, depth) {
            var children = byParent[parentName] || []
            for (var j = 0; j < children.length; j++) {
                var item = children[j]
                var hasKids = (byParent[item.name] || []).length > 0
                result.push({
                    name: item.name,
                    label: item.label,
                    typeName: item.typeName,
                    parent: item.parent,
                    depth: depth,
                    hasChildren: hasKids,
                    isExpanded: panel.expanded[item.name] !== false,  // default true
                    isContainer: isContainer(item.typeName)
                })
                if (hasKids && panel.expanded[item.name] !== false) {
                    walk(item.name, depth + 1)
                }
            }
        }
        walk("", 0)
        return result
    }

    // Convert a datum plane feature name into the plane index expected by
    // `cadEngine.createSketch`. Uses the label as a reliable key — FreeCAD
    // assigns the same label string regardless of unique-name suffixing.
    function planeTypeForName(label, name) {
        var s = (label || name || "").toUpperCase()
        if (s.indexOf("XY") >= 0) return 0
        if (s.indexOf("XZ") >= 0) return 1
        if (s.indexOf("YZ") >= 0) return 2
        return -1
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 0
        spacing: 0

        // ── Header ──────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true; height: 36
            color: Theme.panelAlt

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12; anchors.rightMargin: 8
                spacing: 6

                Rectangle {
                    width: 20; height: 20; radius: 4
                    color: Theme.accentLight
                    Text {
                        anchors.centerIn: parent
                        text: "\u2261"   // ≡ hamburger-style tree icon
                        font.pixelSize: 14; font.bold: true
                        color: Theme.accent
                    }
                }

                Text {
                    text: "Model Tree"
                    font.pixelSize: Theme.fontMd
                    font.bold: true
                    color: Theme.text
                    Layout.fillWidth: true
                }

                // Persistent "New Sketch" button — always available from
                // the tree header so the user doesn't hunt for the menu.
                // Click opens the plane-picker dialog in Main.qml.
                Rectangle {
                    Layout.preferredWidth: 28; Layout.preferredHeight: 22
                    radius: 4
                    color: nsArea.containsMouse ? Theme.hover : Theme.accentLight
                    border.color: Theme.accent; border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: "\u270E"   // ✎ pencil glyph — reads as "sketch"
                        font.pixelSize: 12; color: Theme.accent
                    }
                    MouseArea {
                        id: nsArea; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: panel.newSketchRequested()
                    }
                    ToolTip.text: "New Sketch"
                    ToolTip.visible: nsArea.containsMouse
                    ToolTip.delay: 400
                }

                // Feature count badge
                Rectangle {
                    visible: cadEngine.featureTree.length > 0
                    width: countLabel.implicitWidth + 10
                    height: 18; radius: 9
                    color: Theme.infoBg
                    border.width: 1; border.color: Theme.accentLight

                    Text {
                        id: countLabel; anchors.centerIn: parent
                        text: cadEngine.featureTree.length
                        font.pixelSize: Theme.fontSm; font.bold: true
                        color: Theme.accent
                    }
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width; height: 1
                color: Theme.border
            }
        }

        // ── Document header row ─────────────────────────────────────
        // Double-click renames the document in place (user request: the
        // "Untitled" label shouldn't be dead weight — the document should
        // read as a nameable root, not a brand stub).
        Rectangle {
            Layout.fillWidth: true; height: 32
            color: Theme.panelAlt
            visible: cadEngine.featureTree.length > 0

            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 8
                spacing: 6

                Text { text: "\u25BC"; font.pixelSize: 9; color: Theme.textSec }
                Rectangle {
                    width: 18; height: 18; radius: 4
                    color: Theme.accentLight
                    // Cube glyph reads as "Part / Body" across the CAD
                    // conventions we target (SolidWorks, Fusion, FreeCAD).
                    Text { anchors.centerIn: parent; text: "\u25A3"; font.pixelSize: 11; color: Theme.accent }
                }

                // Name label — inline edit on double-click. Default
                // "Body" if the document was never named so the root has
                // a meaningful read instead of "Untitled".
                // Editing state is tracked via a dedicated property so
                // losing focus doesn't fight the binding update cycle.
                Text {
                    id: docNameLabel
                    visible: !panel.renamingDocument
                    text: (cadEngine.documentName && cadEngine.documentName !== "Untitled")
                          ? cadEngine.documentName : "Body"
                    font.pixelSize: Theme.fontMd; font.bold: true
                    color: Theme.text; Layout.fillWidth: true
                    elide: Text.ElideRight
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.IBeamCursor
                        onDoubleClicked: {
                            docRenameField.text = docNameLabel.text
                            panel.renamingDocument = true
                            Qt.callLater(function() {
                                docRenameField.forceActiveFocus()
                                docRenameField.selectAll()
                            })
                        }
                    }
                }
                TextField {
                    id: docRenameField
                    visible: panel.renamingDocument
                    Layout.fillWidth: true
                    font.pixelSize: Theme.fontMd; font.bold: true
                    height: 24
                    selectByMouse: true
                    background: Rectangle { radius: 3; color: "#F5F3FF"
                                            border.width: 1; border.color: Theme.accent }
                    // Commit: persist the name via the adapter, then exit
                    // edit mode. Lose-focus also commits so clicking away
                    // doesn't discard the typed value (previous behaviour
                    // discarded the edit — that's why user saw the label
                    // revert to "Body").
                    function commit() {
                        if (text.length > 0) cadEngine.renameDocument(text)
                        panel.renamingDocument = false
                    }
                    onAccepted: commit()
                    Keys.onEscapePressed: panel.renamingDocument = false
                    onActiveFocusChanged: if (!activeFocus && panel.renamingDocument) commit()
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom; width: parent.width; height: 1
                color: Theme.divider
            }
        }

        // ── Feature list ────────────────────────────────────────────
        ListView {
            id: treeView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            // Flattened hierarchy — rebuilt whenever the raw tree or the
            // expand/collapse state changes.
            property var flatModel: panel.flattenedTree()
            model: flatModel

            // React to feature-tree changes without needing a Qt signal —
            // Connections bridges cadEngine.featureTreeChanged to a local
            // property write.
            Connections {
                target: cadEngine
                function onFeatureTreeChanged() { treeView.flatModel = panel.flattenedTree() }
            }

            function refresh() { flatModel = panel.flattenedTree() }

            delegate: Rectangle {
                id: delegate
                width: treeView.width
                height: 30
                color: {
                    if (panel.selectedIndex === index) return Theme.selected
                    if (mouseArea.containsMouse) return Theme.hover
                    return "transparent"
                }

                property bool isSelected: panel.selectedIndex === index
                // Label-aware resolver so X-axis reads red, XY-plane reads
                // amber etc., matching the viewport gizmo. Falls back to
                // the plain-typeName lookup when the label is ambiguous.
                property color fColor: Theme.featureColorByLabel(modelData.typeName, modelData.label)
                // Indent: base 12px + 14px per depth level. Matches the
                // document row's leftMargin so top-level items line up with
                // the filename.
                property int indentPx: 12 + modelData.depth * 14

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: delegate.indentPx
                    anchors.rightMargin: 8
                    spacing: 4

                    // Expand/collapse caret — only for containers with kids.
                    // `z: 5` lifts it above the outer row MouseArea so the
                    // caret's own MouseArea is the one that receives clicks
                    // (without this the whole-delegate MouseArea swallowed
                    // the event and the caret looked inert).
                    Rectangle {
                        z: 5
                        width: 14; height: 20
                        color: caretArea.containsMouse ? Theme.hover : "transparent"
                        radius: 3
                        Text {
                            anchors.centerIn: parent
                            text: modelData.hasChildren
                                  ? (modelData.isExpanded ? "\u25BE" : "\u25B8")  // ▾/▸
                                  : ""
                            font.pixelSize: 10
                            color: Theme.textSec
                        }
                        MouseArea {
                            id: caretArea
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: modelData.hasChildren
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var cp = panel.expanded
                                cp[modelData.name] = !(cp[modelData.name] !== false)
                                panel.expanded = cp
                                treeView.refresh()
                            }
                        }
                    }

                    // Color indicator bar
                    Rectangle {
                        width: 3; height: 18; radius: 1.5
                        color: delegate.fColor
                    }

                    // Feature icon — label-aware so the three axes read as
                    // arrow-glyphs in their axis colours and the base planes
                    // share the perspective quadrilateral glyph.
                    Text {
                        text: Theme.featureIconByLabel(modelData.typeName, modelData.label)
                        font.pixelSize: 12
                        color: delegate.fColor
                    }

                    // Feature name — switches to inline TextField when renaming
                    Text {
                        text: modelData.label || modelData.name
                        font.pixelSize: Theme.fontBase
                        font.bold: delegate.isSelected
                        color: Theme.text
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        visible: panel.renamingName !== modelData.name
                    }
                    TextField {
                        id: renameField
                        visible: panel.renamingName === modelData.name
                        Layout.fillWidth: true
                        text: modelData.label || modelData.name
                        font.pixelSize: Theme.fontBase
                        height: 22
                        selectByMouse: true
                        background: Rectangle { radius: 3; color: "#F5F3FF"; border.width: 1; border.color: Theme.accent }
                        onAccepted: { cadEngine.renameFeature(modelData.name, text); panel.renamingName = "" }
                        onActiveFocusChanged: if (!activeFocus) panel.renamingName = ""
                        Keys.onEscapePressed: panel.renamingName = ""
                        Component.onCompleted: if (visible) { forceActiveFocus(); selectAll() }
                        onVisibleChanged: if (visible) { forceActiveFocus(); selectAll() }
                    }

                    // "+" quick-action button for Body rows — gives the
                    // user a discoverable entry point for common ops
                    // (New Sketch, Add Datum Plane) without going through
                    // right-click. Only shown on the Body container row.
                    Rectangle {
                        z: 5
                        visible: modelData.typeName === "PartDesign::Body" ||
                                 modelData.typeName === "App::Part"
                        Layout.preferredWidth: 20; Layout.preferredHeight: 18
                        radius: 9
                        color: plusArea.containsMouse ? Theme.accent : Theme.accentLight
                        border.color: Theme.accent; border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: "+"
                            font.pixelSize: 13; font.bold: true
                            color: plusArea.containsMouse ? "white" : Theme.accent
                        }
                        MouseArea {
                            id: plusArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: bodyQuickMenu.popup()
                        }
                        ToolTip.text: "Quick actions"
                        ToolTip.visible: plusArea.containsMouse
                        ToolTip.delay: 400
                    }

                    // Type badge (always visible, compact)
                    Rectangle {
                        width: typeBadge.implicitWidth + 8
                        height: 16; radius: 3
                        color: Qt.rgba(delegate.fColor.r, delegate.fColor.g, delegate.fColor.b, 0.12)

                        Text {
                            id: typeBadge; anchors.centerIn: parent
                            text: Theme.shortTypeName(modelData.typeName)
                            font.pixelSize: 8; font.bold: true
                            color: delegate.fColor
                        }
                    }
                }

                MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton

                    onClicked: function(mouse) {
                        panel.selectedIndex = index
                        if (mouse.button === Qt.RightButton) {
                            contextMenu.targetIndex = index
                            contextMenu.targetName = modelData.name
                            contextMenu.targetType = modelData.typeName
                            contextMenu.popup(mouse.x, mouse.y)
                        }
                    }
                    onDoubleClicked: {
                        var t = modelData.typeName
                        if (t.indexOf("Sketch") >= 0) {
                            sketchDoubleClicked(modelData.name)
                        }
                        // Datum plane under Origin → start a sketch on it.
                        // UX-016: XY/XZ/YZ_Plane double-click creates a sketch
                        // on that plane (matches FreeCAD / SolidWorks behaviour).
                        else if (t === "App::Plane") {
                            var pt = panel.planeTypeForName(modelData.label, modelData.name)
                            if (pt >= 0) planeDoubleClicked(modelData.name, pt)
                        }
                        // Editable PartDesign features → task panel.
                        else if (t.indexOf("Pad") >= 0 || t.indexOf("Pocket") >= 0 ||
                                 t.indexOf("Revolution") >= 0 || t.indexOf("Groove") >= 0) {
                            featureEditRequested(modelData.name, t)
                        }
                        // Container (Body/Origin) → toggle expansion.
                        else if (modelData.hasChildren) {
                            var cp = panel.expanded
                            cp[modelData.name] = !(cp[modelData.name] !== false)
                            panel.expanded = cp
                            treeView.refresh()
                        }
                    }
                }

                // Bottom separator
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.leftMargin: delegate.indentPx
                    height: 1; color: Theme.divider
                }
            }

            // Empty state
            Column {
                anchors.centerIn: parent
                visible: treeView.count === 0
                spacing: 8

                Text {
                    text: "\u25A1"   // □ empty box
                    font.pixelSize: 32; color: Theme.textTer
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    text: "No features yet"
                    color: Theme.textTer; font.pixelSize: Theme.fontBase; font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    text: "Create a Sketch to start"
                    color: Theme.textTer; font.pixelSize: Theme.fontSm
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }

        // ── Footer ──────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true; height: 24
            color: Theme.panelAlt
            visible: cadEngine.featureTree.length > 0

            Rectangle {
                anchors.top: parent.top; width: parent.width; height: 1
                color: Theme.borderLight
            }

            Text {
                anchors.centerIn: parent
                text: cadEngine.featureTree.length + " feature" + (cadEngine.featureTree.length !== 1 ? "s" : "")
                font.pixelSize: Theme.fontSm
                color: Theme.textTer
            }
        }
    }

    // ── Rename inline editor ───────────────────────────────────────
    property string renamingName: ""

    // ── Context Menu ────────────────────────────────────────────────
    Menu {
        id: contextMenu
        property int targetIndex: -1
        property string targetName: ""
        property string targetType: ""

        // ── Type-specific primary action ────────────────────────────
        MenuItem {
            text: "Edit Sketch"
            visible: contextMenu.targetType.indexOf("Sketch") >= 0
            height: visible ? implicitHeight : 0
            onTriggered: sketchDoubleClicked(contextMenu.targetName)
        }
        MenuItem {
            text: "Edit Feature…"
            visible: contextMenu.targetType.indexOf("Pad") >= 0 ||
                     contextMenu.targetType.indexOf("Pocket") >= 0 ||
                     contextMenu.targetType.indexOf("Revolution") >= 0 ||
                     contextMenu.targetType.indexOf("Groove") >= 0
            height: visible ? implicitHeight : 0
            onTriggered: featureEditRequested(contextMenu.targetName, contextMenu.targetType)
        }
        MenuItem {
            text: "Start Sketch on this Plane"
            visible: contextMenu.targetType === "App::Plane"
            height: visible ? implicitHeight : 0
            onTriggered: {
                var pt = panel.planeTypeForName("", contextMenu.targetName)
                if (pt < 0) {
                    // Fall back on the label (e.g. "XY_Plane")
                    var raw = cadEngine.featureTree
                    for (var i = 0; i < raw.length; i++) {
                        if (raw[i].name === contextMenu.targetName) {
                            pt = panel.planeTypeForName(raw[i].label, raw[i].name); break
                        }
                    }
                }
                if (pt >= 0) planeDoubleClicked(contextMenu.targetName, pt)
            }
        }

        MenuSeparator {}

        // ── Visibility ──────────────────────────────────────────────
        MenuItem {
            text: cadEngine.isFeatureVisible(contextMenu.targetName)
                  ? "Hide" : "Show"
            enabled: contextMenu.targetType !== ""
            onTriggered: {
                cadEngine.toggleFeatureVisibility(contextMenu.targetName)
                treeView.refresh()
            }
        }

        MenuSeparator {}

        // ── Structure actions (always available) ────────────────────
        MenuItem {
            text: "New Sketch\u2026"
            onTriggered: panel.newSketchRequested()
        }
        MenuItem {
            text: "Add Datum Plane\u2026"
            onTriggered: panel.newDatumPlaneRequested()
        }

        MenuSeparator {}

        // ── Generic actions ─────────────────────────────────────────
        MenuItem {
            text: "Rename"
            // Containers and Origin children are internal — renaming them
            // breaks FreeCAD's link resolution.
            enabled: contextMenu.targetType.indexOf("Body") < 0 &&
                     contextMenu.targetType.indexOf("Origin") < 0 &&
                     contextMenu.targetType !== "App::Plane" &&
                     contextMenu.targetType !== "App::Line" &&
                     contextMenu.targetType !== "App::Point"
            onTriggered: panel.renamingName = contextMenu.targetName
        }
        MenuItem {
            text: "Delete"
            // Body + Origin children are structural — deleting them orphans
            // every feature beneath. Disable to prevent footgun.
            enabled: contextMenu.targetType.indexOf("Body") < 0 &&
                     contextMenu.targetType.indexOf("Origin") < 0 &&
                     contextMenu.targetType !== "App::Plane" &&
                     contextMenu.targetType !== "App::Line" &&
                     contextMenu.targetType !== "App::Point"
            onTriggered: {
                // Warn if this feature has downstream dependents — deleting
                // orphans them (Pad → Fillet chain breaks etc.).
                var deps = cadEngine.featureDependents(contextMenu.targetName)
                if (deps.length > 0) {
                    deleteWarnDialog.depNames = deps.join(", ")
                    deleteWarnDialog.targetName = contextMenu.targetName
                    deleteWarnDialog.open()
                } else {
                    cadEngine.deleteFeature(contextMenu.targetName)
                }
            }
        }
    }

    // Quick-action menu triggered by the "+" button on the Body row
    Menu {
        id: bodyQuickMenu
        MenuItem {
            text: "New Sketch\u2026"
            onTriggered: panel.newSketchRequested()
        }
        MenuItem {
            text: "Add Datum Plane\u2026"
            onTriggered: panel.newDatumPlaneRequested()
        }
    }

    // Dependency-aware delete confirmation
    Dialog {
        id: deleteWarnDialog
        property string depNames: ""
        property string targetName: ""
        title: "Delete feature with dependents?"
        standardButtons: Dialog.Yes | Dialog.Cancel
        modal: true
        anchors.centerIn: Overlay.overlay

        Text {
            width: 320
            wrapMode: Text.Wrap
            color: Theme.text
            text: "'" + deleteWarnDialog.targetName + "' is used by: " +
                  deleteWarnDialog.depNames +
                  ".\n\nDeleting it will leave those features broken until you reassign their base.\n\nProceed?"
        }
        onAccepted: cadEngine.deleteFeature(deleteWarnDialog.targetName)
    }
}
