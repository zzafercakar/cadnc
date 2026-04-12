/**
 * @file BoundingBoxNester.cpp
 * @brief Implementation of the row-based bounding-box nesting algorithm.
 *
 * Parts are expanded by quantity, sorted by descending area, and greedily
 * placed left-to-right in horizontal rows across each available sheet.
 */

#include "BoundingBoxNester.h"

#include <algorithm>

namespace MilCAD {

namespace {

/**
 * @struct PendingPart
 * @brief Internal representation of a single part instance awaiting placement.
 *
 * Created by expanding each NestPart by its quantity. Carries the dimensions
 * and rotation permission needed by the placement loop.
 */
struct PendingPart {
    std::string id;              ///< Part type identifier (from NestPart::id).
    int instanceIndex = 0;       ///< Instance index within the part's quantity.
    double width = 0.0;          ///< Bounding box width.
    double height = 0.0;         ///< Bounding box height.
    bool allowRotation = false;  ///< Whether rotation is permitted for this part.
};

/**
 * @brief Test whether two rectangles overlap, considering a minimum gap.
 * @param a   First rectangle.
 * @param b   Second rectangle.
 * @param gap Minimum required separation between the rectangles.
 * @return True if the rectangles are closer than @p gap in any direction.
 */
bool overlaps(const NestRect &a, const NestRect &b, double gap)
{
    return !(a.x + a.width + gap <= b.x
             || b.x + b.width + gap <= a.x
             || a.y + a.height + gap <= b.y
             || b.y + b.height + gap <= a.y);
}

/**
 * @brief Check whether a rectangle fits entirely within a sheet, respecting edge gaps.
 * @param r       The candidate rectangle.
 * @param sheet   The target sheet.
 * @param edgeGap Minimum distance from the rectangle to any sheet edge.
 * @return True if the rectangle is fully inside the usable area of the sheet.
 */
bool insideSheet(const NestRect &r, const NestSheet &sheet, double edgeGap)
{
    return r.x >= edgeGap
        && r.y >= edgeGap
        && (r.x + r.width) <= (sheet.width - edgeGap)
        && (r.y + r.height) <= (sheet.height - edgeGap);
}

/**
 * @brief Test whether a rectangle overlaps any exclusion zone on a sheet.
 * @param r     The candidate rectangle.
 * @param sheet The sheet whose exclusion zones are checked.
 * @param gap   Minimum clearance from exclusion zone boundaries.
 * @return True if the rectangle conflicts with at least one exclusion zone.
 */
bool intersectsExclusions(const NestRect &r, const NestSheet &sheet, double gap)
{
    for (const auto &z : sheet.exclusionZones) {
        if (!z.isValid())
            continue;
        if (overlaps(r, z, gap))
            return true;
    }
    return false;
}

/**
 * @brief Expand parts by their quantity and sort by descending area.
 *
 * Each NestPart with quantity N produces N PendingPart entries. The result
 * is sorted largest-first so that big parts are placed before small ones,
 * improving packing density.
 *
 * @param job The nesting job whose parts are expanded.
 * @return A sorted vector of individual part instances.
 */
std::vector<PendingPart> expandParts(const NestJob &job)
{
    std::vector<PendingPart> out;
    for (const auto &part : job.parts()) {
        for (int i = 0; i < part.quantity; ++i) {
            PendingPart item;
            item.id = part.id;
            item.instanceIndex = i;
            item.width = part.bounds.width;
            item.height = part.bounds.height;
            item.allowRotation = part.allowRotation;
            out.push_back(item);
        }
    }
    // Sort by area descending so larger parts are placed first
    std::sort(out.begin(), out.end(), [](const PendingPart &a, const PendingPart &b) {
        return (a.width * a.height) > (b.width * b.height);
    });
    return out;
}

} // namespace

/**
 * @brief Run the row-packing nesting algorithm.
 *
 * Algorithm outline:
 *   1. Expand all parts by quantity and sort by descending area.
 *   2. For each sheet, maintain a cursor (cursorX, cursorY) and current row height.
 *   3. For each unplaced part, optionally rotate it to minimize row height,
 *      then attempt to place it at the cursor position.
 *   4. If the part exceeds the sheet width, start a new row.
 *   5. Skip parts that fall outside the sheet or collide with exclusion
 *      zones or already-placed parts.
 *   6. After processing all sheets, collect any remaining unplaced part IDs.
 *
 * @param job The nesting job to execute.
 * @return NestResult with all placements and utilization statistics.
 */
NestResult BoundingBoxNester::run(const NestJob &job) const
{
    NestResult result;
    if (!job.isValid())
        return result;

    const auto items = expandParts(job);
    std::vector<bool> placed(items.size(), false);

    // Accumulate total sheet area for utilization calculation
    for (const auto &sheet : job.sheets())
        result.totalSheetArea += sheet.area();

    // Iterate over each sheet
    for (size_t sidx = 0; sidx < job.sheets().size(); ++sidx) {
        const auto &sheet = job.sheets()[sidx];

        // Row cursor: starts at top-left usable corner
        double cursorX = job.params().edgeGap;
        double cursorY = job.params().edgeGap;
        double rowHeight = 0.0;

        for (size_t i = 0; i < items.size(); ++i) {
            if (placed[i])
                continue;

            double w = items[i].width;
            double h = items[i].height;
            double rotation = 0.0;

            // Optionally rotate to prefer landscape (smaller row height)
            if (job.params().rotationMode != NestRotationMode::None && items[i].allowRotation) {
                if (h > w)
                    std::swap(w, h), rotation = 90.0;
            }

            // Wrap to a new row if the part exceeds the remaining width
            if (cursorX + w > sheet.width - job.params().edgeGap) {
                cursorX = job.params().edgeGap;
                cursorY += rowHeight + job.params().partGap;
                rowHeight = 0.0;
            }

            NestRect candidate{cursorX, cursorY, w, h};

            // Verify the candidate fits within the sheet and avoids exclusion zones
            if (!insideSheet(candidate, sheet, job.params().edgeGap)
                || intersectsExclusions(candidate, sheet, job.params().partGap)) {
                continue;
            }

            // Check for overlap with previously placed parts on this sheet
            bool clash = false;
            for (const auto &pl : result.placements) {
                if (pl.sheetIndex != static_cast<int>(sidx))
                    continue;
                NestRect other{pl.x, pl.y, pl.width, pl.height};
                if (overlaps(candidate, other, job.params().partGap)) {
                    clash = true;
                    break;
                }
            }
            if (clash)
                continue;

            // Place the part and advance the cursor
            result.placements.push_back({
                items[i].id, items[i].instanceIndex, static_cast<int>(sidx),
                candidate.x, candidate.y, candidate.width, candidate.height,
                rotation, false
            });
            result.totalPlacedArea += candidate.area();
            placed[i] = true;

            cursorX += w + job.params().partGap;
            rowHeight = std::max(rowHeight, h);
        }
    }

    // Collect IDs of parts that could not be placed on any sheet
    for (size_t i = 0; i < items.size(); ++i) {
        if (!placed[i])
            result.unplacedPartIds.push_back(items[i].id);
    }

    return result;
}

} // namespace MilCAD
