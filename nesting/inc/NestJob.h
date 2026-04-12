/**
 * @file NestJob.h
 * @brief Definition of the NestJob class that aggregates parts, sheets, and parameters for a nesting run.
 *
 * A NestJob is the primary input container for the nesting engine. It holds
 * the list of parts to nest, the available sheets, the nesting parameters,
 * and (after execution) the resulting placements.
 */

#ifndef MILCAD_NEST_JOB_H
#define MILCAD_NEST_JOB_H

#include "NestTypes.h"

#include <vector>

namespace MilCAD {

/**
 * @class NestJob
 * @brief Encapsulates all inputs and outputs for a single nesting operation.
 *
 * Clients populate the job with parts and sheets, configure parameters,
 * then pass it to a NestingEngine. After execution the engine stores the
 * result back into the job via setResult().
 */
class NestJob
{
public:
    /**
     * @brief Reset the job to its initial empty state.
     *
     * Clears all parts, sheets, parameters, and any previous result.
     */
    void clear();

    /**
     * @brief Add a part definition to the job.
     * @param part The part to add. Must pass NestPart::isValid().
     * @return True if the part was valid and added; false otherwise.
     */
    bool addPart(const NestPart &part);

    /**
     * @brief Add a sheet definition to the job.
     * @param sheet The sheet to add. Must pass NestSheet::isValid().
     * @return True if the sheet was valid and added; false otherwise.
     */
    bool addSheet(const NestSheet &sheet);

    /// @brief Read-only access to the parts list.
    const std::vector<NestPart> &parts() const { return parts_; }

    /// @brief Read-only access to the sheets list.
    const std::vector<NestSheet> &sheets() const { return sheets_; }

    /// @brief Mutable access to the parts list.
    std::vector<NestPart> &parts() { return parts_; }

    /// @brief Mutable access to the sheets list.
    std::vector<NestSheet> &sheets() { return sheets_; }

    /// @brief Mutable access to nesting parameters.
    NestParams &params() { return params_; }

    /// @brief Read-only access to nesting parameters.
    const NestParams &params() const { return params_; }

    /**
     * @brief Store the nesting result produced by an algorithm.
     * @param result The result to store (moved in).
     */
    void setResult(NestResult result) { result_ = std::move(result); }

    /// @brief Read-only access to the stored nesting result.
    const NestResult &result() const { return result_; }

    /**
     * @brief Validate the entire job.
     *
     * A job is valid when it has valid parameters, at least one valid part,
     * and at least one valid sheet.
     *
     * @return True if the job is ready to be executed.
     */
    bool isValid() const;

private:
    std::vector<NestPart> parts_;   ///< Parts to be nested.
    std::vector<NestSheet> sheets_; ///< Available sheets.
    NestParams params_;             ///< Nesting parameters.
    NestResult result_;             ///< Stored result from the last run.
};

} // namespace MilCAD

#endif // MILCAD_NEST_JOB_H
