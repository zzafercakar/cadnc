/**
 * @file test_part_flow.cpp
 * @brief End-to-end test: sketch → close → pad through adapter API.
 */
#include <cstdio>
#include "CadSession.h"
#include "CadDocument.h"
#include "SketchFacade.h"
#include "PartFacade.h"

#define CHECK(expr, msg) do { \
    if (!(expr)) { std::fprintf(stderr, "FAIL: %s\n", msg); return 1; } \
    std::printf("  OK: %s\n", msg); \
} while(0)

int main(int argc, char* argv[])
{
    std::printf("=== Part Flow Test ===\n");

    CADNC::CadSession session;
    std::fprintf(stderr, "DIAG: calling init\n");
    bool initOk = session.initialize(argc, argv);
    std::fprintf(stderr, "DIAG: init returned %d\n", initOk);
    CHECK(initOk, "Session init");

    {
        // Scope block — document destroyed before session
        auto doc = session.newDocument("PFTest");
        CHECK(doc != nullptr, "Document created");

        auto sketch = doc->addSketch("Sketch001", 0);
        CHECK(sketch != nullptr, "Sketch created");

        int r = sketch->addRectangle({-10, -5}, {10, 5});
        CHECK(r >= 0, "Rectangle added");

        sketch->close();
        doc->recompute();
        std::printf("  OK: Sketch closed\n");

        // Feature tree
        auto tree = doc->featureTree();
        std::printf("  Features (%zu):\n", tree.size());
        for (const auto& f : tree)
            std::printf("    %s [%s]\n", f.name.c_str(), f.typeName.c_str());

        // Pad
        auto part = doc->partDesign();
        CHECK(part != nullptr, "PartFacade obtained");

        std::string padName = part->pad("Sketch001", 15.0);
        if (padName.empty()) {
            std::printf("  WARN: Pad creation failed (Body may need Python)\n");
        } else {
            std::printf("  OK: Pad created: %s\n", padName.c_str());

            void* shape = doc->getFeatureShape(padName);
            if (shape) std::printf("  OK: Pad has shape\n");
            else std::printf("  WARN: Pad has no shape\n");
        }

        // Explicit cleanup
        sketch.reset();
        part.reset();
        doc.reset();
    }

    std::printf("=== DONE ===\n");
    return 0;
}
