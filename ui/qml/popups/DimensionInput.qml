import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/**
 * DimensionInput — Floating popup for entering constraint values.
 * Purple-bordered, clean layout with type selector.
 */
Popup {
    id: popup
    width: 260
    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    property int targetGeoId: -1
    property string presetType: ""  // "distance", "radius", "angle" — set before open()
    signal valueAccepted(string constraintType, double value)

    background: Rectangle {
        radius: 8
        color: "#FFFFFF"
        border.width: 2
        border.color: "#8B5CF6"

        // Drop shadow simulation
        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 2
            anchors.leftMargin: 2
            radius: 8
            color: "#00000015"
            z: -1
        }
    }

    contentItem: ColumnLayout {
        spacing: 12

        // Header
        Text {
            text: "Smart Dimension"
            font.pixelSize: 14
            font.bold: true
            color: "#1F2937"
        }

        // Type selector
        RowLayout {
            spacing: 8
            Layout.fillWidth: true

            Repeater {
                model: [
                    { label: "Distance", type: "distance", color: "#2563EB" },
                    { label: "Radius", type: "radius", color: "#059669" },
                    { label: "Angle", type: "angle", color: "#D97706" }
                ]

                Rectangle {
                    width: 72; height: 28; radius: 6
                    color: typeSelector.currentIndex === index ? modelData.color : "#F3F4F6"
                    border.width: 1
                    border.color: typeSelector.currentIndex === index ? Qt.darker(modelData.color, 1.2) : "#D1D5DB"

                    Text {
                        anchors.centerIn: parent
                        text: modelData.label
                        font.pixelSize: 11
                        font.bold: typeSelector.currentIndex === index
                        color: typeSelector.currentIndex === index ? "white" : "#4B5563"
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: typeSelector.currentIndex = index
                    }
                }
            }
        }

        // Invisible state holder
        Item {
            id: typeSelector
            property int currentIndex: 0
            property var types: ["distance", "radius", "angle"]
            property var units: ["mm", "mm", "\u00B0"]
        }

        // Value input
        RowLayout {
            spacing: 8
            Layout.fillWidth: true

            TextField {
                id: valueField
                Layout.fillWidth: true
                text: "10.0"
                font.pixelSize: 14
                font.family: "monospace"
                horizontalAlignment: Text.AlignRight
                selectByMouse: true
                validator: DoubleValidator { bottom: 0.001; decimals: 4 }

                background: Rectangle {
                    radius: 4
                    color: valueField.activeFocus ? "#F5F3FF" : "#F9FAFB"
                    border.width: valueField.activeFocus ? 2 : 1
                    border.color: valueField.activeFocus ? "#8B5CF6" : "#D1D5DB"
                }

                Component.onCompleted: selectAll()
                onAccepted: applyValue()
            }

            Text {
                text: typeSelector.units[typeSelector.currentIndex]
                font.pixelSize: 13
                font.bold: true
                color: "#6B7280"
            }
        }

        // Buttons
        RowLayout {
            spacing: 8
            Layout.fillWidth: true

            Button {
                text: "Cancel"
                flat: true
                onClicked: popup.close()
                Layout.fillWidth: true
            }

            Button {
                text: "Apply"
                highlighted: true
                enabled: valueField.acceptableInput
                onClicked: applyValue()
                Layout.fillWidth: true

                palette.button: "#16A34A"
                palette.brightText: "white"
            }
        }
    }

    function applyValue() {
        var val = parseFloat(valueField.text)
        if (isNaN(val) || val <= 0) return
        // If a special preset type is active, use it directly instead of the selector
        if (presetType === "distanceX" || presetType === "distanceY" || presetType === "diameter") {
            valueAccepted(presetType, val)
            popup.close()
            return
        }
        var type = typeSelector.types[typeSelector.currentIndex]
        valueAccepted(type, val)
        popup.close()
    }

    onOpened: {
        // Apply preset type if set by toolbar button
        if (presetType === "radius") typeSelector.currentIndex = 1
        else if (presetType === "angle") typeSelector.currentIndex = 2
        else typeSelector.currentIndex = 0  // default: distance
        // Note: don't clear presetType here — applyValue() needs it for distanceX/distanceY/diameter

        valueField.forceActiveFocus()
        valueField.selectAll()
    }
}
