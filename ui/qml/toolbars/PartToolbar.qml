import QtQuick
import QtQuick.Layouts
import "../components"

Rectangle {
    id: toolbar
    height: 58

    signal actionRequested(string action)

    gradient: Gradient {
        GradientStop { position: 0.0; color: "#F0F3FF" }
        GradientStop { position: 0.5; color: "#E4EAFF" }
        GradientStop { position: 1.0; color: "#DCE4FF" }
    }
    border.width: 1; border.color: "#A8B8E8"

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10; anchors.rightMargin: 10
        spacing: 8

        // Features
        RibbonGroup {
            title: "Features"; accentColor: "#2563EB"
            content: [
                CadToolButton { iconPath: "qrc:/resources/icons/part/extrude.svg"; tipText: "Pad"; accentColor: "#2563EB"; onClicked: actionRequested("pad") },
                CadToolButton { iconPath: "qrc:/resources/icons/part/pocket.svg"; tipText: "Pocket"; accentColor: "#2563EB"; onClicked: actionRequested("pocket") },
                CadToolButton { iconPath: "qrc:/resources/icons/part/revolve.svg"; tipText: "Revolve"; accentColor: "#2563EB"; onClicked: actionRequested("revolve") },
                CadToolButton { iconPath: "qrc:/resources/icons/part/swept.svg"; tipText: "Sweep"; accentColor: "#2563EB"; onClicked: actionRequested("sweep") },
                CadToolButton { iconPath: "qrc:/resources/icons/part/loft.svg"; tipText: "Loft"; accentColor: "#2563EB"; onClicked: actionRequested("loft") },
                CadToolButton { iconPath: "qrc:/resources/icons/part/hole.svg"; tipText: "Hole"; accentColor: "#2563EB"; onClicked: actionRequested("hole") },
                CadToolButton { iconPath: "qrc:/resources/icons/part/sketch_on_face.svg"; tipText: "Sketch on Face"; accentColor: "#059669"; onClicked: actionRequested("newSketch") }
            ]
        }

        // Dress-Up
        RibbonGroup {
            title: "Dress-Up"; accentColor: "#7C3AED"
            content: [
                CadToolButton { iconPath: "qrc:/resources/icons/part/fillet.svg"; tipText: "Fillet"; accentColor: "#7C3AED"; onClicked: actionRequested("fillet3d") },
                CadToolButton { iconPath: "qrc:/resources/icons/part/chamfer.svg"; tipText: "Chamfer"; accentColor: "#7C3AED"; onClicked: actionRequested("chamfer3d") },
                CadToolButton { iconPath: "qrc:/resources/icons/part/draft.svg"; tipText: "Draft"; accentColor: "#7C3AED"; onClicked: actionRequested("draft") },
                CadToolButton { iconPath: "qrc:/resources/icons/part/shell.svg"; tipText: "Shell"; accentColor: "#7C3AED"; onClicked: actionRequested("shell") }
            ]
        }

        // Patterns
        RibbonGroup {
            title: "Patterns"; accentColor: "#0891B2"
            content: [
                CadToolButton { iconPath: "qrc:/resources/icons/part/linear_pattern.svg"; tipText: "Linear Pattern"; accentColor: "#0891B2"; onClicked: actionRequested("linearPattern") },
                CadToolButton { iconPath: "qrc:/resources/icons/part/mirror_part.svg"; tipText: "Mirror"; accentColor: "#0891B2"; onClicked: actionRequested("mirror") }
            ]
        }

        // Primitives
        RibbonGroup {
            title: "Primitives"; accentColor: "#D97706"
            content: [
                CadToolButton { iconPath: "qrc:/resources/icons/part/box.svg"; tipText: "Box"; accentColor: "#D97706"; onClicked: actionRequested("box") },
                CadToolButton { iconPath: "qrc:/resources/icons/part/cylinder.svg"; tipText: "Cylinder"; accentColor: "#D97706"; onClicked: actionRequested("cylinder") },
                CadToolButton { iconPath: "qrc:/resources/icons/part/sphere.svg"; tipText: "Sphere"; accentColor: "#D97706"; onClicked: actionRequested("sphere") },
                CadToolButton { iconPath: "qrc:/resources/icons/part/cone.svg"; tipText: "Cone"; accentColor: "#D97706"; onClicked: actionRequested("cone") },
                CadToolButton { iconPath: "qrc:/resources/icons/part/torus.svg"; tipText: "Torus"; accentColor: "#D97706"; onClicked: actionRequested("torus") }
            ]
        }

        // Boolean
        RibbonGroup {
            title: "Boolean"; accentColor: "#DC2626"
            content: [
                CadToolButton { iconPath: "qrc:/resources/icons/part/union.svg"; tipText: "Union"; accentColor: "#DC2626"; onClicked: actionRequested("union") },
                CadToolButton { iconPath: "qrc:/resources/icons/part/cut.svg"; tipText: "Cut"; accentColor: "#DC2626"; onClicked: actionRequested("cut") },
                CadToolButton { iconPath: "qrc:/resources/icons/part/intersect.svg"; tipText: "Intersect"; accentColor: "#DC2626"; onClicked: actionRequested("intersect") }
            ]
        }

        Item { Layout.fillWidth: true }
    }
}
