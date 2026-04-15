import QtQuick
import QtQuick.Layouts

/**
 * RibbonGroup — Container for a group of toolbar buttons with a label.
 */
Rectangle {
    id: group
    radius: 8
    color: "#F8FAFF"
    border.width: 1
    border.color: Qt.lighter(accentColor, 1.55)

    property string title: "Group"
    property color accentColor: "#2563EB"
    property alias content: buttonRow.data

    implicitWidth: col.implicitWidth + 16
    implicitHeight: col.implicitHeight + 8

    ColumnLayout {
        id: col
        anchors.centerIn: parent
        spacing: 2

        RowLayout {
            id: buttonRow
            spacing: 4
            Layout.alignment: Qt.AlignHCenter
        }

        Text {
            text: group.title
            font.pixelSize: 9
            font.bold: true
            color: "#64748B"
            Layout.alignment: Qt.AlignHCenter
        }
    }
}
