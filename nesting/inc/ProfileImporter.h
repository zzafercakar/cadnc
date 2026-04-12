/**
 * @file ProfileImporter.h
 * @brief Imports sketch profiles and part faces into NestPart for nesting.
 */

#ifndef MILCAD_PROFILE_IMPORTER_H
#define MILCAD_PROFILE_IMPORTER_H

#include "NestTypes.h"

#include <TopoDS_Shape.hxx>

#include <vector>

namespace MilCAD {

class SketchDocument;

/// Extracts nestable parts from sketch profiles and part geometry.
class ProfileImporter
{
public:
    /// Extract NestParts from a sketch document.
    /// Each closed wire in the sketch becomes a NestPart.
    /// Open profiles are ignored (not nestable).
    static std::vector<NestPart> fromSketch(const SketchDocument &doc);

    /// Extract NestParts from a 3D part shape.
    /// Each planar face in the shape becomes a NestPart (for sheet metal).
    static std::vector<NestPart> fromPartFaces(const TopoDS_Shape &shape);
};

} // namespace MilCAD

#endif // MILCAD_PROFILE_IMPORTER_H
