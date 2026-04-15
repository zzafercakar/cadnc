import QtQuick
import QtQuick.Layouts
import "../components"

Rectangle {
    id: toolbar
    height: 58

    signal actionRequested(string action)

    gradient: Gradient {
        GradientStop { position: 0.0; color: "#FFF9F0" }
        GradientStop { position: 0.5; color: "#FFF3E0" }
        GradientStop { position: 1.0; color: "#FFECCC" }
    }
    border.width: 1; border.color: "#E0C8A0"

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10; anchors.rightMargin: 10
        spacing: 8

        // Setup
        RibbonGroup {
            title: "Setup"; accentColor: "#D97706"
            content: [
                CadToolButton { iconPath: "qrc:/resources/icons/cam/stock.svg"; tipText: "Stock Setup"; accentColor: "#D97706"; onClicked: actionRequested("stock") },
                CadToolButton { iconPath: "qrc:/resources/icons/cam/wcs.svg"; tipText: "WCS"; accentColor: "#D97706"; onClicked: actionRequested("wcs") },
                CadToolButton { iconPath: "qrc:/resources/icons/cam/tool.svg"; tipText: "Tool Library"; accentColor: "#D97706"; onClicked: actionRequested("toolLibrary") }
            ]
        }

        // Operations
        RibbonGroup {
            title: "Operations"; accentColor: "#F59E0B"
            content: [
                CadToolButton { iconPath: "qrc:/resources/icons/cam/profile.svg"; tipText: "Profile"; accentColor: "#F59E0B"; onClicked: actionRequested("profile") },
                CadToolButton { iconPath: "qrc:/resources/icons/cam/pocket.svg"; tipText: "Pocket"; accentColor: "#F59E0B"; onClicked: actionRequested("pocket") },
                CadToolButton { iconPath: "qrc:/resources/icons/cam/drill.svg"; tipText: "Drilling"; accentColor: "#F59E0B"; onClicked: actionRequested("drill") },
                CadToolButton { iconPath: "qrc:/resources/icons/cam/slot.svg"; tipText: "Slot"; accentColor: "#F59E0B"; onClicked: actionRequested("slot") },
                CadToolButton { iconPath: "qrc:/resources/icons/cam/engrave.svg"; tipText: "Engrave"; accentColor: "#F59E0B"; onClicked: actionRequested("engrave") },
                CadToolButton { iconPath: "qrc:/resources/icons/cam/adaptive.svg"; tipText: "Adaptive"; accentColor: "#F59E0B"; onClicked: actionRequested("adaptive") },
                CadToolButton { iconPath: "qrc:/resources/icons/cam/helix.svg"; tipText: "Helix"; accentColor: "#F59E0B"; onClicked: actionRequested("helix") }
            ]
        }

        // Post-Process
        RibbonGroup {
            title: "Post-Process"; accentColor: "#2563EB"
            content: [
                CadToolButton { iconPath: "qrc:/resources/icons/cam/simulate.svg"; tipText: "Simulate"; accentColor: "#2563EB"; onClicked: actionRequested("simulate") }
            ]
        }

        // Export buttons (special style)
        Rectangle {
            width: 84; height: 34; radius: 6
            gradient: Gradient {
                GradientStop { position: 0; color: gcArea.containsMouse ? "#C6F6D5" : "#F0FDF4" }
                GradientStop { position: 1; color: gcArea.containsMouse ? "#86EFAC" : "#DCFCE7" }
            }
            border.width: 1; border.color: gcArea.containsMouse ? "#16A34A" : "#BBF7D0"

            Column {
                anchors.centerIn: parent; spacing: 1
                Text { text: "G-code"; font.pixelSize: 10; font.bold: true; color: "#16A34A"; anchors.horizontalCenter: parent.horizontalCenter }
                Text { text: "Standard"; font.pixelSize: 8; color: "#6B7280"; anchors.horizontalCenter: parent.horizontalCenter }
            }
            MouseArea { id: gcArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: actionRequested("exportGCode") }
        }

        Rectangle {
            width: 90; height: 34; radius: 6
            gradient: Gradient {
                GradientStop { position: 0; color: csArea.containsMouse ? "#BFDBFE" : "#EFF6FF" }
                GradientStop { position: 1; color: csArea.containsMouse ? "#93C5FD" : "#DBEAFE" }
            }
            border.width: 1; border.color: csArea.containsMouse ? "#2563EB" : "#BFDBFE"

            Column {
                anchors.centerIn: parent; spacing: 1
                Text { text: "G-code"; font.pixelSize: 10; font.bold: true; color: "#2563EB"; anchors.horizontalCenter: parent.horizontalCenter }
                Text { text: "CODESYS"; font.pixelSize: 8; color: "#6B7280"; anchors.horizontalCenter: parent.horizontalCenter }
            }
            MouseArea { id: csArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: actionRequested("exportCodeSys") }
        }

        Item { Layout.fillWidth: true }
    }
}
