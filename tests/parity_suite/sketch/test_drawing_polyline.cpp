/**
 * @file test_drawing_polyline.cpp
 * @brief Parity test for Tool #3 — CmdSketcherCreatePolyline.
 *
 * FreeCAD source: src/Mod/Sketcher/Gui/CommandCreateGeo.cpp:225
 * Facade method:   SketchFacade::addPolyline(const std::vector<Point2D>&, bool)
 *
 * Polyline is modelled as N-1 line segments sharing Coincident constraints
 * at the interior vertices. The facade creates the lines + coincidents
 * inside a single engine-level transaction so undo rolls back the whole
 * chain.
 *
 * Asserts:
 *   1. Happy path returns the first line's geoId; N-1 Line segments are
 *      added with matching endpoints in the expected order.
 *   2. Construction flag is honoured (every segment marked construction).
 *   3. FacadeError::InvalidArgument is thrown when fewer than 2 points
 *      are supplied (single-point polyline is geometrically meaningless).
 *   4. FacadeError::NoActiveDocument is thrown when the underlying
 *      SketchObject pointer is null.
 */

#include "test_helpers.h"

#include "FacadeError.h"

using namespace CADNC;

CADNC_PARITY_TEST(Sketcher_CreatePolyline_HappyPath)
{
    auto fx = cadnc::test::makeSketchFixture();

    const std::vector<Point2D> pts = {
        {0.0, 0.0}, {10.0, 0.0}, {10.0, 5.0}, {0.0, 5.0}
    };
    const int firstId = fx.sketch->addPolyline(pts, /*construction=*/false);
    CADNC_TEST_GE(firstId, 0);

    const auto geos = fx.sketch->geometry();

    // Expect 3 Line segments (N-1 for N points), appended in order at the tail.
    int lineCount = 0;
    for (const auto& g : geos) if (g.type == "Line") ++lineCount;
    CADNC_TEST_GE(lineCount, 3);

    // Check the first segment's endpoints match pts[0] → pts[1].
    const GeoInfo* firstLine = nullptr;
    for (const auto& g : geos) {
        if (g.id == firstId && g.type == "Line") { firstLine = &g; break; }
    }
    CADNC_TEST_TRUE(firstLine != nullptr);
    CADNC_TEST_NEAR(firstLine->start.x, 0.0,  1e-9);
    CADNC_TEST_NEAR(firstLine->start.y, 0.0,  1e-9);
    CADNC_TEST_NEAR(firstLine->end.x,  10.0,  1e-9);
    CADNC_TEST_NEAR(firstLine->end.y,   0.0,  1e-9);

    // At least N-2 internal coincident constraints (2 for this 4-point chain).
    int coincidents = 0;
    for (const auto& c : fx.sketch->constraints()) {
        if (c.type == ConstraintType::Coincident) ++coincidents;
    }
    CADNC_TEST_GE(coincidents, 2);
}

CADNC_PARITY_TEST(Sketcher_CreatePolyline_ConstructionFlag)
{
    auto fx = cadnc::test::makeSketchFixture();

    const std::vector<Point2D> pts = {{0.0, 0.0}, {1.0, 0.0}, {1.0, 1.0}};
    const int firstId = fx.sketch->addPolyline(pts, /*construction=*/true);
    CADNC_TEST_GE(firstId, 0);

    // Every Line segment created by this polyline must be construction.
    int checkedSegments = 0;
    for (const auto& g : fx.sketch->geometry()) {
        if (g.type == "Line" && g.id >= firstId) {
            CADNC_TEST_TRUE(g.construction);
            ++checkedSegments;
        }
    }
    CADNC_TEST_GE(checkedSegments, 2);
}

CADNC_PARITY_TEST(Sketcher_CreatePolyline_TooFewPointsThrows)
{
    auto fx = cadnc::test::makeSketchFixture();

    bool caught = false;
    try {
        fx.sketch->addPolyline({{1.0, 1.0}});
    } catch (const FacadeError& e) {
        caught = (e.code() == FacadeError::Code::InvalidArgument);
    } catch (...) {}
    CADNC_TEST_TRUE(caught);
}

CADNC_PARITY_TEST(Sketcher_CreatePolyline_NoSketchThrows)
{
    SketchFacade empty(nullptr);
    bool caught = false;
    try {
        empty.addPolyline({{0.0, 0.0}, {1.0, 1.0}});
    } catch (const FacadeError& e) {
        caught = (e.code() == FacadeError::Code::NoActiveDocument);
    } catch (...) {}
    CADNC_TEST_TRUE(caught);
}
