#pragma once

/**
 * @file OccViewport.h
 * @brief QML-facing 3D viewport widget using OCCT V3d rendering.
 *
 * OccViewport is a QQuickFramebufferObject that embeds an OCCT 3D viewer.
 * It handles mouse input (orbit, pan, zoom via AIS_ViewController) and
 * delegates shape display/selection to the render-thread OccRenderer.
 *
 * Usage in QML:
 *   OccViewport { anchors.fill: parent }
 *
 * Must be registered via qmlRegisterType before QML engine loads.
 */

#include <QQuickFramebufferObject>
#include <QMouseEvent>
#include <QWheelEvent>

#include <TopoDS_Shape.hxx>
#include <Quantity_Color.hxx>

#include <string>

namespace CADNC {

class OccRenderer;

class OccViewport : public QQuickFramebufferObject {
    Q_OBJECT
    QML_ELEMENT

    /// When true, right-button orbit is blocked (sketch mode)
    Q_PROPERTY(bool sketchMode READ sketchMode WRITE setSketchMode NOTIFY sketchModeChanged)

public:
    explicit OccViewport(QQuickItem* parent = nullptr);
    ~OccViewport() override;

    Renderer* createRenderer() const override;

    // ── Shape management (thread-safe, deferred to render thread) ───
    Q_INVOKABLE void addShape(const QString& id, const QVariant& shapePtr,
                               double r = 0.5, double g = 0.7, double b = 0.9);
    Q_INVOKABLE void removeShape(const QString& id);
    Q_INVOKABLE void clearShapes();
    Q_INVOKABLE void fitAll();

    // ── View presets ────────────────────────────────────────────────
    Q_INVOKABLE void viewTop();
    Q_INVOKABLE void viewFront();
    Q_INVOKABLE void viewRight();
    Q_INVOKABLE void viewIsometric();

    /// Direct native shape API (called from C++ adapter, not QML)
    /// wireframe: true = display as wireframe (for sketches), false = shaded (for solids)
    void displayShape(const std::string& id, const TopoDS_Shape& shape,
                      const Quantity_Color& color, bool wireframe = false);

    bool sketchMode() const { return sketchMode_; }
    void setSketchMode(bool on) { if (sketchMode_ != on) { sketchMode_ = on; Q_EMIT sketchModeChanged(); } }

Q_SIGNALS:
    void viewReady();
    void sketchModeChanged();

protected:
    // Mouse event handling (forwarded to AIS_ViewController on render thread)
    void mousePressEvent(QMouseEvent* event) override;
    void mouseReleaseEvent(QMouseEvent* event) override;
    void mouseMoveEvent(QMouseEvent* event) override;
    void hoverMoveEvent(QHoverEvent* event) override;
    void wheelEvent(QWheelEvent* event) override;

private:
    // Renderer is owned by Qt's scene graph, we keep a non-owning pointer
    mutable OccRenderer* renderer_ = nullptr;
    bool sketchMode_ = false;
};

} // namespace CADNC
