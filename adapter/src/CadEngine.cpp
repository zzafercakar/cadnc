#include "CadEngine.h"
#include "CadSession.h"
#include "CadDocument.h"
#include "SketchFacade.h"

#include <cmath>

namespace CADNC {

CadEngine::CadEngine(QObject* parent)
    : QObject(parent)
    , session_(std::make_unique<CadSession>())
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

// ── Document ────────────────────────────────────────────────────────

bool CadEngine::newDocument(const QString& name)
{
    document_ = session_->newDocument(name.toStdString());
    if (document_) {
        setStatus("Document created: " + name);
        Q_EMIT featureTreeChanged();
        return true;
    }
    return false;
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

// ── Sketch lifecycle ────────────────────────────────────────────────

bool CadEngine::createSketch(const QString& name)
{
    if (!document_) return false;
    activeSketch_ = document_->addSketch(name.toStdString());
    if (activeSketch_) {
        setStatus("Sketch created: " + name);
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
        setStatus("Editing sketch: " + name);
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
        setStatus("Sketch closed");
        Q_EMIT sketchChanged();
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

void CadEngine::removeGeometry(int geoId)
{
    if (!activeSketch_) return;
    activeSketch_->removeGeometry(geoId);
    refreshSketch();
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
            default:                            item["typeName"] = "Other"; break;
        }
        list.append(item);
    }
    return list;
}

QString CadEngine::solverStatus() const { return solverStatus_; }
QString CadEngine::statusMessage() const { return statusMessage_; }
bool CadEngine::sketchActive() const { return activeSketch_ != nullptr; }

// ── Internal ────────────────────────────────────────────────────────

void CadEngine::refreshSketch()
{
    if (activeSketch_) {
        solve(); // auto-solve after every change
    }
    Q_EMIT sketchChanged();
}

void CadEngine::setStatus(const QString& msg)
{
    statusMessage_ = msg;
    Q_EMIT statusMessageChanged();
}

} // namespace CADNC
