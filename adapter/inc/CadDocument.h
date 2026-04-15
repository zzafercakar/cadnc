#pragma once

/**
 * @file CadDocument.h
 * @brief Wrapper around FreeCAD App::Document.
 *
 * Provides a clean interface for document operations without exposing
 * FreeCAD types to the UI layer. All FreeCAD interactions go through
 * opaque pointers resolved in the .cpp file.
 */

#include <memory>
#include <string>
#include <vector>

namespace CADNC {

class SketchFacade;
class PartFacade;

/// Minimal info about a feature in the document tree
struct FeatureInfo {
    std::string name;       // internal name (e.g. "Sketch001")
    std::string label;      // user-visible label
    std::string typeName;   // e.g. "Sketcher::SketchObject"
};

class CadDocument {
public:
    /// Create a new FreeCAD document with the given name
    explicit CadDocument(const std::string& name);
    ~CadDocument();

    // non-copyable
    CadDocument(const CadDocument&) = delete;
    CadDocument& operator=(const CadDocument&) = delete;

    /// Document name (internal)
    std::string name() const;

    // ── Persistence ─────────────────────────────────────────────────
    bool save(const std::string& path);
    bool load(const std::string& path);

    // ── Feature tree ────────────────────────────────────────────────
    std::vector<FeatureInfo> featureTree() const;
    int featureCount() const;

    // ── Undo / Redo ─────────────────────────────────────────────────
    void undo();
    void redo();
    bool canUndo() const;
    bool canRedo() const;

    // ── Sketch operations ───────────────────────────────────────────
    /// Add a new sketch on the XY plane and return a facade to operate on it
    std::shared_ptr<SketchFacade> addSketch(const std::string& name = "Sketch");

    /// Get a facade for an existing sketch by name
    std::shared_ptr<SketchFacade> getSketch(const std::string& name);

    // ── Part operations ─────────────────────────────────────────────
    /// Get a facade for PartDesign operations on this document
    std::shared_ptr<PartFacade> partDesign();

    // ── Recompute ───────────────────────────────────────────────────
    void recompute();

private:
    struct Impl;
    std::unique_ptr<Impl> impl_;
};

} // namespace CADNC
