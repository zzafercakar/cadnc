import QtQuick
import QtQuick.Controls

/**
 * CadToolButton — Professional 3D-beveled toolbar button.
 *
 * MilCAD-inspired design: gradient fill, top highlight, bottom shadow,
 * press scale animation, hover tooltip, active/disabled states.
 */
Rectangle {
    id: btn
    width: 36; height: 36
    radius: 6

    property string iconPath: ""
    property string tipText: ""
    property bool isActive: false
    property bool isDisabled: false
    property bool isToggle: false
    property color accentColor: "#3B82F6"
    property color activeColor: "#34D399"

    signal clicked()

    opacity: isDisabled ? 0.38 : 1.0

    gradient: Gradient {
        GradientStop { position: 0.0; color: mouseArea.pressed ? Qt.darker(accentColor, 1.15)
                                             : isActive ? Qt.lighter(activeColor, 1.4)
                                             : mouseArea.containsMouse ? "#E8F0FE"
                                             : "#F8F9FC" }
        GradientStop { position: 0.5; color: mouseArea.pressed ? Qt.darker(accentColor, 1.05)
                                             : isActive ? Qt.lighter(activeColor, 1.2)
                                             : mouseArea.containsMouse ? "#DDE6F8"
                                             : "#EFF1F5" }
        GradientStop { position: 1.0; color: mouseArea.pressed ? accentColor
                                             : isActive ? activeColor
                                             : mouseArea.containsMouse ? "#D0DBEF"
                                             : "#E4E7ED" }
    }

    border.width: 1
    border.color: isActive ? Qt.darker(activeColor, 1.2)
                 : mouseArea.containsMouse ? Qt.darker(accentColor, 1.1)
                 : "#C0C6D0"

    // Top highlight bevel
    Rectangle {
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        anchors.margins: 1
        height: 1; radius: 5
        color: Qt.rgba(1, 1, 1, isActive ? 0.5 : 0.7)
    }

    // Bottom shadow bevel
    Rectangle {
        anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
        anchors.margins: 1
        height: 1; radius: 5
        color: Qt.rgba(0, 0, 0, 0.08)
    }

    // Icon
    Image {
        anchors.centerIn: parent
        width: 22; height: 22
        sourceSize: Qt.size(44, 44)
        source: iconPath
        smooth: true; mipmap: true
        opacity: isDisabled ? 0.4 : 1.0
    }

    // Press animation
    scale: mouseArea.pressed ? 0.93 : 1.0
    Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: isDisabled ? Qt.ForbiddenCursor : Qt.PointingHandCursor
        onClicked: { if (!isDisabled) btn.clicked() }
    }

    ToolTip {
        visible: mouseArea.containsMouse && tipText.length > 0
        text: tipText
        delay: 500
    }
}
