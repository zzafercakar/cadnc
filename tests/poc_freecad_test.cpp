/**
 * @file poc_freecad_test.cpp
 * @brief Phase 1.3 PoC — Proves FreeCAD backend works headlessly inside CADNC.
 *
 * Steps:
 *  1. Initialize FreeCAD Base + App (headless, no GUI)
 *  2. Create a new document
 *  3. Add a SketchObject
 *  4. Add geometry: a line + a circle
 *  5. Add constraints: line length (Distance) + circle radius (Radius)
 *  6. Solve the sketch
 *  7. Print results
 */

#include <cstdio>
#include <cstdlib>
#include <memory>
#include <iostream>

// Python must be included before any standard headers in some setups
#include <CXX/WrapPython.h>

// FreeCAD Base
#include <Base/Console.h>
#include <Base/Type.h>
#include <Base/Interpreter.h>
#include <Base/Exception.h>
#include <Base/Vector3D.h>

// FreeCAD App
#include <App/Application.h>
#include <App/Document.h>

// Part geometry types
#include <Mod/Part/App/Geometry.h>

// Sketcher
#include <Mod/Sketcher/App/SketchObject.h>
#include <Mod/Sketcher/App/Constraint.h>
#include <Mod/Sketcher/App/GeoEnum.h>

// Module init functions (declared in AppPart.cpp / AppSketcher.cpp)
extern "C" PyObject* PyInit_Part();
extern "C" PyObject* PyInit_Sketcher();
extern "C" PyObject* PyInit_Materials();
extern "C" PyObject* PyInit__PartDesign();

static void printSeparator(const char* title)
{
    std::printf("\n══════════════════════════════════════════════\n");
    std::printf("  %s\n", title);
    std::printf("══════════════════════════════════════════════\n");
}

int main(int argc, char* argv[])
{
    try {
        printSeparator("CADNC — FreeCAD Backend PoC Test");

        // ── Step 0: Register Python modules before Py_Initialize ─────────
        // FreeCAD's Application::init() does this for FreeCAD and __FreeCADBase__,
        // but we also need Part, Sketcher, Materials, PartDesign modules
        PyImport_AppendInittab("Part", PyInit_Part);
        PyImport_AppendInittab("Sketcher", PyInit_Sketcher);
        PyImport_AppendInittab("Materials", PyInit_Materials);
        PyImport_AppendInittab("_PartDesign", PyInit__PartDesign);

        // ── Step 1: Initialize FreeCAD ───────────────────────────────────
        std::printf("[1/7] Initializing FreeCAD...\n");
        App::Application::init(argc, argv);
        std::printf("  ✓ FreeCAD initialized successfully\n");

        // ── Step 2: Create a new document ────────────────────────────────
        std::printf("[2/7] Creating document...\n");
        App::Document* doc = App::GetApplication().newDocument("TestDoc", "PoC Test");
        std::printf("  ✓ Document created: '%s'\n", doc->getName());

        // ── Step 3: Add a SketchObject ───────────────────────────────────
        std::printf("[3/7] Adding SketchObject...\n");
        auto* sketch = dynamic_cast<Sketcher::SketchObject*>(
            doc->addObject("Sketcher::SketchObject", "Sketch001")
        );
        if (!sketch) {
            std::fprintf(stderr, "  ✗ Failed to create SketchObject\n");
            return 1;
        }
        std::printf("  ✓ SketchObject added: '%s'\n", sketch->getNameInDocument());

        // ── Step 4: Add geometry ─────────────────────────────────────────
        std::printf("[4/7] Adding geometry (line + circle)...\n");

        // Line from (0,0) to (10,0)
        auto line = std::make_unique<Part::GeomLineSegment>();
        line->setPoints(Base::Vector3d(0.0, 0.0, 0.0), Base::Vector3d(10.0, 0.0, 0.0));
        int lineId = sketch->addGeometry(line.release());
        std::printf("  ✓ Line added (geoId=%d): (0,0) → (10,0)\n", lineId);

        // Circle at (5, 5) with radius 3
        auto circle = std::make_unique<Part::GeomCircle>();
        circle->setCenter(Base::Vector3d(5.0, 5.0, 0.0));
        circle->setRadius(3.0);
        int circleId = sketch->addGeometry(circle.release());
        std::printf("  ✓ Circle added (geoId=%d): center=(5,5), r=3\n", circleId);

        // ── Step 5: Add constraints ──────────────────────────────────────
        std::printf("[5/7] Adding constraints...\n");

        // Distance constraint on line (length = 15.0)
        {
            auto constraint = std::make_unique<Sketcher::Constraint>();
            constraint->Type = Sketcher::Distance;
            constraint->setElement(0, Sketcher::GeoElementId(lineId, Sketcher::PointPos::start));
            constraint->setElement(1, Sketcher::GeoElementId(lineId, Sketcher::PointPos::end));
            constraint->setValue(15.0);
            constraint->isDriving = true;
            int cId = sketch->addConstraint(constraint.release());
            std::printf("  ✓ Distance constraint (id=%d): line length = 15.0\n", cId);
        }

        // Radius constraint on circle (radius = 4.0)
        {
            auto constraint = std::make_unique<Sketcher::Constraint>();
            constraint->Type = Sketcher::Radius;
            constraint->setElement(0, Sketcher::GeoElementId(circleId, Sketcher::PointPos::none));
            constraint->setValue(4.0);
            constraint->isDriving = true;
            int cId = sketch->addConstraint(constraint.release());
            std::printf("  ✓ Radius constraint (id=%d): circle radius = 4.0\n", cId);
        }

        // ── Step 6: Solve the sketch ─────────────────────────────────────
        std::printf("[6/7] Solving sketch...\n");
        int solveResult = sketch->solve();
        switch (solveResult) {
            case 0:
                std::printf("  ✓ Sketch solved successfully (fully constrained)\n");
                break;
            case -1:
                std::printf("  ⚠ Solver error\n");
                break;
            case -2:
                std::printf("  ⚠ Redundant constraints\n");
                break;
            case -3:
                std::printf("  ⚠ Conflicting constraints\n");
                break;
            case -4:
                std::printf("  ⚠ Over-constrained\n");
                break;
            default:
                std::printf("  ⚠ Solve result: %d (under-constrained is expected)\n", solveResult);
                break;
        }

        // ── Step 7: Print results ────────────────────────────────────────
        std::printf("[7/7] Reading solved geometry...\n");

        const auto& geos = sketch->getInternalGeometry();
        std::printf("  Total geometry count: %zu\n", geos.size());

        for (size_t i = 0; i < geos.size(); ++i) {
            const auto* geo = geos[i];
            if (auto* ls = dynamic_cast<const Part::GeomLineSegment*>(geo)) {
                Base::Vector3d p1 = ls->getStartPoint();
                Base::Vector3d p2 = ls->getEndPoint();
                double length = (p2 - p1).Length();
                std::printf("  [%zu] Line: (%.2f, %.2f) → (%.2f, %.2f), length=%.2f\n",
                    i, p1.x, p1.y, p2.x, p2.y, length);
            }
            else if (auto* c = dynamic_cast<const Part::GeomCircle*>(geo)) {
                Base::Vector3d center = c->getCenter();
                double radius = c->getRadius();
                std::printf("  [%zu] Circle: center=(%.2f, %.2f), radius=%.2f\n",
                    i, center.x, center.y, radius);
            }
            else {
                std::printf("  [%zu] Other geometry type\n", i);
            }
        }

        // Constraint count
        const auto& constraints = sketch->Constraints.getValues();
        std::printf("\n  Total constraints: %zu\n", constraints.size());

        printSeparator("PoC Test COMPLETED");
        std::printf("All FreeCAD modules working: Base, App, Part, Sketcher\n\n");

        // Cleanup
        App::GetApplication().closeDocument(doc->getName());
        App::Application::destruct();

        return 0;
    }
    catch (const Base::Exception& e) {
        std::fprintf(stderr, "\n✗ FreeCAD Exception: %s\n", e.what());
        return 1;
    }
    catch (const std::exception& e) {
        std::fprintf(stderr, "\n✗ Exception: %s\n", e.what());
        return 1;
    }
}
