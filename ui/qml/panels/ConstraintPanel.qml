import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".."

/**
 * ConstraintPanel — Constraint list for active sketch.
 * Shows constraint type, value, driving/reference status.
 */
Rectangle {
    id: panel
    color: Theme.panel

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 0
        spacing: 0

        // ── Header ──────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true; height: 36
            color: Qt.rgba(Theme.cstrDriving.r, Theme.cstrDriving.g, Theme.cstrDriving.b, 0.06)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12; anchors.rightMargin: 8
                spacing: 6

                Rectangle {
                    width: 20; height: 20; radius: 4
                    color: Qt.rgba(Theme.cstrDriving.r, Theme.cstrDriving.g, Theme.cstrDriving.b, 0.15)
                    Text {
                        anchors.centerIn: parent
                        text: "\u26D3"
                        font.pixelSize: 11
                    }
                }

                Text {
                    text: "Constraints"
                    font.pixelSize: Theme.fontMd
                    font.bold: true
                    color: Theme.text
                    Layout.fillWidth: true
                }

                Rectangle {
                    visible: cadEngine.sketchActive
                    width: cCountLabel.implicitWidth + 10
                    height: 18; radius: 9
                    color: Qt.rgba(Theme.cstrDriving.r, Theme.cstrDriving.g, Theme.cstrDriving.b, 0.12)
                    border.width: 1
                    border.color: Qt.rgba(Theme.cstrDriving.r, Theme.cstrDriving.g, Theme.cstrDriving.b, 0.3)

                    Text {
                        id: cCountLabel; anchors.centerIn: parent
                        text: cadEngine.sketchConstraints.length
                        font.pixelSize: Theme.fontSm; font.bold: true
                        color: Theme.cstrDriving
                    }
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width; height: 1
                color: Theme.border
            }
        }

        // ── Constraint list ─────────────────────────────────────────
        ListView {
            id: constraintList
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true
            model: cadEngine.sketchConstraints

            delegate: Rectangle {
                id: cDelegate
                width: constraintList.width; height: editMode ? 52 : 34
                color: cMouseArea.containsMouse ? Theme.hover : "transparent"

                property bool isDriving: modelData.isDriving !== false
                property color cColor: isDriving ? Theme.cstrDriving : Theme.cstrRef
                property bool hasDatum: modelData.value !== undefined && modelData.value !== 0
                property bool editMode: false

                RowLayout {
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.leftMargin: 12; anchors.rightMargin: 8
                    height: 34; spacing: 6

                    // Driving toggle dot — click to toggle driving/reference
                    Rectangle {
                        width: 8; height: 8; radius: 4
                        color: cColor
                        MouseArea {
                            anchors.fill: parent; anchors.margins: -4
                            cursorShape: Qt.PointingHandCursor
                            onClicked: cadEngine.toggleDriving(modelData.id)
                            ToolTip.text: isDriving ? "Make reference" : "Make driving"
                            ToolTip.visible: containsMouse; ToolTip.delay: 300
                            hoverEnabled: true
                        }
                    }

                    // Constraint type icon
                    Image {
                        width: 16; height: 16
                        sourceSize: Qt.size(16, 16)
                        opacity: isDriving ? 0.85 : 0.45
                        source: {
                            var t = modelData.typeName || ""
                            if (t === "Coincident") return "qrc:/resources/icons/constraint/coincident.svg"
                            if (t === "Horizontal") return "qrc:/resources/icons/constraint/horiz.svg"
                            if (t === "Vertical") return "qrc:/resources/icons/constraint/vert.svg"
                            if (t === "Parallel") return "qrc:/resources/icons/constraint/parallel.svg"
                            if (t === "Perpendicular") return "qrc:/resources/icons/constraint/perp.svg"
                            if (t === "Tangent") return "qrc:/resources/icons/constraint/tangent.svg"
                            if (t === "Equal") return "qrc:/resources/icons/constraint/equal.svg"
                            if (t === "Fixed") return "qrc:/resources/icons/constraint/fixed.svg"
                            if (t === "Distance" || t === "DistanceX" || t === "DistanceY") return "qrc:/resources/icons/constraint/distance.svg"
                            if (t === "Angle") return "qrc:/resources/icons/constraint/angle.svg"
                            if (t === "Radius" || t === "Diameter") return "qrc:/resources/icons/constraint/radius.svg"
                            if (t === "Symmetric") return "qrc:/resources/icons/constraint/symmetric.svg"
                            if (t === "PointOnObject") return "qrc:/resources/icons/constraint/midpoint.svg"
                            return "qrc:/resources/icons/constraint/fixed.svg"
                        }
                    }

                    Text {
                        text: modelData.typeName || "Constraint"
                        font.pixelSize: Theme.fontBase
                        font.bold: isDriving
                        color: Theme.text
                        Layout.fillWidth: true
                    }

                    // Clickable datum value — click to enter edit mode
                    Rectangle {
                        visible: hasDatum
                        width: datumLabel.implicitWidth + 8; height: 18; radius: 3
                        color: datumArea.containsMouse ? Qt.rgba(cColor.r, cColor.g, cColor.b, 0.15) : "transparent"

                        Text {
                            id: datumLabel; anchors.centerIn: parent
                            text: modelData.value !== undefined ? modelData.value.toFixed(2) : ""
                            font.pixelSize: Theme.fontSm; font.family: Theme.fontMono
                            color: isDriving ? Theme.success : Theme.warning
                        }
                        MouseArea {
                            id: datumArea; anchors.fill: parent
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { cDelegate.editMode = true; datumField.text = modelData.value.toFixed(4); datumField.forceActiveFocus(); datumField.selectAll() }
                        }
                    }

                    Text {
                        visible: !isDriving
                        text: "(ref)"
                        font.pixelSize: Theme.fontXs; font.italic: true
                        color: Theme.textTer
                    }

                    Text {
                        text: "G" + (modelData.firstGeoId !== undefined ? modelData.firstGeoId : "?")
                        font.pixelSize: Theme.fontXs; font.family: Theme.fontMono
                        color: Theme.textTer
                    }

                    Rectangle {
                        width: 18; height: 18; radius: 3
                        visible: cMouseArea.containsMouse
                        color: delArea.containsMouse ? Theme.dangerBg : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "\u2715"; font.pixelSize: 10
                            color: delArea.containsMouse ? Theme.danger : Theme.textTer
                        }
                        MouseArea {
                            id: delArea; anchors.fill: parent
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: cadEngine.removeConstraint(modelData.id)
                        }
                    }
                }

                // Inline datum editor — appears below constraint row when editMode=true
                Row {
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.topMargin: 34
                    anchors.leftMargin: 20; anchors.rightMargin: 8
                    visible: editMode; spacing: 4; height: 18

                    TextField {
                        id: datumField; width: 80; height: 18
                        font.pixelSize: 11; font.family: Theme.fontMono
                        horizontalAlignment: Text.AlignRight
                        validator: DoubleValidator { bottom: 0.001; decimals: 4 }
                        background: Rectangle { radius: 3; color: "#F5F3FF"; border.width: 1; border.color: Theme.cstrDriving }
                        onAccepted: { cadEngine.setDatum(modelData.id, parseFloat(text)); cDelegate.editMode = false }
                        onActiveFocusChanged: if (!activeFocus) cDelegate.editMode = false
                        Keys.onEscapePressed: cDelegate.editMode = false
                    }

                    Text { text: "mm"; font.pixelSize: 10; color: Theme.textTer; anchors.verticalCenter: parent.verticalCenter }
                }

                MouseArea {
                    id: cMouseArea; anchors.fill: parent
                    hoverEnabled: true; z: -1
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.leftMargin: 12; height: 1; color: Theme.divider
                }
            }

            Column {
                anchors.centerIn: parent
                visible: constraintList.count === 0
                spacing: 4

                Text {
                    text: cadEngine.sketchActive ? "No constraints" : "No active sketch"
                    font.pixelSize: Theme.fontBase; font.italic: true
                    color: Theme.textTer
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    visible: cadEngine.sketchActive
                    text: "Press H, V, or D to add"
                    font.pixelSize: Theme.fontSm; color: Theme.textTer
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true; height: 24
            color: Theme.panelAlt; visible: cadEngine.sketchActive

            Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: Theme.borderLight }

            Text {
                anchors.centerIn: parent
                text: cadEngine.sketchConstraints.length + " constraint" + (cadEngine.sketchConstraints.length !== 1 ? "s" : "")
                font.pixelSize: Theme.fontSm; color: Theme.textTer
            }
        }
    }
}
