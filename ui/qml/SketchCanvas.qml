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

    property string tool: ""         // "line", "circle", "rectangle", "arc", "point", "ellipse", "polyline", "bspline", "trim", "fillet", "chamfer", "extend", "split", "dimension"
    property int selectedGeo: -1     // primary selected geometry (for tool pick flow)
    property var selectedGeos: []    // rubber-band / multi-select geometry ids

    // Rubber-band drag state (BUG-012). Only active when no tool + no draw in
    // progress. Left-to-right = fully-enclosed selection; right-to-left =
    // crossing selection (SolidWorks / FreeCAD convention).
    property bool rubberActive: false
    property real rubberX0: 0
    property real rubberY0: 0
    property real rubberX1: 0
    property real rubberY1: 0

    // Switching tools cancels any in-progress dimension edit so the floating
    // editor doesn't linger and apply a stale value to the wrong geometry.
    // Also drops any hover preselection so the amber tint doesn't persist.
    onToolChanged: {
        if (tool !== "dimension") cancelDimension()
        hoveredGeo = -1
    }

    // Grid — both visibility and spacing come from CadEngine so toggling via
    // the status bar hits the 2D overlay AND the 3D OCCT viewer grid in one
    // shot (BUG-013). Keep the declarations as bindings, not assignments —
    // writing `gridVisible = X` from JS would break the binding.
    property bool gridVisible: cadEngine.gridVisible
    onGridVisibleChanged: drawCanvas.requestPaint()
    property real gridSpacing: cadEngine.gridSpacing

    // Adaptive grid step in sketch units. Declarative binding so the value
    // re-computes the instant viewScale or gridSpacing changes — drawGrid()
    // and snapToGrid() always observe the same number.
    // Single source of truth: never mutate from inside paint().
    property real activeGridSpacing: {
        var baseStep = viewScale * gridSpacing
        var step = baseStep
        if (step < 12) step = baseStep * 5
        if (step < 12) step = baseStep * 10
        if (step > 200) step = baseStep / 5
        return step / viewScale
    }
    onActiveGridSpacingChanged: drawCanvas.requestPaint()

    // Snap
    property bool snapEnabled: true
    property string snapType: ""
    property real snapRadius: 15      // pixel tolerance

    // Snap target tracking — matches FreeCAD's PreselectionData.
    // Populated by snapped(); captured into startSnap* on first click so
    // finishDrawing() can emit auto-constraints.
    // pos semantics (Sketcher::PointPos): 0=none (edge), 1=start, 2=end, 3=mid (circle/arc center, point)
    property int currentSnapGeoId: -1
    property int currentSnapPos: 0
    property int startSnapGeoId: -1
    property int startSnapPos: 0
    property string startSnapType: ""

    // Hover highlight for tool modes (dimension/trim/fillet/extend/split).
    // Matches FreeCAD's Preselection visual feedback.
    property int hoveredGeo: -1

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

    // Pending fillet/chamfer state — set when vertex picked, consumed on Apply
    property int pendingFilletGeo: -1
    property int pendingFilletPos: 0
    property string pendingFilletKind: ""  // "fillet" or "chamfer"

    // Smart Dimension state — set when geo picked, consumed on Enter
    property int dimGeo: -1
    property string dimKind: ""    // "distance" | "radius" | "diameter"
    property real dimX: 0          // canvas pixel anchor for the floating input
    property real dimY: 0
    property real dimCurrent: 0    // current measured value (mm or deg)
    // Constraint id of an already-existing dimension on the picked geometry.
    // >= 0 → applyDimension() calls setDatum() instead of addConstraint(),
    // matching FreeCAD's re-open-for-edit behaviour.
    property int dimExistingId: -1

    // Per-constraint label offsets for drag-to-move dimension labels. Keyed
    // by constraint id; value is a Qt.point in screen pixels (dx, dy) added
    // on top of the automatic placement. MilCAD / SolidWorks parity — users
    // expect to drag dimension text out of the way.
    property var dimOffsets: ({})
    function dimOffsetFor(cid) {
        var v = dimOffsets[cid]
        return v ? v : Qt.point(0, 0)
    }
    function setDimOffset(cid, dx, dy) {
        var copy = {}
        for (var k in dimOffsets) copy[k] = dimOffsets[k]
        copy[cid] = Qt.point(dx, dy)
        dimOffsets = copy
        drawCanvas.requestPaint()
    }

    // ── Coordinate conversion ──────────────────────────────────────
    function toScreen(sx, sy) { return Qt.point(panX + sx * viewScale, panY - sy * viewScale) }
    function toSketch(px, py) { return Qt.point((px - panX) / viewScale, -(py - panY) / viewScale) }

    // ── Colors (MilCAD/FreeCAD convention) ──────────────────────────
    readonly property color colDefault:       "#006BD4"  // under-constrained blue
    readonly property color colConstrained:   "#22B83B"  // fully constrained green
    readonly property color colConflict:      "#DC2626"  // over-constrained / conflicting red
    readonly property color colRedundant:     "#F59E0B"  // redundant amber
    readonly property color colOverConstr:    "#DC2626"  // over-constrained red
    readonly property color colConstruction:  "#808080"  // construction gray
    readonly property color colSelected:      "#F97316"  // selection orange
    readonly property color colHover:         "#FCD34D"  // hover amber (tool preselection)
    readonly property color colPreview:       "#3B82F6"  // preview blue
    readonly property color colGridMinor:     "#D0D4DC"
    readonly property color colGridMajor:     "#A8AEBA"
    readonly property color colAxisX:         "#EF5350"  // red
    readonly property color colAxisY:         "#66BB6A"  // green
    readonly property color colInference:     Qt.rgba(0/255, 184/255, 108/255, 0.5)
    readonly property color colSnapInference: Qt.rgba(0/255, 168/255, 220/255, 0.4)

    // ── Snap engine ────────────────────────────────────────────────
    function snapToGrid(val) { return Math.round(val / activeGridSpacing) * activeGridSpacing }

    function snapped(sx, sy) {
        if (!snapEnabled) {
            snapType = ""; currentSnapGeoId = -1; currentSnapPos = 0
            return Qt.point(sx, sy)
        }
        var geoSnap = findGeometrySnap(sx, sy)
        if (geoSnap.found) {
            snapType = geoSnap.type
            currentSnapGeoId = geoSnap.geoId
            currentSnapPos = geoSnap.pos
            return Qt.point(geoSnap.x, geoSnap.y)
        }
        snapType = "grid"
        currentSnapGeoId = -1
        currentSnapPos = 0
        return Qt.point(snapToGrid(sx), snapToGrid(sy))
    }

    // Snap point classification mirrors Sketcher::PointPos (used by the
    // auto-constraint pipeline): 1=start, 2=end, 3=mid (center), 0=none (edge).
    function findGeometrySnap(sx, sy) {
        var geos = cadEngine.sketchGeometry
        var best = { found: false, x: 0, y: 0, type: "", dist: snapRadius / viewScale, geoId: -1, pos: 0 }
        for (var i = 0; i < geos.length; i++) {
            var g = geos[i]
            if (g.type === "Line") {
                checkSnap(best, sx, sy, g.startX, g.startY, "endpoint", g.id, 1)
                checkSnap(best, sx, sy, g.endX, g.endY, "endpoint", g.id, 2)
                // Midpoint of a line has no native PointPos — pos=0 marks it so
                // the caller knows to emit Symmetric(line.start, line.end, ours)
                // rather than a direct Coincident.
                checkSnap(best, sx, sy, (g.startX + g.endX)/2, (g.startY + g.endY)/2, "midpoint", g.id, 0)
            } else if (g.type === "Circle" || g.type === "Arc") {
                checkSnap(best, sx, sy, g.centerX, g.centerY, "center", g.id, 3)
                if (g.type === "Arc") {
                    var asx = g.centerX + g.radius * Math.cos(g.startAngle)
                    var asy = g.centerY + g.radius * Math.sin(g.startAngle)
                    var aex = g.centerX + g.radius * Math.cos(g.endAngle)
                    var aey = g.centerY + g.radius * Math.sin(g.endAngle)
                    checkSnap(best, sx, sy, asx, asy, "endpoint", g.id, 1)
                    checkSnap(best, sx, sy, aex, aey, "endpoint", g.id, 2)
                }
            } else if (g.type === "Point") {
                // GeomPoint stores its vertex at PointPos::start (1)
                checkSnap(best, sx, sy, g.centerX, g.centerY, "endpoint", g.id, 1)
            }
            else if (g.type === "Ellipse") {
                checkSnap(best, sx, sy, g.centerX, g.centerY, "center", g.id, 3)
                var eca = Math.cos(g.angle || 0), esa = Math.sin(g.angle || 0)
                // Ellipse axis endpoints aren't first-class sketcher vertices —
                // leave geoId=-1 so they act as positional snap only.
                checkSnap(best, sx, sy, g.centerX + (g.majorRadius || 0) * eca, g.centerY + (g.majorRadius || 0) * esa, "endpoint", -1, 0)
                checkSnap(best, sx, sy, g.centerX - (g.majorRadius || 0) * eca, g.centerY - (g.majorRadius || 0) * esa, "endpoint", -1, 0)
                checkSnap(best, sx, sy, g.centerX - (g.minorRadius || 0) * esa, g.centerY + (g.minorRadius || 0) * eca, "endpoint", -1, 0)
                checkSnap(best, sx, sy, g.centerX + (g.minorRadius || 0) * esa, g.centerY - (g.minorRadius || 0) * eca, "endpoint", -1, 0)
            }
            else if (g.type === "BSpline") {
                var bspoles = g.poles
                if (bspoles) {
                    // Pole positions aren't vertices — positional snap only.
                    for (var bsp = 0; bsp < bspoles.length; bsp++)
                        checkSnap(best, sx, sy, bspoles[bsp].x, bspoles[bsp].y, "endpoint", -1, 0)
                }
            }
        }
        // Origin point — handled as positional snap (no associated geoId)
        checkSnap(best, sx, sy, 0, 0, "endpoint", -1, 0)
        return best
    }

    function checkSnap(best, sx, sy, px, py, type, geoId, pos) {
        var dx = sx - px, dy = sy - py
        var dist = Math.sqrt(dx*dx + dy*dy)
        if (dist < best.dist) {
            best.found = true; best.x = px; best.y = py; best.type = type; best.dist = dist
            best.geoId = (geoId === undefined) ? -1 : geoId
            best.pos = (pos === undefined) ? 0 : pos
        }
    }

    // Mirrors FreeCAD DrawSketchHandler::createAutoConstraints for the VERTEX
    // case (we're placing a vertex — line endpoint, circle center, etc.):
    //   endpoint / center snap → Coincident(new.pos, target.pos)
    //   midpoint snap          → Symmetric(line.start, line.end, new.pos)
    //   edge snap (curve only) → PointOnObject
    // The caller passes the newly-created geometry id and the PointPos that
    // was being placed (1 for line start, 2 for line end, 3 for circle/arc center).
    function emitAutoConstraint(newGeoId, newPos, tgtGeoId, tgtPos, tgtType) {
        if (newGeoId < 0 || tgtGeoId < 0 || tgtGeoId === newGeoId) return
        if (tgtType === "endpoint" || tgtType === "center") {
            cadEngine.addCoincidentConstraint(newGeoId, newPos, tgtGeoId, tgtPos)
        } else if (tgtType === "midpoint") {
            // Symmetric(line.start, line.end, new.pos) forces new to sit on the
            // perpendicular bisector of the line — at the midpoint specifically
            // because the two endpoints are themselves fixed relative to it.
            cadEngine.addSymmetricConstraint(tgtGeoId, 1, tgtGeoId, 2, newGeoId, newPos)
        }
        // "grid" / none → nothing
    }

    // Scan current constraints for an existing Distance/Radius/Diameter on
    // the given geometry. Returns {id, value} or {id:-1, value:0}. Enables
    // Smart Dimension's re-apply-to-update behaviour (FreeCAD parity).
    function findExistingDimension(geoId, kind) {
        var cs = cadEngine.sketchConstraints
        var want = (kind === "distance") ? "Distance" :
                   (kind === "radius")   ? "Radius"   :
                   (kind === "diameter") ? "Diameter" : ""
        for (var i = 0; i < cs.length; i++) {
            if (cs[i].firstGeoId === geoId && cs[i].typeName === want)
                return { id: cs[i].id, value: cs[i].value }
        }
        return { id: -1, value: 0 }
    }

    // Tool-mode hover: find the closest geometry under (mx,my) without
    // committing a selection. Shared logic with selectAt but non-mutating.
    function findGeoAt(mx, my) {
        var sk = toSketch(mx, my)
        var geos = cadEngine.sketchGeometry
        var minDist = 15 / viewScale
        var bestId = -1
        for (var i = 0; i < geos.length; i++) {
            var g = geos[i]
            var d = 999999
            if (g.type === "Line") {
                d = distToSegment(sk.x, sk.y, g.startX, g.startY, g.endX, g.endY)
            } else if (g.type === "Circle" || g.type === "Arc") {
                var dc = Math.sqrt((sk.x - g.centerX)*(sk.x - g.centerX) + (sk.y - g.centerY)*(sk.y - g.centerY))
                d = Math.abs(dc - g.radius)
            } else if (g.type === "Point") {
                d = Math.sqrt((sk.x - g.centerX)*(sk.x - g.centerX) + (sk.y - g.centerY)*(sk.y - g.centerY))
            }
            if (d < minDist) { minDist = d; bestId = g.id }
        }
        return bestId
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
            drawDimensions(ctx)

            if (canvas.drawing) {
                drawInferenceLines(ctx)
                drawPreview(ctx)
            }

            if (canvas.tool !== "" || canvas.drawing) {
                drawSnapMarker(ctx)
            }

            if (canvas.rubberActive) {
                drawRubberBand(ctx)
            }
        }

        // Rubber-band rectangle: solid blue outline for fully-enclosed
        // (left-to-right drag), dashed green for crossing (right-to-left).
        // Matches SolidWorks/FreeCAD selection semantics.
        function drawRubberBand(ctx) {
            var p0 = canvas.toScreen(canvas.rubberX0, canvas.rubberY0)
            var p1 = canvas.toScreen(canvas.rubberX1, canvas.rubberY1)
            var x = Math.min(p0.x, p1.x), y = Math.min(p0.y, p1.y)
            var w = Math.abs(p1.x - p0.x), h = Math.abs(p1.y - p0.y)
            var crossing = canvas.rubberX1 < canvas.rubberX0
            ctx.save()
            ctx.strokeStyle = crossing ? "#22B83B" : "#3B82F6"
            ctx.fillStyle   = crossing ? "rgba(34,184,59,0.08)" : "rgba(59,130,246,0.08)"
            ctx.lineWidth = 1
            if (crossing) ctx.setLineDash([5, 3])
            ctx.fillRect(x, y, w, h)
            ctx.strokeRect(x, y, w, h)
            ctx.restore()
        }

        // ── Grid ───────────────────────────────────────────────────
        function drawGrid(ctx) {
            if (!canvas.gridVisible) return

            // Read the binding-driven step. Never write back here:
            // assignment from JS would destroy the binding declared on canvas.
            var step = canvas.activeGridSpacing * canvas.viewScale

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
            // Semantic: DoF=0 → fully-constrained green; DoF>0 → blue;
            // over/conflicting → red; redundant → amber. solverStatus
            // now differentiates Under vs Fully via DoF count.
            var status = cadEngine.solverStatus
            var baseCol = canvas.colDefault
            // "Fully Constrained" and "Fully Constrained (Redundant)" both
            // have DoF=0, so both stay green. A redundant constraint just
            // duplicates information — the geometry is still locked.
            if (status.indexOf("Fully Constrained") === 0)  baseCol = canvas.colConstrained
            else if (status.indexOf("Under") === 0)          baseCol = canvas.colDefault
            else if (status === "Over Constrained" ||
                     status === "Conflicting")               baseCol = canvas.colConflict
            else if (status === "Redundant")                 baseCol = canvas.colRedundant

            for (var i = 0; i < geos.length; i++) {
                var g = geos[i]
                var isSel = (g.id === canvas.selectedGeo)
                                 || (canvas.selectedGeos.indexOf(g.id) >= 0)
                var isHover = (g.id === canvas.hoveredGeo) && !isSel

                // Color priority: selected > hover > solver-derived base.
                if (isSel)
                    ctx.strokeStyle = canvas.colSelected
                else if (isHover)
                    ctx.strokeStyle = canvas.colHover
                else
                    ctx.strokeStyle = baseCol

                ctx.lineWidth = (isSel || isHover) ? 2.5 : 1.8
                ctx.setLineDash([])

                // Construction geometry: dashed gray
                if (g.construction) {
                    ctx.strokeStyle = isSel ? canvas.colSelected :
                                      isHover ? canvas.colHover : canvas.colConstruction
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
                        ctx.strokeStyle = isSel ? canvas.colSelected : baseCol
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

        // ── UX-013: Dimension labels ───────────────────────────────
        // Draw a thin black leader + value label for every Distance/Radius/
        // Diameter constraint. Mirrors FreeCAD's on-canvas dimension style
        // so sketches "look dimensioned" at a glance instead of forcing the
        // user to open the constraint panel.
        function drawDimensions(ctx) {
            var cs = cadEngine.sketchConstraints
            var geos = cadEngine.sketchGeometry
            if (!cs || cs.length === 0 || !geos || geos.length === 0) return

            // Build a geoId → geometry map. Faster than re-scanning the list
            // for each constraint and keeps drawDimensions O(n+m).
            var byId = {}
            for (var i = 0; i < geos.length; i++) byId[geos[i].id] = geos[i]

            ctx.save()
            ctx.lineWidth = 1
            ctx.font = "11px 'Segoe UI', sans-serif"
            ctx.textAlign = "center"
            ctx.textBaseline = "middle"

            for (var j = 0; j < cs.length; j++) {
                var c = cs[j]
                var g = byId[c.firstGeoId]
                if (!g) continue

                var off = canvas.dimOffsetFor(c.id)
                if (c.typeName === "Distance" && g.type === "Line") {
                    drawDistanceLabel(ctx, g, c.value, "", off)
                } else if (c.typeName === "Radius" && (g.type === "Arc" || g.type === "Circle")) {
                    drawRadiusLabel(ctx, g, c.value, false, off)
                } else if (c.typeName === "Diameter" && g.type === "Circle") {
                    drawRadiusLabel(ctx, g, c.value, true, off)
                } else if (c.typeName === "DistanceX" && g.type === "Line") {
                    drawDistanceLabel(ctx, g, c.value, "X", off)
                } else if (c.typeName === "DistanceY" && g.type === "Line") {
                    drawDistanceLabel(ctx, g, c.value, "Y", off)
                }
            }
            ctx.restore()
        }

        // Distance dimension: parallel offset leader with arrow tips + text.
        // `axis` is "" for euclidean distance, "X" for horizontal component,
        // "Y" for vertical — matches the three constraint flavours we expose.
        // `userOffset` is a screen-pixel point (dx,dy) added to the label
        // position so the user can drag the label clear of the geometry.
        function drawDistanceLabel(ctx, g, value, axis, userOffset) {
            var p1 = toScreen(g.startX, g.startY)
            var p2 = toScreen(g.endX,   g.endY)
            var dx = p2.x - p1.x, dy = p2.y - p1.y
            var len = Math.sqrt(dx*dx + dy*dy)
            if (len < 1) return

            // Perpendicular offset so the dimension line sits above the
            // geometry. Fixed pixel distance so it stays readable at any
            // zoom — FreeCAD does the same.
            var offsetPx = 18
            var nx = -dy / len, ny = dx / len
            var o1x = p1.x + nx * offsetPx, o1y = p1.y + ny * offsetPx
            var o2x = p2.x + nx * offsetPx, o2y = p2.y + ny * offsetPx

            ctx.strokeStyle = "#1F2937"
            ctx.fillStyle   = "#1F2937"

            // Extension lines (geometry endpoints ➝ dimension line)
            ctx.beginPath()
            ctx.moveTo(p1.x, p1.y); ctx.lineTo(o1x, o1y)
            ctx.moveTo(p2.x, p2.y); ctx.lineTo(o2x, o2y)
            ctx.stroke()

            // Dimension line itself
            ctx.beginPath(); ctx.moveTo(o1x, o1y); ctx.lineTo(o2x, o2y); ctx.stroke()

            // Arrow tips at both ends
            drawArrowhead(ctx, o1x, o1y, -dx / len, -dy / len)
            drawArrowhead(ctx, o2x, o2y,  dx / len,  dy / len)

            // Label background pill + value. If the user dragged the label,
            // draw a thin leader from the natural midpoint to the dragged
            // position so the association stays visible.
            var mx = (o1x + o2x) * 0.5, my = (o1y + o2y) * 0.5
            var lx = mx + (userOffset ? userOffset.x : 0)
            var ly = my + (userOffset ? userOffset.y : 0)
            if (userOffset && (userOffset.x !== 0 || userOffset.y !== 0)) {
                ctx.save()
                ctx.strokeStyle = "#9CA3AF"
                ctx.setLineDash([3, 3])
                ctx.beginPath(); ctx.moveTo(mx, my); ctx.lineTo(lx, ly); ctx.stroke()
                ctx.restore()
            }
            var prefix = (axis === "X") ? "" : (axis === "Y") ? "" : ""
            var label = prefix + value.toFixed(2)
            var tw = ctx.measureText(label).width + 8
            ctx.fillStyle = "#FFFFFF"
            ctx.fillRect(lx - tw/2, ly - 8, tw, 16)
            ctx.strokeStyle = "#1F2937"
            ctx.strokeRect(lx - tw/2, ly - 8, tw, 16)
            ctx.fillStyle = "#1F2937"
            ctx.fillText(label, lx, ly)
        }

        // Radius / diameter leader: line from the circle edge outward at 30°
        // then a short horizontal run + label. "R" prefix for radius, "Ø"
        // for diameter.
        function drawRadiusLabel(ctx, g, value, isDiameter, userOffset) {
            var c = toScreen(g.centerX, g.centerY)
            var rpx = g.radius * viewScale
            if (rpx < 2) return

            // Angle for the leader — prefer the 30° direction, unless the
            // arc's sweep doesn't cover it, in which case use the arc's
            // midpoint so the leader always touches real geometry.
            var theta = Math.PI / 6
            if (g.type === "Arc" && typeof g.startAngle === "number") {
                theta = (g.startAngle + g.endAngle) * 0.5
            }
            var ex = c.x + Math.cos(theta) * rpx
            var ey = c.y - Math.sin(theta) * rpx  // screen Y inverted
            var lx = ex + Math.cos(theta) * 28
            var ly = ey - Math.sin(theta) * 28

            ctx.strokeStyle = "#1F2937"
            ctx.fillStyle   = "#1F2937"
            ctx.beginPath(); ctx.moveTo(c.x, c.y); ctx.lineTo(ex, ey); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(ex, ey); ctx.lineTo(lx, ly); ctx.stroke()
            drawArrowhead(ctx, ex, ey, -Math.cos(theta), Math.sin(theta))

            var label = (isDiameter ? "\u00D8" : "R") + value.toFixed(2)
            var tw = ctx.measureText(label).width + 8
            var tx = lx + (Math.cos(theta) >= 0 ? tw / 2 + 4 : -tw / 2 - 4)
            var ty = ly - 2
            // Apply optional drag offset, with a dashed leader back to the
            // natural label position when dragged.
            var dx = (userOffset ? userOffset.x : 0)
            var dy = (userOffset ? userOffset.y : 0)
            var fx = tx + dx, fy = ty + dy
            if (dx !== 0 || dy !== 0) {
                ctx.save()
                ctx.strokeStyle = "#9CA3AF"
                ctx.setLineDash([3, 3])
                ctx.beginPath(); ctx.moveTo(tx, ty); ctx.lineTo(fx, fy); ctx.stroke()
                ctx.restore()
            }
            ctx.fillStyle = "#FFFFFF"
            ctx.fillRect(fx - tw/2, fy - 8, tw, 16)
            ctx.strokeStyle = "#1F2937"
            ctx.strokeRect(fx - tw/2, fy - 8, tw, 16)
            ctx.fillStyle = "#1F2937"
            ctx.fillText(label, fx, fy)
        }

        // Solid triangle at (px, py) pointing along (dirX, dirY). Size fixed
        // at 5px so it stays proportional to the dimension line regardless
        // of zoom level.
        function drawArrowhead(ctx, px, py, dirX, dirY) {
            var size = 5
            var pxEnd = px - dirX * size
            var pyEnd = py - dirY * size
            // Perpendicular for the base of the triangle
            var perpX = -dirY * size * 0.4
            var perpY =  dirX * size * 0.4
            ctx.beginPath()
            ctx.moveTo(px, py)
            ctx.lineTo(pxEnd + perpX, pyEnd + perpY)
            ctx.lineTo(pxEnd - perpX, pyEnd - perpY)
            ctx.closePath()
            ctx.fill()
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

    // ── Draggable dimension label handles ──────────────────────────────
    // The Canvas paints static leaders, arrows and pills, but it cannot be
    // interacted with on a per-label basis. We overlay a transparent MouseArea
    // per dimension whose position mirrors the painted label; dragging it
    // updates `dimOffsets[constraintId]` so the Canvas repaints the label at
    // the new spot.
    Repeater {
        id: dimHandleRepeater
        z: 5
        model: cadEngine.sketchConstraints
        delegate: Item {
            id: handle
            required property var modelData
            required property int index

            // Look up the matching geometry so we can mirror drawDistanceLabel /
            // drawRadiusLabel positioning. Rebuilds when the sketch changes.
            readonly property var geoList: cadEngine.sketchGeometry
            function findGeo(gid) {
                for (var i = 0; i < geoList.length; i++)
                    if (geoList[i].id === gid) return geoList[i]
                return null
            }
            readonly property var geo: findGeo(modelData.firstGeoId)

            // Compute the (natural) anchor point + raw offset in the same way
            // the canvas does. A little duplication, but keeping the two
            // coordinate systems derived from the same input is the easiest
            // way to stop them drifting.
            function anchorPoint() {
                if (!geo) return null
                var off = canvas.dimOffsetFor(modelData.id)
                if (modelData.typeName === "Distance" ||
                    modelData.typeName === "DistanceX" ||
                    modelData.typeName === "DistanceY") {
                    if (geo.type !== "Line") return null
                    var p1 = canvas.toScreen(geo.startX, geo.startY)
                    var p2 = canvas.toScreen(geo.endX,   geo.endY)
                    var dx = p2.x - p1.x, dy = p2.y - p1.y
                    var len = Math.sqrt(dx*dx + dy*dy)
                    if (len < 1) return null
                    var nx = -dy / len, ny = dx / len
                    var o1x = p1.x + nx * 18, o1y = p1.y + ny * 18
                    var o2x = p2.x + nx * 18, o2y = p2.y + ny * 18
                    return Qt.point((o1x + o2x) * 0.5 + off.x,
                                    (o1y + o2y) * 0.5 + off.y)
                }
                if (modelData.typeName === "Radius" || modelData.typeName === "Diameter") {
                    if (geo.type !== "Arc" && geo.type !== "Circle") return null
                    var c = canvas.toScreen(geo.centerX, geo.centerY)
                    var rpx = geo.radius * canvas.viewScale
                    var theta = Math.PI / 6
                    if (geo.type === "Arc" && typeof geo.startAngle === "number")
                        theta = (geo.startAngle + geo.endAngle) * 0.5
                    var ex = c.x + Math.cos(theta) * rpx
                    var ey = c.y - Math.sin(theta) * rpx
                    var lx = ex + Math.cos(theta) * 28
                    var ly = ey - Math.sin(theta) * 28
                    var tx = lx + (Math.cos(theta) >= 0 ? 4 : -4)
                    var ty = ly - 2
                    return Qt.point(tx + off.x, ty + off.y)
                }
                return null
            }

            readonly property var ap: anchorPoint()
            visible: ap !== null &&
                     (modelData.typeName === "Distance" ||
                      modelData.typeName === "DistanceX" ||
                      modelData.typeName === "DistanceY" ||
                      modelData.typeName === "Radius" ||
                      modelData.typeName === "Diameter")

            // A 52×20 transparent grab area centered on the label pill.
            // Matches the largest label footprint (value up to 7 chars).
            width: 56; height: 20
            x: visible ? ap.x - width / 2 : -1000
            y: visible ? ap.y - height / 2 : -1000

            MouseArea {
                id: dragArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.SizeAllCursor
                property real dragStartX: 0
                property real dragStartY: 0
                property real originDx: 0
                property real originDy: 0
                onPressed: function(mouse) {
                    dragStartX = mouse.x + handle.x
                    dragStartY = mouse.y + handle.y
                    var o = canvas.dimOffsetFor(handle.modelData.id)
                    originDx = o.x; originDy = o.y
                }
                onPositionChanged: function(mouse) {
                    if (!pressed) return
                    var abs = Qt.point(mouse.x + handle.x, mouse.y + handle.y)
                    var dx = abs.x - dragStartX
                    var dy = abs.y - dragStartY
                    canvas.setDimOffset(handle.modelData.id,
                                        originDx + dx, originDy + dy)
                }
                // Double-click the label to reopen Smart Dimension editor on
                // the same constraint — fast way to re-datum without hunting
                // through geometry.
                onDoubleClicked: {
                    if (handle.modelData.typeName === "Radius" ||
                        handle.modelData.typeName === "Diameter") {
                        canvas.beginDimension(handle.modelData.firstGeoId,
                                              handle.ap.x, handle.ap.y)
                    } else {
                        canvas.beginDimension(handle.modelData.firstGeoId,
                                              handle.ap.x, handle.ap.y)
                    }
                }
            }
        }
    }

    // OCCT NavCube sits in the upper-right ~90×90 px region. We yield clicks
    // there to the OccViewport so the cube stays interactive in sketch mode.
    // Width guard: skip on a narrow canvas where (width - 100) is negative —
    // otherwise every left-edge click would be forwarded to the cube.
    function isInNavCubeZone(mx, my) {
        return width > 200 && mx >= width - 100 && my <= 100
    }

    // ── Mouse: drawing + hover ─────────────────────────────────────
    MouseArea {
        id: drawArea
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        hoverEnabled: true  // always hover to show snap markers + coordinates
        propagateComposedEvents: false  // we handle all buttons in sketch mode
        cursorShape: (canvas.tool !== "" && cadEngine.sketchActive) ? Qt.CrossCursor : Qt.ArrowCursor

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

            // Rubber-band drag update (no tool active)
            if (canvas.rubberActive) {
                canvas.rubberX1 = raw.x
                canvas.rubberY1 = raw.y
                drawCanvas.requestPaint()
                return
            }

            // Hover highlight in tool-pick modes (dimension/trim/fillet/chamfer/
            // extend/split). Matches FreeCAD's Preselection visual feedback so
            // the user sees which geometry will be picked before clicking.
            if (canvas.tool === "dimension" || canvas.tool === "trim" ||
                canvas.tool === "fillet"    || canvas.tool === "chamfer" ||
                canvas.tool === "extend"    || canvas.tool === "split") {
                canvas.hoveredGeo = canvas.findGeoAt(mouse.x, mouse.y)
            } else {
                canvas.hoveredGeo = -1
            }

            drawCanvas.requestPaint()
        }

        onPressed: function(mouse) {
            lastMx = mouse.x; lastMy = mouse.y

            // NavCube zone: forward click to 3D viewport (UX-003)
            if (mouse.button === Qt.LeftButton && canvas.isInNavCubeZone(mouse.x, mouse.y)) {
                if (typeof occViewport !== "undefined" && occViewport.forwardNavCubeClick)
                    occViewport.forwardNavCubeClick(mouse.x, mouse.y)
                return
            }

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

                if (tool === "dimension") {
                    // Smart Dimension: click geometry → infer constraint type → on-canvas input
                    selectAt(mouse.x, mouse.y)
                    if (selectedGeo >= 0) {
                        beginDimension(selectedGeo, mouse.x, mouse.y)
                    }
                    return
                }

                if (tool === "trim") {
                    // Trim portion at click point. SketchObject finds the segment
                    // closest to (sk.x, sk.y) and removes it.
                    selectAt(mouse.x, mouse.y)
                    if (selectedGeo >= 0) {
                        cadEngine.trimAtPoint(selectedGeo, sk.x, sk.y)
                        selectedGeo = -1
                    }
                    return
                }

                if (tool === "fillet" || tool === "chamfer") {
                    // Pick a vertex (endpoint). FreeCAD walks coincident
                    // constraints to discover the second edge automatically.
                    var v = findVertexAt(mouse.x, mouse.y)
                    if (v) {
                        canvas.pendingFilletGeo = v.geoId
                        canvas.pendingFilletPos = v.posId
                        canvas.pendingFilletKind = tool
                        // Position popup near the click
                        filletPopup.x = Math.min(mouse.x + 10, canvas.width - filletPopup.width - 10)
                        filletPopup.y = Math.min(mouse.y + 10, canvas.height - filletPopup.height - 10)
                        filletPopup.open()
                    }
                    return
                }

                if (tool === "extend") {
                    // Extend the picked endpoint by a default increment scaled to view.
                    var ev = findVertexAt(mouse.x, mouse.y)
                    if (ev) {
                        var inc = Math.max(5.0, 30.0 / viewScale)
                        cadEngine.extendGeo(ev.geoId, inc, ev.posId)
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
                    // Capture the snap target at the first click so finishDrawing
                    // can emit auto-constraints when the geometry is committed.
                    startX = sk.x; startY = sk.y
                    startSnapGeoId = currentSnapGeoId
                    startSnapPos = currentSnapPos
                    startSnapType = snapType
                    drawing = true
                } else {
                    // currentSnap* reflects the end-click snap target.
                    finishDrawing(sk.x, sk.y, currentSnapGeoId, currentSnapPos, snapType)
                }
            }

            // Left button without tool → select, or start rubber-band.
            // If the click lands on a geometry, do a regular single-select.
            // Otherwise begin a drag-box selection (BUG-012).
            if (mouse.button === Qt.LeftButton && tool === "" && !drawing && cadEngine.sketchActive) {
                var hit = canvas.findGeoAt(mouse.x, mouse.y)
                if (hit >= 0) {
                    canvas.selectedGeo = hit
                    canvas.selectedGeos = [hit]
                    drawCanvas.requestPaint()
                } else {
                    var sketchPt = toSketch(mouse.x, mouse.y)
                    canvas.rubberActive = true
                    canvas.rubberX0 = sketchPt.x
                    canvas.rubberY0 = sketchPt.y
                    canvas.rubberX1 = sketchPt.x
                    canvas.rubberY1 = sketchPt.y
                    canvas.selectedGeo = -1
                    canvas.selectedGeos = []
                    drawCanvas.requestPaint()
                }
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

        // Double-click any dimensionable geometry → open Smart Dimension
        // in re-edit mode. Works for lines (Distance), circles (Diameter),
        // arcs (Radius — including fillet arcs). Matches FreeCAD's
        // "double-click the dimension" editing loop and closes the user's
        // complaint that fillet/chamfer sizes were unreachable after the
        // operation was applied.
        onDoubleClicked: function(mouse) {
            if (mouse.button !== Qt.LeftButton) return
            if (!cadEngine.sketchActive) return
            var hit = canvas.findGeoAt(mouse.x, mouse.y)
            if (hit >= 0) canvas.beginDimension(hit, mouse.x, mouse.y)
        }

        onReleased: function(mouse) {
            if (mouse.button === Qt.MiddleButton) { panning = false }

            // Finalize rubber-band selection (BUG-012)
            if (mouse.button === Qt.LeftButton && canvas.rubberActive) {
                canvas.rubberActive = false
                var crossing = canvas.rubberX1 < canvas.rubberX0  // right-to-left = crossing
                var x0 = Math.min(canvas.rubberX0, canvas.rubberX1)
                var x1 = Math.max(canvas.rubberX0, canvas.rubberX1)
                var y0 = Math.min(canvas.rubberY0, canvas.rubberY1)
                var y1 = Math.max(canvas.rubberY0, canvas.rubberY1)
                // Reject microscopic drags (accidental click-and-drag by 1 px)
                if ((x1 - x0) * viewScale < 3 && (y1 - y0) * viewScale < 3) {
                    drawCanvas.requestPaint()
                    return
                }
                // BUG FIX (session 2026-04-22): `geoIdsInRect` is defined
                // on the MouseArea, not the outer `canvas` Rectangle.
                // Calling it as `canvas.geoIdsInRect(...)` silently returned
                // undefined, which left `selectedGeos` empty and made the
                // rubber-band look broken. Use `drawArea.geoIdsInRect`.
                var picked = drawArea.geoIdsInRect(x0, y0, x1, y1, crossing)
                canvas.selectedGeos = picked.slice()
                canvas.selectedGeo = picked.length > 0 ? picked[0] : -1
                drawCanvas.requestPaint()
            }
        }

        // Collect geo ids whose key points fall inside the rectangle.
        // crossing = true means ANY touching point counts (SW/FreeCAD right→left);
        // crossing = false requires ALL key points inside (left→right).
        function geoIdsInRect(x0, y0, x1, y1, crossing) {
            function inside(px, py) {
                return px >= x0 && px <= x1 && py >= y0 && py <= y1
            }
            // Cohen-Sutherland-style segment-rect overlap test. Needed for
            // crossing selection: a line that passes through the box with
            // both endpoints outside should still be picked up.
            function segmentHitsRect(ax, ay, bx, by) {
                if (inside(ax, ay) || inside(bx, by)) return true
                // Test each rect edge against the segment via orientation
                function intersects(p1x, p1y, p2x, p2y, p3x, p3y, p4x, p4y) {
                    function cross(a, b, c, d) { return (b-a)*(d-c) }
                    var d1 = (p4x-p3x)*(p1y-p3y) - (p4y-p3y)*(p1x-p3x)
                    var d2 = (p4x-p3x)*(p2y-p3y) - (p4y-p3y)*(p2x-p3x)
                    var d3 = (p2x-p1x)*(p3y-p1y) - (p2y-p1y)*(p3x-p1x)
                    var d4 = (p2x-p1x)*(p4y-p1y) - (p2y-p1y)*(p4x-p1x)
                    return ((d1>0 && d2<0) || (d1<0 && d2>0)) &&
                           ((d3>0 && d4<0) || (d3<0 && d4>0))
                }
                return intersects(ax, ay, bx, by, x0, y0, x1, y0) ||
                       intersects(ax, ay, bx, by, x1, y0, x1, y1) ||
                       intersects(ax, ay, bx, by, x1, y1, x0, y1) ||
                       intersects(ax, ay, bx, by, x0, y1, x0, y0)
            }
            var ids = []
            var geos = cadEngine.sketchGeometry
            for (var i = 0; i < geos.length; i++) {
                var g = geos[i]
                var pts = []
                if (g.type === "Line") {
                    pts = [{x: g.startX, y: g.startY}, {x: g.endX, y: g.endY}]
                } else if (g.type === "Circle" || g.type === "Arc" || g.type === "Ellipse") {
                    var r = g.type === "Ellipse" ? Math.max(g.majorRadius || 0, g.minorRadius || 0) : g.radius
                    pts = [
                        {x: g.centerX, y: g.centerY},
                        {x: g.centerX + r, y: g.centerY},
                        {x: g.centerX - r, y: g.centerY},
                        {x: g.centerX, y: g.centerY + r},
                        {x: g.centerX, y: g.centerY - r}
                    ]
                } else if (g.type === "Point") {
                    pts = [{x: g.centerX, y: g.centerY}]
                } else if (g.type === "BSpline" && g.poles) {
                    for (var bi = 0; bi < g.poles.length; bi++) pts.push(g.poles[bi])
                }
                if (pts.length === 0) continue

                // Lines get the segment-rect overlap test for crossing so a
                // line that cuts through the box but has no endpoint inside
                // is still selected.
                if (g.type === "Line" && crossing) {
                    if (segmentHitsRect(g.startX, g.startY, g.endX, g.endY)) {
                        ids.push(g.id)
                        continue
                    }
                }

                var hit = crossing ? false : true
                for (var k = 0; k < pts.length; k++) {
                    var ok = inside(pts[k].x, pts[k].y)
                    if (crossing && ok) { hit = true; break }
                    if (!crossing && !ok) { hit = false; break }
                }
                if (hit) ids.push(g.id)
            }
            return ids
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
    function finishDrawing(ex, ey, endSnapGeoId, endSnapPos, endSnapType) {
        drawing = false
        if (tool === "line") {
            var lineId = cadEngine.addLine(startX, startY, ex, ey)
            if (lineId >= 0) {
                // Line start = PointPos::start (1), end = PointPos::end (2)
                emitAutoConstraint(lineId, 1, startSnapGeoId, startSnapPos, startSnapType)
                emitAutoConstraint(lineId, 2, endSnapGeoId,   endSnapPos,   endSnapType)
            }
        } else if (tool === "circle") {
            var dx = ex - startX, dy = ey - startY
            var r = Math.sqrt(dx*dx + dy*dy)
            if (r > 0.01) {
                var circleId = cadEngine.addCircle(startX, startY, r)
                if (circleId >= 0) {
                    // Circle center = PointPos::mid (3)
                    emitAutoConstraint(circleId, 3, startSnapGeoId, startSnapPos, startSnapType)
                    // End-click = radius point. If it snapped to an existing
                    // vertex, bind that vertex onto the circle curve with a
                    // PointOnObject constraint (FreeCAD's CURVE auto-constraint
                    // path). Fixes BUG-018 where dimensioning the rectangle
                    // around a snapped circle left the radius unconstrained.
                    if (endSnapGeoId >= 0 && endSnapGeoId !== circleId && endSnapType === "endpoint") {
                        cadEngine.addPointOnObjectConstraint(endSnapGeoId, endSnapPos, circleId)
                    }
                }
            }
        } else if (tool === "rectangle") {
            cadEngine.addRectangle(startX, startY, ex, ey)
        } else if (tool === "arc") {
            var adx = ex - startX, ady = ey - startY
            var arcR = Math.sqrt(adx*adx + ady*ady)
            var endAngle = Math.atan2(ady, adx) * 180.0 / Math.PI
            if (arcR > 0.01) {
                var arcId = cadEngine.addArc(startX, startY, arcR, 0, endAngle)
                if (arcId >= 0) {
                    emitAutoConstraint(arcId, 3, startSnapGeoId, startSnapPos, startSnapType)
                }
            }
        }
        else if (tool === "ellipse") {
            var emajR = Math.abs(ex - startX)
            var eminR = Math.abs(ey - startY)
            if (emajR > 0.01 || eminR > 0.01) {
                var ellipseId = cadEngine.addEllipse(startX, startY, emajR, eminR, 0)
                if (ellipseId >= 0) {
                    emitAutoConstraint(ellipseId, 3, startSnapGeoId, startSnapPos, startSnapType)
                }
            }
        }

        // Reset start snap so the next drawing starts clean
        startSnapGeoId = -1
        startSnapPos = 0
        startSnapType = ""
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

    // ── Smart Dimension ────────────────────────────────────────────
    // Pick a geometry → derive constraint type from its shape → show
    // a floating TextField near the click point pre-filled with the
    // current measurement. Enter applies, Esc cancels.
    function beginDimension(geoId, mx, my) {
        var geos = cadEngine.sketchGeometry
        var g = null
        for (var i = 0; i < geos.length; i++) {
            if (geos[i].id === geoId) { g = geos[i]; break }
        }
        if (!g) return

        if (g.type === "Line") {
            var dx = g.endX - g.startX, dy = g.endY - g.startY
            dimCurrent = Math.sqrt(dx * dx + dy * dy)
            dimKind = "distance"
        } else if (g.type === "Circle") {
            dimCurrent = g.radius * 2.0
            dimKind = "diameter"
        } else if (g.type === "Arc") {
            dimCurrent = g.radius
            dimKind = "radius"
        } else {
            return  // Points, ellipses, splines: no quick smart dimension yet
        }

        // If a matching dimension already exists, pre-fill with its datum and
        // remember its id so applyDimension() will call setDatum instead of
        // creating a redundant constraint (FreeCAD re-open-for-edit parity).
        var existing = findExistingDimension(geoId, dimKind)
        dimExistingId = existing.id
        if (existing.id >= 0) dimCurrent = existing.value

        dimGeo = geoId
        dimX = mx
        dimY = my
        dimField.text = dimCurrent.toFixed(2)
        dimEditor.visible = true
        Qt.callLater(function() { dimField.forceActiveFocus(); dimField.selectAll() })
    }

    function applyDimension() {
        if (dimGeo < 0 || dimKind === "") { cancelDimension(); return }
        var v = parseFloat(dimField.text)
        if (isNaN(v) || v <= 0) { cancelDimension(); return }
        if (dimExistingId >= 0) {
            // Update the existing datum — avoids creating a redundant constraint
            // that the solver would flag and silently ignore.
            cadEngine.setDatum(dimExistingId, v)
        } else if (dimKind === "distance") {
            cadEngine.addDistanceConstraint(dimGeo, v)
        } else if (dimKind === "radius") {
            cadEngine.addRadiusConstraint(dimGeo, v)
        } else if (dimKind === "diameter") {
            cadEngine.addDiameterConstraint(dimGeo, v)
        }
        cancelDimension()
    }

    function cancelDimension() {
        dimGeo = -1
        dimKind = ""
        dimExistingId = -1
        dimEditor.visible = false
        // Drop the selection highlight so the geometry flips back to its
        // solver-derived colour (green when fully constrained) instead of
        // staying orange after the dimension commits.
        canvas.selectedGeo = -1
        canvas.selectedGeos = []
        canvas.hoveredGeo = -1
        canvas.requestPaint()
    }

    // Find a vertex (endpoint) near pixel (mx,my). Returns {geoId, posId} or null.
    // FreeCAD's Sketcher::PointPos: 1 = start, 2 = end. Used by fillet/chamfer/extend.
    function findVertexAt(mx, my) {
        var sk = toSketch(mx, my)
        var geos = cadEngine.sketchGeometry
        var bestGeo = -1, bestPos = 0
        var minDist = 18 / viewScale  // a bit more generous than segment select
        for (var i = 0; i < geos.length; i++) {
            var g = geos[i]
            var pts = []
            if (g.type === "Line") {
                pts.push({x: g.startX, y: g.startY, pos: 1})
                pts.push({x: g.endX,   y: g.endY,   pos: 2})
            } else if (g.type === "Arc") {
                pts.push({x: g.centerX + g.radius * Math.cos(g.startAngle),
                          y: g.centerY + g.radius * Math.sin(g.startAngle), pos: 1})
                pts.push({x: g.centerX + g.radius * Math.cos(g.endAngle),
                          y: g.centerY + g.radius * Math.sin(g.endAngle),   pos: 2})
            }
            for (var k = 0; k < pts.length; k++) {
                var d = Math.sqrt((sk.x - pts[k].x) * (sk.x - pts[k].x) +
                                  (sk.y - pts[k].y) * (sk.y - pts[k].y))
                if (d < minDist) { minDist = d; bestGeo = g.id; bestPos = pts[k].pos }
            }
        }
        return bestGeo >= 0 ? { geoId: bestGeo, posId: bestPos } : null
    }

    // ── Smart Dimension floating editor ────────────────────────────
    // Lives on top of the canvas; positioned at the click point.
    Rectangle {
        id: dimEditor
        visible: false
        z: 10
        x: Math.max(0, Math.min(canvas.width  - width,  canvas.dimX - width / 2))
        y: Math.max(0, Math.min(canvas.height - height, canvas.dimY - height - 12))
        width: dimRow.implicitWidth + 16
        height: 30
        radius: 6
        color: "#FFFFFF"
        border.width: 2
        border.color: "#7C3AED"

        Row {
            id: dimRow
            anchors.centerIn: parent
            spacing: 6
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: canvas.dimKind === "diameter" ? "\u2300" :
                      canvas.dimKind === "radius"   ? "R"    : "D"
                font.pixelSize: 12; font.bold: true; color: "#7C3AED"
            }
            TextField {
                id: dimField
                width: 80
                font.pixelSize: 12; font.family: "monospace"
                horizontalAlignment: Text.AlignRight
                selectByMouse: true
                validator: DoubleValidator { bottom: 0.001; decimals: 4 }
                background: Rectangle {
                    radius: 3
                    color: dimField.activeFocus ? "#F5F3FF" : "#F9FAFB"
                    border.width: 1
                    border.color: dimField.activeFocus ? "#7C3AED" : "#E5E7EB"
                }
                onAccepted: canvas.applyDimension()
                Keys.onEscapePressed: canvas.cancelDimension()
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "mm"
                font.pixelSize: 11; color: "#6B7280"
            }
        }
    }

    // ── Fillet / Chamfer radius input popup ─────────────────────────
    Popup {
        id: filletPopup
        width: 220
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            radius: 8
            color: "#FFFFFF"
            border.width: 2
            border.color: "#D97706"
        }

        contentItem: Column {
            spacing: 10
            Text {
                text: canvas.pendingFilletKind === "chamfer" ? "Chamfer Size" : "Fillet Radius"
                font.pixelSize: 13; font.bold: true; color: "#1F2937"
            }
            Row {
                spacing: 6
                TextField {
                    id: filletField
                    width: 120
                    text: "5.0"
                    validator: DoubleValidator { bottom: 0.001; decimals: 3 }
                    onAccepted: filletApplyBtn.clicked()
                    Component.onCompleted: selectAll()
                }
                Text { text: "mm"; anchors.verticalCenter: parent.verticalCenter
                       font.pixelSize: 12; color: "#6B7280" }
            }
            Row {
                spacing: 6
                Button { text: "Cancel"; onClicked: filletPopup.close() }
                Button {
                    id: filletApplyBtn
                    text: "Apply"; highlighted: true
                    enabled: filletField.acceptableInput
                    onClicked: {
                        var v = parseFloat(filletField.text)
                        if (!isNaN(v) && v > 0 && canvas.pendingFilletGeo >= 0) {
                            if (canvas.pendingFilletKind === "chamfer")
                                cadEngine.chamferVertex(canvas.pendingFilletGeo, canvas.pendingFilletPos, v)
                            else
                                cadEngine.filletVertex(canvas.pendingFilletGeo, canvas.pendingFilletPos, v)
                        }
                        canvas.pendingFilletGeo = -1
                        canvas.pendingFilletPos = 0
                        filletPopup.close()
                    }
                }
            }
        }

        onOpened: { filletField.forceActiveFocus(); filletField.selectAll() }
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
