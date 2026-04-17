/**
 * @file OccViewport.cpp
 * @brief QML-facing 3D viewport widget implementation.
 */

#include "OccViewport.h"
#include "OccRenderer.h"
#include "GlTools.h"

#include <QQuickWindow>

namespace CADNC {

OccViewport::OccViewport(QQuickItem* parent)
    : QQuickFramebufferObject(parent)
{
    setMirrorVertically(true);  // Qt FBO y-axis handling
    setAcceptHoverEvents(true);
    setAcceptedMouseButtons(Qt::AllButtons);
}

OccViewport::~OccViewport() = default;

QQuickFramebufferObject::Renderer* OccViewport::createRenderer() const
{
    auto* r = new OccRenderer(this);
    renderer_ = r;
    return r;
}

// ── Shape management ────────────────────────────────────────────────

void OccViewport::addShape(const QString& id, const QVariant& /*shapePtr*/,
                           double r, double g, double b)
{
    // QML-facing stub — real shape addition goes through displayShape()
    Q_UNUSED(id); Q_UNUSED(r); Q_UNUSED(g); Q_UNUSED(b);
}

void OccViewport::removeShape(const QString& id)
{
    if (renderer_)
        renderer_->queueRemoveShape(id.toStdString());
    update();
}

void OccViewport::clearShapes()
{
    if (renderer_)
        renderer_->queueClearShapes();
    update();
}

void OccViewport::fitAll()
{
    if (renderer_)
        renderer_->queueFitAll();
    update();
}

void OccViewport::displayShape(const std::string& id, const TopoDS_Shape& shape,
                               const Quantity_Color& color, bool wireframe)
{
    if (renderer_)
        renderer_->queueAddShape(id, shape, color, wireframe);
    update();
}

// ── View presets ────────────────────────────────────────────────────

void OccViewport::viewTop()
{
    if (!renderer_) return;
    renderer_->queueViewPreset(1);
    update();
}

void OccViewport::viewFront()
{
    if (!renderer_) return;
    renderer_->queueViewPreset(2);
    update();
}

void OccViewport::viewRight()
{
    if (!renderer_) return;
    renderer_->queueViewPreset(3);
    update();
}

void OccViewport::viewIsometric()
{
    if (!renderer_) return;
    renderer_->queueViewPreset(4);
    update();
}

// ── Mouse events → AIS_ViewController on render thread ──────────────

void OccViewport::mousePressEvent(QMouseEvent* event)
{
    if (!renderer_ || renderer_->view().IsNull()) return;

    // In sketch mode, block right-button orbit (MilCAD pattern).
    // ViewCube clicks, middle-button pan, and scroll zoom still work.
    const bool blockOrbit = sketchMode_ && event->button() == Qt::RightButton;
    if (blockOrbit) return;

    double s = renderer_->scale();
    Graphic3d_Vec2i pos = GlTools::convertPos(event->position(), s);
    Aspect_VKeyFlags flags = GlTools::qtModifiers2VKeys(event->modifiers());
    Aspect_VKeyMouse buttons = GlTools::qtButtons2VKeys(event->buttons());

    // Left-click: check ViewCube first, then selection
    if (event->button() == Qt::LeftButton) {
        renderer_->queueViewCubeClick(pos.x(), pos.y());
        renderer_->queueSelect(pos.x(), pos.y());
    }

    renderer_->UpdateMouseButtons(pos, buttons, flags, false);
    update();
}

void OccViewport::mouseReleaseEvent(QMouseEvent* event)
{
    if (!renderer_ || renderer_->view().IsNull()) return;

    double s = renderer_->scale();
    Graphic3d_Vec2i pos = GlTools::convertPos(event->position(), s);
    Aspect_VKeyFlags flags = GlTools::qtModifiers2VKeys(event->modifiers());
    Aspect_VKeyMouse buttons = GlTools::qtButtons2VKeys(event->buttons());

    renderer_->UpdateMouseButtons(pos, buttons, flags, false);
    update();
}

void OccViewport::mouseMoveEvent(QMouseEvent* event)
{
    if (!renderer_ || renderer_->view().IsNull()) return;

    double s = renderer_->scale();
    Graphic3d_Vec2i pos = GlTools::convertPos(event->position(), s);
    Aspect_VKeyFlags flags = GlTools::qtModifiers2VKeys(event->modifiers());

    renderer_->UpdateMousePosition(pos, renderer_->PressedMouseButtons(), flags, false);
    update();
}

void OccViewport::hoverMoveEvent(QHoverEvent* event)
{
    if (!renderer_ || renderer_->view().IsNull()) return;

    double s = renderer_->scale();
    Graphic3d_Vec2i pos = GlTools::convertPos(event->position(), s);
    Aspect_VKeyFlags flags = GlTools::qtModifiers2VKeys(event->modifiers());

    renderer_->UpdateMousePosition(pos, Aspect_VKeyMouse_NONE, flags, false);
    update();
}

void OccViewport::wheelEvent(QWheelEvent* event)
{
    if (!renderer_ || renderer_->view().IsNull()) return;

    double s = renderer_->scale();
    Graphic3d_Vec2i pos(static_cast<int>(event->position().x() * s),
                        static_cast<int>(event->position().y() * s));
    double delta = event->angleDelta().y() / 8.0;

    renderer_->UpdateZoom(Aspect_ScrollDelta(pos, delta));
    update();
}

} // namespace CADNC
