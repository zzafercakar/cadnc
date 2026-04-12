/**
 * @file NestTypes.h
 * @brief Core data types for the nesting module.
 *
 * Defines the fundamental structures used throughout the nesting subsystem:
 * rectangles, parts, sheets, nesting parameters, placement results, and
 * the overall nesting result container. These types form the data contract
 * between the nesting engine, individual nesting algorithms, and the UI.
 */

#ifndef MILCAD_NEST_TYPES_H
#define MILCAD_NEST_TYPES_H

#include <string>
#include <algorithm>
#include <vector>

namespace MilCAD {

/**
 * @struct NestRect
 * @brief Axis-aligned rectangle used for bounding boxes and placement regions.
 *
 * Represents a 2D rectangle with position (x, y) at the bottom-left corner
 * and dimensions (width, height). Used both for part bounding boxes in local
 * space and for exclusion zones on sheets.
 */
struct NestRect {
    double x = 0.0;      ///< X coordinate of the bottom-left corner.
    double y = 0.0;      ///< Y coordinate of the bottom-left corner.
    double width = 0.0;   ///< Width of the rectangle (must be > 0 to be valid).
    double height = 0.0;  ///< Height of the rectangle (must be > 0 to be valid).

    /**
     * @brief Check whether this rectangle has positive dimensions.
     * @return True if both width and height are strictly positive.
     */
    bool isValid() const { return width > 0.0 && height > 0.0; }

    /**
     * @brief Compute the area of this rectangle.
     * @return The area (width * height), or 0 if the rectangle is invalid.
     */
    double area() const { return (width > 0.0 && height > 0.0) ? width * height : 0.0; }
};

/**
 * @struct NestPart
 * @brief Describes a part to be nested, including its bounding box and placement options.
 *
 * Each NestPart represents a unique part type. The @c quantity field controls
 * how many instances of this part should be placed. Rotation and mirroring
 * permissions are per-part overrides.
 */
struct NestPart {
    std::string id;             ///< Unique identifier for this part type.
    NestRect bounds;            ///< Local-space axis-aligned bounding box.
    int quantity = 1;           ///< Number of instances to place.
    bool allowRotation = true;  ///< Whether the nester may rotate this part.
    bool allowMirror = false;   ///< Whether the nester may mirror this part.

    /**
     * @brief Validate the part definition.
     * @return True if the part has a non-empty id, positive quantity, and valid bounds.
     */
    bool isValid() const
    {
        return !id.empty() && quantity > 0 && bounds.isValid();
    }
};

/**
 * @struct NestSheet
 * @brief Describes a sheet (stock material) onto which parts are nested.
 *
 * Sheets have physical dimensions, an optional material label, and may
 * contain exclusion zones (rectangular regions where parts must not be placed,
 * e.g. clamp locations or pre-existing cuts).
 */
struct NestSheet {
    std::string id;                        ///< Unique identifier for this sheet.
    double width = 0.0;                    ///< Sheet width in working units.
    double height = 0.0;                   ///< Sheet height in working units.
    double thickness = 0.0;                ///< Sheet thickness (informational, not used by nester).
    std::string material;                  ///< Material description (informational).
    std::vector<NestRect> exclusionZones;  ///< Rectangular no-go areas on the sheet.

    /**
     * @brief Validate the sheet definition.
     * @return True if the sheet has a non-empty id and positive dimensions.
     */
    bool isValid() const
    {
        return !id.empty() && width > 0.0 && height > 0.0;
    }

    /**
     * @brief Compute the total area of this sheet.
     * @return The area (width * height), or 0 if dimensions are non-positive.
     */
    double area() const
    {
        return (width > 0.0 && height > 0.0) ? width * height : 0.0;
    }
};

/**
 * @enum NestRotationMode
 * @brief Controls what rotations the nesting algorithm is allowed to apply.
 */
enum class NestRotationMode {
    None,      ///< No rotation allowed; parts keep their original orientation.
    Quadrant,  ///< Only 90-degree rotations (0, 90, 180, 270).
    Free,      ///< Arbitrary rotation angles (not yet implemented by current algorithms).
};

/**
 * @enum NestingAlgorithmKind
 * @brief Public capability-facing algorithm identifiers.
 */
enum class NestingAlgorithmKind {
    BoundingBoxRows,  ///< Row packing using axis-aligned bounding boxes.
    BottomLeftFill,   ///< Bottom-left-fill using axis-aligned bounding boxes.
    TrueShapeNfp,     ///< True-shape no-fit-polygon nesting (not implemented yet).
};

/**
 * @struct CutPathCapabilities
 * @brief Declares which post-nesting cut-path features are actually available.
 */
struct CutPathCapabilities {
    bool cutPathGeneration = false;
    bool commonLine = false;
    bool leadInOut = false;
    bool tabBridge = false;
    bool gcodeExport = false;
};

/**
 * @struct NestingCapabilities
 * @brief Backend truth model exposed to UI and tests.
 *
 * This separates what the backend can really do from what the toolbar might
 * want to present. The recovery plan uses this to keep the Nesting UI honest.
 */
struct NestingCapabilities {
    std::vector<NestingAlgorithmKind> availableAlgorithms;
    CutPathCapabilities cutPath;

    bool optimizationLoop = true;
    bool sheetExclusionZones = true;
    bool dxfExport = true;
    bool remnantTracking = false;
    bool reporting = false;
    bool importProfilesFromSketch = false;
    bool importProfilesFromDxf = false;

    bool supports(NestingAlgorithmKind kind) const
    {
        return std::find(availableAlgorithms.begin(), availableAlgorithms.end(), kind)
               != availableAlgorithms.end();
    }
};

/**
 * @struct NestParams
 * @brief Global parameters that control nesting behavior.
 *
 * These parameters apply to the entire nesting job and override per-part
 * settings where applicable (e.g. rotation mode).
 */
struct NestParams {
    double partGap = 2.0;           ///< Minimum gap between placed parts (mm).
    double edgeGap = 2.0;           ///< Minimum gap between parts and sheet edges (mm).
    NestRotationMode rotationMode = NestRotationMode::Quadrant;  ///< Allowed rotation mode.
    bool allowMirror = false;       ///< Global mirror permission.
    double optimizationSeconds = 0.0;  ///< Time budget for iterative optimization (0 = single pass).

    /**
     * @brief Validate the nesting parameters.
     * @return True if all gap values and the optimization budget are non-negative.
     */
    bool isValid() const
    {
        return partGap >= 0.0 && edgeGap >= 0.0 && optimizationSeconds >= 0.0;
    }
};

/**
 * @struct NestPlacement
 * @brief Describes the placed position and orientation of a single part instance.
 *
 * After nesting, each successfully placed part instance gets a NestPlacement
 * record indicating which sheet it landed on, its position, effective
 * bounding size, rotation, and mirror state.
 */
struct NestPlacement {
    std::string partId;       ///< ID of the parent NestPart.
    int instanceIndex = 0;    ///< Instance index within the part's quantity (0-based).
    int sheetIndex = 0;       ///< Index of the sheet this instance was placed on.

    double x = 0.0;           ///< X coordinate of the placed bottom-left corner.
    double y = 0.0;           ///< Y coordinate of the placed bottom-left corner.
    double width = 0.0;       ///< Effective width after rotation.
    double height = 0.0;      ///< Effective height after rotation.

    double rotationDeg = 0.0; ///< Rotation applied, in degrees.
    bool mirrored = false;    ///< Whether the part was mirrored.

    /**
     * @brief Compute the area occupied by this placement.
     * @return The area (width * height), or 0 if dimensions are non-positive.
     */
    double area() const
    {
        return (width > 0.0 && height > 0.0) ? width * height : 0.0;
    }
};

/**
 * @struct NestResult
 * @brief Aggregated output of a nesting operation.
 *
 * Contains all successful placements, a list of part IDs that could not
 * be placed, and summary statistics for sheet utilization.
 */
struct NestResult {
    std::vector<NestPlacement> placements;      ///< All successfully placed part instances.
    std::vector<std::string> unplacedPartIds;   ///< IDs of parts that could not be placed.

    double totalPlacedArea = 0.0;  ///< Sum of bounding areas of all placed parts.
    double totalSheetArea = 0.0;   ///< Sum of areas of all sheets used.

    /**
     * @brief Compute the sheet utilization ratio.
     * @return Ratio of placed area to total sheet area (0.0 .. 1.0), or 0 if no sheet area.
     */
    double utilization() const
    {
        if (totalSheetArea <= 1e-12)
            return 0.0;
        return totalPlacedArea / totalSheetArea;
    }
};

} // namespace MilCAD

#endif // MILCAD_NEST_TYPES_H
