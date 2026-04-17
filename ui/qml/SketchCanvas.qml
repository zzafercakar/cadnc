import QtQuick
import QtQuick.Controls
import "components"
import "."

/**
 * SketchCanvas — Full 2D sketch editing overlay.
 *
 * Renders ALL sketch visuals on a QML Canvas:
 *   - Adaptive grid + origin axes
 *   - Committed geometry (lines, circles, arcs, points) from cadEngine.sketchGeometry
 *   - Rubber-band preview while drawing
 *   - Snap markers (endpoint ◆, midpoint ▲, center ⊕, grid +)
 *   - Inference lines (H/V guides through start point)
 *   - Selection highlight
 *   - Cursor coordinate tooltip
 *
 * Colors follow MilCAD/FreeCAD convention:
 *   Under-constrained: #006BD4 (blue)   Fully constrained: #22B83B (green)
 *   Over-constrained:  #DC2626 (red)    Construction:      #808080 (gray)
 *   Selected:          #F97316 (orange)  Preview:           #3B82F6 (blue dashed)
 */
Item {
    id: canvas

    property string tool: ""         // "line", "circle", "rectangle", "arc", "point", "ellipse", "polyline", "bspline", "trim", "fillet", "chamfer", "extend", "split"
    property int selectedGeo: -1     // selected geometry id

    // Grid
    property bool gridVisible: true
    property real gridSpacing: 10.0   // mm

    // Snap
    property bool snapEnabled: true
    property string snapType: ""
    property real snapRadius: 15      // pixel tolerance

    // View transform (pixels per sketch-unit)
    property real viewScale: 8.0
    property real panX: width / 2
    property real panY: height / 2

    // Drawing state
    property bool drawing: false
    property real startX: 0
    property real startY: 0
    property real currentSketchX: 0
    property real currentSketchY: 0
    property var polylinePoints: []

    // ── Coordinate conversion ──────────────────────────────────────
    function toScreen(sx, sy) { return Qt.point(panX + sx * viewScale, panY - sy * viewScale) }
    function toSketch(px, py) { return Qt.point((px - panX) / viewScale, -(py - panY) / viewScale) }

    // ── Colors (MilCAD/FreeCAD convention) ──────────────────────────
    readonly property color colDefault:       "#006BD4"  // under-constrained blue
    readonly property color colConstrained:   "#22B83B"  // fully constrained green
    readonly property color colOverConstr:    "#DC2626"  // over-constrained red
    readonly property color colConstruction:  "#808080"  // construction gray
    readonly property color colSelected:      "#F97316"  // selection orange
    readonly property color colPreview:       "#3B82F6"  // preview blue
    readonly property color colGridMinor:     "#D0D4DC"
    readonly property color colGridMajor:     "#A8AEBA"
    readonly property color colAxisX:         "#EF5350"  // red
    readonly property color colAxisY:         "#66BB6A"  // green
    readonly property color colInference:     "rgba(0, 184, 108, 0.5)"
    readonly property color colSnapInference: "rgba(0, 168, 220, 0.4)"

    // ── Snap engine ────────────────────────────────────────────────
    function snapToGrid(val) { return Math.round(val / gridSpacing) * gridSpacing }

    function snapped(sx, sy) {
        if (!snapEnabled) { snapType = ""; return Qt.point(sx, sy) }
        var geoSnap = findGeometrySnap(sx, sy)
        if (geoSnap.found) { snapType = geoSnap.type; return Qt.point(geoSnap.x, geoSnap.y) }
        snapType = "grid"
        return Qt.point(snapToGrid(sx), snapToGrid(sy))
    }

    function findGeometrySnap(sx, sy) {
        var geos = cadEngine.sketchGeometry
        var best = { found: false, x: 0, y: 0, type: "", dist: snapRadius / viewScale }
        for (var i = 0; i < geos.length; i++) {
            var g = geos[i]
            if (g.type === "Line") {
                checkSnap(best, sx, sy, g.startX, g.startY, "endpoint")
                checkSnap(best, sx, sy, g.endX, g.endY, "endpoint")
                checkSnap(best, sx, sy, (g.startX + g.endX)/2, (g.startY + g.endY)/2, "midpoint")
            } else if (g.type === "Circle" || g.type === "Arc") {
                checkSnap(best, sx, sy, g.centerX, g.centerY, "center")
                if (g.type === "Arc") {
                    // Arc endpoints from parametric → cartesian
                    var asx = g.centerX + g.radius * Math.cos(g.startAngle)
                    var asy = g.centerY + g.radius * Math.sin(g.startAngle)
                    var aex = g.centerX + g.radius * Math.cos(g.endAngle)
                    var aey = g.centerY + g.radius * Math.sin(g.endAngle)
                    checkSnap(best, sx, sy, asx, asy, "endpoint")
                    checkSnap(best, sx, sy, aex, aey, "endpoint")
                }
            } else if (g.type === "Point") {
                checkSnap(best, sx, sy, g.centerX, g.centerY, "endpoint")
            }
            else if (g.type === "Ellipse") {
                checkSnap(best, sx, sy, g.centerX, g.centerY, "center")
                var eca = Math.cos(g.angle || 0), esa = Math.sin(g.angle || 0)
                checkSnap(best, sx, sy, g.centerX + (g.majorRadius || 0) * eca, g.centerY + (g.majorRadius || 0) * esa, "endpoint")
                checkSnap(best, sx, sy, g.centerX - (g.majorRadius || 0) * eca, g.centerY - (g.majorRadius || 0) * esa, "endpoint")
                checkSnap(best, sx, sy, g.centerX - (g.minorRadius || 0) * esa, g.centerY + (g.minorRadius || 0) * eca, "endpoint")
                checkSnap(best, sx, sy, g.centerX + (g.minorRadius || 0) * esa, g.centerY - (g.minorRadius || 0) * eca, "endpoint")
            }
            else if (g.type === "BSpline") {
                var bspoles = g.poles
                if (bspoles) {
                    for (var bsp = 0; bsp < bspoles.length; bsp++)
                        checkSnap(best, sx, sy, bspoles[bsp].x, bspoles[bsp].y, "endpoint")
                }
            }
            // Origin point snap
            checkSnap(best, sx, sy, 0, 0, "endpoint")
        }
        return best
    }

    function checkSnap(best, sx, sy, px, py, type) {
        var dx = sx - px, dy = sy - py
        var dist = Math.sqrt(dx*dx + dy*dy)
        if (dist < best.dist) { best.found = true; best.x = px; best.y = py; best.type = type; best.dist = dist }
    }

    // ── Main rendering canvas ──────────────────────────────────────
    Canvas {
        id: drawCanvas
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.clearRect(0, 0, width, height)

            drawGrid(ctx)
            drawAxes(ctx)
            drawGeometry(ctx)

            if (canvas.drawing) {
                drawInferenceLines(ctx)
                drawPreview(ctx)
            }

            if (canvas.tool !== "" || canvas.drawing) {
                drawSnapMarker(ctx)
            }
        }

        // ── Grid ───────────────────────────────────────────────────
        function drawGrid(ctx) {
            if (!canvas.gridVisible) return

            var baseStep = viewScale * canvas.gridSpacing
            var step = baseStep
            if (step < 12) step = baseStep * 5
            if (step < 12) step = baseStep * 10
            if (step > 200) step = baseStep / 5

            // Minor grid — dots
            ctx.fillStyle = canvas.colGridMinor
            var dotSize = 1.2
            for (var gx = panX % step; gx < width; gx += step) {
                for (var gy = panY % step; gy < height; gy += step) {
                    ctx.fillRect(gx - dotSize/2, gy - dotSize/2, dotSize, dotSize)
                }
            }

            // Major grid — slightly larger dots every 5 grid units
            var majorStep = step * 5
            if (majorStep > 30 && majorStep < width * 2) {
                ctx.fillStyle = canvas.colGridMajor
                var majorDot = 2.0
                for (var mx = panX % majorStep; mx < width; mx += majorStep) {
                    for (var my = panY % majorStep; my < height; my += majorStep) {
                        ctx.fillRect(mx - majorDot/2, my - majorDot/2, majorDot, majorDot)
                    }
                }
            }
        }

        // ── Axes ───────────────────────────────────────────────────
        function drawAxes(ctx) {
            // X axis (red)
            ctx.strokeStyle = canvas.colAxisX
            ctx.lineWidth = 1.2
            ctx.beginPath(); ctx.moveTo(0, panY); ctx.lineTo(width, panY); ctx.stroke()
            // Y axis (green)
            ctx.strokeStyle = canvas.colAxisY
            ctx.beginPath(); ctx.moveTo(panX, 0); ctx.lineTo(panX, height); ctx.stroke()

            // Origin marker
            ctx.fillStyle = "#1F2937"
            ctx.beginPath(); ctx.arc(panX, panY, 3, 0, 2 * Math.PI); ctx.fill()
        }

        // ── Committed geometry from solver ─────────────────────────
        function drawGeometry(ctx) {
            var geos = cadEngine.sketchGeometry
            var solverOk = cadEngine.solverStatus === "Fully Constrained"

            for (var i = 0; i < geos.length; i++) {
                var g = geos[i]
                var isSel = (g.id === canvas.selectedGeo)

                // Color: selected > over-constrained > constrained > default
                if (isSel)
                    ctx.strokeStyle = canvas.colSelected
                else if (solverOk)
                    ctx.strokeStyle = canvas.colConstrained
                else
                    ctx.strokeStyle = canvas.colDefault

                ctx.lineWidth = isSel ? 2.5 : 1.8
                ctx.setLineDash([])

                // Construction geometry: dashed gray
                if (g.construction) {
                    ctx.strokeStyle = isSel ? canvas.colSelected : canvas.colConstruction
                    ctx.setLineDash([6, 3])
                }

                if (g.type === "Line") {
                    var lp1 = toScreen(g.startX, g.startY)
                    var lp2 = toScreen(g.endX, g.endY)
                    ctx.beginPath(); ctx.moveTo(lp1.x, lp1.y); ctx.lineTo(lp2.x, lp2.y); ctx.stroke()

                    // Endpoint dots
                    drawEndpoint(ctx, lp1.x, lp1.y, isSel)
                    drawEndpoint(ctx, lp2.x, lp2.y, isSel)
                }
                else if (g.type === "Circle") {
                    var cc = toScreen(g.centerX, g.centerY)
                    var cr = g.radius * viewScale
                    ctx.beginPath(); ctx.arc(cc.x, cc.y, cr, 0, 2 * Math.PI); ctx.stroke()

                    // Center marker
                    drawCenterMarker(ctx, cc.x, cc.y, isSel)
                }
                else if (g.type === "Arc") {
                    var ac = toScreen(g.centerX, g.centerY)
                    var ar = g.radius * viewScale
                    // Canvas arc: angles in radians, Y-axis inverted
                    ctx.beginPath()
                    ctx.arc(ac.x, ac.y, ar, -g.endAngle, -g.startAngle)
                    ctx.stroke()

                    // Arc endpoints
                    var as1 = toScreen(g.centerX + g.radius * Math.cos(g.startAngle),
                                       g.centerY + g.radius * Math.sin(g.startAngle))
                    var ae1 = toScreen(g.centerX + g.radius * Math.cos(g.endAngle),
                                       g.centerY + g.radius * Math.sin(g.endAngle))
                    drawEndpoint(ctx, as1.x, as1.y, isSel)
                    drawEndpoint(ctx, ae1.x, ae1.y, isSel)
                    drawCenterMarker(ctx, ac.x, ac.y, isSel)
                }
                else if (g.type === "Point") {
                    var pp = toScreen(g.centerX, g.centerY)
                    ctx.fillStyle = isSel ? canvas.colSelected : canvas.colDefault
                    ctx.beginPath(); ctx.arc(pp.x, pp.y, 4, 0, 2 * Math.PI); ctx.fill()
                }
                else if (g.type === "Ellipse") {
                    var ec = toScreen(g.centerX, g.centerY)
                    var majR = (g.majorRadius || 1) * viewScale
                    var minR = (g.minorRadius || 1) * viewScale
                    ctx.save()
                    ctx.translate(ec.x, ec.y)
                    ctx.rotate(-(g.angle || 0))
                    ctx.scale(1, minR / Math.max(majR, 0.01))
                    ctx.beginPath()
                    ctx.arc(0, 0, majR, 0, 2 * Math.PI)
                    ctx.restore()
                    ctx.stroke()
                    drawCenterMarker(ctx, ec.x, ec.y, isSel)
                }
                else if (g.type === "BSpline") {
                    var poles = g.poles
                    if (poles && poles.length >= 2) {
                        // Control polygon (dashed, faint)
                        ctx.save()
                        ctx.strokeStyle = isSel ? canvas.colSelected : "rgba(100, 100, 100, 0.4)"
                        ctx.lineWidth = 0.8
                        ctx.setLineDash([3, 3])
                        ctx.beginPath()
                        var bcp0 = toScreen(poles[0].x, poles[0].y)
                        ctx.moveTo(bcp0.x, bcp0.y)
                        for (var bci = 1; bci < poles.length; bci++) {
                            var bcpi = toScreen(poles[bci].x, poles[bci].y)
                            ctx.lineTo(bcpi.x, bcpi.y)
                        }
                        ctx.stroke()
                        ctx.restore()

                        // Smooth curve via Catmull-Rom → cubic bezier
                        ctx.strokeStyle = isSel ? canvas.colSelected : (solverOk ? canvas.colConstrained : canvas.colDefault)
                        ctx.lineWidth = isSel ? 2.5 : 1.8
                        ctx.setLineDash([])
                        ctx.beginPath()
                        var bp0 = toScreen(poles[0].x, poles[0].y)
                        ctx.moveTo(bp0.x, bp0.y)
                        if (poles.length === 2) {
                            var bp1 = toScreen(poles[1].x, poles[1].y)
                            ctx.lineTo(bp1.x, bp1.y)
                        } else if (poles.length === 3) {
                            var bqp1 = toScreen(poles[1].x, poles[1].y)
                            var bqp2 = toScreen(poles[2].x, poles[2].y)
                            ctx.quadraticCurveTo(bqp1.x, bqp1.y, bqp2.x, bqp2.y)
                        } else {
                            for (var bsi = 0; bsi < poles.length - 1; bsi++) {
                                var s0 = toScreen(poles[Math.max(0, bsi-1)].x, poles[Math.max(0, bsi-1)].y)
                                var s1 = toScreen(poles[bsi].x, poles[bsi].y)
                                var s2 = toScreen(poles[Math.min(poles.length-1, bsi+1)].x, poles[Math.min(poles.length-1, bsi+1)].y)
                                var s3 = toScreen(poles[Math.min(poles.length-1, bsi+2)].x, poles[Math.min(poles.length-1, bsi+2)].y)
                                var c1x = s1.x + (s2.x - s0.x) / 6
                                var c1y = s1.y + (s2.y - s0.y) / 6
                                var c2x = s2.x - (s3.x - s1.x) / 6
                                var c2y = s2.y - (s3.y - s1.y) / 6
                                ctx.bezierCurveTo(c1x, c1y, c2x, c2y, s2.x, s2.y)
                            }
                        }
                        ctx.stroke()

                        // Control point markers (small squares)
                        for (var bpi = 0; bpi < poles.length; bpi++) {
                            var bpp = toScreen(poles[bpi].x, poles[bpi].y)
                            ctx.fillStyle = isSel ? canvas.colSelected : "#6366F1"
                            ctx.fillRect(bpp.x - 3, bpp.y - 3, 6, 6)
                        }
                    }
                }
            }
        }

        function drawEndpoint(ctx, px, py, selected) {
            ctx.fillStyle = selected ? canvas.colSelected : "#2563EB"
            ctx.beginPath(); ctx.arc(px, py, selected ? 3.5 : 2.5, 0, 2 * Math.PI); ctx.fill()
        }

        function drawCenterMarker(ctx, px, py, selected) {
            var s = 3
            ctx.strokeStyle = selected ? canvas.colSelected : "#6B7280"
            ctx.lineWidth = 1
            ctx.beginPath(); ctx.moveTo(px - s, py); ctx.lineTo(px + s, py); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(px, py - s); ctx.lineTo(px, py + s); ctx.stroke()
        }

        // ── Inference lines (H/V guides from start point) ──────────
        function drawInferenceLines(ctx) {
            var sp = toScreen(startX, startY)
            ctx.save()
            ctx.setLineDash([6, 4])
            ctx.lineWidth = 1

            // H/V through start point
            ctx.strokeStyle = canvas.colInference
            ctx.beginPath(); ctx.moveTo(0, sp.y); ctx.lineTo(width, sp.y); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(sp.x, 0); ctx.lineTo(sp.x, height); ctx.stroke()

            // Snap reference lines through current point
            if (snapType !== "" && snapType !== "grid") {
                var cp = toScreen(currentSketchX, currentSketchY)
                ctx.strokeStyle = canvas.colSnapInference
                ctx.beginPath(); ctx.moveTo(0, cp.y); ctx.lineTo(width, cp.y); ctx.stroke()
                ctx.beginPath(); ctx.moveTo(cp.x, 0); ctx.lineTo(cp.x, height); ctx.stroke()
            }
            ctx.restore()
        }

        // ── Drawing preview (rubber band) ──────────────────────────
        function drawPreview(ctx) {
            var sp = toScreen(startX, startY)
            var ep = toScreen(currentSketchX, currentSketchY)

            ctx.strokeStyle = canvas.colPreview
            ctx.lineWidth = 1.5
            ctx.setLineDash([5, 3])

            if (tool === "line") {
                ctx.beginPath(); ctx.moveTo(sp.x, sp.y); ctx.lineTo(ep.x, ep.y); ctx.stroke()
            } else if (tool === "circle") {
                var dx = currentSketchX - startX, dy = currentSketchY - startY
                var r = Math.sqrt(dx*dx + dy*dy) * viewScale
                ctx.beginPath(); ctx.arc(sp.x, sp.y, Math.max(r, 1), 0, 2 * Math.PI); ctx.stroke()
                // Show radius text
                var rVal = Math.sqrt(dx*dx + dy*dy)
                if (rVal > 0.5) {
                    ctx.setLineDash([])
                    ctx.fillStyle = "#3B82F6"
                    ctx.font = "11px monospace"
                    ctx.fillText("R " + rVal.toFixed(1), (sp.x + ep.x)/2 + 8, (sp.y + ep.y)/2 - 6)
                }
            } else if (tool === "rectangle") {
                var rx1 = Math.min(sp.x, ep.x), ry1 = Math.min(sp.y, ep.y)
                var rw = Math.abs(ep.x - sp.x), rh = Math.abs(ep.y - sp.y)
                ctx.beginPath(); ctx.rect(rx1, ry1, rw, rh); ctx.stroke()
                // Show dimensions text
                var dw = Math.abs(currentSketchX - startX), dh = Math.abs(currentSketchY - startY)
                if (dw > 0.5 || dh > 0.5) {
                    ctx.setLineDash([])
                    ctx.fillStyle = "#3B82F6"
                    ctx.font = "11px monospace"
                    ctx.fillText(dw.toFixed(1) + " x " + dh.toFixed(1), rx1 + rw/2 - 20, ry1 - 6)
                }
            } else if (tool === "arc") {
                var adx = currentSketchX - startX, ady = currentSketchY - startY
                var ar = Math.sqrt(adx*adx + ady*ady) * viewScale
                // Show full circle as guide, arc portion solid
                ctx.globalAlpha = 0.3
                ctx.beginPath(); ctx.arc(sp.x, sp.y, Math.max(ar, 1), 0, 2 * Math.PI); ctx.stroke()
                ctx.globalAlpha = 1.0
                // Radius line
                ctx.beginPath(); ctx.moveTo(sp.x, sp.y); ctx.lineTo(ep.x, ep.y); ctx.stroke()
            }
            else if (tool === "ellipse") {
                var emajR = Math.abs(currentSketchX - startX) * viewScale
                var eminR = Math.abs(currentSketchY - startY) * viewScale
                if (emajR > 1 || eminR > 1) {
                    ctx.save()
                    ctx.translate(sp.x, sp.y)
                    ctx.scale(1, eminR / Math.max(emajR, 0.01))
                    ctx.beginPath()
                    ctx.arc(0, 0, emajR, 0, 2 * Math.PI)
                    ctx.restore()
                    ctx.stroke()
                    ctx.setLineDash([])
                    ctx.fillStyle = "#3B82F6"
                    ctx.font = "11px monospace"
                    var emjV = Math.abs(currentSketchX - startX)
                    var emnV = Math.abs(currentSketchY - startY)
                    ctx.fillText(emjV.toFixed(1) + " x " + emnV.toFixed(1), sp.x + 8, sp.y - 8)
                }
            }
            else if (tool === "polyline" || tool === "bspline") {
                ctx.beginPath()
                if (polylinePoints.length >= 1) {
                    var plp0 = toScreen(polylinePoints[0].x, polylinePoints[0].y)
                    ctx.moveTo(plp0.x, plp0.y)
                    for (var pli = 1; pli < polylinePoints.length; pli++) {
                        var plpi = toScreen(polylinePoints[pli].x, polylinePoints[pli].y)
                        ctx.lineTo(plpi.x, plpi.y)
                    }
                    ctx.lineTo(ep.x, ep.y)
                } else if (drawing) {
                    ctx.moveTo(sp.x, sp.y)
                    ctx.lineTo(ep.x, ep.y)
                }
                ctx.stroke()
                // BSpline control point markers
                if (tool === "bspline") {
                    ctx.setLineDash([])
                    ctx.fillStyle = "#6366F1"
                    for (var bmi = 0; bmi < polylinePoints.length; bmi++) {
                        var bmp = toScreen(polylinePoints[bmi].x, polylinePoints[bmi].y)
                        ctx.fillRect(bmp.x - 3, bmp.y - 3, 6, 6)
                    }
                }
            }
            ctx.setLineDash([])
        }

        // ── Snap markers ───────────────────────────────────────────
        function drawSnapMarker(ctx) {
            if (snapType === "") return
            var sp = toScreen(currentSketchX, currentSketchY)
            var px = sp.x, py = sp.y

            if (snapType === "endpoint") {
                // ◆ Green diamond
                ctx.fillStyle = "rgba(0, 217, 51, 0.9)"
                ctx.beginPath()
                ctx.moveTo(px, py - 7); ctx.lineTo(px + 7, py)
                ctx.lineTo(px, py + 7); ctx.lineTo(px - 7, py)
                ctx.closePath(); ctx.fill()
                ctx.strokeStyle = "#00AA22"; ctx.lineWidth = 1
                ctx.stroke()
            } else if (snapType === "midpoint") {
                // ▲ Cyan triangle
                ctx.fillStyle = "rgba(0, 191, 243, 0.9)"
                ctx.beginPath()
                ctx.moveTo(px, py - 7); ctx.lineTo(px + 7, py + 5); ctx.lineTo(px - 7, py + 5)
                ctx.closePath(); ctx.fill()
                ctx.strokeStyle = "#0088CC"; ctx.lineWidth = 1
                ctx.stroke()
            } else if (snapType === "center") {
                // ⊕ Orange circle with cross
                ctx.strokeStyle = "rgba(255, 166, 0, 0.9)"
                ctx.lineWidth = 2
                ctx.beginPath(); ctx.arc(px, py, 7, 0, 2 * Math.PI); ctx.stroke()
                ctx.beginPath(); ctx.moveTo(px - 5, py); ctx.lineTo(px + 5, py); ctx.stroke()
                ctx.beginPath(); ctx.moveTo(px, py - 5); ctx.lineTo(px, py + 5); ctx.stroke()
            } else if (snapType === "grid") {
                // Small crosshair for grid snap
                ctx.strokeStyle = "rgba(249, 115, 22, 0.6)"
                ctx.lineWidth = 1.2
                ctx.beginPath(); ctx.moveTo(px - 5, py); ctx.lineTo(px + 5, py); ctx.stroke()
                ctx.beginPath(); ctx.moveTo(px, py - 5); ctx.lineTo(px, py + 5); ctx.stroke()
            }
        }

        Connections {
            target: cadEngine
            function onSketchChanged() { drawCanvas.requestPaint() }
        }
    }

    // ── Mouse: drawing + hover ─────────────────────────────────────
    MouseArea {
        id: drawArea
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        hoverEnabled: true  // always hover to show snap markers + coordinates
        propagateComposedEvents: true

        property real lastMx: 0
        property real lastMy: 0
        property bool panning: false

        onPositionChanged: function(mouse) {
            // Middle-button pan
            if (panning) {
                panX += (mouse.x - lastMx)
                panY += (mouse.y - lastMy)
                lastMx = mouse.x; lastMy = mouse.y
                drawCanvas.requestPaint()
                return
            }

            var raw = toSketch(mouse.x, mouse.y)
            var sk = snapped(raw.x, raw.y)
            currentSketchX = sk.x
            currentSketchY = sk.y
            lastMx = mouse.x; lastMy = mouse.y
            cursorCoordLabel.mouseX = mouse.x
            cursorCoordLabel.mouseY = mouse.y
            drawCanvas.requestPaint()
        }

        onPressed: function(mouse) {
            lastMx = mouse.x; lastMy = mouse.y

            // Middle button → pan
            if (mouse.button === Qt.MiddleButton) {
                panning = true
                return
            }

            // Left button → draw
            if (mouse.button === Qt.LeftButton && tool !== "" && cadEngine.sketchActive) {
                var sk = snapped(toSketch(mouse.x, mouse.y).x, toSketch(mouse.x, mouse.y).y)

                if (tool === "point") {
                    cadEngine.addPoint(sk.x, sk.y)
                    return
                }

                if (tool === "polyline" || tool === "bspline") {
                    if (!drawing) {
                        polylinePoints = [{"x": sk.x, "y": sk.y}]
                        drawing = true
                    } else {
                        polylinePoints.push({"x": sk.x, "y": sk.y})
                    }
                    drawCanvas.requestPaint()
                    return
                }

                if (tool === "extend") {
                    selectAt(mouse.x, mouse.y)
                    if (selectedGeo >= 0) {
                        cadEngine.extendGeo(selectedGeo, 10.0, 2)
                    }
                    return
                }

                if (tool === "split") {
                    selectAt(mouse.x, mouse.y)
                    if (selectedGeo >= 0) {
                        cadEngine.splitAtPoint(selectedGeo, sk.x, sk.y)
                        selectedGeo = -1
                    }
                    return
                }

                if (!drawing) {
                    startX = sk.x; startY = sk.y
                    drawing = true
                } else {
                    finishDrawing(sk.x, sk.y)
                }
            }

            // Left button without tool → select
            if (mouse.button === Qt.LeftButton && tool === "" && !drawing && cadEngine.sketchActive) {
                selectAt(mouse.x, mouse.y)
            }

            // Right button → cancel drawing
            if (mouse.button === Qt.RightButton) {
                if ((tool === "polyline" || tool === "bspline") && drawing && polylinePoints.length >= 2) {
                    if (tool === "polyline") {
                        var plPts = []
                        for (var pfi = 0; pfi < polylinePoints.length; pfi++)
                            plPts.push({"x": polylinePoints[pfi].x, "y": polylinePoints[pfi].y})
                        cadEngine.addPolyline(plPts)
                    } else {
                        cadEngine.addBSpline(polylinePoints)
                    }
                    polylinePoints = []
                    drawing = false
                    drawCanvas.requestPaint()
                } else if (drawing) {
                    drawing = false
                    polylinePoints = []
                    drawCanvas.requestPaint()
                } else {
                    tool = ""
                    drawCanvas.requestPaint()
                }
            }
        }

        onReleased: function(mouse) {
            if (mouse.button === Qt.MiddleButton) { panning = false }
        }

        onWheel: function(wheel) {
            // Zoom centered on cursor
            var factor = wheel.angleDelta.y > 0 ? 1.15 : (1.0 / 1.15)
            var mx = wheel.x, my = wheel.y

            // Adjust pan so the point under cursor stays fixed
            panX = mx - (mx - panX) * factor
            panY = my - (my - panY) * factor
            viewScale *= factor

            // Clamp
            if (viewScale < 0.5) viewScale = 0.5
            if (viewScale > 200) viewScale = 200

            drawCanvas.requestPaint()
        }
    }

    // ── Drawing completion ──────────────────────────────────────────
    function finishDrawing(ex, ey) {
        drawing = false
        if (tool === "line") {
            cadEngine.addLine(startX, startY, ex, ey)
        } else if (tool === "circle") {
            var dx = ex - startX, dy = ey - startY
            var r = Math.sqrt(dx*dx + dy*dy)
            if (r > 0.01) cadEngine.addCircle(startX, startY, r)
        } else if (tool === "rectangle") {
            cadEngine.addRectangle(startX, startY, ex, ey)
        } else if (tool === "arc") {
            var adx = ex - startX, ady = ey - startY
            var arcR = Math.sqrt(adx*adx + ady*ady)
            var endAngle = Math.atan2(ady, adx) * 180.0 / Math.PI
            if (arcR > 0.01) cadEngine.addArc(startX, startY, arcR, 0, endAngle)
        }
        else if (tool === "ellipse") {
            var emajR = Math.abs(ex - startX)
            var eminR = Math.abs(ey - startY)
            if (emajR > 0.01 || eminR > 0.01)
                cadEngine.addEllipse(startX, startY, emajR, eminR, 0)
        }
        // Tool stays active for continuous drawing
    }

    // ── Selection ──────────────────────────────────────────────────
    function selectAt(mx, my) {
        selectedGeo = -1
        var sk = toSketch(mx, my)
        var geos = cadEngine.sketchGeometry
        var minDist = 15 / viewScale

        for (var i = 0; i < geos.length; i++) {
            var g = geos[i]
            var d = 999999

            if (g.type === "Line") {
                d = distToSegment(sk.x, sk.y, g.startX, g.startY, g.endX, g.endY)
            } else if (g.type === "Circle") {
                var dc = Math.sqrt((sk.x - g.centerX)*(sk.x - g.centerX) + (sk.y - g.centerY)*(sk.y - g.centerY))
                d = Math.abs(dc - g.radius)
            } else if (g.type === "Arc") {
                var dac = Math.sqrt((sk.x - g.centerX)*(sk.x - g.centerX) + (sk.y - g.centerY)*(sk.y - g.centerY))
                d = Math.abs(dac - g.radius)
            } else if (g.type === "Point") {
                d = Math.sqrt((sk.x - g.centerX)*(sk.x - g.centerX) + (sk.y - g.centerY)*(sk.y - g.centerY))
            }
            else if (g.type === "Ellipse") {
                var edx = sk.x - g.centerX, edy = sk.y - g.centerY
                var eca2 = Math.cos(g.angle || 0), esa2 = Math.sin(g.angle || 0)
                var elx = edx * eca2 + edy * esa2, ely = -edx * esa2 + edy * eca2
                var majR = g.majorRadius || 1, minR = g.minorRadius || 1
                var normDist = Math.sqrt((elx*elx)/(majR*majR) + (ely*ely)/(minR*minR))
                d = Math.abs(normDist - 1.0) * Math.max(majR, minR)
            }
            else if (g.type === "BSpline") {
                var bspoles2 = g.poles
                if (bspoles2 && bspoles2.length >= 2) {
                    d = 999999
                    for (var bsi2 = 0; bsi2 < bspoles2.length - 1; bsi2++) {
                        var bsd = distToSegment(sk.x, sk.y, bspoles2[bsi2].x, bspoles2[bsi2].y, bspoles2[bsi2+1].x, bspoles2[bsi2+1].y)
                        if (bsd < d) d = bsd
                    }
                }
            }

            if (d < minDist) { minDist = d; selectedGeo = g.id }
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

    // ── Cursor coordinate tooltip ──────────────────────────────────
    Rectangle {
        id: cursorCoordLabel
        visible: cadEngine.sketchActive
        x: mouseX + 18; y: mouseY + 18
        width: coordText.implicitWidth + 14
        height: 22; radius: 4
        color: Qt.rgba(1, 1, 1, 0.92)
        border.width: 1; border.color: "#D1D5DB"

        property real mouseX: 0
        property real mouseY: 0

        Text {
            id: coordText
            anchors.centerIn: parent
            text: canvas.currentSketchX.toFixed(2) + ", " + canvas.currentSketchY.toFixed(2)
            font.pixelSize: 10; font.family: "monospace"; color: "#1F2937"
        }
    }
}
