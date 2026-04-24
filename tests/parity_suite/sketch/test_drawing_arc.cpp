/**
 * @file test_drawing_arc.cpp
 * @brief Parity test for Tool #4 — CmdSketcherCreateArc.
 *
 * FreeCAD source: src/Mod/Sketcher/Gui/CommandCreateGeo.cpp:330
 * Facade method:   SketchFacade::addArc(Point2D, double, double, double, bool)
 *
 * FreeCAD's "Arc From Center" places the arc by picking a center then an
 * end point — the App-level SketchObject stores the arc as Part::GeomArcOf
 * Circle with (center, radius, startAngle, endAngle). The facade takes
 * those four scalars directly in radians; DrawSketchHandlerArc owns the
 * click-to-angle conversion at the UI layer.
 *
 * Asserts:
 *   1. Happy path stores center/radius/angles on the GeomArcOfCircle.
 *   2. Construction flag is honoured.
 *   3. FacadeError::InvalidArgument is thrown for non-positive radius
 *      (matches facade's radius < 1e-7 guard — FreeCAD DrawSketchHandler
 *      enforces the same via mouse distance).
 *   4. FacadeError::NoActiveDocument is thrown when the SketchObject
 *      pointer is null.
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

CADNC_PARITY_TEST(Sketcher_CreateArc_HappyPath)
{
    auto fx = cadnc::test::makeSketchFixture();

    const double sa = 0.0;
    const double ea = M_PI / 2.0;
    const int id = fx.sketch->addArc({2.0, -3.0}, 5.0, sa, ea, /*construction=*/false);
    CADNC_TEST_GE(id, 0);

    const auto geos = fx.sketch->geometry();
    const GeoInfo* arc = findLastArc(geos);
    CADNC_TEST_TRUE(arc != nullptr);
    CADNC_TEST_NEAR(arc->center.x,   2.0, 1e-9);
    CADNC_TEST_NEAR(arc->center.y,  -3.0, 1e-9);
    CADNC_TEST_NEAR(arc->radius,     5.0, 1e-9);
    CADNC_TEST_NEAR(arc->startAngle, sa,  1e-9);
    CADNC_TEST_NEAR(arc->endAngle,   ea,  1e-9);
    CADNC_TEST_FALSE(arc->construction);
}

CADNC_PARITY_TEST(Sketcher_CreateArc_ConstructionFlag)
{
    auto fx = cadnc::test::makeSketchFixture();

    const int id = fx.sketch->addArc({0.0, 0.0}, 1.0, 0.0, M_PI, /*construction=*/true);
    CADNC_TEST_GE(id, 0);

    const GeoInfo* arc = findLastArc(fx.sketch->geometry());
    CADNC_TEST_TRUE(arc != nullptr);
    CADNC_TEST_TRUE(arc->construction);
}

CADNC_PARITY_TEST(Sketcher_CreateArc_ZeroRadiusThrows)
{
    auto fx = cadnc::test::makeSketchFixture();

    bool caught = false;
    try {
        fx.sketch->addArc({0.0, 0.0}, 0.0, 0.0, M_PI);
    } catch (const FacadeError& e) {
        caught = (e.code() == FacadeError::Code::InvalidArgument);
    } catch (...) {}
    CADNC_TEST_TRUE(caught);
}

CADNC_PARITY_TEST(Sketcher_CreateArc_NoSketchThrows)
{
    SketchFacade empty(nullptr);
    bool caught = false;
    try {
        empty.addArc({0.0, 0.0}, 1.0, 0.0, M_PI);
    } catch (const FacadeError& e) {
        caught = (e.code() == FacadeError::Code::NoActiveDocument);
    } catch (...) {}
    CADNC_TEST_TRUE(caught);
}
