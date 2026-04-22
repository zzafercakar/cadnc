import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".."

/**
 * PropertiesPanel — Right sidebar showing selected feature properties.
 * SolidWorks/Fusion 360-style parameter inspector.
 * Shows feature type, parameters, and allows inline editing.
 */
Rectangle {
    id: panel
    color: Theme.panel

    property int selectedFeatureIndex: -1

    // Forwarded to Main.qml so the FeatureEditPanel can open in the left
    // column. Same contract as ModelTreePanel's featureEditRequested signal.
    signal featureEditRequested(string name, string typeName)

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
                        text: "\u2699"  // gear
                        font.pixelSize: 12
                    }
                }

                Text {
                    text: "Properties"
                    font.pixelSize: Theme.fontMd
                    font.bold: true
                    color: Theme.text
                    Layout.fillWidth: true
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width; height: 1
                color: Theme.border
            }
        }

        // ── Content ─────────────────────────────────────────────────
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentHeight: contentCol.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: contentCol
                width: parent.width
                spacing: 0

                // ── Document Info ───────────────────────────────────
                PropertySection {
                    title: "Document"
                    visible: !cadEngine.sketchActive

                    PropertyRow { label: "Name"; value: "Untitled" }
                    PropertyRow { label: "Features"; value: cadEngine.featureTree.length.toString() }
                }

                // ── Feature List (compact with actions) ─────────────
                // Each row is a feature card with hover-revealed action
                // buttons (Edit / Rename / Duplicate / Delete). Keeps the
                // common "select then right-click" detour out of the flow —
                // FreeCAD and SolidWorks expose the same actions inline.
                PropertySection {
                    title: "Feature Parameters"
                    visible: cadEngine.featureTree.length > 0 && !cadEngine.sketchActive

                    Repeater {
                        model: cadEngine.featureTree
                        delegate: Rectangle {
                            id: featRow
                            width: contentCol.width
                            height: 34
                            color: featureArea.containsMouse ? Theme.hover : "transparent"

                            // Editable parametric features fit these type strings.
                            property bool isEditable:
                                modelData.typeName.indexOf("Pad") >= 0      ||
                                modelData.typeName.indexOf("Pocket") >= 0   ||
                                modelData.typeName.indexOf("Revolution") >= 0 ||
                                modelData.typeName.indexOf("Groove") >= 0
                            property bool isStructural:
                                modelData.typeName === "App::Origin" ||
                                modelData.typeName === "App::Line"   ||
                                modelData.typeName === "App::Plane"  ||
                                modelData.typeName === "App::Point"

                            MouseArea {
                                id: featureArea
                                anchors.fill: parent
                                hoverEnabled: true
                            }

                            RowLayout {
                                anchors.left: parent.left; anchors.right: parent.right
                                anchors.leftMargin: 12; anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6

                                Rectangle {
                                    Layout.preferredWidth: 4; Layout.preferredHeight: 16
                                    radius: 2
                                    color: Theme.featureColor(modelData.typeName)
                                }
                                Text {
                                    text: Theme.featureIcon(modelData.typeName) + " " + (modelData.label || modelData.name)
                                    font.pixelSize: Theme.fontBase
                                    font.bold: true
                                    color: Theme.text
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                // Action buttons: compact icons, only visible
                                // on hover so the row stays tidy when idle.
                                Row {
                                    spacing: 2
                                    visible: featureArea.containsMouse && !featRow.isStructural

                                    component ActionBtn: Rectangle {
                                        property string glyph: ""
                                        property string tip: ""
                                        signal clicked()
                                        width: 22; height: 22; radius: 3
                                        color: ma.containsMouse ? Theme.accent : "transparent"
                                        border.color: Theme.border; border.width: 1
                                        Text {
                                            anchors.centerIn: parent
                                            text: parent.glyph
                                            font.pixelSize: 11
                                            color: ma.containsMouse ? "white" : Theme.text
                                        }
                                        MouseArea {
                                            id: ma; anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: parent.clicked()
                                        }
                                        ToolTip.text: tip
                                        ToolTip.visible: ma.containsMouse
                                        ToolTip.delay: 500
                                    }
                                    ActionBtn {
                                        glyph: "\u270E"   // ✎ pencil — Edit parameters
                                        tip: "Edit"
                                        visible: featRow.isEditable
                                        onClicked: panel.featureEditRequested(modelData.name, modelData.typeName)
                                    }
                                    ActionBtn {
                                        glyph: "\u2398"   // ⎘ copy
                                        tip: "Duplicate"
                                        onClicked: cadEngine.duplicateFeature(modelData.name)
                                    }
                                    ActionBtn {
                                        glyph: "\u2716"   // ✖ delete
                                        tip: "Delete"
                                        onClicked: cadEngine.deleteFeature(modelData.name)
                                    }
                                }

                                Rectangle {
                                    Layout.preferredWidth: typeText.implicitWidth + 8
                                    Layout.preferredHeight: 16
                                    radius: 3
                                    color: Qt.lighter(Theme.featureColor(modelData.typeName), 1.8)
                                    Text {
                                        id: typeText
                                        anchors.centerIn: parent
                                        text: Theme.shortTypeName(modelData.typeName)
                                        font.pixelSize: Theme.fontXs
                                        color: Theme.featureColor(modelData.typeName)
                                    }
                                }
                            }

                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left; anchors.right: parent.right
                                anchors.leftMargin: 12
                                height: 1; color: Theme.divider
                            }
                        }
                    }
                }

                // ── Sketch Info ─────────────────────────────────────
                PropertySection {
                    title: "Sketch"
                    visible: cadEngine.sketchActive

                    PropertyRow { label: "Geometry"; value: cadEngine.sketchGeometry.length.toString() }
                    PropertyRow { label: "Constraints"; value: cadEngine.sketchConstraints.length.toString() }
                    PropertyRow {
                        label: "Solver"
                        value: cadEngine.solverStatus
                        valueColor: cadEngine.solverStatus === "Fully Constrained" ? Theme.success : Theme.warning
                    }
                }

                // ── Viewport Info ───────────────────────────────────
                // UX-012: Grid control moved to the status bar; only static
                // render info shown here.
                PropertySection {
                    title: "Display"
                    visible: !cadEngine.sketchActive

                    PropertyRow { label: "Render"; value: "OCCT V3d" }
                    PropertyRow { label: "MSAA"; value: "8x" }
                }

                // ── Empty state ─────────────────────────────────────
                Item {
                    visible: cadEngine.featureTree.length === 0 && !cadEngine.sketchActive
                    Layout.fillWidth: true; height: 80

                    Column {
                        anchors.centerIn: parent; spacing: 4
                        Text {
                            text: "No selection"
                            font.pixelSize: Theme.fontBase; font.italic: true
                            color: Theme.textTer
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        Text {
                            text: "Create a feature to see properties"
                            font.pixelSize: Theme.fontSm
                            color: Theme.textTer
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }
            }
        }
    }

    // ── Inline Components ───────────────────────────────────────────

    component PropertySection: ColumnLayout {
        property string title: ""
        Layout.fillWidth: true
        spacing: 0

        Rectangle {
            Layout.fillWidth: true; height: 28
            color: Theme.panelAlt

            Text {
                anchors.left: parent.left; anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: title
                font.pixelSize: Theme.fontSm; font.bold: true; font.letterSpacing: 0.5
                color: Theme.accent
                font.capitalization: Font.AllUppercase
            }

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width; height: 1
                color: Theme.borderLight
            }
        }
    }

    component PropertyRow: Rectangle {
        property string label: ""
        property string value: ""
        property color valueColor: Theme.text

        Layout.fillWidth: true; height: 26
        color: "transparent"

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16; anchors.rightMargin: 12
            spacing: 8

            Text {
                text: label
                font.pixelSize: Theme.fontSm
                color: Theme.textSec
                Layout.preferredWidth: 80
            }
            Text {
                text: value
                font.pixelSize: Theme.fontSm
                font.family: Theme.fontMono
                color: valueColor
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
            }
        }
    }

}
