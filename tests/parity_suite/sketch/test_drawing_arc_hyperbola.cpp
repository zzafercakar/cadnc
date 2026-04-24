/**
 * @file test_drawing_arc_hyperbola.cpp
 * @brief Parity test for Tool #7 — CmdSketcherCreateArcOfHyperbola.
 *
 * FreeCAD source: src/Mod/Sketcher/Gui/CommandCreateGeo.cpp:429
 * Facade method:   SketchFacade::addArcHyperbola
 *
 * Hyperbola parametrised by OCCT as (a·cosh t, b·sinh t) where a=major,
 * b=minor semi-axes. The facade stores the parameters exactly as passed;
 * majorRadius is the real-axis, minorRadius the imaginary-axis semi-axis.
 * Unlike the ellipse case, no major>=minor normalisation is required
 * (both axes play asymmetric roles).
 */

#include "test_helpers.h"

#include "FacadeError.h"

#include <cmath>

using namespace CADNC;

namespace {

const GeoInfo* findLastArcOfHyperbola(const std::vector<GeoInfo>& geos)
{
    for (auto it = geos.rbegin(); it != geos.rend(); ++it) {
        if (it->type == "ArcOfHyperbola") return &*it;
    }
    return nullptr;
}

} // namespace

CADNC_PARITY_TEST(Sketcher_CreateArcOfHyperbola_HappyPath)
{
    auto fx = cadnc::test::makeSketchFixture();

    const int id = fx.sketch->addArcHyperbola(
        /*center=*/{0.0, 0.0},
        /*major=*/3.0, /*minor=*/2.0,
        /*rotation=*/0.0,
        /*start=*/0.0, /*end=*/1.5);
    CADNC_TEST_GE(id, 0);

    const GeoInfo* ah = findLastArcOfHyperbola(fx.sketch->geometry());
    CADNC_TEST_TRUE(ah != nullptr);
    CADNC_TEST_NEAR(ah->majorRadius, 3.0, 1e-9);
    CADNC_TEST_NEAR(ah->minorRadius, 2.0, 1e-9);
    CADNC_TEST_FALSE(ah->construction);
}

CADNC_PARITY_TEST(Sketcher_CreateArcOfHyperbola_ConstructionFlag)
{
    auto fx = cadnc::test::makeSketchFixture();
    const int id = fx.sketch->addArcHyperbola({0.0, 0.0}, 2.0, 1.0,
                                                0.0, -0.5, 0.5,
                                                /*construction=*/true);
    CADNC_TEST_GE(id, 0);
    const GeoInfo* ah = findLastArcOfHyperbola(fx.sketch->geometry());
    CADNC_TEST_TRUE(ah != nullptr);
    CADNC_TEST_TRUE(ah->construction);
}

CADNC_PARITY_TEST(Sketcher_CreateArcOfHyperbola_ZeroRadiusThrows)
{
    auto fx = cadnc::test::makeSketchFixture();
    bool caught = false;
    try {
        fx.sketch->addArcHyperbola({0.0, 0.0}, 0.0, 1.0, 0.0, 0.0, 1.0);
    } catch (const FacadeError& e) {
        caught = (e.code() == FacadeError::Code::InvalidArgument);
    } catch (...) {}
    CADNC_TEST_TRUE(caught);
}

CADNC_PARITY_TEST(Sketcher_CreateArcOfHyperbola_NoSketchThrows)
{
    SketchFacade empty(nullptr);
    bool caught = false;
    try {
        empty.addArcHyperbola({0.0, 0.0}, 2.0, 1.0, 0.0, 0.0, 1.0);
    } catch (const FacadeError& e) {
        caught = (e.code() == FacadeError::Code::NoActiveDocument);
    } catch (...) {}
    CADNC_TEST_TRUE(caught);
}
