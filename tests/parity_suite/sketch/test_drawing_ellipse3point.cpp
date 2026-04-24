/**
 * @file test_drawing_ellipse3point.cpp
 * @brief Parity test for Tool #12 — CmdSketcherCreateEllipseBy3Points.
 *
 * FreeCAD source: src/Mod/Sketcher/Gui/CommandCreateGeo.cpp:660
 * Facade method:   SketchFacade::addEllipse3Point(Point2D, Point2D, Point2D, bool)
 *
 * Interpretation: p1 and p2 are the two endpoints of the major axis; p3
 * is any rim point (not on the major axis, within the major-axis band)
 * that determines the minor radius. center = midpoint(p1,p2); major axis
 * direction = (p2-p1); minor radius derived from p3's projection into
 * the local frame.
 */

#include "test_helpers.h"

#include "FacadeError.h"

#include <cmath>

using namespace CADNC;

namespace {

const GeoInfo* findLastEllipse(const std::vector<GeoInfo>& geos)
{
    for (auto it = geos.rbegin(); it != geos.rend(); ++it) {
        if (it->type == "Ellipse") return &*it;
    }
    return nullptr;
}

} // namespace

CADNC_PARITY_TEST(Sketcher_CreateEllipseBy3Points_HappyPath)
{
    auto fx = cadnc::test::makeSketchFixture();

    // Axis-aligned ellipse: major axis from (-5,0) to (5,0) ⇒ a=5 at origin;
    // p3=(0,3) ⇒ local (0, 3) ⇒ minor=3.
    const int id = fx.sketch->addEllipse3Point({-5.0, 0.0}, {5.0, 0.0}, {0.0, 3.0});
    CADNC_TEST_GE(id, 0);

    const GeoInfo* e = findLastEllipse(fx.sketch->geometry());
    CADNC_TEST_TRUE(e != nullptr);
    CADNC_TEST_NEAR(e->center.x,     0.0, 1e-9);
    CADNC_TEST_NEAR(e->center.y,     0.0, 1e-9);
    CADNC_TEST_NEAR(e->majorRadius,  5.0, 1e-9);
    CADNC_TEST_NEAR(e->minorRadius,  3.0, 1e-9);
    CADNC_TEST_NEAR(e->angle,        0.0, 1e-9);
}

CADNC_PARITY_TEST(Sketcher_CreateEllipseBy3Points_ConstructionFlag)
{
    auto fx = cadnc::test::makeSketchFixture();
    const int id = fx.sketch->addEllipse3Point({-2.0, 0.0}, {2.0, 0.0},
                                                  {0.0, 1.0},
                                                  /*construction=*/true);
    CADNC_TEST_GE(id, 0);
    const GeoInfo* e = findLastEllipse(fx.sketch->geometry());
    CADNC_TEST_TRUE(e != nullptr);
    CADNC_TEST_TRUE(e->construction);
}

CADNC_PARITY_TEST(Sketcher_CreateEllipseBy3Points_DegenerateMajorThrows)
{
    auto fx = cadnc::test::makeSketchFixture();
    bool caught = false;
    try {
        // p1 == p2 → zero major axis
        fx.sketch->addEllipse3Point({1.0, 1.0}, {1.0, 1.0}, {0.0, 2.0});
    } catch (const FacadeError& e) {
        caught = (e.code() == FacadeError::Code::InvalidArgument);
    } catch (...) {}
    CADNC_TEST_TRUE(caught);
}

CADNC_PARITY_TEST(Sketcher_CreateEllipseBy3Points_OnAxisThrows)
{
    auto fx = cadnc::test::makeSketchFixture();
    bool caught = false;
    try {
        // p3 on major axis → yields zero minor radius
        fx.sketch->addEllipse3Point({-1.0, 0.0}, {1.0, 0.0}, {0.5, 0.0});
    } catch (const FacadeError& e) {
        caught = (e.code() == FacadeError::Code::InvalidArgument);
    } catch (...) {}
    CADNC_TEST_TRUE(caught);
}

CADNC_PARITY_TEST(Sketcher_CreateEllipseBy3Points_NoSketchThrows)
{
    SketchFacade empty(nullptr);
    bool caught = false;
    try {
        empty.addEllipse3Point({-1.0, 0.0}, {1.0, 0.0}, {0.0, 0.5});
    } catch (const FacadeError& e) {
        caught = (e.code() == FacadeError::Code::NoActiveDocument);
    } catch (...) {}
    CADNC_TEST_TRUE(caught);
}
