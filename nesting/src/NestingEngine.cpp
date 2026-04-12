/**
 * @file NestingEngine.cpp
 * @brief Implementation of the NestingEngine facade with iterative optimization.
 *
 * Dispatches nesting jobs to the selected algorithm implementation. When
 * optimizationSeconds > 0, runs multiple passes with randomized part ordering
 * to find the best placement (highest utilization), similar to professional
 * nesting software optimization behavior.
 */

#include "NestingEngine.h"

#include "BottomLeftFillNester.h"
#include "BoundingBoxNester.h"

#include <algorithm>
#include <chrono>
#include <random>

namespace MilCAD {

NestingCapabilities NestingEngine::capabilities() const
{
    NestingCapabilities caps;
    caps.availableAlgorithms = {
        NestingAlgorithmKind::BoundingBoxRows,
        NestingAlgorithmKind::BottomLeftFill,
    };
    caps.optimizationLoop = true;
    caps.sheetExclusionZones = true;
    caps.dxfExport = true;
    caps.remnantTracking = false;
    caps.reporting = false;
    caps.importProfilesFromSketch = false;
    caps.importProfilesFromDxf = false;
    caps.cutPath = {};
    return caps;
}

/**
 * @brief Execute a nesting operation using the specified algorithm.
 *
 * If the job's optimizationSeconds parameter is > 0, the engine runs
 * multiple passes within the time budget, shuffling part order each time
 * and keeping the result with the highest utilization ratio. This
 * implements a simple stochastic optimization approach.
 *
 * @param job       The nesting job (parts, sheets, parameters).
 * @param algorithm Which packing algorithm to use.
 * @return The best nesting result found within the time budget.
 */
NestResult NestingEngine::run(const NestJob &job, NestingAlgorithm algorithm) const
{
    // Single-pass execution (no optimization budget)
    const auto runOnce = [&](const NestJob &j) -> NestResult {
        switch (algorithm) {
        case NestingAlgorithm::BoundingBoxRows: {
            BoundingBoxNester nester;
            return nester.run(j);
        }
        case NestingAlgorithm::BottomLeftFill:
        default: {
            BottomLeftFillNester nester;
            return nester.run(j);
        }
        }
    };

    // First pass with original part order
    NestResult bestResult = runOnce(job);

    // If no optimization budget, return the single-pass result
    if (job.params().optimizationSeconds <= 1e-9)
        return bestResult;

    // Iterative optimization: run multiple passes with shuffled part order
    const auto startTime = std::chrono::steady_clock::now();
    const auto budget = std::chrono::duration<double>(job.params().optimizationSeconds);

    std::mt19937 rng(42); // Deterministic seed for reproducibility
    int passCount = 0;

    while (true) {
        // Check time budget
        const auto elapsed = std::chrono::steady_clock::now() - startTime;
        if (elapsed >= budget)
            break;

        // Create a job copy with shuffled part order
        NestJob shuffledJob;
        auto parts = job.parts();
        std::shuffle(parts.begin(), parts.end(), rng);

        // Rebuild job with shuffled parts, same sheets and params
        shuffledJob.params() = job.params();
        for (const auto &part : parts)
            shuffledJob.addPart(part);
        for (const auto &sheet : job.sheets())
            shuffledJob.addSheet(sheet);

        // Run the nesting with shuffled order
        NestResult candidate = runOnce(shuffledJob);

        // Keep the result with the highest utilization (fewer unplaced parts)
        const bool betterUtilization = candidate.utilization() > bestResult.utilization();
        const bool fewerUnplaced = candidate.unplacedPartIds.size() < bestResult.unplacedPartIds.size();

        if (fewerUnplaced || (candidate.unplacedPartIds.size() == bestResult.unplacedPartIds.size() && betterUtilization))
            bestResult = candidate;

        ++passCount;
    }

    return bestResult;
}

} // namespace MilCAD
