#include "CadEngine.h"
#include "CadSession.h"
#include "CadDocument.h"
#include "SketchFacade.h"
#include "PartFacade.h"
#include "CamFacade.h"
#include "NestFacade.h"
#include "OccViewport.h"

#include <cmath>
#include <TopoDS_Shape.hxx>
#include <Quantity_Color.hxx>
#include <Mod/Part/App/PartFeature.h>

namespace CADNC {

CadEngine::CadEngine(QObject* parent)
    : QObject(parent)
    , session_(std::make_unique<CadSession>())
    , cam_(std::make_unique<CamFacade>())
    , nest_(std::make_unique<NestFacade>())
{
}

CadEngine::~CadEngine() = default;

bool CadEngine::init(int argc, char** argv)
{
    bool ok = session_->initialize(argc, argv);
    if (ok) setStatus("Backend initialized");
    else    setStatus("Backend init FAILED");
    return ok;
}

void CadEngine::setViewport(OccViewport* viewport)
{
    viewport_ = viewport;
}

// ── Document ────────────────────────────────────────────────────────

bool CadEngine::newDocument(const QString& name)
{
    // Close existing document if any
    if (document_) {
        activeSketch_.reset();
        document_.reset();
    }

    document_ = session_->newDocument(name.toStdString());
    documentPath_.clear();
    if (document_) {
        setStatus("New document: " + name);
        Q_EMIT featureTreeChanged();
        Q_EMIT sketchChanged();
        return true;
    }
    return false;
}

bool CadEngine::openDocument(const QString& filePath)
{
    if (filePath.isEmpty()) return false;

    // Close existing
    if (document_) {
        activeSketch_.reset();
        document_.reset();
    }

    auto doc = std::make_shared<CadDocument>("Loading");
    if (doc->load(filePath.toStdString())) {
        document_ = doc;
        documentPath_ = filePath;
        setStatus("Opened: " + filePath);
        Q_EMIT featureTreeChanged();
        updateViewportShapes();
        return true;
    }
    setStatus("Failed to open: " + filePath);
    return false;
}

bool CadEngine::saveDocument()
{
    if (!document_) return false;

    if (documentPath_.isEmpty()) {
        setStatus("No file path — use Save As");
        return false;
    }
    return saveDocumentAs(documentPath_);
}

bool CadEngine::saveDocumentAs(const QString& filePath)
{
    if (!document_ || filePath.isEmpty()) return false;

    bool ok = document_->save(filePath.toStdString());
    if (ok) {
        documentPath_ = filePath;
        setStatus("Saved: " + filePath);
        Q_EMIT featureTreeChanged();
    } else {
        setStatus("Save failed: " + filePath);
    }
    return ok;
}

bool CadEngine::exportDocument(const QString& filePath)
{
    if (!document_ || filePath.isEmpty()) return false;

    bool ok = document_->exportTo(filePath.toStdString());
    if (ok)
        setStatus("Exported: " + filePath);
    else
        setStatus("Export failed: " + filePath);
    return ok;
}

bool CadEngine::importFile(const QString& filePath)
{
    if (filePath.isEmpty()) return false;

    // Auto-create document if none exists
    if (!document_) {
        if (!newDocument("Untitled")) return false;
    }

    bool ok = document_->importFrom(filePath.toStdString());
    if (ok) {
        setStatus("Imported: " + filePath);
        Q_EMIT featureTreeChanged();
        updateViewportShapes();
    } else {
        setStatus("Import failed: " + filePath);
    }
    return ok;
}

void CadEngine::closeDocument()
{
    if (activeSketch_) closeSketch();
    document_.reset();
    documentPath_.clear();
    setStatus("Document closed");
    Q_EMIT featureTreeChanged();
    Q_EMIT sketchChanged();
}

void CadEngine::undo()
{
    if (document_) {
        document_->undo();
        refreshSketch();
        Q_EMIT featureTreeChanged();
    }
}

void CadEngine::redo()
{
    if (document_) {
        document_->redo();
        refreshSketch();
        Q_EMIT featureTreeChanged();
    }
}

bool CadEngine::deleteFeature(const QString& name)
{
    if (!document_) return false;

    // Don't allow deleting the active sketch
    if (activeSketch_ && name.toStdString() == activeSketchName_) {
        setStatus("Cannot delete active sketch — close it first");
        return false;
    }

    bool ok = document_->deleteFeature(name.toStdString());
    if (ok) {
        setStatus("Deleted: " + name);
        Q_EMIT featureTreeChanged();
        updateViewportShapes();
    } else {
        setStatus("Delete failed: " + name);
    }
    return ok;
}

bool CadEngine::renameFeature(const QString& name, const QString& newLabel)
{
    if (!document_) return false;

    bool ok = document_->renameFeature(name.toStdString(), newLabel.toStdString());
    if (ok) {
        setStatus("Renamed: " + newLabel);
        Q_EMIT featureTreeChanged();
    }
    return ok;
}

// ── Sketch lifecycle ────────────────────────────────────────────────

bool CadEngine::createSketch(const QString& name, int planeType)
{
    // Auto-create document if none exists
    if (!document_) {
        if (!newDocument("Untitled")) return false;
    }
    activeSketch_ = document_->addSketch(name.toStdString(), planeType);
    if (activeSketch_) {
        static const char* planeNames[] = {"XY", "XZ", "YZ"};
        const char* pn = (planeType >= 0 && planeType <= 2) ? planeNames[planeType] : "XY";
        activeSketchName_ = name.toStdString();
        setStatus(QString("Sketch created: %1 (%2 plane)").arg(name, pn));

        // Keep sketch wireframe visible in OCCT viewport during editing
        // (QML Canvas overlay only renders snap markers, not geometry)

        // Orient viewport camera to face the sketch plane
        if (viewport_) {
            switch (planeType) {
                case 0: viewport_->viewTop(); break;     // XY → top view
                case 1: viewport_->viewFront(); break;   // XZ → front view
                case 2: viewport_->viewRight(); break;   // YZ → right view
            }
        }

        Q_EMIT featureTreeChanged();
        Q_EMIT sketchChanged();
        return true;
    }
    return false;
}

bool CadEngine::openSketch(const QString& name)
{
    if (!document_) return false;
    activeSketch_ = document_->getSketch(name.toStdString());
    if (activeSketch_) {
        activeSketchName_ = name.toStdString();
        setStatus("Editing sketch: " + name);

        // Refresh viewport to show latest sketch wireframe
        updateViewportShapes();

        Q_EMIT sketchChanged();
        return true;
    }
    return false;
}

void CadEngine::closeSketch()
{
    if (activeSketch_) {
        activeSketch_->close();
        activeSketch_.reset();

        // Recompute so FreeCAD builds the InternalShape (required for Pad/Pocket)
        if (document_) document_->recompute();

        setStatus("Sketch closed");
        Q_EMIT sketchChanged();
        Q_EMIT featureTreeChanged();

        // Show sketch wireframe + any 3D features in the viewport
        updateViewportShapes();
    }
}

// ── Sketch geometry ─────────────────────────────────────────────────

int CadEngine::addLine(double x1, double y1, double x2, double y2)
{
    if (!activeSketch_) return -1;
    int id = activeSketch_->addLine({x1, y1}, {x2, y2});
    refreshSketch();
    return id;
}

int CadEngine::addCircle(double cx, double cy, double radius)
{
    if (!activeSketch_) return -1;
    int id = activeSketch_->addCircle({cx, cy}, radius);
    refreshSketch();
    return id;
}

int CadEngine::addArc(double cx, double cy, double radius,
                      double startAngle, double endAngle)
{
    if (!activeSketch_) return -1;
    // Convert degrees to radians for FreeCAD
    double sa = startAngle * M_PI / 180.0;
    double ea = endAngle * M_PI / 180.0;
    int id = activeSketch_->addArc({cx, cy}, radius, sa, ea);
    refreshSketch();
    return id;
}

int CadEngine::addRectangle(double x1, double y1, double x2, double y2)
{
    if (!activeSketch_) return -1;
    int id = activeSketch_->addRectangle({x1, y1}, {x2, y2});
    refreshSketch();
    return id;
}

int CadEngine::addPoint(double x, double y)
{
    if (!activeSketch_) return -1;
    int id = activeSketch_->addPoint({x, y});
    refreshSketch();
    return id;
}

void CadEngine::removeGeometry(int geoId)
{
    if (!activeSketch_) return;
    activeSketch_->removeGeometry(geoId);
    refreshSketch();
}

int CadEngine::addEllipse(double cx, double cy, double majorR, double minorR, double angleDeg)
{
    if (!activeSketch_) return -1;
    double angleRad = angleDeg * M_PI / 180.0;
    int id = activeSketch_->addEllipse({cx, cy}, majorR, minorR, angleRad);
    refreshSketch();
    return id;
}

int CadEngine::addBSpline(const QVariantList& points, int degree)
{
    if (!activeSketch_) return -1;
    std::vector<CADNC::Point2D> poles;
    for (const auto& pt : points) {
        auto map = pt.toMap();
        poles.push_back({map["x"].toDouble(), map["y"].toDouble()});
    }
    int id = activeSketch_->addBSpline(poles, degree);
    refreshSketch();
    return id;
}

int CadEngine::addPolyline(const QVariantList& points)
{
    if (!activeSketch_) return -1;
    std::vector<CADNC::Point2D> pts;
    for (const auto& pt : points) {
        auto map = pt.toMap();
        pts.push_back({map["x"].toDouble(), map["y"].toDouble()});
    }
    int id = activeSketch_->addPolyline(pts);
    refreshSketch();
    return id;
}

int CadEngine::toggleConstruction(int geoId)
{
    if (!activeSketch_) return -1;
    int result = activeSketch_->toggleConstruction(geoId);
    refreshSketch();
    return result;
}

// ── Sketch constraints ──────────────────────────────────────────────

int CadEngine::addDistanceConstraint(int geoId, double value)
{
    if (!activeSketch_) return -1;
    int id = activeSketch_->addDistance(geoId, value);
    refreshSketch();
    return id;
}

int CadEngine::addRadiusConstraint(int geoId, double value)
{
    if (!activeSketch_) return -1;
    int id = activeSketch_->addRadius(geoId, value);
    refreshSketch();
    return id;
}

int CadEngine::addHorizontalConstraint(int geoId)
{
    if (!activeSketch_) return -1;
    int id = activeSketch_->addHorizontal(geoId);
    refreshSketch();
    return id;
}

int CadEngine::addVerticalConstraint(int geoId)
{
    if (!activeSketch_) return -1;
    int id = activeSketch_->addVertical(geoId);
    refreshSketch();
    return id;
}

int CadEngine::addCoincidentConstraint(int geo1, int pos1, int geo2, int pos2)
{
    if (!activeSketch_) return -1;
    int id = activeSketch_->addCoincident(geo1, pos1, geo2, pos2);
    refreshSketch();
    return id;
}

int CadEngine::addAngleConstraint(int geo1, int geo2, double angleDeg)
{
    if (!activeSketch_) return -1;
    double angleRad = angleDeg * M_PI / 180.0;
    int id = activeSketch_->addAngle(geo1, geo2, angleRad);
    refreshSketch();
    return id;
}

int CadEngine::addFixedConstraint(int geoId)
{
    if (!activeSketch_) return -1;
    int id = activeSketch_->addFixed(geoId);
    refreshSketch();
    return id;
}

int CadEngine::addDistanceXConstraint(int geoId, double value)
{
    if (!activeSketch_) return -1;
    int id = activeSketch_->addConstraint(ConstraintType::DistanceX, geoId, -1, value);
    refreshSketch();
    return id;
}

int CadEngine::addDistanceYConstraint(int geoId, double value)
{
    if (!activeSketch_) return -1;
    int id = activeSketch_->addConstraint(ConstraintType::DistanceY, geoId, -1, value);
    refreshSketch();
    return id;
}

int CadEngine::addDiameterConstraint(int geoId, double value)
{
    if (!activeSketch_) return -1;
    int id = activeSketch_->addConstraint(ConstraintType::Diameter, geoId, -1, value);
    refreshSketch();
    return id;
}

int CadEngine::addSymmetricConstraint(int geo1, int pos1, int geo2, int pos2, int symGeo, int symPos)
{
    if (!activeSketch_) return -1;
    int id = activeSketch_->addConstraint(ConstraintType::Symmetric, geo1, geo2);
    refreshSketch();
    return id;
}

int CadEngine::addPointOnObjectConstraint(int pointGeo, int pointPos, int objectGeo)
{
    if (!activeSketch_) return -1;
    int id = activeSketch_->addConstraint(ConstraintType::PointOnObject, pointGeo, objectGeo);
    refreshSketch();
    return id;
}

int CadEngine::addConstraintTwoGeo(const QString& type, int geoId)
{
    if (!activeSketch_) return -1;

    // Two-click workflow: first call stores geo, second call applies constraint
    if (pendingConstraintType_ == type && pendingFirstGeo_ >= 0 && pendingFirstGeo_ != geoId) {
        int id = -1;
        int g1 = pendingFirstGeo_, g2 = geoId;

        if (type == "parallel")
            id = activeSketch_->addConstraint(ConstraintType::Parallel, g1, g2);
        else if (type == "perpendicular")
            id = activeSketch_->addConstraint(ConstraintType::Perpendicular, g1, g2);
        else if (type == "tangent")
            id = activeSketch_->addConstraint(ConstraintType::Tangent, g1, g2);
        else if (type == "equal")
            id = activeSketch_->addConstraint(ConstraintType::Equal, g1, g2);
        else if (type == "coincident")
            id = activeSketch_->addCoincident(g1, 1, g2, 1);  // start-to-start
        else if (type == "symmetric")
            id = activeSketch_->addConstraint(ConstraintType::Symmetric, g1, g2);
        else if (type == "pointOnObject")
            id = activeSketch_->addConstraint(ConstraintType::PointOnObject, g1, g2);

        pendingConstraintType_.clear();
        pendingFirstGeo_ = -1;
        setStatus(QString("%1 constraint applied (G%2, G%3)").arg(type).arg(g1).arg(g2));
        refreshSketch();
        return id;
    }

    // First click — store and wait for second selection
    pendingConstraintType_ = type;
    pendingFirstGeo_ = geoId;
    setStatus(QString("Select second geometry for %1 constraint").arg(type));
    return -1;
}

void CadEngine::removeConstraint(int constraintId)
{
    if (!activeSketch_) return;
    activeSketch_->removeConstraint(constraintId);
    refreshSketch();
}

void CadEngine::setDatum(int constraintId, double value)
{
    if (!activeSketch_) return;
    activeSketch_->setDatum(constraintId, value);
    refreshSketch();
}

void CadEngine::toggleDriving(int constraintId)
{
    if (!activeSketch_) return;
    activeSketch_->toggleDriving(constraintId);
    refreshSketch();
}

// ── Sketch tools ────────────────────────────────────────────────────

int CadEngine::trimAtPoint(int geoId, double px, double py)
{
    if (!activeSketch_) return -1;
    int id = activeSketch_->trim(geoId, {px, py});
    refreshSketch();
    return id;
}

int CadEngine::filletVertex(int geoId, int posId, double radius)
{
    if (!activeSketch_) return -1;
    int id = activeSketch_->fillet(geoId, posId, radius);
    refreshSketch();
    return id;
}

int CadEngine::chamferVertex(int geoId, int posId, double size)
{
    if (!activeSketch_) return -1;
    int id = activeSketch_->chamfer(geoId, posId, size);
    refreshSketch();
    return id;
}

int CadEngine::extendGeo(int geoId, double increment, int endPointPos)
{
    if (!activeSketch_) return -1;
    int id = activeSketch_->extend(geoId, increment, endPointPos);
    refreshSketch();
    return id;
}

int CadEngine::splitAtPoint(int geoId, double px, double py)
{
    if (!activeSketch_) return -1;
    int id = activeSketch_->split(geoId, {px, py});
    refreshSketch();
    return id;
}

// ── Part features (3D operations) ───────────────────────────────

QString CadEngine::pad(const QString& sketchName, double length)
{
    if (!document_) return {};

    // Close active sketch before creating pad
    if (activeSketch_) closeSketch();

    auto part = document_->partDesign();
    if (!part) return {};

    std::string result = part->pad(sketchName.toStdString(), length);
    if (!result.empty()) {
        setStatus("Pad created: " + QString::fromStdString(result));
        Q_EMIT featureTreeChanged();
        updateViewportShapes();
    }
    return QString::fromStdString(result);
}

QString CadEngine::pocket(const QString& sketchName, double depth)
{
    if (!document_) return {};

    if (activeSketch_) closeSketch();

    auto part = document_->partDesign();
    if (!part) return {};

    std::string result = part->pocket(sketchName.toStdString(), depth);
    if (!result.empty()) {
        setStatus("Pocket created: " + QString::fromStdString(result));
        Q_EMIT featureTreeChanged();
        updateViewportShapes();
    }
    return QString::fromStdString(result);
}

QString CadEngine::revolution(const QString& sketchName, double angleDeg)
{
    if (!document_) return {};

    if (activeSketch_) closeSketch();

    auto part = document_->partDesign();
    if (!part) return {};

    std::string result = part->revolution(sketchName.toStdString(), angleDeg);
    if (!result.empty()) {
        setStatus("Revolution created: " + QString::fromStdString(result));
        Q_EMIT featureTreeChanged();
        updateViewportShapes();
    }
    return QString::fromStdString(result);
}

QString CadEngine::groove(const QString& sketchName, double angleDeg)
{
    if (!document_) return {};
    if (activeSketch_) closeSketch();
    auto part = document_->partDesign();
    if (!part) return {};
    std::string result = part->groove(sketchName.toStdString(), angleDeg);
    if (!result.empty()) {
        setStatus("Groove created: " + QString::fromStdString(result));
        Q_EMIT featureTreeChanged();
        updateViewportShapes();
    }
    return QString::fromStdString(result);
}

QString CadEngine::booleanFuse(const QString& baseName, const QString& toolName)
{
    if (!document_) return {};
    auto part = document_->partDesign();
    if (!part) return {};
    std::string result = part->booleanFuse(baseName.toStdString(), toolName.toStdString());
    if (!result.empty()) {
        setStatus("Boolean Fuse: " + QString::fromStdString(result));
        Q_EMIT featureTreeChanged();
        updateViewportShapes();
    }
    return QString::fromStdString(result);
}

QString CadEngine::booleanCut(const QString& baseName, const QString& toolName)
{
    if (!document_) return {};
    auto part = document_->partDesign();
    if (!part) return {};
    std::string result = part->booleanCut(baseName.toStdString(), toolName.toStdString());
    if (!result.empty()) {
        setStatus("Boolean Cut: " + QString::fromStdString(result));
        Q_EMIT featureTreeChanged();
        updateViewportShapes();
    }
    return QString::fromStdString(result);
}

QString CadEngine::booleanCommon(const QString& baseName, const QString& toolName)
{
    if (!document_) return {};
    auto part = document_->partDesign();
    if (!part) return {};
    std::string result = part->booleanCommon(baseName.toStdString(), toolName.toStdString());
    if (!result.empty()) {
        setStatus("Boolean Common: " + QString::fromStdString(result));
        Q_EMIT featureTreeChanged();
        updateViewportShapes();
    }
    return QString::fromStdString(result);
}

QString CadEngine::addBox(double length, double width, double height)
{
    if (!document_) {
        if (!newDocument("Untitled")) return {};
    }
    auto part = document_->partDesign();
    if (!part) return {};
    std::string result = part->addBox(length, width, height);
    if (!result.empty()) {
        setStatus(QString("Box: %1x%2x%3").arg(length).arg(width).arg(height));
        Q_EMIT featureTreeChanged();
        updateViewportShapes();
    }
    return QString::fromStdString(result);
}

QString CadEngine::addCylinder(double radius, double height, double angle)
{
    if (!document_) {
        if (!newDocument("Untitled")) return {};
    }
    auto part = document_->partDesign();
    if (!part) return {};
    std::string result = part->addCylinder(radius, height, angle);
    if (!result.empty()) {
        setStatus(QString("Cylinder: R%1 H%2").arg(radius).arg(height));
        Q_EMIT featureTreeChanged();
        updateViewportShapes();
    }
    return QString::fromStdString(result);
}

QString CadEngine::addSphere(double radius)
{
    if (!document_) {
        if (!newDocument("Untitled")) return {};
    }
    auto part = document_->partDesign();
    if (!part) return {};
    std::string result = part->addSphere(radius);
    if (!result.empty()) {
        setStatus(QString("Sphere: R%1").arg(radius));
        Q_EMIT featureTreeChanged();
        updateViewportShapes();
    }
    return QString::fromStdString(result);
}

QString CadEngine::addCone(double radius1, double radius2, double height)
{
    if (!document_) {
        if (!newDocument("Untitled")) return {};
    }
    auto part = document_->partDesign();
    if (!part) return {};
    std::string result = part->addCone(radius1, radius2, height);
    if (!result.empty()) {
        setStatus(QString("Cone: R1=%1 R2=%2 H=%3").arg(radius1).arg(radius2).arg(height));
        Q_EMIT featureTreeChanged();
        updateViewportShapes();
    }
    return QString::fromStdString(result);
}

QString CadEngine::filletAll(const QString& featureName, double radius)
{
    if (!document_) return {};
    auto part = document_->partDesign();
    if (!part) return {};
    std::string result = part->filletAll(featureName.toStdString(), radius);
    if (!result.empty()) {
        setStatus("3D Fillet: R" + QString::number(radius));
        Q_EMIT featureTreeChanged();
        updateViewportShapes();
    }
    return QString::fromStdString(result);
}

QString CadEngine::chamferAll(const QString& featureName, double size)
{
    if (!document_) return {};
    auto part = document_->partDesign();
    if (!part) return {};
    std::string result = part->chamferAll(featureName.toStdString(), size);
    if (!result.empty()) {
        setStatus("3D Chamfer: " + QString::number(size));
        Q_EMIT featureTreeChanged();
        updateViewportShapes();
    }
    return QString::fromStdString(result);
}

QString CadEngine::linearPattern(const QString& featureName, double length, int occurrences)
{
    if (!document_) return {};
    auto part = document_->partDesign();
    if (!part) return {};
    std::string result = part->linearPattern(featureName.toStdString(), 0, 0, 1, length, occurrences);
    if (!result.empty()) {
        setStatus(QString("Linear Pattern: %1x").arg(occurrences));
        Q_EMIT featureTreeChanged();
        updateViewportShapes();
    }
    return QString::fromStdString(result);
}

QString CadEngine::polarPattern(const QString& featureName, double angleDeg, int occurrences)
{
    if (!document_) return {};
    auto part = document_->partDesign();
    if (!part) return {};
    std::string result = part->polarPattern(featureName.toStdString(), 0, 0, 1, angleDeg, occurrences);
    if (!result.empty()) {
        setStatus(QString("Polar Pattern: %1x @ %2°").arg(occurrences).arg(angleDeg));
        Q_EMIT featureTreeChanged();
        updateViewportShapes();
    }
    return QString::fromStdString(result);
}

QString CadEngine::mirrorFeature(const QString& featureName)
{
    if (!document_) return {};
    auto part = document_->partDesign();
    if (!part) return {};
    std::string result = part->mirror(featureName.toStdString(), 1, 0, 0);
    if (!result.empty()) {
        setStatus("Mirror: " + QString::fromStdString(result));
        Q_EMIT featureTreeChanged();
        updateViewportShapes();
    }
    return QString::fromStdString(result);
}

// ── CAM ────────────────────────────────────────────────────────────

void CadEngine::camSetStock(double length, double width, double height)
{
    cam_->setStock(length, width, height);
    setStatus(QString("Stock set: %1 x %2 x %3 mm").arg(length).arg(width).arg(height));
}

int CadEngine::camAddTool(const QString& name, double diameter, double fluteLength)
{
    int id = cam_->addEndMill(name.toStdString(), diameter, fluteLength);
    setStatus(QString("Tool added: %1 (D%2)").arg(name).arg(diameter));
    return id;
}

int CadEngine::camAddController(int toolId, double rpm, double feedXY, double feedZ)
{
    return cam_->addToolController(toolId, rpm, feedXY, feedZ);
}

int CadEngine::camAddProfile(int controllerId, double depth, double stepDown,
                             double x1, double y1, double x2, double y2)
{
    int id = cam_->addProfileOp(controllerId, depth, stepDown, x1, y1, x2, y2);
    setStatus(QString("Profile operation added (depth: %1mm)").arg(depth));
    return id;
}

int CadEngine::camAddPocket(int controllerId, double depth, double stepDown, double stepOver,
                            double x1, double y1, double x2, double y2)
{
    int id = cam_->addPocketOp(controllerId, depth, stepDown, stepOver, x1, y1, x2, y2);
    setStatus(QString("Pocket operation added (depth: %1mm)").arg(depth));
    return id;
}

int CadEngine::camAddDrill(int controllerId, double depth, const QVariantList& points)
{
    std::vector<std::pair<double,double>> pts;
    for (const auto& pt : points) {
        auto map = pt.toMap();
        pts.emplace_back(map["x"].toDouble(), map["y"].toDouble());
    }
    int id = cam_->addDrillOp(controllerId, depth, pts);
    setStatus(QString("Drill operation added (%1 holes)").arg(pts.size()));
    return id;
}

int CadEngine::camAddFacing(int controllerId, double depth, double stepOver)
{
    int id = cam_->addFacingOp(controllerId, depth, stepOver);
    setStatus(QString("Facing operation added (depth: %1mm)").arg(depth));
    return id;
}

int CadEngine::camOpCount() const { return cam_->operationCount(); }

QString CadEngine::camGenerateGCode() const
{
    return QString::fromStdString(cam_->generateGCode());
}

bool CadEngine::camExportGCode(const QString& filePath, bool codesys) const
{
    return cam_->exportToFile(filePath.toStdString(), codesys);
}

// ── Nesting ────────────────────────────────────────────────────────

bool CadEngine::nestAddPart(const QString& id, double width, double height,
                            int quantity, bool allowRotation)
{
    bool ok = nest_->addPart(id.toStdString(), width, height, quantity, allowRotation);
    if (ok) setStatus(QString("Nest part added: %1 (%2x%3, qty:%4)").arg(id).arg(width).arg(height).arg(quantity));
    return ok;
}

void CadEngine::nestClearParts() { nest_->clearParts(); setStatus("Nest parts cleared"); }

void CadEngine::nestSetSheet(const QString& id, double width, double height)
{
    nest_->setSheet(id.toStdString(), width, height);
    setStatus(QString("Nest sheet: %1 (%2 x %3 mm)").arg(id).arg(width).arg(height));
}

void CadEngine::nestSetPartGap(double gap)  { nest_->setPartGap(gap); }
void CadEngine::nestSetEdgeGap(double gap)  { nest_->setEdgeGap(gap); }
void CadEngine::nestSetRotation(int mode)   { nest_->setRotationMode(mode); }

QVariantMap CadEngine::nestRun(int algorithm)
{
    auto result = nest_->run(algorithm);

    QVariantMap map;
    map["totalPlaced"] = result.totalPlaced;
    map["totalUnplaced"] = result.totalUnplaced;
    map["utilization"] = result.utilization;
    map["sheetsUsed"] = result.sheetsUsed;

    QVariantList placements;
    for (const auto& p : result.placements) {
        QVariantMap pm;
        pm["partId"] = QString::fromStdString(p.partId);
        pm["x"] = p.x; pm["y"] = p.y;
        pm["rotation"] = p.rotation;
        pm["sheetIndex"] = p.sheetIndex;
        placements.append(pm);
    }
    map["placements"] = placements;

    setStatus(QString("Nesting: %1 placed, %2 unplaced, %3% util")
        .arg(result.totalPlaced).arg(result.totalUnplaced)
        .arg(static_cast<int>(result.utilization * 100)));

    return map;
}

// ── Solver ──────────────────────────────────────────────────────────

QString CadEngine::solve()
{
    if (!activeSketch_) return "No sketch";

    auto result = activeSketch_->solve();
    switch (result) {
        case SolveResult::Solved:           solverStatus_ = "Fully Constrained"; break;
        case SolveResult::UnderConstrained: solverStatus_ = "Under Constrained"; break;
        case SolveResult::OverConstrained:  solverStatus_ = "Over Constrained"; break;
        case SolveResult::Conflicting:      solverStatus_ = "Conflicting"; break;
        case SolveResult::Redundant:        solverStatus_ = "Redundant"; break;
        case SolveResult::SolverError:      solverStatus_ = "Solver Error"; break;
    }
    Q_EMIT sketchChanged();
    return solverStatus_;
}

// ── Property readers ────────────────────────────────────────────────

QVariantList CadEngine::featureTree() const
{
    QVariantList list;
    if (!document_) return list;

    for (const auto& f : document_->featureTree()) {
        QVariantMap item;
        item["name"] = QString::fromStdString(f.name);
        item["label"] = QString::fromStdString(f.label);
        item["typeName"] = QString::fromStdString(f.typeName);
        list.append(item);
    }
    return list;
}

QVariantList CadEngine::sketchGeometry() const
{
    QVariantList list;
    if (!activeSketch_) return list;

    for (const auto& g : activeSketch_->geometry()) {
        QVariantMap item;
        item["id"] = g.id;
        item["type"] = QString::fromStdString(g.type);
        item["startX"] = g.start.x;
        item["startY"] = g.start.y;
        item["endX"] = g.end.x;
        item["endY"] = g.end.y;
        item["centerX"] = g.center.x;
        item["centerY"] = g.center.y;
        item["radius"] = g.radius;
        item["startAngle"] = g.startAngle;
        item["endAngle"] = g.endAngle;
        item["construction"] = g.construction;
        item["majorRadius"] = g.majorRadius;
        item["minorRadius"] = g.minorRadius;
        item["angle"] = g.angle;
        item["degree"] = g.degree;

        if (!g.poles.empty()) {
            QVariantList polesList;
            for (const auto& p : g.poles) {
                QVariantMap pm;
                pm["x"] = p.x;
                pm["y"] = p.y;
                polesList.append(pm);
            }
            item["poles"] = polesList;
        }
        list.append(item);
    }
    return list;
}

QVariantList CadEngine::sketchConstraints() const
{
    QVariantList list;
    if (!activeSketch_) return list;

    for (const auto& c : activeSketch_->constraints()) {
        QVariantMap item;
        item["id"] = c.id;
        item["value"] = c.value;
        item["isDriving"] = c.isDriving;
        item["firstGeoId"] = c.firstGeoId;
        item["secondGeoId"] = c.secondGeoId;

        // Type name for display
        switch (c.type) {
            case ConstraintType::Distance:      item["typeName"] = "Distance"; break;
            case ConstraintType::Radius:        item["typeName"] = "Radius"; break;
            case ConstraintType::Horizontal:    item["typeName"] = "Horizontal"; break;
            case ConstraintType::Vertical:      item["typeName"] = "Vertical"; break;
            case ConstraintType::Coincident:    item["typeName"] = "Coincident"; break;
            case ConstraintType::Angle:         item["typeName"] = "Angle"; break;
            case ConstraintType::Perpendicular: item["typeName"] = "Perpendicular"; break;
            case ConstraintType::Parallel:      item["typeName"] = "Parallel"; break;
            case ConstraintType::Tangent:       item["typeName"] = "Tangent"; break;
            case ConstraintType::Equal:         item["typeName"] = "Equal"; break;
            case ConstraintType::Fixed:         item["typeName"] = "Fixed"; break;
            case ConstraintType::DistanceX:     item["typeName"] = "DistanceX"; break;
            case ConstraintType::DistanceY:     item["typeName"] = "DistanceY"; break;
            case ConstraintType::Diameter:      item["typeName"] = "Diameter"; break;
            case ConstraintType::Symmetric:     item["typeName"] = "Symmetric"; break;
            case ConstraintType::PointOnObject: item["typeName"] = "PointOnObject"; break;
            default:                            item["typeName"] = "Other"; break;
        }
        list.append(item);
    }
    return list;
}

QString CadEngine::solverStatus() const { return solverStatus_; }
QString CadEngine::statusMessage() const { return statusMessage_; }
bool CadEngine::sketchActive() const { return activeSketch_ != nullptr; }

bool CadEngine::canUndo() const
{
    return document_ && document_->canUndo();
}

bool CadEngine::canRedo() const
{
    return document_ && document_->canRedo();
}

bool CadEngine::hasDocument() const { return document_ != nullptr; }
QString CadEngine::documentPath() const { return documentPath_; }
QString CadEngine::documentName() const { return document_ ? QString::fromStdString(document_->name()) : ""; }

QStringList CadEngine::sketchNames() const
{
    QStringList names;
    if (!document_) return names;

    for (const auto& f : document_->featureTree()) {
        // Sketcher::SketchObject type name
        if (f.typeName.find("Sketcher::SketchObject") != std::string::npos) {
            names.append(QString::fromStdString(f.name));
        }
    }
    return names;
}

// ── Internal ────────────────────────────────────────────────────────

void CadEngine::refreshSketch()
{
    if (activeSketch_) {
        solve(); // auto-solve after every change
        // Note: recompute + viewport update deferred to closeSketch().
        // During sketch editing, only the solver runs — the QML SketchCanvas
        // reads sketchGeometry directly from the SketchFacade, not from OCCT shapes.
    }
    Q_EMIT sketchChanged();
}

void CadEngine::setStatus(const QString& msg)
{
    statusMessage_ = msg;
    Q_EMIT statusMessageChanged();
}

void CadEngine::updateViewportShapes()
{
    if (!viewport_ || !document_) return;

    // Clear existing shapes and re-display all features
    viewport_->clearShapes();

    auto features = document_->featureTree();

    // Find the last solid feature (Body Tip) — show only its result shape
    // plus any sketches as wireframe. PartDesign Body chain means the Tip
    // already contains the cumulative solid from all features.
    std::string tipName;
    for (auto it = features.rbegin(); it != features.rend(); ++it) {
        bool isSolid = it->typeName.find("Pad") != std::string::npos
                    || it->typeName.find("Pocket") != std::string::npos
                    || it->typeName.find("Revolution") != std::string::npos
                    || it->typeName.find("Groove") != std::string::npos
                    || it->typeName.find("Fuse") != std::string::npos
                    || it->typeName.find("Cut") != std::string::npos
                    || it->typeName.find("Common") != std::string::npos
                    || it->typeName.find("Box") != std::string::npos
                    || it->typeName.find("Cylinder") != std::string::npos
                    || it->typeName.find("Sphere") != std::string::npos
                    || it->typeName.find("Cone") != std::string::npos
                    || it->typeName.find("Fillet") != std::string::npos
                    || it->typeName.find("Chamfer") != std::string::npos
                    || it->typeName.find("LinearPattern") != std::string::npos
                    || it->typeName.find("PolarPattern") != std::string::npos
                    || it->typeName.find("Mirrored") != std::string::npos
                    || it->typeName.find("Body") != std::string::npos;
        if (isSolid) { tipName = it->name; break; }
    }

    for (const auto& f : features) {
        bool isSketch = f.typeName.find("Sketcher::SketchObject") != std::string::npos;
        bool isBody   = f.typeName.find("Body") != std::string::npos;

        // Skip body object itself (its shape = Tip shape, we show Tip directly)
        if (isBody) continue;

        // For solid features, only show the Tip (last in chain) to avoid
        // overlapping semi-transparent shapes
        bool isSolid = f.typeName.find("Pad") != std::string::npos
                    || f.typeName.find("Pocket") != std::string::npos
                    || f.typeName.find("Revolution") != std::string::npos
                    || f.typeName.find("Groove") != std::string::npos
                    || f.typeName.find("Fuse") != std::string::npos
                    || f.typeName.find("Cut") != std::string::npos
                    || f.typeName.find("Common") != std::string::npos
                    || f.typeName.find("Box") != std::string::npos
                    || f.typeName.find("Cylinder") != std::string::npos
                    || f.typeName.find("Sphere") != std::string::npos
                    || f.typeName.find("Cone") != std::string::npos
                    || f.typeName.find("Fillet") != std::string::npos
                    || f.typeName.find("Chamfer") != std::string::npos
                    || f.typeName.find("LinearPattern") != std::string::npos
                    || f.typeName.find("PolarPattern") != std::string::npos
                    || f.typeName.find("Mirrored") != std::string::npos;
        if (isSolid && f.name != tipName) continue;

        void* featurePtr = document_->getFeatureShape(f.name);
        if (!featurePtr) continue;

        // getFeatureShape returns Part::Feature* — extract a COPY of the shape
        // so the pointer stays valid after we leave this scope
        auto* partFeature = static_cast<Part::Feature*>(featurePtr);
        TopoDS_Shape shape = partFeature->Shape.getShape().getShape(); // copy
        if (shape.IsNull()) continue;

        // Color based on feature type
        Quantity_Color color(0.5, 0.7, 0.9, Quantity_TOC_sRGB);  // default blue
        if (isSketch)
            color = Quantity_Color(0.02, 0.6, 0.4, Quantity_TOC_sRGB);    // teal wireframe
        else if (f.typeName.find("Pad") != std::string::npos)
            color = Quantity_Color(0.4, 0.75, 0.45, Quantity_TOC_sRGB);   // green
        else if (f.typeName.find("Pocket") != std::string::npos)
            color = Quantity_Color(0.85, 0.4, 0.35, Quantity_TOC_sRGB);   // red
        else if (f.typeName.find("Revolution") != std::string::npos)
            color = Quantity_Color(0.35, 0.55, 0.9, Quantity_TOC_sRGB);   // blue
        else if (f.typeName.find("Groove") != std::string::npos)
            color = Quantity_Color(0.7, 0.4, 0.35, Quantity_TOC_sRGB);   // dark red
        else if (f.typeName.find("Box") != std::string::npos
              || f.typeName.find("Cylinder") != std::string::npos
              || f.typeName.find("Sphere") != std::string::npos
              || f.typeName.find("Cone") != std::string::npos)
            color = Quantity_Color(0.6, 0.7, 0.8, Quantity_TOC_sRGB);   // light steel
        else if (f.typeName.find("Fillet") != std::string::npos
              || f.typeName.find("Chamfer") != std::string::npos)
            color = Quantity_Color(0.5, 0.8, 0.6, Quantity_TOC_sRGB);   // mint
        else if (f.typeName.find("Fuse") != std::string::npos)
            color = Quantity_Color(0.45, 0.7, 0.85, Quantity_TOC_sRGB); // cyan
        else if (f.typeName.find("Cut") != std::string::npos
              || f.typeName.find("Common") != std::string::npos)
            color = Quantity_Color(0.85, 0.55, 0.4, Quantity_TOC_sRGB); // orange

        // Sketches shown as wireframe, solids as shaded
        viewport_->displayShape(f.name, shape, color, isSketch);
    }

    viewport_->fitAll();
}

} // namespace CADNC
