/**
 * @file test_adapter.cpp
 * @brief Phase 2 test — verifies the adapter layer works end-to-end.
 *
 * Uses CadSession, CadDocument, SketchFacade to create a sketch,
 * add geometry, constrain it, and solve — all through the clean adapter API.
 * No FreeCAD headers are included here (only adapter headers).
 */

#include <cstdio>
#include <cmath>
#include "CadSession.h"
#include "CadDocument.h"
#include "SketchFacade.h"
#include "PartFacade.h"

int main(int argc, char* argv[])
{
    std::printf("\n══════════════════════════════════════════════\n");
    std::printf("  CADNC — Adapter Layer Test (Phase 2)\n");
    std::printf("══════════════════════════════════════════════\n\n");

    // ── 1. Session init ─────────────────────────────────────────────
    CADNC::CadSession session;
    if (!session.initialize(argc, argv)) {
        std::fprintf(stderr, "Failed to initialize CadSession\n");
        return 1;
    }
    std::printf("[1] CadSession initialized\n");

    // ── 2. Create document ──────────────────────────────────────────
    auto doc = session.newDocument("AdapterTest");
    std::printf("[2] Document created: '%s'\n", doc->name().c_str());

    // ── 3. Add sketch ───────────────────────────────────────────────
    auto sketch = doc->addSketch("Sketch001");
    if (!sketch) {
        std::fprintf(stderr, "Failed to create sketch\n");
        return 1;
    }
    std::printf("[3] Sketch created\n");

    // ── 4. Add geometry via facade ──────────────────────────────────
    int lineId = sketch->addLine({0, 0}, {20, 0});
    int circId = sketch->addCircle({10, 10}, 5.0);
    std::printf("[4] Geometry added: line(id=%d), circle(id=%d)\n", lineId, circId);

    // ── 5. Add constraints ──────────────────────────────────────────
    int c1 = sketch->addDistance(lineId, 30.0);   // line length = 30
    int c2 = sketch->addRadius(circId, 8.0);      // circle radius = 8
    int c3 = sketch->addHorizontal(lineId);        // line is horizontal
    std::printf("[5] Constraints added: distance(id=%d), radius(id=%d), horizontal(id=%d)\n",
                c1, c2, c3);

    // ── 6. Solve ────────────────────────────────────────────────────
    auto result = sketch->solve();
    const char* resultStr = "?";
    switch (result) {
        case CADNC::SolveResult::Solved:           resultStr = "Solved"; break;
        case CADNC::SolveResult::UnderConstrained:  resultStr = "UnderConstrained"; break;
        case CADNC::SolveResult::OverConstrained:   resultStr = "OverConstrained"; break;
        case CADNC::SolveResult::Conflicting:       resultStr = "Conflicting"; break;
        case CADNC::SolveResult::Redundant:         resultStr = "Redundant"; break;
        case CADNC::SolveResult::SolverError:       resultStr = "SolverError"; break;
    }
    std::printf("[6] Solver result: %s\n", resultStr);

    // ── 7. Read back solved geometry ────────────────────────────────
    auto geos = sketch->geometry();
    std::printf("[7] Solved geometry (%zu items):\n", geos.size());
    for (const auto& g : geos) {
        if (g.type == "Line") {
            double dx = g.end.x - g.start.x;
            double dy = g.end.y - g.start.y;
            double len = std::sqrt(dx*dx + dy*dy);
            std::printf("    [%d] Line: (%.1f,%.1f) -> (%.1f,%.1f)  len=%.1f\n",
                        g.id, g.start.x, g.start.y, g.end.x, g.end.y, len);
        } else if (g.type == "Circle") {
            std::printf("    [%d] Circle: center=(%.1f,%.1f) r=%.1f\n",
                        g.id, g.center.x, g.center.y, g.radius);
        }
    }

    // ── 8. Feature tree ─────────────────────────────────────────────
    auto tree = doc->featureTree();
    std::printf("[8] Feature tree (%zu items):\n", tree.size());
    for (const auto& f : tree) {
        std::printf("    - %s (%s)\n", f.name.c_str(), f.typeName.c_str());
    }

    // ── 9. Constraint query ─────────────────────────────────────────
    auto constrs = sketch->constraints();
    std::printf("[9] Constraints (%zu):\n", constrs.size());
    for (const auto& c : constrs) {
        std::printf("    [%d] value=%.1f driving=%s\n",
                    c.id, c.value, c.isDriving ? "yes" : "no");
    }

    std::printf("\n══════════════════════════════════════════════\n");
    std::printf("  Adapter Layer Test COMPLETED\n");
    std::printf("══════════════════════════════════════════════\n\n");

    return 0;
}
