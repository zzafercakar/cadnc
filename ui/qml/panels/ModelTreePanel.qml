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

    property int selectedIndex: -1

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

        // ── Document origin row ─────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true; height: 30
            color: Theme.panelAlt
            visible: cadEngine.featureTree.length > 0

            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 8
                spacing: 6

                Text { text: "\u25BC"; font.pixelSize: 8; color: Theme.textSec }
                Rectangle {
                    width: 16; height: 16; radius: 3
                    color: Theme.accentLight
                    Text { anchors.centerIn: parent; text: "\u25A3"; font.pixelSize: 10; color: Theme.accent }
                }
                Text {
                    text: cadEngine.documentName || "Untitled"
                    font.pixelSize: Theme.fontBase; font.bold: true
                    color: Theme.text; Layout.fillWidth: true
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

            model: cadEngine.featureTree

            delegate: Rectangle {
                id: delegate
                width: treeView.width
                height: 34
                color: {
                    if (panel.selectedIndex === index) return Theme.selected
                    if (mouseArea.containsMouse) return Theme.hover
                    return "transparent"
                }

                property bool isSelected: panel.selectedIndex === index
                property color fColor: Theme.featureColor(modelData.typeName)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 20  // indented under document
                    anchors.rightMargin: 8
                    spacing: 6

                    // Color indicator bar
                    Rectangle {
                        width: 3; height: 20; radius: 1.5
                        color: delegate.fColor
                    }

                    // Feature icon
                    Text {
                        text: Theme.featureIcon(modelData.typeName)
                        font.pixelSize: 13
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
                        if (modelData.typeName.indexOf("Sketch") >= 0) {
                            sketchDoubleClicked(modelData.name)
                        }
                    }
                }

                // Bottom separator
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.leftMargin: 20
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

        MenuItem {
            text: "Edit Sketch"
            enabled: contextMenu.targetType.indexOf("Sketch") >= 0
            onTriggered: sketchDoubleClicked(contextMenu.targetName)
        }
        MenuSeparator {}
        MenuItem {
            text: "Rename"
            onTriggered: {
                panel.renamingName = contextMenu.targetName
            }
        }
        MenuItem {
            text: "Delete"
            onTriggered: cadEngine.deleteFeature(contextMenu.targetName)
        }
    }
}
