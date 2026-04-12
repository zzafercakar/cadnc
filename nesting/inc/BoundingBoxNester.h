/**
 * @file BoundingBoxNester.h
 * @brief Row-based bounding-box nesting algorithm.
 *
 * Implements a simple greedy row-packing strategy: parts are sorted by
 * area (largest first), then placed left-to-right in rows. When a part
 * does not fit in the current row, a new row is started below. This is
 * fast but may leave gaps between parts of different heights.
 */

#ifndef MILCAD_BOUNDING_BOX_NESTER_H
#define MILCAD_BOUNDING_BOX_NESTER_H

#include "NestJob.h"

namespace MilCAD {

/**
 * @class BoundingBoxNester
 * @brief Simple row-packing nester using part bounding boxes only.
 *
 * Parts are expanded by quantity, sorted by descending area, and greedily
 * placed into rows across each sheet. Rotation (90 degrees) is applied
 * when allowed, preferring the orientation that minimizes row height.
 */
class BoundingBoxNester
{
public:
    /**
     * @brief Run the row-packing algorithm on the given nesting job.
     * @param job A valid NestJob with parts, sheets, and parameters.
     * @return NestResult containing placements and utilization statistics.
     *         Returns an empty result if the job is invalid.
     */
    NestResult run(const NestJob &job) const;
};

} // namespace MilCAD

#endif // MILCAD_BOUNDING_BOX_NESTER_H
