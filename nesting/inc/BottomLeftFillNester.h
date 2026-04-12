/**
 * @file BottomLeftFillNester.h
 * @brief Bottom-left-fill nesting algorithm for axis-aligned rectangles.
 *
 * Implements the bottom-left-fill (BLF) heuristic: for each part, the
 * algorithm finds the lowest available Y position, breaking ties by
 * choosing the leftmost X. Candidate positions are generated from sheet
 * edges, exclusion zone boundaries, and the edges of already-placed parts,
 * yielding tighter packing than simple row-based approaches.
 */

#ifndef MILCAD_BOTTOM_LEFT_FILL_NESTER_H
#define MILCAD_BOTTOM_LEFT_FILL_NESTER_H

#include "NestJob.h"

namespace MilCAD {

/**
 * @class BottomLeftFillNester
 * @brief Bottom-left-fill packing for axis-aligned rectangles.
 *
 * Parts are expanded by quantity, sorted by descending area, and placed
 * one-by-one at the bottom-left-most valid position on each sheet. The
 * candidate position grid grows dynamically as parts are placed.
 */
class BottomLeftFillNester
{
public:
    /**
     * @brief Run the bottom-left-fill algorithm on the given nesting job.
     * @param job A valid NestJob with parts, sheets, and parameters.
     * @return NestResult containing placements and utilization statistics.
     *         Returns an empty result if the job is invalid.
     */
    NestResult run(const NestJob &job) const;
};

} // namespace MilCAD

#endif // MILCAD_BOTTOM_LEFT_FILL_NESTER_H
