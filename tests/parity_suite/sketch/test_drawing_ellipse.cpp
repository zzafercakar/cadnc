/**
 * @file test_drawing_ellipse.cpp
 * @brief Parity test for Tool #11 — CmdSketcherCreateEllipseByCenter.
 *
 * FreeCAD source: src/Mod/Sketcher/Gui/CommandCreateGeo.cpp:625
 * Facade method:   SketchFacade::addEllipse(Point2D, double, double, double, bool)
 *
 * addEllipse is the full-ellipse counterpart of addArcEllipse (Tool #6)
 * and reuses the same major>=minor normalisation rule.
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

CADNC_PARITY_TEST(Sketcher_CreateEllipseByCenter_HappyPath)
{
    auto fx = cadnc::test::makeSketchFixture();

    const int id = fx.sketch->addEllipse({1.0, -1.0}, 5.0, 3.0, /*angle=*/0.0);
    CADNC_TEST_GE(id, 0);

    const GeoInfo* e = findLastEllipse(fx.sketch->geometry());
    CADNC_TEST_TRUE(e != nullptr);
    CADNC_TEST_NEAR(e->center.x,     1.0, 1e-9);
    CADNC_TEST_NEAR(e->center.y,    -1.0, 1e-9);
    CADNC_TEST_NEAR(e->majorRadius,  5.0, 1e-9);
    CADNC_TEST_NEAR(e->minorRadius,  3.0, 1e-9);
    CADNC_TEST_FALSE(e->construction);
}

CADNC_PARITY_TEST(Sketcher_CreateEllipseByCenter_SwapsReversedRadii)
{
    auto fx = cadnc::test::makeSketchFixture();

    const int id = fx.sketch->addEllipse({0.0, 0.0},
                                           /*major=*/1.0, /*minor=*/4.0);
    CADNC_TEST_GE(id, 0);
    const GeoInfo* e = findLastEllipse(fx.sketch->geometry());
    CADNC_TEST_TRUE(e != nullptr);
    CADNC_TEST_NEAR(e->majorRadius, 4.0, 1e-9);
    CADNC_TEST_NEAR(e->minorRadius, 1.0, 1e-9);
}

CADNC_PARITY_TEST(Sketcher_CreateEllipseByCenter_ConstructionFlag)
{
    auto fx = cadnc::test::makeSketchFixture();
    const int id = fx.sketch->addEllipse({0.0, 0.0}, 2.0, 1.0, 0.0,
                                           /*construction=*/true);
    CADNC_TEST_GE(id, 0);
    const GeoInfo* e = findLastEllipse(fx.sketch->geometry());
    CADNC_TEST_TRUE(e != nullptr);
    CADNC_TEST_TRUE(e->construction);
}

CADNC_PARITY_TEST(Sketcher_CreateEllipseByCenter_ZeroRadiusThrows)
{
    auto fx = cadnc::test::makeSketchFixture();
    bool caught = false;
    try {
        fx.sketch->addEllipse({0.0, 0.0}, 0.0, 1.0);
    } catch (const FacadeError& e) {
        caught = (e.code() == FacadeError::Code::InvalidArgument);
    } catch (...) {}
    CADNC_TEST_TRUE(caught);
}

CADNC_PARITY_TEST(Sketcher_CreateEllipseByCenter_NoSketchThrows)
{
    SketchFacade empty(nullptr);
    bool caught = false;
    try {
        empty.addEllipse({0.0, 0.0}, 2.0, 1.0);
    } catch (const FacadeError& e) {
        caught = (e.code() == FacadeError::Code::NoActiveDocument);
    } catch (...) {}
    CADNC_TEST_TRUE(caught);
}
