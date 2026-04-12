/**
 * @file NestingEngine.h
 * @brief High-level nesting engine that dispatches to concrete algorithm implementations.
 *
 * The NestingEngine is the main entry point for running a nesting operation.
 * It accepts a NestJob and an algorithm selector, then delegates to the
 * appropriate algorithm class (BoundingBoxNester or BottomLeftFillNester).
 */

#ifndef MILCAD_NESTING_ENGINE_H
#define MILCAD_NESTING_ENGINE_H

#include "NestJob.h"

namespace MilCAD {

/**
 * @enum NestingAlgorithm
 * @brief Selects which nesting algorithm the engine should use.
 */
enum class NestingAlgorithm {
    BoundingBoxRows,  ///< Simple row-based packing using bounding boxes.
    BottomLeftFill,   ///< Bottom-left-fill heuristic for tighter packing.
};

/**
 * @class NestingEngine
 * @brief Facade that runs a nesting job using a selected algorithm.
 *
 * Usage:
 * @code
 *   NestJob job;
 *   // ... populate job with parts, sheets, params ...
 *   NestingEngine engine;
 *   NestResult result = engine.run(job, NestingAlgorithm::BottomLeftFill);
 * @endcode
 */
class NestingEngine
{
public:
    /// @return Backend truth about currently implemented nesting capabilities.
    NestingCapabilities capabilities() const;

    /**
     * @brief Execute a nesting operation on the given job.
     * @param job       The nesting job containing parts, sheets, and parameters.
     * @param algorithm The algorithm to use (defaults to BottomLeftFill).
     * @return A NestResult with placements, unplaced parts, and utilization stats.
     */
    NestResult run(const NestJob &job, NestingAlgorithm algorithm = NestingAlgorithm::BottomLeftFill) const;
};

} // namespace MilCAD

#endif // MILCAD_NESTING_ENGINE_H
