import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".."

/**
 * DatumPlanePanel — left-side docked task panel for creating datum planes.
 *
 * Replaces the previous popup dialog so the user can click on the 3D
 * viewport to pick a face without dismissing the editor (the popup closed
 * on any outside click, which conflicts with face-pick interaction).
 *
 * Lifecycle: open()  → reset to defaults, refresh feature/face combos
 *            apply() → cadEngine.addDatumPlane* → emit accepted
 *            cancel() → emit cancelled
 */
Rectangle {
    id: root

    color: Theme.panel
    border.color: Theme.border
    border.width: 1

    signal accepted()
    signal cancelled()

    // ── Task state ────────────────────────────────────────────────────
    property string mode: "base"     // "base" | "face"
    property int    baseIdx: 0       // 0=XY 1=XZ 2=YZ
    property double offsetMm: 10.0
    property double rotXDeg: 0.0
    property double rotYDeg: 0.0
    property string faceFeature: ""
    property string faceSub: ""
    property bool   pickActive: false   // viewport click will set face when true

    function open() {
        mode      = "base"
        baseIdx   = 0
        offsetMm  = 10.0
        rotXDeg   = 0.0
        rotYDeg   = 0.0
        faceFeature = ""
        faceSub     = ""
        pickActive  = false
        refreshFaces()
    }

    function refreshFaces() {
        var feats = cadEngine.solidFeatureNames()
        featureCombo.model = feats
        featureCombo.currentIndex = feats.length > 0 ? 0 : -1
        faceFeature = feats.length > 0 ? feats[0] : ""
        refreshFaceCombo()
    }

    function refreshFaceCombo() {
        if (faceFeature === "") { faceCombo.model = []; faceCombo.currentIndex = -1; return }
        var faces = cadEngine.featureFaces(faceFeature)
        faceCombo.model = faces
        faceCombo.currentIndex = faces.length > 0 ? 0 : -1
        faceSub = faces.length > 0 ? faces[0] : ""
    }

    function apply() {
        if (mode === "base") {
            cadEngine.addDatumPlaneRotated(baseIdx, offsetMm, rotXDeg, rotYDeg, "DatumPlane")
        } else if (mode === "face") {
            if (faceFeature !== "" && faceSub !== "")
                cadEngine.addDatumPlaneOnFace(faceFeature, faceSub, offsetMm, "DatumPlane")
        }
        accepted()
    }

    function cancel() { cancelled() }

    // Listen for facePicked signal from cadEngine and auto-fill the fields
    // when the user clicks a face in the viewport with pickActive=true.
    Connections {
        target: cadEngine
        function onFacePicked(featureName, sub) {
            if (!root.pickActive) return
            // Force face-mode, flip combos to match the click target.
            root.mode = "face"
            root.faceFeature = featureName
            root.faceSub     = sub
            var feats = featureCombo.model
            for (var i = 0; i < feats.length; i++) {
                if (feats[i] === featureName) { featureCombo.currentIndex = i; break }
            }
            var faces = cadEngine.featureFaces(featureName)
            faceCombo.model = faces
            for (var j = 0; j < faces.length; j++) {
                if (faces[j] === sub) { faceCombo.currentIndex = j; break }
            }
            root.pickActive = false   // one-shot; click the button again to pick another
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 0
        spacing: 0

        // ── Header bar ───────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true; height: 42
            color: Theme.wbPart

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12; anchors.rightMargin: 8
                spacing: 8

                Text {
                    text: "\u25A1"   // ▱ plane glyph
                    color: "white"; font.pixelSize: 16; font.bold: true
                }
                Text {
                    text: qsTr("New Datum Plane")
                    color: "white"; font.pixelSize: 14; font.bold: true
                    Layout.fillWidth: true
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width; height: 1; color: Theme.border
            }
        }

        // ── Content ──────────────────────────────────────────────────
        Flickable {
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true
            contentHeight: contentCol.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: contentCol
                width: parent.width
                spacing: 10
                anchors.leftMargin: 12; anchors.rightMargin: 12

                Item { height: 8; Layout.fillWidth: true }

                // Mode tabs
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 12; Layout.rightMargin: 12
                    spacing: 6

                    Repeater {
                        model: [
                            { key: "base", label: qsTr("Base plane") },
                            { key: "face", label: qsTr("On face") }
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 28
                            radius: 4
                            color: root.mode === modelData.key ? Theme.wbPart : Theme.surfaceAlt
                            border.color: root.mode === modelData.key ? Theme.wbPart : Theme.border
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: modelData.label
                                font.pixelSize: 11; font.bold: true
                                color: root.mode === modelData.key ? "white" : Theme.text
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.mode = modelData.key
                            }
                        }
                    }
                }

                // ── Base plane fields ─────────────────────────────────
                ColumnLayout {
                    visible: root.mode === "base"
                    Layout.fillWidth: true
                    Layout.leftMargin: 12; Layout.rightMargin: 12
                    spacing: 6

                    Text { text: qsTr("Reference plane:"); font.pixelSize: 11; color: Theme.textSec }
                    ComboBox {
                        Layout.fillWidth: true
                        model: ["XY", "XZ", "YZ"]
                        currentIndex: root.baseIdx
                        onActivated: root.baseIdx = currentIndex
                    }

                    Text { text: qsTr("Offset (mm):"); font.pixelSize: 11; color: Theme.textSec }
                    TextField {
                        Layout.fillWidth: true
                        text: root.offsetMm.toString()
                        font.pixelSize: 13; font.family: "monospace"
                        validator: DoubleValidator { decimals: 4 }
                        onTextChanged: {
                            var v = parseFloat(text)
                            if (!isNaN(v)) root.offsetMm = v
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text { text: qsTr("Rot X (°):"); font.pixelSize: 11; color: Theme.textSec }
                            TextField {
                                Layout.fillWidth: true
                                text: root.rotXDeg.toString()
                                font.pixelSize: 13; font.family: "monospace"
                                validator: DoubleValidator { decimals: 3 }
                                onTextChanged: {
                                    var v = parseFloat(text)
                                    if (!isNaN(v)) root.rotXDeg = v
                                }
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text { text: qsTr("Rot Y (°):"); font.pixelSize: 11; color: Theme.textSec }
                            TextField {
                                Layout.fillWidth: true
                                text: root.rotYDeg.toString()
                                font.pixelSize: 13; font.family: "monospace"
                                validator: DoubleValidator { decimals: 3 }
                                onTextChanged: {
                                    var v = parseFloat(text)
                                    if (!isNaN(v)) root.rotYDeg = v
                                }
                            }
                        }
                    }
                }

                // ── Face mode fields ──────────────────────────────────
                ColumnLayout {
                    visible: root.mode === "face"
                    Layout.fillWidth: true
                    Layout.leftMargin: 12; Layout.rightMargin: 12
                    spacing: 6

                    // Interactive pick button. Flips pickActive, which the
                    // Connections handler up top consumes on the next
                    // facePicked signal.
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 34
                        radius: 4
                        color: root.pickActive ? Theme.accent : Theme.surfaceAlt
                        border.color: root.pickActive ? Theme.accent : Theme.border
                        border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: root.pickActive
                                  ? qsTr("Click a face in the viewport…")
                                  : qsTr("\u2316  Pick Face from viewport")
                            font.pixelSize: 12; font.bold: root.pickActive
                            color: root.pickActive ? "white" : Theme.text
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.pickActive = !root.pickActive
                                cadEngine.facePickMode = root.pickActive
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: qsTr("Feature:"); font.pixelSize: 11; color: Theme.textSec
                    }
                    ComboBox {
                        id: featureCombo
                        Layout.fillWidth: true
                        onActivated: {
                            root.faceFeature = model[currentIndex] || ""
                            root.refreshFaceCombo()
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: qsTr("Face:"); font.pixelSize: 11; color: Theme.textSec
                    }
                    ComboBox {
                        id: faceCombo
                        Layout.fillWidth: true
                        onActivated: {
                            root.faceSub = model[currentIndex] || ""
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: qsTr("Offset along normal (mm):"); font.pixelSize: 11; color: Theme.textSec
                    }
                    TextField {
                        Layout.fillWidth: true
                        text: root.offsetMm.toString()
                        font.pixelSize: 13; font.family: "monospace"
                        validator: DoubleValidator { decimals: 4 }
                        onTextChanged: {
                            var v = parseFloat(text)
                            if (!isNaN(v)) root.offsetMm = v
                        }
                    }
                }

                Item { height: 12; Layout.fillWidth: true }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 12; Layout.rightMargin: 12
                    spacing: 6

                    Button {
                        Layout.fillWidth: true
                        text: qsTr("Cancel")
                        onClicked: {
                            cadEngine.facePickMode = false
                            root.cancel()
                        }
                    }
                    Button {
                        Layout.fillWidth: true
                        highlighted: true
                        text: qsTr("Add")
                        onClicked: {
                            cadEngine.facePickMode = false
                            root.apply()
                        }
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }
    }
}
