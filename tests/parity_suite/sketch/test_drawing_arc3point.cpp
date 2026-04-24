/**
 * @file test_drawing_arc3point.cpp
 * @brief Parity test for Tool #5 — CmdSketcherCreate3PointArc.
 *
 * FreeCAD source: src/Mod/Sketcher/Gui/CommandCreateGeo.cpp:362
 * Facade method:   SketchFacade::addArc3Point(Point2D, Point2D, Point2D, bool)
 *
 * The facade delegates to OCCT's GC_MakeArcOfCircle so the circumcircle
 * computation and the p1→p2→p3 orientation handling stay kernel-canonical.
 * GC_MakeArcOfCircle::IsDone() returns false for collinear or coincident
 * points; the facade translates that to FacadeError::InvalidArgument.
 *
 * Asserts:
 *   1. Happy path on a unit circle quadrant (p1=(1,0), p2=(cos45°,sin45°),
 *      p3=(0,1)) — center=(0,0), radius=1, arc passes through p2.
 *   2. Construction flag is honoured.
 *   3. Collinear p1/p2/p3 triggers FacadeError::InvalidArgument.
 *   4. Null sketch triggers FacadeError::NoActiveDocument.
 */

#include "test_helpers.h"

#include "FacadeError.h"

#include <cmath>

using namespace CADNC;

namespace {

const GeoInfo* findLastArc(const std::vector<GeoInfo>& geos)
{
    for (auto it = geos.rbegin(); it != geos.rend(); ++it) {
        if (it->type == "Arc") return &*it;
    }
    return nullptr;
}

} // namespace

CADNC_PARITY_TEST(Sketcher_Create3PointArc_HappyPath)
{
    auto fx = cadnc::test::makeSketchFixture();

    const Point2D p1{1.0, 0.0};
    const Point2D p2{std::cos(M_PI / 4.0), std::sin(M_PI / 4.0)};
    const Point2D p3{0.0, 1.0};
    const int id = fx.sketch->addArc3Point(p1, p2, p3, /*construction=*/false);
    CADNC_TEST_GE(id, 0);

    const GeoInfo* arc = findLastArc(fx.sketch->geometry());
    CADNC_TEST_TRUE(arc != nullptr);
    CADNC_TEST_NEAR(arc->center.x, 0.0, 1e-9);
    CADNC_TEST_NEAR(arc->center.y, 0.0, 1e-9);
    CADNC_TEST_NEAR(arc->radius,   1.0, 1e-9);
    CADNC_TEST_FALSE(arc->construction);
}

CADNC_PARITY_TEST(Sketcher_Create3PointArc_ConstructionFlag)
{
    auto fx = cadnc::test::makeSketchFixture();

    const int id = fx.sketch->addArc3Point(
        {1.0, 0.0}, {0.0, 1.0}, {-1.0, 0.0}, /*construction=*/true);
    CADNC_TEST_GE(id, 0);

    const GeoInfo* arc = findLastArc(fx.sketch->geometry());
    CADNC_TEST_TRUE(arc != nullptr);
    CADNC_TEST_TRUE(arc->construction);
}

CADNC_PARITY_TEST(Sketcher_Create3PointArc_CollinearThrows)
{
    auto fx = cadnc::test::makeSketchFixture();

    bool caught = false;
    try {
        fx.sketch->addArc3Point({0.0, 0.0}, {1.0, 0.0}, {2.0, 0.0});
    } catch (const FacadeError& e) {
        caught = (e.code() == FacadeError::Code::InvalidArgument);
    } catch (...) {}
    CADNC_TEST_TRUE(caught);
}

CADNC_PARITY_TEST(Sketcher_Create3PointArc_NoSketchThrows)
{
    SketchFacade empty(nullptr);
    bool caught = false;
    try {
        empty.addArc3Point({1.0, 0.0}, {0.0, 1.0}, {-1.0, 0.0});
    } catch (const FacadeError& e) {
        caught = (e.code() == FacadeError::Code::NoActiveDocument);
    } catch (...) {}
    CADNC_TEST_TRUE(caught);
}
