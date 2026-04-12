/**
 * @file NestJob.cpp
 * @brief Implementation of the NestJob class.
 *
 * Provides part/sheet management, validation, and state reset for a
 * nesting job container.
 */

#include "NestJob.h"

namespace MilCAD {

/**
 * @brief Reset the job to its initial empty state.
 *
 * Clears all parts, sheets, resets parameters to defaults, and discards
 * any stored result from a previous nesting run.
 */
void NestJob::clear()
{
    parts_.clear();
    sheets_.clear();
    result_ = {};
    params_ = {};
}

/**
 * @brief Add a part to the job after validation.
 * @param part The part definition to add.
 * @return True if the part passed validation and was appended; false if rejected.
 */
bool NestJob::addPart(const NestPart &part)
{
    // Reject invalid parts (empty id, non-positive quantity, or bad bounds)
    if (!part.isValid())
        return false;
    parts_.push_back(part);
    return true;
}

/**
 * @brief Add a sheet to the job after validation.
 * @param sheet The sheet definition to add.
 * @return True if the sheet passed validation and was appended; false if rejected.
 */
bool NestJob::addSheet(const NestSheet &sheet)
{
    // Reject invalid sheets (empty id or non-positive dimensions)
    if (!sheet.isValid())
        return false;
    sheets_.push_back(sheet);
    return true;
}

/**
 * @brief Validate the entire job for execution readiness.
 *
 * Checks that parameters are valid, there is at least one part and one sheet,
 * and every individual part and sheet passes its own validation.
 *
 * @return True if the job can be safely passed to a nesting engine.
 */
bool NestJob::isValid() const
{
    // Must have valid params and at least one part and one sheet
    if (!params_.isValid() || parts_.empty() || sheets_.empty())
        return false;

    // Every part must individually be valid
    for (const auto &p : parts_) {
        if (!p.isValid())
            return false;
    }

    // Every sheet must individually be valid
    for (const auto &s : sheets_) {
        if (!s.isValid())
            return false;
    }
    return true;
}

} // namespace MilCAD
