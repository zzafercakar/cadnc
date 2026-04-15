#pragma once

/**
 * @file CadEngine.h
 * @brief QML-facing bridge that exposes CADNC adapter to the UI.
 *
 * CadEngine is a QObject registered with QML. It owns the CadSession and
 * active CadDocument, and exposes sketch/part operations as Q_INVOKABLE
 * methods. QML never touches FreeCAD types — only this bridge.
 */

#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QString>
#include <memory>

namespace CADNC {

class CadSession;
class CadDocument;
class SketchFacade;

class CadEngine : public QObject {
    Q_OBJECT

    /// Feature tree as a QVariantList for QML ListView
    Q_PROPERTY(QVariantList featureTree READ featureTree NOTIFY featureTreeChanged)

    /// Geometry list of active sketch as QVariantList
    Q_PROPERTY(QVariantList sketchGeometry READ sketchGeometry NOTIFY sketchChanged)

    /// Constraints of active sketch
    Q_PROPERTY(QVariantList sketchConstraints READ sketchConstraints NOTIFY sketchChanged)

    /// Solver status text
    Q_PROPERTY(QString solverStatus READ solverStatus NOTIFY sketchChanged)

    /// Status bar message
    Q_PROPERTY(QString statusMessage READ statusMessage NOTIFY statusMessageChanged)

    /// Whether a sketch is currently active
    Q_PROPERTY(bool sketchActive READ sketchActive NOTIFY sketchChanged)

public:
    explicit CadEngine(QObject* parent = nullptr);
    ~CadEngine() override;

    /// Initialize backend (call once from main before QML loads)
    Q_INVOKABLE bool init(int argc, char** argv);

    // ── Document ────────────────────────────────────────────────────
    Q_INVOKABLE bool newDocument(const QString& name = "Untitled");
    Q_INVOKABLE void undo();
    Q_INVOKABLE void redo();

    // ── Sketch lifecycle ────────────────────────────────────────────
    Q_INVOKABLE bool createSketch(const QString& name = "Sketch");
    Q_INVOKABLE bool openSketch(const QString& name);
    Q_INVOKABLE void closeSketch();

    // ── Sketch geometry ─────────────────────────────────────────────
    Q_INVOKABLE int addLine(double x1, double y1, double x2, double y2);
    Q_INVOKABLE int addCircle(double cx, double cy, double radius);
    Q_INVOKABLE int addArc(double cx, double cy, double radius,
                           double startAngle, double endAngle);
    Q_INVOKABLE int addRectangle(double x1, double y1, double x2, double y2);
    Q_INVOKABLE void removeGeometry(int geoId);

    // ── Sketch constraints ──────────────────────────────────────────
    Q_INVOKABLE int addDistanceConstraint(int geoId, double value);
    Q_INVOKABLE int addRadiusConstraint(int geoId, double value);
    Q_INVOKABLE int addHorizontalConstraint(int geoId);
    Q_INVOKABLE int addVerticalConstraint(int geoId);
    Q_INVOKABLE int addCoincidentConstraint(int geo1, int pos1, int geo2, int pos2);
    Q_INVOKABLE int addAngleConstraint(int geo1, int geo2, double angleDeg);
    Q_INVOKABLE int addFixedConstraint(int geoId);
    Q_INVOKABLE void removeConstraint(int constraintId);
    Q_INVOKABLE void setDatum(int constraintId, double value);
    Q_INVOKABLE void toggleDriving(int constraintId);

    // ── Sketch tools ────────────────────────────────────────────────
    Q_INVOKABLE int trimAtPoint(int geoId, double px, double py);
    Q_INVOKABLE int filletVertex(int geoId, int posId, double radius);

    // ── Solver ──────────────────────────────────────────────────────
    Q_INVOKABLE QString solve();

    // ── Property readers ────────────────────────────────────────────
    QVariantList featureTree() const;
    QVariantList sketchGeometry() const;
    QVariantList sketchConstraints() const;
    QString solverStatus() const;
    QString statusMessage() const;
    bool sketchActive() const;

Q_SIGNALS:
    void featureTreeChanged();
    void sketchChanged();
    void statusMessageChanged();

private:
    std::unique_ptr<CadSession> session_;
    std::shared_ptr<CadDocument> document_;
    std::shared_ptr<SketchFacade> activeSketch_;
    QString solverStatus_;
    QString statusMessage_;

    void refreshSketch();
    void setStatus(const QString& msg);
};

} // namespace CADNC
