import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/**
 * BooleanDialog — Popup for boolean operations (Fuse, Cut, Common).
 * Selects two features from the model tree.
 */
Popup {
    id: dialog
    width: 340
    padding: 0
    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    x: (mainWindow.width - width) / 2
    y: (mainWindow.height - height) / 2

    property string booleanType: "fuse"  // "fuse", "cut", "common"

    signal featureCreated(string featureName)

    readonly property var config: {
        "fuse":   { title: "Boolean Union",     color: "#2563EB" },
        "cut":    { title: "Boolean Cut",       color: "#DC2626" },
        "common": { title: "Boolean Intersect", color: "#D97706" }
    }
    readonly property var cfg: config[booleanType] || config["fuse"]

    // Get solid feature names for combo boxes
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
                Text { text: "Base Shape"; font.pixelSize: 12; font.bold: true; color: "#374151" }
                ComboBox { id: baseCombo; Layout.fillWidth: true; model: getSolidNames(); currentIndex: 0 }
            }

            ColumnLayout {
                spacing: 4; Layout.fillWidth: true
                Text { text: "Tool Shape"; font.pixelSize: 12; font.bold: true; color: "#374151" }
                ComboBox { id: toolCombo; Layout.fillWidth: true; model: getSolidNames(); currentIndex: Math.min(1, getSolidNames().length - 1) }
            }

            RowLayout {
                spacing: 8; Layout.fillWidth: true; Layout.topMargin: 8
                Button { text: "Cancel"; flat: true; Layout.fillWidth: true; onClicked: dialog.close() }
                Button {
                    text: "Apply"; highlighted: true; Layout.fillWidth: true
                    enabled: baseCombo.currentIndex >= 0 && toolCombo.currentIndex >= 0
                    palette.button: dialog.cfg.color; palette.brightText: "white"
                    onClicked: {
                        var names = getSolidNames()
                        var baseName = names[baseCombo.currentIndex]
                        var toolName = names[toolCombo.currentIndex]
                        var result = ""
                        if (booleanType === "fuse") result = cadEngine.booleanFuse(baseName, toolName)
                        else if (booleanType === "cut") result = cadEngine.booleanCut(baseName, toolName)
                        else if (booleanType === "common") result = cadEngine.booleanCommon(baseName, toolName)
                        if (result !== "") featureCreated(result)
                        dialog.close()
                    }
                }
            }
        }
    }
}
