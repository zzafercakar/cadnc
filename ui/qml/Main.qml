import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: root
    visible: true
    width: 1400
    height: 900
    title: "CADNC v" + appVersion

    // Top menu bar
    menuBar: MenuBar {
        Menu {
            title: qsTr("File")
            Action { text: qsTr("New");  shortcut: "Ctrl+N" }
            Action { text: qsTr("Open"); shortcut: "Ctrl+O" }
            Action { text: qsTr("Save"); shortcut: "Ctrl+S" }
            MenuSeparator {}
            Action { text: qsTr("Exit"); onTriggered: Qt.quit() }
        }
        Menu {
            title: qsTr("Edit")
            Action { text: qsTr("Undo"); shortcut: "Ctrl+Z" }
            Action { text: qsTr("Redo"); shortcut: "Ctrl+Y" }
        }
        Menu {
            title: qsTr("View")
            Action { text: qsTr("Fit All"); shortcut: "V" }
        }
    }

    // Top toolbar
    header: ToolBar {
        id: mainToolbar
        RowLayout {
            anchors.fill: parent
            spacing: 4

            // Workbench tabs
            TabBar {
                id: workbenchTabs
                Layout.fillWidth: true

                TabButton { text: qsTr("Part") }
                TabButton { text: qsTr("Sketch") }
                TabButton { text: qsTr("CAM") }
                TabButton { text: qsTr("Nesting") }
            }
        }
    }

    // Main content area
    SplitView {
        anchors.fill: parent
        orientation: Qt.Horizontal

        // Left panel: Model tree
        Pane {
            SplitView.preferredWidth: 250
            SplitView.minimumWidth: 180

            ColumnLayout {
                anchors.fill: parent

                Label {
                    text: qsTr("Model Tree")
                    font.bold: true
                }

                ListView {
                    id: modelTree
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    model: ListModel {
                        ListElement { name: "Origin" }
                        ListElement { name: "XY Plane" }
                        ListElement { name: "XZ Plane" }
                        ListElement { name: "YZ Plane" }
                    }

                    delegate: ItemDelegate {
                        width: modelTree.width
                        text: name
                    }
                }
            }
        }

        // Center: 3D Viewport placeholder
        Rectangle {
            SplitView.fillWidth: true
            color: "#2b2b2b"

            Label {
                anchors.centerIn: parent
                text: qsTr("3D Viewport\n(FreeCAD backend integration pending)")
                color: "#888"
                font.pixelSize: 18
                horizontalAlignment: Text.AlignHCenter
            }
        }

        // Right panel: Properties
        Pane {
            SplitView.preferredWidth: 250
            SplitView.minimumWidth: 180

            ColumnLayout {
                anchors.fill: parent

                Label {
                    text: qsTr("Properties")
                    font.bold: true
                }

                Label {
                    Layout.fillWidth: true
                    text: qsTr("No selection")
                    color: "#888"
                    wrapMode: Text.Wrap
                }

                Item { Layout.fillHeight: true }
            }
        }
    }

    // Status bar
    footer: Pane {
        height: 28
        padding: 4

        RowLayout {
            anchors.fill: parent

            Label {
                text: qsTr("Ready")
                color: "#ccc"
            }

            Item { Layout.fillWidth: true }

            Label {
                text: "CADNC v" + appVersion
                color: "#888"
            }
        }
    }
}
