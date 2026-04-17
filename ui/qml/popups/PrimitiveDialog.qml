import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/**
 * PrimitiveDialog — Popup for creating Part primitives (Box, Cylinder, Sphere, Cone).
 */
Popup {
    id: dialog
    width: 340
    padding: 0
    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    x: (mainWindow.width - width) / 2
    y: (mainWindow.height - height) / 2

    property string primitiveType: "box"  // "box", "cylinder", "sphere", "cone"

    signal featureCreated(string featureName)

    readonly property var config: {
        "box":      { title: "Box",      color: "#D97706", fields: ["Length", "Width", "Height"], units: ["mm","mm","mm"], defaults: ["100","100","100"] },
        "cylinder": { title: "Cylinder", color: "#D97706", fields: ["Radius", "Height"],         units: ["mm","mm"],      defaults: ["50","100"] },
        "sphere":   { title: "Sphere",   color: "#D97706", fields: ["Radius"],                   units: ["mm"],           defaults: ["50"] },
        "cone":     { title: "Cone",     color: "#D97706", fields: ["Radius 1", "Radius 2", "Height"], units: ["mm","mm","mm"], defaults: ["50","0","100"] }
    }
    readonly property var cfg: config[primitiveType] || config["box"]

    background: Rectangle {
        radius: 10; color: "#FFFFFF"
        border.width: 2; border.color: dialog.cfg.color
        Rectangle { anchors.fill: parent; anchors.margins: -4; z: -1; radius: 14; color: Qt.rgba(0,0,0,0.12) }
    }

    contentItem: ColumnLayout {
        spacing: 0

        // Header
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 44; radius: 10
            color: dialog.cfg.color
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 12; color: parent.color }
            Text { anchors.centerIn: parent; text: dialog.cfg.title; font.pixelSize: 15; font.bold: true; color: "white" }
        }

        // Body
        ColumnLayout {
            spacing: 10
            Layout.fillWidth: true
            Layout.topMargin: 16; Layout.bottomMargin: 12
            Layout.leftMargin: 16; Layout.rightMargin: 16

            Repeater {
                model: dialog.cfg.fields.length
                ColumnLayout {
                    spacing: 4; Layout.fillWidth: true
                    Text { text: dialog.cfg.fields[index]; font.pixelSize: 12; font.bold: true; color: "#374151" }
                    RowLayout {
                        spacing: 8; Layout.fillWidth: true
                        TextField {
                            id: fieldInput
                            Layout.fillWidth: true
                            text: dialog.cfg.defaults[index]
                            font.pixelSize: 14; font.family: "monospace"
                            horizontalAlignment: Text.AlignRight
                            selectByMouse: true
                            validator: DoubleValidator { bottom: 0; decimals: 4 }
                            objectName: "field_" + index
                            background: Rectangle {
                                radius: 6; color: fieldInput.activeFocus ? "#FFF7ED" : "#F9FAFB"
                                border.width: fieldInput.activeFocus ? 2 : 1
                                border.color: fieldInput.activeFocus ? dialog.cfg.color : "#D1D5DB"
                            }
                        }
                        Text { text: dialog.cfg.units[index]; font.pixelSize: 13; font.bold: true; color: "#6B7280" }
                    }
                }
            }

            RowLayout {
                spacing: 8; Layout.fillWidth: true; Layout.topMargin: 8
                Button { text: "Cancel"; flat: true; Layout.fillWidth: true; onClicked: dialog.close() }
                Button {
                    text: "Create"; highlighted: true; Layout.fillWidth: true
                    palette.button: dialog.cfg.color; palette.brightText: "white"
                    onClicked: applyPrimitive()
                }
            }
        }
    }

    function getFieldValue(idx) {
        var fields = dialog.contentItem.children[1]  // body ColumnLayout
        var repeater = fields.children[0]  // Repeater
        var item = repeater.itemAt(idx)
        if (!item) return parseFloat(dialog.cfg.defaults[idx])
        // Get TextField from ColumnLayout > RowLayout > TextField
        var row = item.children[1]  // RowLayout
        if (row && row.children[0]) return parseFloat(row.children[0].text)
        return parseFloat(dialog.cfg.defaults[idx])
    }

    function applyPrimitive() {
        var result = ""
        if (primitiveType === "box") {
            result = cadEngine.addBox(getFieldValue(0), getFieldValue(1), getFieldValue(2))
        } else if (primitiveType === "cylinder") {
            result = cadEngine.addCylinder(getFieldValue(0), getFieldValue(1))
        } else if (primitiveType === "sphere") {
            result = cadEngine.addSphere(getFieldValue(0))
        } else if (primitiveType === "cone") {
            result = cadEngine.addCone(getFieldValue(0), getFieldValue(1), getFieldValue(2))
        }
        if (result !== "") featureCreated(result)
        dialog.close()
    }
}
