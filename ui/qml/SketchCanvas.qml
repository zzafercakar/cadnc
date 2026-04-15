import QtQuick
import QtQuick.Controls
import "components"

/**
 * SketchCanvas — 2D canvas for drawing and visualizing sketch geometry.
 *
 * Renders lines, circles, arcs from cadEngine.sketchGeometry.
 * Handles mouse interaction for drawing tools and selection.
 */
Item {
    id: canvas

    property string tool: ""         // "line", "circle", "rectangle", "arc", ""
    property int selectedGeo: -1     // selected geometry id

    // View transform
    property real viewScale: 8.0     // pixels per unit
    property real panX: width / 2
    property real panY: height / 2

    // Drawing state
    property bool drawing: false
    property real startX: 0
    property real startY: 0

    // Convert sketch coords to screen coords
    function toScreen(sx, sy) { return Qt.point(panX + sx * viewScale, panY - sy * viewScale) }
    // Convert screen coords to sketch coords
    function toSketch(px, py) { return Qt.point((px - panX) / viewScale, -(py - panY) / viewScale) }

    // ── Grid + geometry rendering ───────────────────────────────────
    Canvas {
        id: drawCanvas
        anchors.fill: parent

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            // Grid
            drawGrid(ctx)

            // Origin axes
            drawAxes(ctx)

            if (!cadEngine.sketchActive) return

            // Draw solved geometry
            var geos = cadEngine.sketchGeometry
            for (var i = 0; i < geos.length; i++) {
                var g = geos[i]
                var isSelected = (g.id === selectedGeo)
                ctx.strokeStyle = isSelected ? "#F97316" : "#2563EB"
                ctx.lineWidth = isSelected ? 2.5 : 1.5

                if (g.type === "Line") {
                    var p1 = toScreen(g.startX, g.startY)
                    var p2 = toScreen(g.endX, g.endY)
                    ctx.beginPath()
                    ctx.moveTo(p1.x, p1.y)
                    ctx.lineTo(p2.x, p2.y)
                    ctx.stroke()

                    // Endpoints
                    drawPoint(ctx, p1.x, p1.y, isSelected)
                    drawPoint(ctx, p2.x, p2.y, isSelected)
                }
                else if (g.type === "Circle") {
                    var c = toScreen(g.centerX, g.centerY)
                    var r = g.radius * viewScale
                    ctx.beginPath()
                    ctx.arc(c.x, c.y, r, 0, 2 * Math.PI)
                    ctx.stroke()
                    drawPoint(ctx, c.x, c.y, isSelected)
                }
                else if (g.type === "Arc") {
                    var ac = toScreen(g.centerX, g.centerY)
                    var ar = g.radius * viewScale
                    ctx.beginPath()
                    // Canvas arc goes clockwise, sketch counterclockwise — flip Y
                    ctx.arc(ac.x, ac.y, ar, -g.endAngle, -g.startAngle)
                    ctx.stroke()
                }
                else if (g.type === "Point") {
                    var pp = toScreen(g.centerX, g.centerY)
                    drawPoint(ctx, pp.x, pp.y, isSelected)
                }
            }

            // Draw in-progress shape
            if (drawing) {
                ctx.strokeStyle = "#059669"
                ctx.lineWidth = 1
                ctx.setLineDash([4, 4])
                drawPreview(ctx)
                ctx.setLineDash([])
            }
        }

        function drawGrid(ctx) {
            var step = viewScale * 10  // grid every 10 units
            if (step < 20) step = viewScale * 50
            ctx.strokeStyle = "#C8CDD6"
            ctx.lineWidth = 0.5
            for (var x = panX % step; x < width; x += step) {
                ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, height); ctx.stroke()
            }
            for (var y = panY % step; y < height; y += step) {
                ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(width, y); ctx.stroke()
            }
        }

        function drawAxes(ctx) {
            // X axis (red)
            ctx.strokeStyle = "#F44336"
            ctx.lineWidth = 1
            ctx.beginPath(); ctx.moveTo(0, panY); ctx.lineTo(width, panY); ctx.stroke()
            // Y axis (green)
            ctx.strokeStyle = "#4CAF50"
            ctx.beginPath(); ctx.moveTo(panX, 0); ctx.lineTo(panX, height); ctx.stroke()
        }

        function drawPoint(ctx, x, y, selected) {
            ctx.fillStyle = selected ? "#F97316" : "#2563EB"
            ctx.beginPath()
            ctx.arc(x, y, selected ? 4 : 3, 0, 2 * Math.PI)
            ctx.fill()
        }

        function drawPreview(ctx) {
            var sp = toScreen(startX, startY)
            var ep = toScreen(currentSketchX, currentSketchY)

            if (tool === "line") {
                ctx.beginPath(); ctx.moveTo(sp.x, sp.y); ctx.lineTo(ep.x, ep.y); ctx.stroke()
            } else if (tool === "circle") {
                var dx = currentSketchX - startX
                var dy = currentSketchY - startY
                var r = Math.sqrt(dx*dx + dy*dy) * viewScale
                ctx.beginPath(); ctx.arc(sp.x, sp.y, r, 0, 2 * Math.PI); ctx.stroke()
            } else if (tool === "rectangle") {
                var rp1 = toScreen(startX, startY)
                var rp2 = toScreen(currentSketchX, currentSketchY)
                ctx.beginPath()
                ctx.rect(Math.min(rp1.x, rp2.x), Math.min(rp1.y, rp2.y),
                         Math.abs(rp2.x - rp1.x), Math.abs(rp2.y - rp1.y))
                ctx.stroke()
            }
        }

        // Refresh when sketch data changes
        Connections {
            target: cadEngine
            function onSketchChanged() { drawCanvas.requestPaint() }
        }
    }

    property real currentSketchX: 0
    property real currentSketchY: 0

    // ── Mouse interaction ───────────────────────────────────────────
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        hoverEnabled: true

        property real lastMx: 0
        property real lastMy: 0

        onPositionChanged: function(mouse) {
            var sk = toSketch(mouse.x, mouse.y)
            currentSketchX = sk.x
            currentSketchY = sk.y

            // Pan with middle button
            if (mouse.buttons & Qt.MiddleButton) {
                panX += mouse.x - lastMx
                panY += mouse.y - lastMy
                drawCanvas.requestPaint()
            }
            lastMx = mouse.x
            lastMy = mouse.y

            cursorCoordLabel.mouseX = mouse.x
            cursorCoordLabel.mouseY = mouse.y
            if (drawing) drawCanvas.requestPaint()
        }

        onPressed: function(mouse) {
            lastMx = mouse.x
            lastMy = mouse.y

            if (mouse.button === Qt.LeftButton && tool !== "" && cadEngine.sketchActive) {
                var sk = toSketch(mouse.x, mouse.y)
                if (!drawing) {
                    startX = sk.x; startY = sk.y
                    drawing = true
                } else {
                    finishDrawing(sk.x, sk.y)
                }
            }
            else if (mouse.button === Qt.LeftButton && tool === "") {
                // Selection: find nearest geometry
                selectAt(mouse.x, mouse.y)
            }
            else if (mouse.button === Qt.RightButton) {
                // Cancel drawing
                drawing = false
                tool = ""
                drawCanvas.requestPaint()
            }
        }

        onWheel: function(wheel) {
            var factor = wheel.angleDelta.y > 0 ? 1.15 : 0.87
            viewScale *= factor
            viewScale = Math.max(0.5, Math.min(viewScale, 200))
            drawCanvas.requestPaint()
        }
    }

    function finishDrawing(ex, ey) {
        drawing = false
        if (tool === "line") {
            cadEngine.addLine(startX, startY, ex, ey)
        } else if (tool === "circle") {
            var dx = ex - startX; var dy = ey - startY
            cadEngine.addCircle(startX, startY, Math.sqrt(dx*dx + dy*dy))
        } else if (tool === "rectangle") {
            cadEngine.addRectangle(startX, startY, ex, ey)
        }
        // Keep tool active for continuous drawing
    }

    function selectAt(mx, my) {
        selectedGeo = -1
        var sk = toSketch(mx, my)
        var geos = cadEngine.sketchGeometry
        var minDist = 15 / viewScale  // 15px tolerance

        for (var i = 0; i < geos.length; i++) {
            var g = geos[i]
            var d = 999999

            if (g.type === "Line") {
                d = distToSegment(sk.x, sk.y, g.startX, g.startY, g.endX, g.endY)
            } else if (g.type === "Circle") {
                var dc = Math.sqrt((sk.x - g.centerX) * (sk.x - g.centerX) + (sk.y - g.centerY) * (sk.y - g.centerY))
                d = Math.abs(dc - g.radius)
            }

            if (d < minDist) {
                minDist = d
                selectedGeo = g.id
            }
        }
        drawCanvas.requestPaint()
    }

    function distToSegment(px, py, x1, y1, x2, y2) {
        var dx = x2 - x1, dy = y2 - y1
        var len2 = dx*dx + dy*dy
        if (len2 === 0) return Math.sqrt((px-x1)*(px-x1) + (py-y1)*(py-y1))
        var t = Math.max(0, Math.min(1, ((px-x1)*dx + (py-y1)*dy) / len2))
        var projX = x1 + t*dx, projY = y1 + t*dy
        return Math.sqrt((px-projX)*(px-projX) + (py-projY)*(py-projY))
    }

    // ── Navigation Cube (top-right) ─────────────────────────────────
    NavCube {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 16
        anchors.topMargin: 16
    }

    // ── Axis Indicator (bottom-left) ────────────────────────────────
    AxisIndicator {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: 8
        anchors.bottomMargin: 8
    }

    // ── Cursor coordinate tooltip ───────────────────────────────────
    Rectangle {
        id: cursorCoordLabel
        visible: canvas.drawing || canvas.tool !== ""
        x: canvas.mouseX + 18
        y: canvas.mouseY + 18
        width: coordText.implicitWidth + 12
        height: 22
        radius: 4
        color: Qt.rgba(1.0, 1.0, 1.0, 0.92)

        property real mouseX: 0
        property real mouseY: 0

        Text {
            id: coordText
            anchors.centerIn: parent
            text: canvas.currentSketchX.toFixed(2) + ", " + canvas.currentSketchY.toFixed(2)
            font.pixelSize: 10
            font.family: "monospace"
            color: "#1F2937"
        }
    }
}
