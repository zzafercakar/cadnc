/**
 * @file test_drawing_circle3point.cpp
 * @brief Parity test for Tool #10 — CmdSketcherCreate3PointCircle.
 *
 * FreeCAD source: src/Mod/Sketcher/Gui/CommandCreateGeo.cpp:589
 * Facade method:   SketchFacade::addCircle3Point(Point2D, Point2D, Point2D, bool)
 *
 * Uses OCCT GC_MakeCircle; IsDone()==false translates to InvalidArgument
 * (same pattern as addArc3Point for collinear/coincident triples).
 */

#include "test_helpers.h"

#include "FacadeError.h"

#include <cmath>

using namespace CADNC;

namespace {

const GeoInfo* findLastCircle(const std::vector<GeoInfo>& geos)
{
    for (auto it = geos.rbegin(); it != geos.rend(); ++it) {
        if (it->type == "Circle") return &*it;
    }
    return nullptr;
}

} // namespace

CADNC_PARITY_TEST(Sketcher_Create3PointCircle_HappyPath)
{
    auto fx = cadnc::test::makeSketchFixture();

    // Three points on the unit circle centred at (0,0).
    const int id = fx.sketch->addCircle3Point(
        { 1.0,  0.0},
        { 0.0,  1.0},
        {-1.0,  0.0});
    CADNC_TEST_GE(id, 0);

    const GeoInfo* c = findLastCircle(fx.sketch->geometry());
    CADNC_TEST_TRUE(c != nullptr);
    CADNC_TEST_NEAR(c->center.x, 0.0, 1e-9);
    CADNC_TEST_NEAR(c->center.y, 0.0, 1e-9);
    CADNC_TEST_NEAR(c->radius,   1.0, 1e-9);
    CADNC_TEST_FALSE(c->construction);
}

CADNC_PARITY_TEST(Sketcher_Create3PointCircle_ConstructionFlag)
{
    auto fx = cadnc::test::makeSketchFixture();
    const int id = fx.sketch->addCircle3Point(
        {1.0, 0.0}, {0.0, 1.0}, {-1.0, 0.0}, /*construction=*/true);
    CADNC_TEST_GE(id, 0);
    const GeoInfo* c = findLastCircle(fx.sketch->geometry());
    CADNC_TEST_TRUE(c != nullptr);
    CADNC_TEST_TRUE(c->construction);
}

CADNC_PARITY_TEST(Sketcher_Create3PointCircle_CollinearThrows)
{
    auto fx = cadnc::test::makeSketchFixture();
    bool caught = false;
    try {
        fx.sketch->addCircle3Point({0.0, 0.0}, {1.0, 0.0}, {2.0, 0.0});
    } catch (const FacadeError& e) {
        caught = (e.code() == FacadeError::Code::InvalidArgument);
    } catch (...) {}
    CADNC_TEST_TRUE(caught);
}

CADNC_PARITY_TEST(Sketcher_Create3PointCircle_NoSketchThrows)
{
    SketchFacade empty(nullptr);
    bool caught = false;
    try {
        empty.addCircle3Point({1.0, 0.0}, {0.0, 1.0}, {-1.0, 0.0});
    } catch (const FacadeError& e) {
        caught = (e.code() == FacadeError::Code::NoActiveDocument);
    } catch (...) {}
    CADNC_TEST_TRUE(caught);
}
