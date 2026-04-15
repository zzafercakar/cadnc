import QtQuick

/**
 * AxisIndicator — XYZ axis gizmo (MilCAD style).
 * White semi-transparent container with colored arrows and labels.
 */
Item {
    id: indicator
    width: 72; height: 72

    property string planeName: "XY"

    // Container
    Rectangle {
        anchors.fill: parent
        radius: 8
        color: Qt.rgba(1.0, 1.0, 1.0, 0.85)
        border.color: Qt.rgba(0, 0, 0, 0.1)
        border.width: 1
    }

    // Plane label
    Text {
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 6
        text: planeName + " Plane"
        color: "#4B5563"
        font.pixelSize: 10
        font.bold: true
    }

    Canvas {
        id: gizmoCanvas
        anchors.fill: parent
        anchors.topMargin: 18
        antialiasing: true

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            var cx = width / 2
            var cy = height / 2 + 10
            var axLen = 22

            var axes = [
                { dx:  axLen, dy: 0, color: "#EF5350", label: "X" },
                { dx:  0, dy: -axLen, color: "#66BB6A", label: "Y" },
                { dx: -axLen * 0.55, dy: axLen * 0.55, color: "#42A5F5", label: "Z" }
            ]

            for (var i = 0; i < axes.length; ++i) {
                drawArrow(ctx, cx, cy, cx + axes[i].dx, cy + axes[i].dy, axes[i].color, axes[i].label)
            }

            // Origin dot
            ctx.beginPath()
            ctx.arc(cx, cy, 2.5, 0, Math.PI * 2)
            ctx.fillStyle = "#FFFFFF"
            ctx.fill()
            ctx.strokeStyle = "#9CA3AF"
            ctx.lineWidth = 0.8
            ctx.stroke()
        }

        function drawArrow(ctx, x1, y1, x2, y2, color, label) {
            var dx = x2 - x1, dy = y2 - y1
            var len = Math.sqrt(dx * dx + dy * dy)
            var nx = dx / len, ny = dy / len

            // Shaft
            ctx.beginPath()
            ctx.moveTo(x1, y1); ctx.lineTo(x2, y2)
            ctx.strokeStyle = color; ctx.lineWidth = 2.5; ctx.lineCap = "round"
            ctx.stroke()

            // Arrowhead
            var headLen = 5, headAngle = Math.PI / 6
            var angle = Math.atan2(dy, dx)
            ctx.beginPath()
            ctx.moveTo(x2, y2)
            ctx.lineTo(x2 - headLen * Math.cos(angle - headAngle), y2 - headLen * Math.sin(angle - headAngle))
            ctx.moveTo(x2, y2)
            ctx.lineTo(x2 - headLen * Math.cos(angle + headAngle), y2 - headLen * Math.sin(angle + headAngle))
            ctx.strokeStyle = color; ctx.lineWidth = 2; ctx.stroke()

            // Label
            ctx.font = "bold 10px sans-serif"
            ctx.fillStyle = color
            ctx.textAlign = "center"; ctx.textBaseline = "middle"
            ctx.fillText(label, x2 + nx * 9, y2 + ny * 9)
        }
    }
}
