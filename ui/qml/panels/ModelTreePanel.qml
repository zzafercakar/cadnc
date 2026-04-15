import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/**
 * ModelTreePanel — Left sidebar showing document feature tree.
 * Color-coded by feature type, double-click to edit.
 */
Rectangle {
    id: panel
    color: "#FFFFFF"
    border.width: 1
    border.color: "#C8CDD6"

    signal sketchDoubleClicked(string name)

    function featureColor(typeName) {
        if (typeName.indexOf("Sketch") >= 0) return "#059669"
        if (typeName.indexOf("Pad") >= 0) return "#16A34A"
        if (typeName.indexOf("Pocket") >= 0) return "#DC2626"
        if (typeName.indexOf("Revolution") >= 0) return "#2563EB"
        if (typeName.indexOf("Fillet") >= 0) return "#7C3AED"
        if (typeName.indexOf("Chamfer") >= 0) return "#7C3AED"
        return "#64748B"
    }

    function featureIcon(typeName) {
        if (typeName.indexOf("Sketch") >= 0) return "\u270E"    // pencil
        if (typeName.indexOf("Pad") >= 0) return "\u2B06"       // up arrow
        if (typeName.indexOf("Pocket") >= 0) return "\u2B07"    // down arrow
        if (typeName.indexOf("Revolution") >= 0) return "\u27F3" // rotate
        return "\u25CF"                                           // circle
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 0
        spacing: 0

        // ── Header ──────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 36
            color: "#F4F5F8"
            border.width: 0

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 8
                spacing: 6

                Rectangle {
                    width: 20; height: 20; radius: 4
                    color: "#DBEAFE"
                    Text {
                        anchors.centerIn: parent
                        text: "\uD83D\uDCC1"
                        font.pixelSize: 12
                    }
                }

                Text {
                    text: "Model Tree"
                    font.pixelSize: 13
                    font.bold: true
                    color: "#111827"
                    Layout.fillWidth: true
                }

                // Feature count badge
                Rectangle {
                    visible: cadEngine.featureTree.length > 0
                    width: countLabel.implicitWidth + 10
                    height: 18
                    radius: 9
                    color: "#EFF6FF"
                    border.width: 1
                    border.color: "#BFDBFE"

                    Text {
                        id: countLabel
                        anchors.centerIn: parent
                        text: cadEngine.featureTree.length
                        font.pixelSize: 10
                        font.bold: true
                        color: "#2563EB"
                    }
                }
            }

            // Bottom border
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width; height: 1
                color: "#C8CDD6"
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
                width: treeView.width
                height: 34
                color: mouseArea.containsMouse ? "#F0F4FF" : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 8
                    spacing: 8

                    // Color indicator
                    Rectangle {
                        width: 4; height: 22; radius: 2
                        color: featureColor(modelData.typeName)
                    }

                    // Feature icon
                    Text {
                        text: featureIcon(modelData.typeName)
                        font.pixelSize: 14
                        color: featureColor(modelData.typeName)
                    }

                    // Feature name
                    Text {
                        text: modelData.label || modelData.name
                        font.pixelSize: 12
                        color: "#1F2937"
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    // Type badge
                    Rectangle {
                        visible: mouseArea.containsMouse
                        width: typeLabel.implicitWidth + 8
                        height: 16
                        radius: 3
                        color: Qt.lighter(featureColor(modelData.typeName), 1.8)

                        Text {
                            id: typeLabel
                            anchors.centerIn: parent
                            text: {
                                var t = modelData.typeName
                                if (t.indexOf("::") >= 0) t = t.split("::").pop()
                                return t
                            }
                            font.pixelSize: 9
                            color: featureColor(modelData.typeName)
                        }
                    }
                }

                MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    hoverEnabled: true
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
                    anchors.leftMargin: 12
                    height: 1
                    color: "#F3F4F6"
                }
            }

            // Empty state
            Label {
                anchors.centerIn: parent
                visible: treeView.count === 0
                text: "No features yet\nCreate a Sketch to start"
                color: "#9CA3AF"
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
