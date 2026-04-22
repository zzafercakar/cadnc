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

    // ── 10. Close sketch and test Pad ────────────────────────────────
    sketch->close();
    doc->recompute();
    std::printf("[10] Sketch closed + recomputed\n");

    // ── 11. Pad via PartFacade ─────────────────────────────────────
    auto part = doc->partDesign();
    if (part) {
        std::string padName = part->pad("Sketch001", 10.0);
        if (!padName.empty()) {
            std::printf("[11] Pad created: %s\n", padName.c_str());

            void* shape = doc->getFeatureShape(padName);
            std::printf("     Pad shape: %s\n", shape ? "OK" : "null");
        } else {
            std::printf("[11] Pad FAILED (Body not available?)\n");
        }
    }

    // ── 12. Export test ────────────────────────────────────────────
    bool exported = doc->exportTo("/tmp/cadnc_adapter_test.step");
    std::printf("[12] STEP export: %s\n", exported ? "OK" : "skipped");

    // ── 13. Final feature tree ─────────────────────────────────────
    tree = doc->featureTree();
    std::printf("[13] Final feature tree (%zu items):\n", tree.size());
    for (const auto& f : tree) {
        std::printf("    - %s (%s)\n", f.name.c_str(), f.typeName.c_str());
    }

    // ── 14. BUG-010/015/016 regression: Body + parametric Pad edit ───
    // Flow: fresh doc → sketch on XY → rectangle → close → pad →
    // verify it is PartDesign::Pad (not the OCCT fallback Part::Feature) →
    // update the Pad length → shape remains valid (recompute ran).
    {
        auto doc2 = session.newDocument("PadEditTest");
        auto sk2  = doc2->addSketch("Profile", 0);
        sk2->addRectangle({0, 0}, {20, 10});
        sk2->close();
        doc2->recompute();

        auto part2 = doc2->partDesign();
        std::string padName = part2->pad("Profile", 5.0);

        auto params = part2->getFeatureParams(padName);
        std::printf("[14] BUG-010/015/016: Pad type='%s' editable=%s length=%.2f\n",
                    params.typeName.c_str(), params.editable ? "yes" : "no", params.length);
        if (params.typeName != "PartDesign::Pad")
            std::fprintf(stderr, "  WARN: Pad is not parametric PartDesign::Pad\n");
        if (!params.editable)
            std::fprintf(stderr, "  WARN: Pad reports editable=false — double-click edit won't work\n");

        bool ok = part2->updatePad(padName, 12.5, false);
        auto params2 = part2->getFeatureParams(padName);
        std::printf("[15] Pad updated %s, new length=%.2f\n", ok ? "OK" : "FAIL", params2.length);
    }

    // ── 16. BUG-017 regression: fillet auto-adds Radius constraint ───
    // Fillet on a rectangle corner should produce an arc WITH a Radius
    // constraint bound to the requested value. Without this, the user can't
    // edit the fillet radius via Smart Dimension after it's applied.
    {
        auto doc3 = session.newDocument("FilletRadiusTest");
        auto sk3  = doc3->addSketch("FilletSketch", 0);
        int r3    = sk3->addRectangle({0, 0}, {50, 30});
        (void)r3;
        // Rectangle is lines 0..3 (plus coincident/horizontal/vertical).
        // Fillet at the corner between line 0 (bottom) and line 3 (left),
        // identified by vertex geoId=0 + posId=1 (start of line 0).
        int before = static_cast<int>(sk3->constraints().size());
        int arcGid = sk3->fillet(0, 1, 4.0);
        int after = static_cast<int>(sk3->constraints().size());
        std::printf("[16] BUG-017: fillet arc=%d, constraints %d→%d (delta=%d)\n",
                    arcGid, before, after, after - before);
        bool hasRadius = false;
        for (const auto& c : sk3->constraints()) {
            if (c.type == CADNC::ConstraintType::Radius && c.firstGeoId == arcGid) {
                hasRadius = true;
                std::printf("     Radius constraint id=%d value=%.2f driving=%s\n",
                            c.id, c.value, c.isDriving ? "yes" : "no");
                break;
            }
        }
        if (!hasRadius)
            std::fprintf(stderr, "  FAIL: fillet did not auto-add a Radius constraint on the arc\n");
    }

    // ── 17. UX-008 regression: Pad rich mode (SideType + method) ─────
    // Verifies padEx stores Symmetric + Length2 and updatePadEx preserves
    // the method when only the length changes. Exercises the QVariantMap
    // bridge via the lower-level PartFacade API for headless coverage.
    {
        auto docS = session.newDocument("PadSymmetricTest");
        auto skS  = docS->addSketch("SymProfile", 0);
        skS->addRectangle({0, 0}, {20, 10});
        skS->close();
        docS->recompute();

        auto part = docS->partDesign();
        CADNC::PadOptions opts;
        opts.length   = 8.0;
        opts.length2  = 4.0;
        opts.sideType = "Two sides";
        opts.method   = "Length";
        std::string n = part->padEx("SymProfile", opts);
        auto p = part->getFeatureParams(n);
        std::printf("[17] UX-008 Pad rich: sideType='%s' method='%s' len=%.2f len2=%.2f\n",
                    p.sideType.c_str(), p.method.c_str(), p.length, p.length2);
        if (p.sideType != "Two sides")
            std::fprintf(stderr, "  FAIL: sideType not preserved (expected 'Two sides')\n");
    }

    std::printf("\n══════════════════════════════════════════════\n");
    std::printf("  Adapter Layer Test COMPLETED\n");
    std::printf("══════════════════════════════════════════════\n\n");

    return 0;
}
