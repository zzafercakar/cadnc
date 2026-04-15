import QtQuick

/**
 * NavCube — OCCT AIS_ViewCube replica in QML.
 * White faces with subtle blue edges, face/edge/corner labels.
 * Matches FreeCAD/MilCAD native ViewCube appearance.
 */
Item {
    id: root
    width: 90; height: 90

    signal viewRequested(string view)

    property int hoveredFace: -1  // 0=top,1=front,2=right,3=left,4=back,5=bottom

    Canvas {
        id: cubeCanvas
        anchors.fill: parent
        antialiasing: true

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            var cx = width / 2, cy = height / 2
            var sz = 28

            // Isometric projection
            function p(x, y, z) {
                var px = cx + (x - z) * 0.866 * 0.68
                var py = cy - y * 0.7 + (x + z) * 0.5 * 0.68
                return { x: px, y: py }
            }

            // 8 vertices
            var v = [
                p(-sz,-sz,-sz), p(sz,-sz,-sz), p(sz,-sz,sz), p(-sz,-sz,sz),
                p(-sz, sz,-sz), p(sz, sz,-sz), p(sz, sz,sz), p(-sz, sz,sz)
            ]

            function drawFace(ctx, verts, faceIdx, baseColor, labelText) {
                var isHovered = (hoveredFace === faceIdx)
                ctx.globalAlpha = isHovered ? 0.95 : 0.88
                ctx.fillStyle = isHovered ? "#DBEAFE" : baseColor
                ctx.beginPath()
                ctx.moveTo(verts[0].x, verts[0].y)
                for (var i = 1; i < verts.length; i++)
                    ctx.lineTo(verts[i].x, verts[i].y)
                ctx.closePath()
                ctx.fill()

                // Edge
                ctx.globalAlpha = 1.0
                ctx.strokeStyle = isHovered ? "#2563EB" : "#94A3B8"
                ctx.lineWidth = isHovered ? 1.5 : 0.8
                ctx.stroke()

                // Label
                if (labelText) {
                    var mcx = 0, mcy = 0
                    for (var j = 0; j < verts.length; j++) { mcx += verts[j].x; mcy += verts[j].y }
                    mcx /= verts.length; mcy /= verts.length
                    ctx.globalAlpha = isHovered ? 1.0 : 0.7
                    ctx.font = isHovered ? "bold 8px sans-serif" : "7px sans-serif"
                    ctx.fillStyle = isHovered ? "#1E40AF" : "#475569"
                    ctx.textAlign = "center"; ctx.textBaseline = "middle"
                    ctx.fillText(labelText, mcx, mcy)
                }
            }

            // Back faces (hidden from this angle)
            // Left face (partially visible)
            drawFace(ctx, [v[0], v[3], v[7], v[4]], 3, "#F1F5F9", "")

            // Bottom face
            drawFace(ctx, [v[0], v[1], v[2], v[3]], 5, "#E2E8F0", "")

            // Top face — lightest, most visible
            drawFace(ctx, [v[4], v[5], v[6], v[7]], 0, "#FFFFFF", "TOP")

            // Front face
            drawFace(ctx, [v[0], v[1], v[5], v[4]], 1, "#F8FAFC", "FRONT")

            // Right face
            drawFace(ctx, [v[1], v[2], v[6], v[5]], 2, "#F1F5F9", "RIGHT")

            // Corner/edge labels (small, subtle)
            ctx.globalAlpha = 0.5
            ctx.font = "5px sans-serif"
            ctx.fillStyle = "#64748B"

            // Edge midpoint labels
            var topFrontMid = { x: (v[4].x+v[5].x)/2, y: (v[4].y+v[5].y)/2 }
            var topRightMid = { x: (v[5].x+v[6].x)/2, y: (v[5].y+v[6].y)/2 }
            ctx.fillText("N", topFrontMid.x, topFrontMid.y - 3)
            ctx.fillText("E", topRightMid.x + 4, topRightMid.y)

            ctx.globalAlpha = 1.0

            // Subtle circular ring around cube
            ctx.strokeStyle = Qt.rgba(0, 0, 0, 0.06)
            ctx.lineWidth = 1
            ctx.beginPath()
            ctx.arc(cx, cy, sz * 1.7, 0, Math.PI * 2)
            ctx.stroke()
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onPositionChanged: function(mouse) {
            var cx = width / 2, cy = height / 2
            var dx = mouse.x - cx, dy = mouse.y - cy

            var prev = hoveredFace
            if (dy < -8) hoveredFace = 0       // top
            else if (dx < -5) hoveredFace = 1  // front (left half)
            else hoveredFace = 2               // right
            if (prev !== hoveredFace) cubeCanvas.requestPaint()
        }

        onExited: { hoveredFace = -1; cubeCanvas.requestPaint() }

        onClicked: function(mouse) {
            var views = ["top", "front", "right"]
            if (hoveredFace >= 0 && hoveredFace < 3) viewRequested(views[hoveredFace])
        }
    }
}
