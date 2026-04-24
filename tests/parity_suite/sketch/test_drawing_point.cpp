/**
 * @file test_drawing_point.cpp
 * @brief Parity test for Tool #1 — CmdSketcherCreatePoint.
 *
 * FreeCAD source: src/Mod/Sketcher/Gui/CommandCreateGeo.cpp:107
 * Facade method:   SketchFacade::addPoint(Point2D, bool)
 *
 * Asserts:
 *   1. Happy path places a point at the requested (x, y).
 *   2. Construction flag is honoured.
 *   3. FacadeError::NoActiveDocument is thrown when the underlying
 *      SketchObject pointer is null (mirrors the refactored precondition).
 */

#include "test_helpers.h"

#include "FacadeError.h"

#include <algorithm>

using namespace CADNC;

namespace {

const GeoInfo* findLastPoint(const std::vector<GeoInfo>& geos)
{
    for (auto it = geos.rbegin(); it != geos.rend(); ++it) {
        if (it->type == "Point") return &*it;
    }
    return nullptr;
}

} // namespace

CADNC_PARITY_TEST(Sketcher_CreatePoint_HappyPath)
{
    auto fx = cadnc::test::makeSketchFixture();

    const int id = fx.sketch->addPoint({3.5, -2.25}, /*construction=*/false);
    CADNC_TEST_GE(id, 0);

    auto geos = fx.sketch->geometry();
    const GeoInfo* pt = findLastPoint(geos);
    CADNC_TEST_TRUE(pt != nullptr);
    CADNC_TEST_NEAR(pt->center.x,  3.5, 1e-9);
    CADNC_TEST_NEAR(pt->center.y, -2.25, 1e-9);
    CADNC_TEST_FALSE(pt->construction);
}

CADNC_PARITY_TEST(Sketcher_CreatePoint_ConstructionFlag)
{
    auto fx = cadnc::test::makeSketchFixture();

    const int id = fx.sketch->addPoint({0.0, 0.0}, /*construction=*/true);
    CADNC_TEST_GE(id, 0);

    auto geos = fx.sketch->geometry();
    const GeoInfo* pt = findLastPoint(geos);
    CADNC_TEST_TRUE(pt != nullptr);
    CADNC_TEST_TRUE(pt->construction);
}

CADNC_PARITY_TEST(Sketcher_CreatePoint_NoSketchThrows)
{
    SketchFacade empty(nullptr);
    bool caught = false;
    try {
        empty.addPoint({1.0, 1.0});
    } catch (const FacadeError& e) {
        caught = (e.code() == FacadeError::Code::NoActiveDocument);
    } catch (...) {}
    CADNC_TEST_TRUE(caught);
}
