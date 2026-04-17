import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/**
 * FeatureDialog — Popup for creating 3D features (Pad, Pocket, Revolution).
 * Configurable via featureType property: "pad", "pocket", "revolve".
 * User selects a sketch and enters a dimensional value (length/depth/angle).
 */
Popup {
    id: dialog
    width: 340
    padding: 0
    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    x: (mainWindow.width - width) / 2
    y: (mainWindow.height - height) / 2

    property string featureType: "pad"  // "pad", "pocket", "revolve", "groove"

    signal featureCreated(string featureName)

    // Config derived from featureType
    readonly property var config: {
        "pad":     { title: "Pad (Extrude)",   color: "#16A34A", icon: "\u2B06", label: "Length", unit: "mm", defaultVal: "10.0" },
        "pocket":  { title: "Pocket",          color: "#DC2626", icon: "\u2B07", label: "Depth",  unit: "mm", defaultVal: "5.0" },
        "revolve": { title: "Revolution",      color: "#2563EB", icon: "\u21BB", label: "Angle",  unit: "\u00B0",  defaultVal: "360.0" },
        "groove":  { title: "Groove",          color: "#9333EA", icon: "\u21BB", label: "Angle",  unit: "\u00B0",  defaultVal: "360.0" }
    }
    readonly property var cfg: config[featureType] || config["pad"]

    background: Rectangle {
        radius: 10; color: "#FFFFFF"
        border.width: 2; border.color: dialog.cfg.color

        // Shadow
        Rectangle {
            anchors.fill: parent; anchors.margins: -4
            z: -1; radius: 14; color: Qt.rgba(0, 0, 0, 0.12)
        }
    }

    contentItem: ColumnLayout {
        spacing: 0

        // Header
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 44; radius: 10
            color: dialog.cfg.color
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 12; color: parent.color }

            RowLayout {
                anchors.centerIn: parent; spacing: 8
                Text { text: dialog.cfg.icon; font.pixelSize: 18; color: "white" }
                Text { text: dialog.cfg.title; font.pixelSize: 15; font.bold: true; color: "white" }
            }
        }

        // Body
        ColumnLayout {
            spacing: 12
            Layout.fillWidth: true
            Layout.topMargin: 16; Layout.bottomMargin: 12
            Layout.leftMargin: 16; Layout.rightMargin: 16

            // Sketch selection
            ColumnLayout {
                spacing: 4; Layout.fillWidth: true

                Text { text: "Profile Sketch"; font.pixelSize: 12; font.bold: true; color: "#374151" }

                ComboBox {
                    id: sketchCombo
                    Layout.fillWidth: true
                    model: cadEngine.sketchNames
                    currentIndex: cadEngine.sketchNames.length > 0 ? cadEngine.sketchNames.length - 1 : -1

                    background: Rectangle {
                        radius: 6
                        color: sketchCombo.down ? "#F3F4F6" : "#FAFAFA"
                        border.width: 1; border.color: sketchCombo.activeFocus ? dialog.cfg.color : "#D1D5DB"
                    }
                }

                Text {
                    visible: cadEngine.sketchNames.length === 0
                    text: "No sketches available. Create a sketch first."
                    font.pixelSize: 11; font.italic: true; color: "#EF4444"
                }
            }

            // Value input
            ColumnLayout {
                spacing: 4; Layout.fillWidth: true

                Text { text: dialog.cfg.label; font.pixelSize: 12; font.bold: true; color: "#374151" }

                RowLayout {
                    spacing: 8; Layout.fillWidth: true

                    TextField {
                        id: valueField
                        Layout.fillWidth: true
                        text: dialog.cfg.defaultVal
                        font.pixelSize: 14; font.family: "monospace"
                        horizontalAlignment: Text.AlignRight
                        selectByMouse: true
                        validator: DoubleValidator { bottom: 0.001; decimals: 4 }

                        background: Rectangle {
                            radius: 6
                            color: valueField.activeFocus ? Qt.rgba(Qt.color(dialog.cfg.color).r, Qt.color(dialog.cfg.color).g, Qt.color(dialog.cfg.color).b, 0.05) : "#F9FAFB"
                            border.width: valueField.activeFocus ? 2 : 1
                            border.color: valueField.activeFocus ? dialog.cfg.color : "#D1D5DB"
                        }

                        onAccepted: applyFeature()
                    }

                    Text {
                        text: dialog.cfg.unit
                        font.pixelSize: 13; font.bold: true; color: "#6B7280"
                    }
                }
            }

            // Symmetric option for pad
            CheckBox {
                id: symmetricCheck
                visible: dialog.featureType === "pad"
                text: "Symmetric (both sides)"
                font.pixelSize: 11
                checked: false
            }

            // Buttons
            RowLayout {
                spacing: 8; Layout.fillWidth: true; Layout.topMargin: 4

                Button {
                    text: "Cancel"; flat: true
                    Layout.fillWidth: true
                    onClicked: dialog.close()
                }

                Button {
                    text: "Create"
                    highlighted: true
                    enabled: valueField.acceptableInput && sketchCombo.currentIndex >= 0
                    Layout.fillWidth: true
                    onClicked: applyFeature()

                    palette.button: dialog.cfg.color
                    palette.brightText: "white"
                }
            }
        }
    }

    function applyFeature() {
        var val = parseFloat(valueField.text)
        if (isNaN(val) || val <= 0) return
        if (sketchCombo.currentIndex < 0) return

        var sketchName = cadEngine.sketchNames[sketchCombo.currentIndex]
        var result = ""

        if (featureType === "pad") {
            result = cadEngine.pad(sketchName, val)
        } else if (featureType === "pocket") {
            result = cadEngine.pocket(sketchName, val)
        } else if (featureType === "revolve") {
            result = cadEngine.revolution(sketchName, val)
        } else if (featureType === "groove") {
            result = cadEngine.groove(sketchName, val)
        }

        if (result !== "") {
            featureCreated(result)
        }
        dialog.close()
    }

    onOpened: {
        valueField.text = cfg.defaultVal
        valueField.forceActiveFocus()
        valueField.selectAll()
    }
}
