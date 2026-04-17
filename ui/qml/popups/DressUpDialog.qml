import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/**
 * DressUpDialog — Popup for 3D Fillet and Chamfer (all edges).
 */
Popup {
    id: dialog
    width: 340
    padding: 0
    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    x: (mainWindow.width - width) / 2
    y: (mainWindow.height - height) / 2

    property string dressUpType: "fillet"  // "fillet", "chamfer"

    signal featureCreated(string featureName)

    readonly property var config: {
        "fillet":  { title: "3D Fillet (All Edges)", color: "#7C3AED", label: "Radius", defaultVal: "2.0" },
        "chamfer": { title: "3D Chamfer (All Edges)", color: "#7C3AED", label: "Size",   defaultVal: "2.0" }
    }
    readonly property var cfg: config[dressUpType] || config["fillet"]

    function getSolidNames() {
        var names = []
        var tree = cadEngine.featureTree
        for (var i = 0; i < tree.length; i++) {
            var t = tree[i].typeName
            if (t.indexOf("Sketcher") === -1 && t.indexOf("Body") === -1)
                names.push(tree[i].name)
        }
        return names
    }

    background: Rectangle {
        radius: 10; color: "#FFFFFF"
        border.width: 2; border.color: dialog.cfg.color
        Rectangle { anchors.fill: parent; anchors.margins: -4; z: -1; radius: 14; color: Qt.rgba(0,0,0,0.12) }
    }

    contentItem: ColumnLayout {
        spacing: 0

        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 44; radius: 10
            color: dialog.cfg.color
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 12; color: parent.color }
            Text { anchors.centerIn: parent; text: dialog.cfg.title; font.pixelSize: 15; font.bold: true; color: "white" }
        }

        ColumnLayout {
            spacing: 12
            Layout.fillWidth: true
            Layout.topMargin: 16; Layout.bottomMargin: 12
            Layout.leftMargin: 16; Layout.rightMargin: 16

            ColumnLayout {
                spacing: 4; Layout.fillWidth: true
                Text { text: "Feature"; font.pixelSize: 12; font.bold: true; color: "#374151" }
                ComboBox { id: featureCombo; Layout.fillWidth: true; model: getSolidNames() }
            }

            ColumnLayout {
                spacing: 4; Layout.fillWidth: true
                Text { text: dialog.cfg.label; font.pixelSize: 12; font.bold: true; color: "#374151" }
                RowLayout {
                    spacing: 8; Layout.fillWidth: true
                    TextField {
                        id: valueField; Layout.fillWidth: true
                        text: dialog.cfg.defaultVal
                        font.pixelSize: 14; font.family: "monospace"
                        horizontalAlignment: Text.AlignRight; selectByMouse: true
                        validator: DoubleValidator { bottom: 0.001; decimals: 4 }
                        background: Rectangle {
                            radius: 6; color: valueField.activeFocus ? "#F5F3FF" : "#F9FAFB"
                            border.width: valueField.activeFocus ? 2 : 1
                            border.color: valueField.activeFocus ? dialog.cfg.color : "#D1D5DB"
                        }
                        onAccepted: applyDressUp()
                    }
                    Text { text: "mm"; font.pixelSize: 13; font.bold: true; color: "#6B7280" }
                }
            }

            RowLayout {
                spacing: 8; Layout.fillWidth: true; Layout.topMargin: 8
                Button { text: "Cancel"; flat: true; Layout.fillWidth: true; onClicked: dialog.close() }
                Button {
                    text: "Apply"; highlighted: true; Layout.fillWidth: true
                    enabled: featureCombo.currentIndex >= 0 && valueField.acceptableInput
                    palette.button: dialog.cfg.color; palette.brightText: "white"
                    onClicked: applyDressUp()
                }
            }
        }
    }

    function applyDressUp() {
        var val = parseFloat(valueField.text)
        if (isNaN(val) || val <= 0) return
        var names = getSolidNames()
        if (featureCombo.currentIndex < 0 || featureCombo.currentIndex >= names.length) return
        var featureName = names[featureCombo.currentIndex]
        var result = ""
        if (dressUpType === "fillet") result = cadEngine.filletAll(featureName, val)
        else if (dressUpType === "chamfer") result = cadEngine.chamferAll(featureName, val)
        if (result !== "") featureCreated(result)
        dialog.close()
    }

    onOpened: { valueField.forceActiveFocus(); valueField.selectAll() }
}
