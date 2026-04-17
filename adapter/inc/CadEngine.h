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
#include <QStringList>
#include <memory>

namespace CADNC {

class CadSession;
class CadDocument;
class SketchFacade;
class OccViewport;
class CamFacade;
class NestFacade;

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

    /// Undo/redo availability
    Q_PROPERTY(bool canUndo READ canUndo NOTIFY featureTreeChanged)
    Q_PROPERTY(bool canRedo READ canRedo NOTIFY featureTreeChanged)

    /// List of sketch names for feature dialog dropdowns
    Q_PROPERTY(QStringList sketchNames READ sketchNames NOTIFY featureTreeChanged)

    /// Whether a document is loaded
    Q_PROPERTY(bool hasDocument READ hasDocument NOTIFY featureTreeChanged)

    /// Current document file path (empty if not saved)
    Q_PROPERTY(QString documentPath READ documentPath NOTIFY featureTreeChanged)

    /// Current document name
    Q_PROPERTY(QString documentName READ documentName NOTIFY featureTreeChanged)

public:
    explicit CadEngine(QObject* parent = nullptr);
    ~CadEngine() override;

    /// Initialize backend (call once from main before QML loads)
    Q_INVOKABLE bool init(int argc, char** argv);

    /// Set the 3D viewport for shape display (call from main after QML loads)
    void setViewport(OccViewport* viewport);

    // ── Document ────────────────────────────────────────────────────
    Q_INVOKABLE bool newDocument(const QString& name = "Untitled");
    Q_INVOKABLE bool openDocument(const QString& filePath);
    Q_INVOKABLE bool saveDocument();
    Q_INVOKABLE bool saveDocumentAs(const QString& filePath);
    Q_INVOKABLE bool exportDocument(const QString& filePath);
    Q_INVOKABLE void closeDocument();
    Q_INVOKABLE void undo();
    Q_INVOKABLE void redo();

    /// Delete a feature by internal name. Returns true on success.
    Q_INVOKABLE bool deleteFeature(const QString& name);
    /// Rename a feature's label. Returns true on success.
    Q_INVOKABLE bool renameFeature(const QString& name, const QString& newLabel);

    // ── Sketch lifecycle ────────────────────────────────────────────
    /// Create a new sketch. planeType: 0=XY, 1=XZ, 2=YZ
    Q_INVOKABLE bool createSketch(const QString& name = "Sketch", int planeType = 0);
    Q_INVOKABLE bool openSketch(const QString& name);
    Q_INVOKABLE void closeSketch();

    // ── Sketch geometry ─────────────────────────────────────────────
    Q_INVOKABLE int addLine(double x1, double y1, double x2, double y2);
    Q_INVOKABLE int addCircle(double cx, double cy, double radius);
    Q_INVOKABLE int addArc(double cx, double cy, double radius,
                           double startAngle, double endAngle);
    Q_INVOKABLE int addRectangle(double x1, double y1, double x2, double y2);
    Q_INVOKABLE int addPoint(double x, double y);
    Q_INVOKABLE int addEllipse(double cx, double cy, double majorR, double minorR, double angleDeg = 0);
    Q_INVOKABLE int addBSpline(const QVariantList& points, int degree = 3);
    Q_INVOKABLE int addPolyline(const QVariantList& points);
    Q_INVOKABLE int toggleConstruction(int geoId);
    Q_INVOKABLE void removeGeometry(int geoId);

    // ── Sketch constraints ──────────────────────────────────────────
    Q_INVOKABLE int addDistanceConstraint(int geoId, double value);
    Q_INVOKABLE int addRadiusConstraint(int geoId, double value);
    Q_INVOKABLE int addHorizontalConstraint(int geoId);
    Q_INVOKABLE int addVerticalConstraint(int geoId);
    Q_INVOKABLE int addCoincidentConstraint(int geo1, int pos1, int geo2, int pos2);
    Q_INVOKABLE int addAngleConstraint(int geo1, int geo2, double angleDeg);
    Q_INVOKABLE int addFixedConstraint(int geoId);
    Q_INVOKABLE int addDistanceXConstraint(int geoId, double value);
    Q_INVOKABLE int addDistanceYConstraint(int geoId, double value);
    Q_INVOKABLE int addDiameterConstraint(int geoId, double value);
    Q_INVOKABLE int addSymmetricConstraint(int geo1, int pos1, int geo2, int pos2, int symGeo, int symPos);
    Q_INVOKABLE int addPointOnObjectConstraint(int pointGeo, int pointPos, int objectGeo);
    /// Generic two-geometry constraint (parallel, perpendicular, tangent, equal, coincident).
    /// If secondGeoId is -1, the first geoId is stored and constraint is deferred
    /// until the method is called again with the same type and a different geoId.
    Q_INVOKABLE int addConstraintTwoGeo(const QString& type, int geoId);
    Q_INVOKABLE void removeConstraint(int constraintId);
    Q_INVOKABLE void setDatum(int constraintId, double value);
    Q_INVOKABLE void toggleDriving(int constraintId);

    // ── Sketch tools ────────────────────────────────────────────────
    Q_INVOKABLE int trimAtPoint(int geoId, double px, double py);
    Q_INVOKABLE int filletVertex(int geoId, int posId, double radius);
    Q_INVOKABLE int chamferVertex(int geoId, int posId, double size);
    Q_INVOKABLE int extendGeo(int geoId, double increment, int endPointPos);
    Q_INVOKABLE int splitAtPoint(int geoId, double px, double py);

    // ── Part features (3D operations) ─────────────────────────────
    Q_INVOKABLE QString pad(const QString& sketchName, double length);
    Q_INVOKABLE QString pocket(const QString& sketchName, double depth);
    Q_INVOKABLE QString revolution(const QString& sketchName, double angleDeg);

    // ── CAM ─────────────────────────────────────────────────────────
    Q_INVOKABLE void camSetStock(double length, double width, double height);
    Q_INVOKABLE int camAddTool(const QString& name, double diameter, double fluteLength);
    Q_INVOKABLE int camAddController(int toolId, double rpm, double feedXY, double feedZ);
    Q_INVOKABLE int camAddProfile(int controllerId, double depth, double stepDown,
                                   double x1, double y1, double x2, double y2);
    Q_INVOKABLE int camAddPocket(int controllerId, double depth, double stepDown, double stepOver,
                                  double x1, double y1, double x2, double y2);
    Q_INVOKABLE int camAddDrill(int controllerId, double depth, const QVariantList& points);
    Q_INVOKABLE int camAddFacing(int controllerId, double depth, double stepOver);
    Q_INVOKABLE int camOpCount() const;
    Q_INVOKABLE QString camGenerateGCode() const;
    Q_INVOKABLE bool camExportGCode(const QString& filePath, bool codesys = false) const;

    // ── Nesting ─────────────────────────────────────────────────────
    Q_INVOKABLE bool nestAddPart(const QString& id, double width, double height,
                                  int quantity = 1, bool allowRotation = true);
    Q_INVOKABLE void nestClearParts();
    Q_INVOKABLE void nestSetSheet(const QString& id, double width, double height);
    Q_INVOKABLE void nestSetPartGap(double gap);
    Q_INVOKABLE void nestSetEdgeGap(double gap);
    Q_INVOKABLE void nestSetRotation(int mode);
    Q_INVOKABLE QVariantMap nestRun(int algorithm = 1);

    // ── Solver ──────────────────────────────────────────────────────
    Q_INVOKABLE QString solve();

    // ── Property readers ────────────────────────────────────────────
    QVariantList featureTree() const;
    QVariantList sketchGeometry() const;
    QVariantList sketchConstraints() const;
    QString solverStatus() const;
    QString statusMessage() const;
    bool sketchActive() const;
    bool canUndo() const;
    bool canRedo() const;
    QStringList sketchNames() const;
    bool hasDocument() const;
    QString documentPath() const;
    QString documentName() const;

Q_SIGNALS:
    void featureTreeChanged();
    void sketchChanged();
    void statusMessageChanged();

private:
    std::unique_ptr<CadSession> session_;
    std::shared_ptr<CadDocument> document_;
    std::shared_ptr<SketchFacade> activeSketch_;
    std::string activeSketchName_;   // name of sketch being edited (for viewport sync)
    QString solverStatus_;
    QString statusMessage_;

    void refreshSketch();
    void setStatus(const QString& msg);
    void updateViewportShapes();

    OccViewport* viewport_ = nullptr;
    QString documentPath_;
    std::unique_ptr<CamFacade> cam_;
    std::unique_ptr<NestFacade> nest_;

    // Pending two-geometry constraint state
    QString pendingConstraintType_;
    int pendingFirstGeo_ = -1;
};

} // namespace CADNC
