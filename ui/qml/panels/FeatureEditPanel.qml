import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".."

/**
 * FeatureEditPanel — SolidWorks/FreeCAD-style task panel.
 *
 * Replaces the model tree on the left while a feature is being edited.
 * Live preview: every length change recreates the actual feature
 * (debounced) so the 3D viewport always shows what Apply will produce.
 *
 * Lifecycle:
 *   open()     — pick most recent sketch, build initial preview
 *   apply()    — keep the current preview, close panel
 *   cancel()   — delete the preview, close panel (Esc / red ✗)
 */
Rectangle {
    id: root

    property string featureType: "pad"   // "pad" | "pocket" | "revolve" | "groove"
    property string previewName: ""       // currently-displayed temp feature (create mode)

    // ── Edit mode state (UX-010 / UX-011) ──────────────────────────
    // editingFeatureName != ""  → editing an existing feature; rebuildPreview
    //   mutates it in place via updatePad/Pocket/Revolution; cancel restores
    //   the original parameters.
    // editingFeatureName == ""  → legacy create flow (delete + recreate).
    property string editingFeatureName: ""
    property string editingSketchName: ""
    property var editingOriginal: ({})

    signal accepted()
    signal cancelled()

    color: Theme.panel
    border.color: Theme.border
    border.width: 1

    // Per-feature config (label, color, icon, default value)
    readonly property var config: ({
        "pad":     { title: "Pad",        color: "#16A34A", verb: "Length", unit: "mm", defaultVal: 10.0 },
        "pocket":  { title: "Pocket",     color: "#DC2626", verb: "Depth",  unit: "mm", defaultVal: 5.0  },
        "revolve": { title: "Revolution", color: "#2563EB", verb: "Angle",  unit: "°",  defaultVal: 360.0 },
        "groove":  { title: "Groove",     color: "#9333EA", verb: "Angle",  unit: "°",  defaultVal: 360.0 }
    })
    readonly property var cfg: config[featureType] || config["pad"]

    // UX-008 current mode selections. Keep as QML properties so the change
    // signals trigger scheduleRebuild without plumbing every ComboBox's
    // `onActivated` to each consumer.
    property string sideType: "One side"      // One side / Two sides / Symmetric
    property string extrudeMethod: "Length"   // Length / ThroughAll
    onSideTypeChanged: scheduleRebuild()
    onExtrudeMethodChanged: scheduleRebuild()

    // ── Public lifecycle ───────────────────────────────────────────
    function openFor(type) {
        // Leaving edit mode (e.g. reopening in create flow) — clear state so
        // cancel() doesn't try to restore an unrelated feature.
        editingFeatureName = ""
        editingSketchName = ""
        editingOriginal = ({})

        // If a previous preview is still around (mode switch without commit),
        // remove it so we don't accumulate stray features.
        if (previewName !== "") {
            cadEngine.deleteFeature(previewName)
            previewName = ""
        }
        featureType = type
        valueField.text = cfg.defaultVal.toFixed(cfg.unit === "°" ? 0 : 2)
        length2Field.text = cfg.defaultVal.toFixed(2)
        reverseToggle.checked = false
        sideType = "One side"
        extrudeMethod = "Length"
        if (cadEngine.sketchNames.length > 0)
            sketchCombo.currentIndex = cadEngine.sketchNames.length - 1
        else
            sketchCombo.currentIndex = -1
        rebuildPreview()
    }

    // Open the panel to edit an existing parametric feature. Returns true if
    // the feature is parametric (PartDesign Pad/Pocket/Revolution/Groove) and
    // was successfully loaded; false for non-editable OCCT fallback features.
    function openForEdit(type, name) {
        // Drop any lingering create-mode preview first.
        if (previewName !== "") {
            cadEngine.deleteFeature(previewName)
            previewName = ""
        }

        var p = cadEngine.getFeatureParams(name)
        if (!p || !p.editable) {
            // Non-parametric — user would need to delete and recreate.
            console.warn("FeatureEditPanel: '" + name + "' is not editable (non-parametric)")
            return false
        }

        featureType = type
        editingFeatureName = name
        editingSketchName = p.sketchName
        // Make a shallow copy; QVariantMap values aren't always reference-safe
        // across later mutations.
        editingOriginal = {
            length: p.length, length2: p.length2, angle: p.angle,
            reversed: p.reversed, sketchName: p.sketchName,
            sideType: p.sideType || "One side",
            method: p.method || "Length"
        }

        var init = (type === "pad" || type === "pocket") ? p.length : p.angle
        valueField.text = init.toFixed(cfg.unit === "°" ? 0 : 2)
        length2Field.text = (p.length2 || 0).toFixed(2)
        reverseToggle.checked = p.reversed
        sideType = p.sideType || "One side"
        extrudeMethod = p.method || "Length"
        // sketchCombo is hidden in edit mode — feature's sketch is fixed.
        return true
    }

    function apply() {
        if (editingFeatureName !== "") {
            // Edit mode: the latest parameter is already applied via the
            // debounced rebuildPreview path. Nothing else to do.
            editingFeatureName = ""
            editingSketchName = ""
            editingOriginal = ({})
            accepted()
            return
        }
        // Create-mode: preview already represents the final result.
        previewName = ""
        accepted()
    }

    function cancel() {
        if (editingFeatureName !== "") {
            // Edit mode: restore the original parameter values so the feature
            // returns to its pre-edit state. Users expect Esc/✗ to undo live
            // previews (SolidWorks/FreeCAD parity).
            var orig = editingOriginal
            if (featureType === "pad") {
                cadEngine.updatePadEx(editingFeatureName, {
                    length: orig.length, length2: orig.length2,
                    reversed: orig.reversed,
                    sideType: orig.sideType, method: orig.method
                })
            } else if (featureType === "pocket") {
                cadEngine.updatePocketEx(editingFeatureName, {
                    length: orig.length, length2: orig.length2,
                    reversed: orig.reversed,
                    sideType: orig.sideType, method: orig.method
                })
            } else if (featureType === "revolve") {
                cadEngine.updateRevolution(editingFeatureName, orig.angle)
            } else if (featureType === "groove") {
                cadEngine.updateGroove(editingFeatureName, orig.angle)
            }
            editingFeatureName = ""
            editingSketchName = ""
            editingOriginal = ({})
            cancelled()
            return
        }
        if (previewName !== "") {
            cadEngine.deleteFeature(previewName)
            previewName = ""
        }
        cancelled()
    }

    // If the document is closed or replaced under us, drop preview tracking
    // (the feature is gone with the document anyway) and exit edit mode
    // so we don't try to delete a stale name in the new document.
    // hasDocument's NOTIFY is featureTreeChanged, so listen there.
    Connections {
        target: cadEngine
        function onFeatureTreeChanged() {
            if (visible && !cadEngine.hasDocument) {
                previewName = ""
                cancelled()
            }
        }
    }

    // ── Live preview ───────────────────────────────────────────────
    // Debounce typing so we don't recompute on every keystroke.
    Timer {
        id: previewTimer
        interval: 250
        repeat: false
        onTriggered: rebuildPreview()
    }

    function scheduleRebuild() { previewTimer.restart() }

    // Build the option map for pad/pocket rich API calls. Pulled out so the
    // edit-mode updatePadEx and the create-mode padEx share the exact same
    // state snapshot — otherwise toggling Reverse during edit could reset
    // sideType to "One side".
    function buildPadOpts(length) {
        return {
            length: length,
            length2: parseFloat(length2Field.text) || cfg.defaultVal,
            reversed: reverseToggle.checked,
            sideType: sideType,
            method: extrudeMethod
        }
    }

    function rebuildPreview() {
        // Don't extrude while a sketch is being edited — the SketchObject
        // hasn't finished recompute yet and the preview would race the solver.
        if (cadEngine.sketchActive) return
        var v = parseFloat(valueField.text)
        if (isNaN(v) || v <= 0) return

        // Edit mode: mutate the existing feature in place. This is cheaper
        // than delete+recreate and preserves the feature id, so downstream
        // dependencies stay intact during live preview.
        if (editingFeatureName !== "") {
            if (featureType === "pad")
                cadEngine.updatePadEx(editingFeatureName, buildPadOpts(v))
            else if (featureType === "pocket")
                cadEngine.updatePocketEx(editingFeatureName, buildPadOpts(v))
            else if (featureType === "revolve")
                cadEngine.updateRevolution(editingFeatureName, v)
            else if (featureType === "groove")
                cadEngine.updateGroove(editingFeatureName, v)
            return
        }

        // Create-mode: delete the previous preview before creating the new one.
        if (sketchCombo.currentIndex < 0) return
        if (previewName !== "") {
            cadEngine.deleteFeature(previewName)
            previewName = ""
        }

        var sketchName = cadEngine.sketchNames[sketchCombo.currentIndex]
        var name = ""
        if (featureType === "pad")
            name = cadEngine.padEx(sketchName, buildPadOpts(v))
        else if (featureType === "pocket")
            name = cadEngine.pocketEx(sketchName, buildPadOpts(v))
        else if (featureType === "revolve") {
            var signedVal = reverseToggle.checked ? -v : v
            name = cadEngine.revolution(sketchName, signedVal)
        } else if (featureType === "groove") {
            var signedVal2 = reverseToggle.checked ? -v : v
            name = cadEngine.groove(sketchName, signedVal2)
        }

        if (name !== "") previewName = name
    }

    // ── Layout ─────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 0
        spacing: 0

        // Header — accent strip + title + accept/cancel buttons
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            color: cfg.color

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 6
                spacing: 8

                Text {
                    text: cfg.title
                    font.pixelSize: 14
                    font.bold: true
                    color: "white"
                    Layout.fillWidth: true
                }

                // ✗ Cancel
                Rectangle {
                    Layout.preferredWidth: 32; Layout.preferredHeight: 32
                    radius: 4
                    color: cancelArea.containsMouse ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.0)
                    Text { anchors.centerIn: parent; text: "\u2715"
                           font.pixelSize: 14; font.bold: true; color: "white" }
                    MouseArea { id: cancelArea; anchors.fill: parent
                                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: root.cancel() }
                    ToolTip.text: "Cancel (Esc)"; ToolTip.visible: cancelArea.containsMouse; ToolTip.delay: 400
                }

                // ✓ Apply
                Rectangle {
                    Layout.preferredWidth: 32; Layout.preferredHeight: 32
                    radius: 4
                    color: applyArea.containsMouse ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.0)
                    Text { anchors.centerIn: parent; text: "\u2713"
                           font.pixelSize: 16; font.bold: true; color: "white" }
                    MouseArea { id: applyArea; anchors.fill: parent
                                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: root.apply() }
                    ToolTip.text: "Apply (Enter)"; ToolTip.visible: applyArea.containsMouse; ToolTip.delay: 400
                }
            }
        }

        // Body — scrollable, responsive
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            ColumnLayout {
                width: root.width - 24
                x: 12
                spacing: 14
                y: 14

                // ── Profile sketch ─────────────────────────────────
                ColumnLayout {
                    spacing: 4
                    Layout.fillWidth: true
                    Text { text: "Profile Sketch"; font.pixelSize: 11; font.bold: true; color: Theme.textSec }
                    // Create mode: pick from available sketches
                    ComboBox {
                        id: sketchCombo
                        Layout.fillWidth: true
                        model: cadEngine.sketchNames
                        visible: root.editingFeatureName === ""
                        onActivated: root.scheduleRebuild()
                    }
                    // Edit mode: show the feature's sketch as read-only —
                    // changing the profile would require a different feature.
                    Rectangle {
                        visible: root.editingFeatureName !== ""
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        radius: 4
                        color: Theme.surface
                        border.color: Theme.borderLight
                        border.width: 1
                        Text {
                            anchors.left: parent.left; anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.editingSketchName || "(no sketch)"
                            font.pixelSize: 12; font.family: "monospace"
                            color: Theme.text
                        }
                    }
                    Text {
                        visible: cadEngine.sketchNames.length === 0 && root.editingFeatureName === ""
                        text: "No sketches available — create one first."
                        font.pixelSize: 10; font.italic: true; color: Theme.danger
                        wrapMode: Text.Wrap; Layout.fillWidth: true
                    }
                }

                // ── Length / depth / angle ─────────────────────────
                ColumnLayout {
                    spacing: 4
                    Layout.fillWidth: true
                    Text { text: cfg.verb; font.pixelSize: 11; font.bold: true; color: Theme.textSec }
                    RowLayout {
                        spacing: 6
                        Layout.fillWidth: true
                        TextField {
                            id: valueField
                            Layout.fillWidth: true
                            text: cfg.defaultVal.toFixed(2)
                            font.pixelSize: 13; font.family: "monospace"
                            horizontalAlignment: Text.AlignRight
                            selectByMouse: true
                            validator: DoubleValidator { bottom: 0.001; decimals: 4 }

                            background: Rectangle {
                                radius: 4
                                color: valueField.activeFocus ? Theme.surfaceAlt : Theme.surface
                                border.width: valueField.activeFocus ? 2 : 1
                                border.color: valueField.activeFocus ? cfg.color : Theme.border
                            }

                            onTextChanged: root.scheduleRebuild()
                            onAccepted: root.apply()
                        }
                        Text {
                            text: cfg.unit
                            font.pixelSize: 12; font.bold: true; color: Theme.textSec
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }

                    // Quick value slider — visual feedback for length.
                    // One-way: slider moves the field; field drives preview.
                    // Slider follows field value via Binding to avoid a loop.
                    Slider {
                        id: lengthSlider
                        visible: cfg.unit === "mm"
                        Layout.fillWidth: true
                        from: 0.5; to: 100
                        stepSize: 0.5
                        onMoved: valueField.text = value.toFixed(2)
                    }
                    Binding {
                        target: lengthSlider
                        property: "value"
                        value: parseFloat(valueField.text) || cfg.defaultVal
                        when: !lengthSlider.pressed
                    }
                }

                // ── Direction toggle ───────────────────────────────
                RowLayout {
                    visible: featureType === "pad" || featureType === "pocket"
                    spacing: 6
                    Layout.fillWidth: true

                    Text { text: "Direction:"; font.pixelSize: 11; color: Theme.textSec
                           Layout.alignment: Qt.AlignVCenter }

                    Rectangle {
                        id: reverseToggle
                        property bool checked: false
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        radius: 4
                        color: checked ? cfg.color : Theme.surface
                        border.width: 1
                        border.color: checked ? cfg.color : Theme.border
                        Text {
                            anchors.centerIn: parent
                            text: reverseToggle.checked ? "Reversed (\u2193)" : "Normal (\u2191)"
                            font.pixelSize: 11; font.bold: true
                            color: reverseToggle.checked ? "white" : Theme.text
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: { reverseToggle.checked = !reverseToggle.checked
                                         root.scheduleRebuild() }
                        }
                    }
                }

                // ── UX-008: Side mode (One side / Two sides / Symmetric) ──
                // Maps directly to FeatureExtrude::SideType — the three
                // strings are FreeCAD's own enum values and shouldn't be
                // localised here (Type.setValue matches them verbatim).
                ColumnLayout {
                    visible: featureType === "pad" || featureType === "pocket"
                    spacing: 4
                    Layout.fillWidth: true
                    Text { text: "Side"; font.pixelSize: 11; font.bold: true; color: Theme.textSec }
                    ComboBox {
                        id: sideCombo
                        Layout.fillWidth: true
                        model: ["One side", "Two sides", "Symmetric"]
                        currentIndex: model.indexOf(root.sideType)
                        onActivated: root.sideType = model[currentIndex]
                    }
                }

                // ── UX-008: Extrusion method (Length / ThroughAll) ────
                // Matches FeatureExtrude::Type. Extra modes (UpToFace /
                // UpToFirst / UpToLast) need a face-pick UI and are
                // deferred with UX-015.
                ColumnLayout {
                    visible: featureType === "pad" || featureType === "pocket"
                    spacing: 4
                    Layout.fillWidth: true
                    Text { text: "Method"; font.pixelSize: 11; font.bold: true; color: Theme.textSec }
                    ComboBox {
                        id: methodCombo
                        Layout.fillWidth: true
                        model: ["Length", "ThroughAll"]
                        currentIndex: model.indexOf(root.extrudeMethod)
                        onActivated: root.extrudeMethod = model[currentIndex]
                    }
                }

                // ── UX-008: Second length (only visible for "Two sides") ──
                ColumnLayout {
                    visible: (featureType === "pad" || featureType === "pocket")
                             && root.sideType === "Two sides"
                    spacing: 4
                    Layout.fillWidth: true
                    Text { text: "Length (opposite side)"
                           font.pixelSize: 11; font.bold: true; color: Theme.textSec }
                    RowLayout {
                        spacing: 6
                        Layout.fillWidth: true
                        TextField {
                            id: length2Field
                            Layout.fillWidth: true
                            text: cfg.defaultVal.toFixed(2)
                            font.pixelSize: 13; font.family: "monospace"
                            horizontalAlignment: Text.AlignRight
                            selectByMouse: true
                            validator: DoubleValidator { bottom: 0.001; decimals: 4 }
                            background: Rectangle {
                                radius: 4
                                color: length2Field.activeFocus ? Theme.surfaceAlt : Theme.surface
                                border.width: length2Field.activeFocus ? 2 : 1
                                border.color: length2Field.activeFocus ? cfg.color : Theme.border
                            }
                            onTextChanged: root.scheduleRebuild()
                            onAccepted: root.apply()
                        }
                        Text { text: "mm"; font.pixelSize: 12; font.bold: true; color: Theme.textSec
                               Layout.alignment: Qt.AlignVCenter }
                    }
                }

                // ── Live status hint (only when preview hasn't materialised) ──
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    radius: 4
                    color: Theme.warningBg
                    border.color: Theme.warning
                    border.width: 1
                    // Only shown in create mode — edit mode already has a
                    // materialised feature to mutate.
                    visible: previewName === "" && root.editingFeatureName === ""
                    Text {
                        anchors.centerIn: parent
                        text: cadEngine.sketchNames.length === 0
                            ? "Create a sketch first" : "Adjust value to preview"
                        font.pixelSize: 10; color: Theme.warning
                    }
                }

                // Spacer so content stays at top
                Item { Layout.fillHeight: true }
            }
        }

        // Footer — alternate accept/cancel buttons (some users prefer bottom)
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            color: Theme.toolbar
            border.color: Theme.border
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 6

                Button {
                    text: "Cancel"
                    Layout.fillWidth: true
                    onClicked: root.cancel()
                }
                Button {
                    text: "Apply"
                    highlighted: true
                    Layout.fillWidth: true
                    // Edit mode always has a valid target; create mode needs
                    // the preview to exist.
                    enabled: root.editingFeatureName !== "" || previewName !== ""
                    onClicked: root.apply()
                    palette.button: cfg.color
                    palette.brightText: "white"
                }
            }
        }
    }

    // Esc key → cancel
    Keys.onEscapePressed: cancel()
    focus: visible
}
