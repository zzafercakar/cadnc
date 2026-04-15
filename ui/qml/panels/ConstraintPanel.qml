import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/**
 * ConstraintPanel — Right sidebar showing active sketch constraints.
 * Purple-themed with Canvas-drawn constraint icons.
 */
Rectangle {
    id: panel
    color: "#FFFFFF"
    border.width: 1
    border.color: "#C8CDD6"

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 0
        spacing: 0

        // ── Header ──────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 36
            color: "#F5F3FF"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 8
                spacing: 6

                Rectangle {
                    width: 20; height: 20; radius: 4
                    color: "#EDE9FE"
                    Text {
                        anchors.centerIn: parent
                        text: "\u26D3"  // chain
                        font.pixelSize: 11
                    }
                }

                Text {
                    text: "Constraints"
                    font.pixelSize: 13
                    font.bold: true
                    color: "#1F2937"
                    Layout.fillWidth: true
                }

                Rectangle {
                    visible: cadEngine.sketchConstraints.length > 0
                    width: cntLabel.implicitWidth + 10
                    height: 18
                    radius: 9
                    color: "#EDE9FE"
                    border.width: 1
                    border.color: "#C4B5FD"

                    Text {
                        id: cntLabel
                        anchors.centerIn: parent
                        text: cadEngine.sketchConstraints.length
                        font.pixelSize: 10
                        font.bold: true
                        color: "#7C3AED"
                    }
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width; height: 1
                color: "#C8CDD6"
            }
        }

        // ── Constraint list ─────────────────────────────────────────
        ListView {
            id: listView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: cadEngine.sketchConstraints

            delegate: Rectangle {
                width: listView.width
                height: 34
                color: delMouse.containsMouse ? "#F5F3FF" : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 8
                    spacing: 6

                    // Constraint type color dot
                    Rectangle {
                        width: 8; height: 8; radius: 4
                        color: modelData.isDriving ? "#7C3AED" : "#D4D4D8"
                    }

                    // Type name
                    Text {
                        text: modelData.typeName
                        font.pixelSize: 11
                        font.bold: true
                        color: "#374151"
                        Layout.preferredWidth: 80
                    }

                    // Value (if dimensional)
                    Text {
                        visible: modelData.value !== 0
                        text: modelData.value.toFixed(2)
                        font.pixelSize: 11
                        font.family: "monospace"
                        color: modelData.isDriving ? "#059669" : "#D97706"
                    }

                    // Driving indicator
                    Text {
                        visible: !modelData.isDriving
                        text: "(ref)"
                        font.pixelSize: 9
                        color: "#9CA3AF"
                    }

                    Item { Layout.fillWidth: true }

                    // Geo reference
                    Text {
                        text: "G" + modelData.firstGeoId
                        font.pixelSize: 9
                        font.family: "monospace"
                        color: "#9CA3AF"
                    }

                    // Delete button (hover reveal)
                    Rectangle {
                        visible: delMouse.containsMouse
                        width: 20; height: 20; radius: 4
                        color: delBtnMouse.containsMouse ? "#FEE2E2" : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "\u00D7"
                            font.pixelSize: 14
                            color: "#DC2626"
                        }

                        MouseArea {
                            id: delBtnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: cadEngine.removeConstraint(modelData.id)
                        }
                    }
                }

                MouseArea {
                    id: delMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    propagateComposedEvents: true
                    onClicked: function(mouse) { mouse.accepted = false }
                    onPressed: function(mouse) { mouse.accepted = false }
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.leftMargin: 12
                    height: 1; color: "#F3F4F6"
                }
            }

            // Empty state
            Label {
                anchors.centerIn: parent
                visible: listView.count === 0
                text: cadEngine.sketchActive ? "No constraints\nAdd H, V, or Dim" : "No active sketch"
                color: "#9CA3AF"
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
            }
        }

        // ── Footer ──────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 24
            color: "#F9FAFB"

            Rectangle { width: parent.width; height: 1; color: "#E5E7EB" }

            Text {
                anchors.centerIn: parent
                text: cadEngine.sketchConstraints.length + " constraint(s)"
                font.pixelSize: 10
                color: "#6B7280"
            }
        }
    }
}
