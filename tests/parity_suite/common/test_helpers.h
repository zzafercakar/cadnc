#pragma once

/**
 * @file test_helpers.h
 * @brief Minimal assertion macros + session fixture for parity tests.
 *
 * Parity tests are plain C++ executables (no GoogleTest dependency).
 * Each test function is `void <name>()` and calls CADNC_TEST_* macros;
 * failures throw std::runtime_error caught by the harness main().
 *
 * Usage:
 *     #include "test_helpers.h"
 *     CADNC_PARITY_TEST(DrawingPointHappyPath) {
 *         auto [session, doc, sketch] = cadnc::test::makeSketchFixture();
 *         int id = sketch->addPoint({0.0, 0.0});
 *         CADNC_TEST_GE(id, 0);
 *     }
 */

#include "CadSession.h"
#include "CadDocument.h"
#include "SketchFacade.h"

#include <cstdio>
#include <memory>
#include <sstream>
#include <stdexcept>
#include <string>
#include <tuple>
#include <vector>

// ── Assertion macros ─────────────────────────────────────────────────

#define CADNC_TEST_FAIL(msg) \
    do { \
        std::ostringstream _oss; _oss << __FILE__ << ":" << __LINE__ << " " << (msg); \
        throw std::runtime_error(_oss.str()); \
    } while (0)

#define CADNC_TEST_TRUE(expr) \
    do { if (!(expr)) CADNC_TEST_FAIL("expected true: " #expr); } while (0)

#define CADNC_TEST_FALSE(expr) \
    do { if (expr) CADNC_TEST_FAIL("expected false: " #expr); } while (0)

#define CADNC_TEST_EQ(a, b) \
    do { if (!((a) == (b))) CADNC_TEST_FAIL("expected equal: " #a " == " #b); } while (0)

#define CADNC_TEST_GE(a, b) \
    do { if (!((a) >= (b))) CADNC_TEST_FAIL("expected " #a " >= " #b); } while (0)

#define CADNC_TEST_NEAR(a, b, tol) \
    do { double _d = (a) - (b); if (_d < 0) _d = -_d; \
         if (_d > (tol)) CADNC_TEST_FAIL("expected " #a " near " #b); } while (0)

#define CADNC_TEST_THROW(expr, ExceptionType) \
    do { bool _caught = false; \
         try { (void)(expr); } \
         catch (const ExceptionType&) { _caught = true; } \
         if (!_caught) CADNC_TEST_FAIL("expected " #ExceptionType " from: " #expr); \
    } while (0)

// ── Test registration ────────────────────────────────────────────────

namespace cadnc::test {

struct TestEntry {
    const char* name;
    void (*fn)();
};

inline std::vector<TestEntry>& registry() {
    static std::vector<TestEntry> r;
    return r;
}

struct Registrar {
    Registrar(const char* n, void (*f)()) { registry().push_back({n, f}); }
};

} // namespace cadnc::test

#define CADNC_PARITY_TEST(Name) \
    static void Name(); \
    static ::cadnc::test::Registrar _reg_##Name(#Name, &Name); \
    static void Name()

// ── Session fixture ──────────────────────────────────────────────────

namespace cadnc::test {

/// Spins up a fresh CadSession + CadDocument + one XY sketch for a test.
struct SketchFixture {
    std::unique_ptr<CADNC::CadSession> session;
    std::shared_ptr<CADNC::CadDocument> doc;
    std::shared_ptr<CADNC::SketchFacade> sketch;
};

inline SketchFixture makeSketchFixture()
{
    SketchFixture fx;
    fx.session = std::make_unique<CADNC::CadSession>();
    static int dummy_argc = 0;
    static char* dummy_argv[1] = { nullptr };
    fx.session->initialize(dummy_argc, dummy_argv);
    fx.doc = fx.session->newDocument("Test");
    fx.sketch = fx.doc->addSketch("Sketch", /*planeType=*/0);
    return fx;
}

// ── Harness entry ────────────────────────────────────────────────────

inline int runAll()
{
    int failed = 0;
    for (const auto& t : registry()) {
        try {
            t.fn();
            std::printf("[  PASS  ] %s\n", t.name);
        } catch (const std::exception& e) {
            std::printf("[  FAIL  ] %s — %s\n", t.name, e.what());
            ++failed;
        }
    }
    std::printf("%d/%zu tests passed\n",
                int(registry().size()) - failed, registry().size());
    return failed == 0 ? 0 : 1;
}

} // namespace cadnc::test

#define CADNC_PARITY_MAIN() \
    int main() { return ::cadnc::test::runAll(); }
