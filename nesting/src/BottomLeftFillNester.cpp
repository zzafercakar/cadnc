/**
 * @file BottomLeftFillNester.cpp
 * @brief Implementation of the bottom-left-fill nesting algorithm.
 *
 * Uses a candidate-position grid approach: potential placement positions
 * are derived from sheet edges, exclusion zone boundaries, and the edges
 * of already-placed parts. Supports quadrant rotation (0/90/180/270),
 * free rotation (configurable step), mirror enforcement, and multi-sheet
 * overflow for professional nesting results.
 */

#include "BottomLeftFillNester.h"

#include <algorithm>
#include <cmath>

namespace MilCAD {

namespace {

constexpr double kPi = 3.14159265358979323846;

/// Angular step for free rotation mode (degrees)
constexpr double kFreeRotationStep = 15.0;

/**
 * @struct PendingPart
 * @brief Internal representation of a single part instance awaiting placement.
 */
struct PendingPart {
    std::string id;              ///< Part type identifier.
    int instanceIndex = 0;       ///< Instance index within the part's quantity.
    double width = 0.0;          ///< Bounding box width.
    double height = 0.0;         ///< Bounding box height.
    bool allowRotation = false;  ///< Whether rotation is permitted.
    bool allowMirror = false;    ///< Whether mirroring is permitted.
};

/**
 * @brief Test whether two rectangles overlap, considering a minimum gap.
 */
bool overlaps(const NestRect &a, const NestRect &b, double gap)
{
    return !(a.x + a.width + gap <= b.x
             || b.x + b.width + gap <= a.x
             || a.y + a.height + gap <= b.y
             || b.y + b.height + gap <= a.y);
}

/**
 * @brief Check whether a rectangle fits within the usable area of a sheet.
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
 * @brief Check whether a candidate rectangle can be placed without conflicts.
 */
bool canPlace(const NestRect &candidate,
              const NestSheet &sheet,
              const std::vector<NestPlacement> &placed,
              int sheetIndex,
              double partGap,
              double edgeGap)
{
    if (!insideSheet(candidate, sheet, edgeGap))
        return false;
    if (intersectsExclusions(candidate, sheet, partGap))
        return false;

    for (const auto &pl : placed) {
        if (pl.sheetIndex != sheetIndex)
            continue;
        NestRect other{pl.x, pl.y, pl.width, pl.height};
        if (overlaps(candidate, other, partGap))
            return false;
    }
    return true;
}

/**
 * @brief Compute the rotated bounding box dimensions at a given angle.
 * @param w      Original width.
 * @param h      Original height.
 * @param angDeg Rotation angle in degrees.
 * @param outW   Output rotated bounding width.
 * @param outH   Output rotated bounding height.
 */
void rotatedBounds(double w, double h, double angDeg, double &outW, double &outH)
{
    const double rad = angDeg * kPi / 180.0;
    const double cosA = std::abs(std::cos(rad));
    const double sinA = std::abs(std::sin(rad));
    outW = w * cosA + h * sinA;
    outH = w * sinA + h * cosA;
}

/**
 * @brief Expand parts by their quantity and sort by descending area.
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
            item.allowMirror = part.allowMirror;
            out.push_back(item);
        }
    }
    // Sort by area descending so larger parts are placed first
    std::sort(out.begin(), out.end(), [](const PendingPart &a, const PendingPart &b) {
        return (a.width * a.height) > (b.width * b.height);
    });
    return out;
}

/**
 * @brief Build the list of rotation angles to try based on the rotation mode.
 * @param mode            The global rotation mode.
 * @param allowRotation   Whether this specific part allows rotation.
 * @return Vector of angles in degrees to attempt.
 */
std::vector<double> getRotationAngles(NestRotationMode mode, bool allowRotation)
{
    if (!allowRotation || mode == NestRotationMode::None)
        return {0.0};

    if (mode == NestRotationMode::Quadrant)
        return {0.0, 90.0, 180.0, 270.0};

    // Free rotation: try angles from 0 to 345 in kFreeRotationStep increments
    std::vector<double> angles;
    for (double a = 0.0; a < 360.0 - 0.1; a += kFreeRotationStep)
        angles.push_back(a);
    return angles;
}

} // anonymous namespace

/**
 * @brief Run the bottom-left-fill nesting algorithm with professional features.
 *
 * Improvements over basic BLF:
 * - Quadrant AND free rotation support (0/15/30/.../345 degree steps)
 * - Mirror enforcement (try both original and mirrored bounding boxes)
 * - Multi-sheet overflow (parts that don't fit on one sheet try the next)
 * - Candidate position grid dynamically expanded from placed parts
 *
 * @param job The nesting job to execute.
 * @return NestResult with all placements and utilization statistics.
 */
NestResult BottomLeftFillNester::run(const NestJob &job) const
{
    NestResult result;
    if (!job.isValid())
        return result;

    const auto items = expandParts(job);
    std::vector<bool> placed(items.size(), false);

    // Accumulate total sheet area for utilization calculation
    for (const auto &sheet : job.sheets())
        result.totalSheetArea += sheet.area();

    // Process each sheet — parts that don't fit overflow to the next sheet
    for (size_t sidx = 0; sidx < job.sheets().size(); ++sidx) {
        const auto &sheet = job.sheets()[sidx];

        // Initialize candidate coordinate lists with the edge gap origin
        std::vector<double> xCandidates = {job.params().edgeGap};
        std::vector<double> yCandidates = {job.params().edgeGap};

        // Add candidate positions from exclusion zone boundaries
        for (const auto &zone : sheet.exclusionZones) {
            if (!zone.isValid())
                continue;
            xCandidates.push_back(zone.x + zone.width + job.params().partGap);
            yCandidates.push_back(zone.y + zone.height + job.params().partGap);
        }

        std::sort(xCandidates.begin(), xCandidates.end());
        std::sort(yCandidates.begin(), yCandidates.end());
        xCandidates.erase(std::unique(xCandidates.begin(), xCandidates.end()), xCandidates.end());
        yCandidates.erase(std::unique(yCandidates.begin(), yCandidates.end()), yCandidates.end());

        for (size_t i = 0; i < items.size(); ++i) {
            if (placed[i])
                continue;

            /// Tracks the best valid placement found for the current part.
            struct CandidatePlacement {
                bool found = false;
                NestRect rect;
                double rotation = 0.0;
                bool mirrored = false;
            } best;

            // Get the list of rotation angles to try
            const auto angles = getRotationAngles(job.params().rotationMode,
                                                   items[i].allowRotation);

            // Determine mirror variants to try
            const bool tryMirror = job.params().allowMirror && items[i].allowMirror;

            /**
             * @brief Try placing a part at every candidate position with given dimensions.
             */
            const auto tryOrientation = [&](double w, double h, double rotDeg, bool mirror) {
                for (double y : yCandidates) {
                    for (double x : xCandidates) {
                        NestRect cand{x, y, w, h};
                        if (!canPlace(cand, sheet, result.placements, static_cast<int>(sidx),
                                      job.params().partGap, job.params().edgeGap)) {
                            continue;
                        }
                        // Select bottom-most; break ties by left-most
                        if (!best.found
                            || cand.y < best.rect.y
                            || (cand.y == best.rect.y && cand.x < best.rect.x)) {
                            best.found = true;
                            best.rect = cand;
                            best.rotation = rotDeg;
                            best.mirrored = mirror;
                        }
                    }
                }
            };

            // Try each rotation angle (quadrant or free)
            for (double angle : angles) {
                double rw, rh;
                rotatedBounds(items[i].width, items[i].height, angle, rw, rh);
                tryOrientation(rw, rh, angle, false);

                // Try mirrored version (swap width/height and mark mirrored)
                if (tryMirror) {
                    rotatedBounds(items[i].height, items[i].width, angle, rw, rh);
                    tryOrientation(rw, rh, angle, true);
                }
            }

            if (!best.found)
                continue; // Will overflow to the next sheet

            // Record the placement
            result.placements.push_back({
                items[i].id, items[i].instanceIndex, static_cast<int>(sidx),
                best.rect.x, best.rect.y, best.rect.width, best.rect.height,
                best.rotation, best.mirrored
            });
            result.totalPlacedArea += best.rect.area();
            placed[i] = true;

            // Add new candidate positions from the placed part's edges
            xCandidates.push_back(best.rect.x + best.rect.width + job.params().partGap);
            yCandidates.push_back(best.rect.y + best.rect.height + job.params().partGap);

            std::sort(xCandidates.begin(), xCandidates.end());
            std::sort(yCandidates.begin(), yCandidates.end());
            xCandidates.erase(std::unique(xCandidates.begin(), xCandidates.end()), xCandidates.end());
            yCandidates.erase(std::unique(yCandidates.begin(), yCandidates.end()), yCandidates.end());
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
