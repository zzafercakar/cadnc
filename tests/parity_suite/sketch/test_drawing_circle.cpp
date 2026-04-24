/**
 * @file test_drawing_circle.cpp
 * @brief Parity test for Tool #9 — CmdSketcherCreateCircle.
 *
 * FreeCAD source: src/Mod/Sketcher/Gui/CommandCreateGeo.cpp:558
 * Facade method:   SketchFacade::addCircle(Point2D, double, bool)
 */

#include "test_helpers.h"

#include "FacadeError.h"

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

CADNC_PARITY_TEST(Sketcher_CreateCircle_HappyPath)
{
    auto fx = cadnc::test::makeSketchFixture();

    const int id = fx.sketch->addCircle({2.0, 3.0}, 4.0);
    CADNC_TEST_GE(id, 0);

    const GeoInfo* c = findLastCircle(fx.sketch->geometry());
    CADNC_TEST_TRUE(c != nullptr);
    CADNC_TEST_NEAR(c->center.x, 2.0, 1e-9);
    CADNC_TEST_NEAR(c->center.y, 3.0, 1e-9);
    CADNC_TEST_NEAR(c->radius,   4.0, 1e-9);
    CADNC_TEST_FALSE(c->construction);
}

CADNC_PARITY_TEST(Sketcher_CreateCircle_ConstructionFlag)
{
    auto fx = cadnc::test::makeSketchFixture();
    const int id = fx.sketch->addCircle({0.0, 0.0}, 1.0, /*construction=*/true);
    CADNC_TEST_GE(id, 0);
    const GeoInfo* c = findLastCircle(fx.sketch->geometry());
    CADNC_TEST_TRUE(c != nullptr);
    CADNC_TEST_TRUE(c->construction);
}

CADNC_PARITY_TEST(Sketcher_CreateCircle_ZeroRadiusThrows)
{
    auto fx = cadnc::test::makeSketchFixture();
    bool caught = false;
    try {
        fx.sketch->addCircle({0.0, 0.0}, 0.0);
    } catch (const FacadeError& e) {
        caught = (e.code() == FacadeError::Code::InvalidArgument);
    } catch (...) {}
    CADNC_TEST_TRUE(caught);
}

CADNC_PARITY_TEST(Sketcher_CreateCircle_NoSketchThrows)
{
    SketchFacade empty(nullptr);
    bool caught = false;
    try {
        empty.addCircle({0.0, 0.0}, 1.0);
    } catch (const FacadeError& e) {
        caught = (e.code() == FacadeError::Code::NoActiveDocument);
    } catch (...) {}
    CADNC_TEST_TRUE(caught);
}
