/**
 * @file test_drawing_rectangle.cpp
 * @brief Parity test for Tool #13 — CmdSketcherCreateRectangle.
 *
 * FreeCAD source: src/Mod/Sketcher/Gui/CommandCreateGeo.cpp:762
 * Facade method:   SketchFacade::addRectangle(Point2D, Point2D, bool)
 *
 * The facade builds four line segments plus the 4 corner Coincident
 * constraints AND the 4 axis-alignment Horizontal/Vertical constraints
 * that match FreeCAD's DrawSketchHandlerRectangle (Diagonal mode). The
 * test verifies the constraint taxonomy so a later SolverParity test
 * can be added without re-reading FreeCAD source.
 */

#include "test_helpers.h"

#include "FacadeError.h"

using namespace CADNC;

CADNC_PARITY_TEST(Sketcher_CreateRectangle_HappyPath)
{
    auto fx = cadnc::test::makeSketchFixture();

    const int firstId = fx.sketch->addRectangle({0.0, 0.0}, {10.0, 5.0});
    CADNC_TEST_GE(firstId, 0);

    // Expect 4 line segments appended at the tail.
    int lines = 0;
    for (const auto& g : fx.sketch->geometry()) {
        if (g.type == "Line" && g.id >= firstId) ++lines;
    }
    CADNC_TEST_EQ(lines, 4);

    // 4 coincident corners + 2 horizontal + 2 vertical.
    int coincidents = 0, horizontals = 0, verticals = 0;
    for (const auto& c : fx.sketch->constraints()) {
        if (c.type == ConstraintType::Coincident) ++coincidents;
        if (c.type == ConstraintType::Horizontal) ++horizontals;
        if (c.type == ConstraintType::Vertical)   ++verticals;
    }
    CADNC_TEST_GE(coincidents, 4);
    CADNC_TEST_GE(horizontals, 2);
    CADNC_TEST_GE(verticals,   2);
}

CADNC_PARITY_TEST(Sketcher_CreateRectangle_ConstructionFlag)
{
    auto fx = cadnc::test::makeSketchFixture();
    const int firstId = fx.sketch->addRectangle({0.0, 0.0}, {2.0, 1.0},
                                                  /*construction=*/true);
    CADNC_TEST_GE(firstId, 0);
    for (const auto& g : fx.sketch->geometry()) {
        if (g.type == "Line" && g.id >= firstId) {
            CADNC_TEST_TRUE(g.construction);
        }
    }
}

CADNC_PARITY_TEST(Sketcher_CreateRectangle_DegenerateThrows)
{
    auto fx = cadnc::test::makeSketchFixture();
    bool caught = false;
    try {
        // Zero height
        fx.sketch->addRectangle({0.0, 1.0}, {5.0, 1.0});
    } catch (const FacadeError& e) {
        caught = (e.code() == FacadeError::Code::InvalidArgument);
    } catch (...) {}
    CADNC_TEST_TRUE(caught);
}

CADNC_PARITY_TEST(Sketcher_CreateRectangle_NoSketchThrows)
{
    SketchFacade empty(nullptr);
    bool caught = false;
    try {
        empty.addRectangle({0.0, 0.0}, {1.0, 1.0});
    } catch (const FacadeError& e) {
        caught = (e.code() == FacadeError::Code::NoActiveDocument);
    } catch (...) {}
    CADNC_TEST_TRUE(caught);
}
