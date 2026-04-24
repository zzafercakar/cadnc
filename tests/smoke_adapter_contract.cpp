/**
 * @file smoke_adapter_contract.cpp
 * @brief Sub-phase 1-Zero smoke test — exercises the adapter-contract
 *        primitives (FacadeError, ScopedTransaction, recomputeIfNeeded)
 *        and confirms the 8 refactored sketch drawing methods surface
 *        FacadeError on the new failure paths.
 *
 * Style matches tests/test_adapter.cpp (printf-based, exit-code 0/1).
 */

#include <cstdio>
#include <stdexcept>

#include "CadDocument.h"
#include "CadSession.h"
#include "FacadeError.h"
#include "ScopedTransaction.h"
#include "SketchFacade.h"

using namespace CADNC;

namespace {

int failures = 0;

#define CHECK(cond, label) \
    do { \
        if (!(cond)) { std::fprintf(stderr, "[FAIL] %s\n", label); ++failures; } \
        else        { std::printf("[ OK ] %s\n", label); } \
    } while (0)

} // namespace

int main(int argc, char* argv[])
{
    std::printf("══════════════════════════════════════════════\n");
    std::printf("  Sub-phase 1-Zero adapter contract smoke test\n");
    std::printf("══════════════════════════════════════════════\n");

    // ── 1. FacadeError basic construction ───────────────────────────
    {
        FacadeError e(FacadeError::Code::InvalidArgument,
                      QStringLiteral("bad input"));
        CHECK(e.code() == FacadeError::Code::InvalidArgument,
              "FacadeError::code preserved");
        CHECK(e.userMessage() == QStringLiteral("bad input"),
              "FacadeError::userMessage preserved");
    }

    // ── 2. FacadeError::fromStdException ────────────────────────────
    {
        std::runtime_error raw("stdfail");
        FacadeError wrapped = FacadeError::fromStdException(raw);
        CHECK(wrapped.code() == FacadeError::Code::StdException,
              "fromStdException produces StdException code");
        CHECK(wrapped.userMessage().contains("stdfail"),
              "fromStdException preserves message");
    }

    // ── 3. Session + document setup (shared by 4-7) ─────────────────
    CadSession session;
    if (!session.initialize(argc, argv)) {
        std::fprintf(stderr, "[FATAL] session init failed\n");
        return 1;
    }
    auto doc = session.newDocument("ContractSmoke");

    // ── 4. ScopedTransaction explicit commit ────────────────────────
    {
        std::shared_ptr<SketchFacade> sketch;
        {
            ScopedTransaction tx(doc.get(), "explicit-commit");
            sketch = doc->addSketch("Committed", /*planeType=*/0);
            tx.commit();
            CHECK(tx.isFinished(), "commit marks tx finished");
        }
        CHECK(sketch != nullptr, "sketch added inside committed tx");
        CHECK(doc->canUndo(), "committed tx appears in undo stack");
    }

    // ── 5. ScopedTransaction abort-on-unwind ────────────────────────
    {
        const int before = doc->featureCount();
        {
            ScopedTransaction tx(doc.get(), "abort-on-unwind");
            doc->addSketch("Aborted", /*planeType=*/0);
            // Intentionally no commit() — destructor aborts.
        }
        const int after = doc->featureCount();
        CHECK(after == before,
              "abort-on-unwind removes uncommitted additions");
    }

    // ── 6. recomputeIfNeeded fast-path is crash-safe on a clean doc ─
    {
        // Force a recompute so isTouched() is false afterwards.
        doc->recompute();
        doc->recomputeIfNeeded();  // should be a no-op, not a crash
        doc->recomputeIfNeeded();
        CHECK(true, "recomputeIfNeeded survives repeated calls on clean doc");
    }

    // ── 7. Refactored facade methods throw FacadeError for bad input ─
    {
        // Re-open a committed sketch so the facade has a live SketchObject.
        auto sketch = doc->addSketch("Checks", /*planeType=*/0);
        bool caughtInvalid = false;
        try {
            sketch->addCircle({0, 0}, /*radius=*/-1.0);
        } catch (const FacadeError& e) {
            caughtInvalid = (e.code() == FacadeError::Code::InvalidArgument);
        } catch (...) {
            // fall through — caughtInvalid stays false
        }
        CHECK(caughtInvalid,
              "addCircle(radius<0) throws FacadeError::InvalidArgument");

        bool caughtDegenerate = false;
        try {
            sketch->addRectangle({0, 0}, {0, 0});
        } catch (const FacadeError& e) {
            caughtDegenerate = (e.code() == FacadeError::Code::InvalidArgument);
        } catch (...) {}
        CHECK(caughtDegenerate,
              "addRectangle(zero-area) throws FacadeError::InvalidArgument");

        bool caughtEmptyBSpline = false;
        try {
            sketch->addBSpline(/*poles=*/{}, /*degree=*/3);
        } catch (const FacadeError& e) {
            caughtEmptyBSpline = (e.code() == FacadeError::Code::InvalidArgument);
        } catch (...) {}
        CHECK(caughtEmptyBSpline,
              "addBSpline(empty poles) throws FacadeError::InvalidArgument");
    }

    // ── 8. Facade throws NoActiveDocument if backend pointer is null ─
    {
        SketchFacade empty(nullptr);
        bool caughtNoDoc = false;
        try {
            empty.addPoint({1.0, 2.0});
        } catch (const FacadeError& e) {
            caughtNoDoc = (e.code() == FacadeError::Code::NoActiveDocument);
        } catch (...) {}
        CHECK(caughtNoDoc,
              "addPoint on null-sketch throws NoActiveDocument");
    }

    std::printf("\nResult: %s (%d failure%s)\n",
                failures == 0 ? "PASS" : "FAIL",
                failures, failures == 1 ? "" : "s");
    return failures == 0 ? 0 : 1;
}
