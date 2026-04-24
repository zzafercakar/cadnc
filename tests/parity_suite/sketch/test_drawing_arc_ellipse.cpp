/**
 * @file test_drawing_arc_ellipse.cpp
 * @brief Parity test for Tool #6 — CmdSketcherCreateArcOfEllipse.
 *
 * FreeCAD source: src/Mod/Sketcher/Gui/CommandCreateGeo.cpp:398
 * Facade method:   SketchFacade::addArcEllipse(Point2D, double, double,
 *                                               double, double, double, bool)
 *
 * The facade builds a Part::GeomArcOfEllipse and trims it via setRange.
 * OCCT requires majorRadius >= minorRadius; the facade swaps when the
 * caller passes them reversed (same normalisation addEllipse uses).
 *
 * Asserts:
 *   1. Happy path stores center, major/minor radii, rotation, and
 *      start/end angles as given.
 *   2. Swap rule: passing minor>major swaps them under the hood.
 *   3. Construction flag is honoured.
 *   4. Non-positive radius throws FacadeError::InvalidArgument.
 *   5. Null sketch throws FacadeError::NoActiveDocument.
 */

#include "test_helpers.h"

#include "FacadeError.h"

#include <cmath>

using namespace CADNC;

namespace {

const GeoInfo* findLastArcOfEllipse(const std::vector<GeoInfo>& geos)
{
    for (auto it = geos.rbegin(); it != geos.rend(); ++it) {
        if (it->type == "ArcOfEllipse") return &*it;
    }
    return nullptr;
}

} // namespace

CADNC_PARITY_TEST(Sketcher_CreateArcOfEllipse_HappyPath)
{
    auto fx = cadnc::test::makeSketchFixture();

    const int id = fx.sketch->addArcEllipse(
        /*center=*/{5.0, -2.0},
        /*major=*/3.0, /*minor=*/1.5,
        /*rotation=*/0.0,
        /*start=*/0.0, /*end=*/M_PI,
        /*construction=*/false);
    CADNC_TEST_GE(id, 0);

    const GeoInfo* ae = findLastArcOfEllipse(fx.sketch->geometry());
    CADNC_TEST_TRUE(ae != nullptr);
    CADNC_TEST_NEAR(ae->center.x,     5.0, 1e-9);
    CADNC_TEST_NEAR(ae->center.y,    -2.0, 1e-9);
    CADNC_TEST_NEAR(ae->majorRadius,  3.0, 1e-9);
    CADNC_TEST_NEAR(ae->minorRadius,  1.5, 1e-9);
    CADNC_TEST_NEAR(ae->startAngle,   0.0, 1e-9);
    CADNC_TEST_NEAR(ae->endAngle,    M_PI, 1e-9);
    CADNC_TEST_FALSE(ae->construction);
}

CADNC_PARITY_TEST(Sketcher_CreateArcOfEllipse_SwapsReversedRadii)
{
    auto fx = cadnc::test::makeSketchFixture();

    // Caller passed minor=2.0 as first radius, major=0.5 as second —
    // facade must normalise so major >= minor per OCCT invariant.
    const int id = fx.sketch->addArcEllipse({0.0, 0.0},
                                              /*major=*/0.5, /*minor=*/2.0,
                                              /*rotation=*/0.0,
                                              0.0, M_PI);
    CADNC_TEST_GE(id, 0);

    const GeoInfo* ae = findLastArcOfEllipse(fx.sketch->geometry());
    CADNC_TEST_TRUE(ae != nullptr);
    CADNC_TEST_NEAR(ae->majorRadius, 2.0, 1e-9);
    CADNC_TEST_NEAR(ae->minorRadius, 0.5, 1e-9);
}

CADNC_PARITY_TEST(Sketcher_CreateArcOfEllipse_ConstructionFlag)
{
    auto fx = cadnc::test::makeSketchFixture();

    const int id = fx.sketch->addArcEllipse({0.0, 0.0}, 2.0, 1.0,
                                              0.0, 0.0, M_PI,
                                              /*construction=*/true);
    CADNC_TEST_GE(id, 0);

    const GeoInfo* ae = findLastArcOfEllipse(fx.sketch->geometry());
    CADNC_TEST_TRUE(ae != nullptr);
    CADNC_TEST_TRUE(ae->construction);
}

CADNC_PARITY_TEST(Sketcher_CreateArcOfEllipse_ZeroRadiusThrows)
{
    auto fx = cadnc::test::makeSketchFixture();

    bool caught = false;
    try {
        fx.sketch->addArcEllipse({0.0, 0.0}, 0.0, 1.0, 0.0, 0.0, M_PI);
    } catch (const FacadeError& e) {
        caught = (e.code() == FacadeError::Code::InvalidArgument);
    } catch (...) {}
    CADNC_TEST_TRUE(caught);
}

CADNC_PARITY_TEST(Sketcher_CreateArcOfEllipse_NoSketchThrows)
{
    SketchFacade empty(nullptr);
    bool caught = false;
    try {
        empty.addArcEllipse({0.0, 0.0}, 2.0, 1.0, 0.0, 0.0, M_PI);
    } catch (const FacadeError& e) {
        caught = (e.code() == FacadeError::Code::NoActiveDocument);
    } catch (...) {}
    CADNC_TEST_TRUE(caught);
}
