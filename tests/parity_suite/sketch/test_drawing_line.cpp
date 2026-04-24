/**
 * @file test_drawing_line.cpp
 * @brief Parity test for Tool #2 — CmdSketcherCreateLine.
 *
 * FreeCAD source: src/Mod/Sketcher/Gui/CommandCreateGeo.cpp:194
 * Facade method:   SketchFacade::addLine(Point2D, Point2D, bool)
 *
 * Asserts:
 *   1. Happy path places a line segment with requested endpoints.
 *   2. Construction flag is honoured.
 *   3. FacadeError::NoActiveDocument is thrown when the underlying
 *      SketchObject pointer is null (mirrors the refactored precondition).
 */

#include "test_helpers.h"

#include "FacadeError.h"

using namespace CADNC;

namespace {

const GeoInfo* findLastLine(const std::vector<GeoInfo>& geos)
{
    for (auto it = geos.rbegin(); it != geos.rend(); ++it) {
        if (it->type == "Line") return &*it;
    }
    return nullptr;
}

} // namespace

CADNC_PARITY_TEST(Sketcher_CreateLine_HappyPath)
{
    auto fx = cadnc::test::makeSketchFixture();

    const int id = fx.sketch->addLine({1.0, 2.0}, {11.0, 7.0}, /*construction=*/false);
    CADNC_TEST_GE(id, 0);

    auto geos = fx.sketch->geometry();
    const GeoInfo* ln = findLastLine(geos);
    CADNC_TEST_TRUE(ln != nullptr);
    CADNC_TEST_NEAR(ln->start.x,  1.0, 1e-9);
    CADNC_TEST_NEAR(ln->start.y,  2.0, 1e-9);
    CADNC_TEST_NEAR(ln->end.x,   11.0, 1e-9);
    CADNC_TEST_NEAR(ln->end.y,    7.0, 1e-9);
    CADNC_TEST_FALSE(ln->construction);
}

CADNC_PARITY_TEST(Sketcher_CreateLine_ConstructionFlag)
{
    auto fx = cadnc::test::makeSketchFixture();

    const int id = fx.sketch->addLine({0.0, 0.0}, {5.0, 0.0}, /*construction=*/true);
    CADNC_TEST_GE(id, 0);

    auto geos = fx.sketch->geometry();
    const GeoInfo* ln = findLastLine(geos);
    CADNC_TEST_TRUE(ln != nullptr);
    CADNC_TEST_TRUE(ln->construction);
}

CADNC_PARITY_TEST(Sketcher_CreateLine_NoSketchThrows)
{
    SketchFacade empty(nullptr);
    bool caught = false;
    try {
        empty.addLine({0.0, 0.0}, {1.0, 1.0});
    } catch (const FacadeError& e) {
        caught = (e.code() == FacadeError::Code::NoActiveDocument);
    } catch (...) {}
    CADNC_TEST_TRUE(caught);
}
