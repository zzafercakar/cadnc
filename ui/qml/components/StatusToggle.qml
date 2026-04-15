import QtQuick

/**
 * StatusToggle — Pill-shaped toggle for status bar (SNAP, GRID, ORTHO).
 */
Rectangle {
    id: toggle
    width: label.implicitWidth + 18
    height: 20
    radius: 10

    property string text: "SNAP"
    property bool isOn: false
    signal toggled()

    gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: isOn ? "#2563EB" : "#E2E8F0" }
        GradientStop { position: 1.0; color: isOn ? "#1D4ED8" : "#CBD5E1" }
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: toggle.text
        font.pixelSize: 10
        font.bold: true
        color: isOn ? "white" : "#475569"
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: { isOn = !isOn; toggle.toggled() }
    }
}
