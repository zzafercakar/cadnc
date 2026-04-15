import QtQuick
import QtQuick.Layouts
import "../components"

Rectangle {
    id: toolbar
    height: 48

    signal actionRequested(string action)

    gradient: Gradient {
        GradientStop { position: 0.0; color: "#F5F0FF" }
        GradientStop { position: 0.5; color: "#EDE5FF" }
        GradientStop { position: 1.0; color: "#DDD6FE" }
    }
    border.width: 1; border.color: "#C4B5FD"

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10; anchors.rightMargin: 10
        spacing: 4

        // Parts
        Text { text: "Parts"; font.pixelSize: 9; font.bold: true; color: "#5B21B6"; Layout.leftMargin: 4 }
        CadToolButton { iconPath: "qrc:/resources/icons/nesting/add_part.svg"; tipText: "Add Part"; accentColor: "#7C3AED"; onClicked: actionRequested("addPart") }
        CadToolButton { iconPath: "qrc:/resources/icons/nesting/import_dxf.svg"; tipText: "Import DXF"; accentColor: "#7C3AED"; onClicked: actionRequested("importDXF") }
        CadToolButton { iconPath: "qrc:/resources/icons/nesting/remove.svg"; tipText: "Remove Part"; accentColor: "#7C3AED"; onClicked: actionRequested("removePart") }

        Rectangle { width: 1; height: 28; color: "#C4B5FD" }

        // Sheet
        Text { text: "Sheet"; font.pixelSize: 9; font.bold: true; color: "#5B21B6" }
        CadToolButton { iconPath: "qrc:/resources/icons/nesting/sheet.svg"; tipText: "Set Sheet"; accentColor: "#7C3AED"; onClicked: actionRequested("setSheet") }

        Rectangle { width: 1; height: 28; color: "#C4B5FD" }

        // Parameters
        Text { text: "Params"; font.pixelSize: 9; font.bold: true; color: "#5B21B6" }
        CadToolButton { iconPath: "qrc:/resources/icons/nesting/gap.svg"; tipText: "Gap"; accentColor: "#7C3AED"; onClicked: actionRequested("setGap") }
        CadToolButton { iconPath: "qrc:/resources/icons/nesting/rotation.svg"; tipText: "Rotation"; accentColor: "#7C3AED"; onClicked: actionRequested("setRotation") }

        Rectangle { width: 1; height: 28; color: "#C4B5FD" }

        // Nesting
        Text { text: "Nest"; font.pixelSize: 9; font.bold: true; color: "#5B21B6" }
        CadToolButton { iconPath: "qrc:/resources/icons/nesting/run.svg"; tipText: "Run Nesting"; accentColor: "#7C3AED"; onClicked: actionRequested("runNesting") }
        CadToolButton { iconPath: "qrc:/resources/icons/nesting/optimize.svg"; tipText: "Optimize"; accentColor: "#7C3AED"; onClicked: actionRequested("optimize") }

        Rectangle { width: 1; height: 28; color: "#C4B5FD" }

        // Export DXF
        Rectangle {
            width: 80; height: 34; radius: 6
            gradient: Gradient {
                GradientStop { position: 0; color: dxfArea.containsMouse ? "#FDE68A" : "#FEF3C7" }
                GradientStop { position: 1; color: dxfArea.containsMouse ? "#FCD34D" : "#FDE68A" }
            }
            border.width: 1; border.color: dxfArea.containsMouse ? "#D97706" : "#FDE68A"
            Text { anchors.centerIn: parent; text: "Export DXF"; font.pixelSize: 10; font.bold: true; color: "#92400E" }
            MouseArea { id: dxfArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: actionRequested("exportDXF") }
        }

        // Export G-Code
        Rectangle {
            width: 90; height: 34; radius: 6
            gradient: Gradient {
                GradientStop { position: 0; color: ngcArea.containsMouse ? "#C6F6D5" : "#F0FDF4" }
                GradientStop { position: 1; color: ngcArea.containsMouse ? "#86EFAC" : "#DCFCE7" }
            }
            border.width: 1; border.color: ngcArea.containsMouse ? "#16A34A" : "#BBF7D0"
            Text { anchors.centerIn: parent; text: "Export G-Code"; font.pixelSize: 10; font.bold: true; color: "#16A34A" }
            MouseArea { id: ngcArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: actionRequested("exportGCode") }
        }

        Item { Layout.fillWidth: true }
    }
}
