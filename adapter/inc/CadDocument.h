#pragma once

/**
 * @file CadDocument.h
 * @brief Wrapper around FreeCAD App::Document.
 *
 * Provides a clean interface for document operations without exposing
 * FreeCAD types to the UI layer.
 */

#include <string>

namespace CADNC {

class CadDocument {
public:
    CadDocument();
    ~CadDocument();

    // Create a new empty document
    bool create(const std::string& name = "Untitled");

    // Save/Load
    bool save(const std::string& path);
    bool load(const std::string& path);

    // Feature tree queries
    // TODO: getFeatureCount(), getFeatureName(), etc.

private:
    // TODO: FreeCAD App::Document* doc_ = nullptr;
};

} // namespace CADNC
