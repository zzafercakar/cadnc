/**
 * @file test_drawing_arc_parabola.cpp
 * @brief Parity test for Tool #8 — CmdSketcherCreateArcOfParabola.
 *
 * FreeCAD source: src/Mod/Sketcher/Gui/CommandCreateGeo.cpp:459
 * Facade method:   SketchFacade::addArcParabola(Point2D vertex, double focal,
 *                                                double rotation,
 *                                                double startParam,
 *                                                double endParam, bool)
 *
 * Parabola is parametrised by a single scalar — the focal length (distance
 * from vertex to focus). geometry() reports the focal length in the
 * majorRadius field (per ConicSection convention consistent with Hyperbola
 * and Ellipse rows above — minor/angle stay zero for parabola).
 */

#include "test_helpers.h"

#include "FacadeError.h"

using namespace CADNC;

namespace {

const GeoInfo* findLastArcOfParabola(const std::vector<GeoInfo>& geos)
{
    for (auto it = geos.rbegin(); it != geos.rend(); ++it) {
        if (it->type == "ArcOfParabola") return &*it;
    }
    return nullptr;
}

} // namespace

CADNC_PARITY_TEST(Sketcher_CreateArcOfParabola_HappyPath)
{
    auto fx = cadnc::test::makeSketchFixture();

    const int id = fx.sketch->addArcParabola(
        /*vertex=*/{0.0, 0.0},
        /*focal=*/1.5,
        /*rotation=*/0.0,
        /*start=*/-2.0, /*end=*/2.0);
    CADNC_TEST_GE(id, 0);

    const GeoInfo* ap = findLastArcOfParabola(fx.sketch->geometry());
    CADNC_TEST_TRUE(ap != nullptr);
    CADNC_TEST_NEAR(ap->center.x,    0.0, 1e-9);
    CADNC_TEST_NEAR(ap->center.y,    0.0, 1e-9);
    CADNC_TEST_NEAR(ap->majorRadius, 1.5, 1e-9);  // focal length
    CADNC_TEST_FALSE(ap->construction);
}

CADNC_PARITY_TEST(Sketcher_CreateArcOfParabola_ConstructionFlag)
{
    auto fx = cadnc::test::makeSketchFixture();
    const int id = fx.sketch->addArcParabola({0.0, 0.0}, 1.0, 0.0, -1.0, 1.0,
                                               /*construction=*/true);
    CADNC_TEST_GE(id, 0);
    const GeoInfo* ap = findLastArcOfParabola(fx.sketch->geometry());
    CADNC_TEST_TRUE(ap != nullptr);
    CADNC_TEST_TRUE(ap->construction);
}

CADNC_PARITY_TEST(Sketcher_CreateArcOfParabola_ZeroFocalThrows)
{
    auto fx = cadnc::test::makeSketchFixture();
    bool caught = false;
    try {
        fx.sketch->addArcParabola({0.0, 0.0}, 0.0, 0.0, -1.0, 1.0);
    } catch (const FacadeError& e) {
        caught = (e.code() == FacadeError::Code::InvalidArgument);
    } catch (...) {}
    CADNC_TEST_TRUE(caught);
}

CADNC_PARITY_TEST(Sketcher_CreateArcOfParabola_NoSketchThrows)
{
    SketchFacade empty(nullptr);
    bool caught = false;
    try {
        empty.addArcParabola({0.0, 0.0}, 1.0, 0.0, -1.0, 1.0);
    } catch (const FacadeError& e) {
        caught = (e.code() == FacadeError::Code::NoActiveDocument);
    } catch (...) {}
    CADNC_TEST_TRUE(caught);
}
