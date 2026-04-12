/**
 * @file ProfileImporter.cpp
 * @brief Implementation of sketch/part profile import for nesting.
 */

#include "ProfileImporter.h"
#include "SketchDocument.h"
#include "SketchEntity.h"

#include <Bnd_Box.hxx>
#include <BRepBndLib.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Wire.hxx>

namespace MilCAD {

std::vector<NestPart> ProfileImporter::fromSketch(const SketchDocument &doc)
{
    std::vector<NestPart> parts;

    // Strategy 1: intrinsically closed entities (Circle, Rectangle, Polygon, Ellipse)
    for (const auto &eid : doc.entityIds()) {
        auto *ent = doc.entity(eid);
        if (!ent || ent->isConstruction())
            continue;

        auto type = ent->type();
        bool isClosed = (type == SketchEntityType::Circle
                      || type == SketchEntityType::Rectangle
                      || type == SketchEntityType::Polygon
                      || type == SketchEntityType::Ellipse);
        if (!isClosed)
            continue;

        TopoDS_Wire wire = ent->toWire();
        TopoDS_Edge edge = ent->toEdge();
        TopoDS_Shape shape = wire.IsNull() ? TopoDS_Shape(edge) : TopoDS_Shape(wire);
        if (shape.IsNull())
            continue;

        // Compute bounding box
        Bnd_Box bbox;
        BRepBndLib::Add(shape, bbox);
        if (bbox.IsVoid())
            continue;

        double xmin, ymin, zmin, xmax, ymax, zmax;
        bbox.Get(xmin, ymin, zmin, xmax, ymax, zmax);

        NestPart part;
        part.id = "sketch_" + eid;
        part.bounds.width = xmax - xmin;
        part.bounds.height = ymax - ymin;
        part.quantity = 1;
        parts.push_back(std::move(part));
    }

    // Strategy 2: try to build a closed wire from connected lines/arcs
    std::vector<TopoDS_Edge> freeEdges;
    for (const auto &eid : doc.entityIds()) {
        auto *ent = doc.entity(eid);
        if (!ent || ent->isConstruction())
            continue;

        auto type = ent->type();
        if (type == SketchEntityType::Line || type == SketchEntityType::Arc) {
            auto edge = ent->toEdge();
            if (!edge.IsNull())
                freeEdges.push_back(edge);
        }
    }

    if (freeEdges.size() >= 3) {
        try {
            BRepBuilderAPI_MakeWire wireMaker;
            for (const auto &e : freeEdges)
                wireMaker.Add(e);

            if (wireMaker.IsDone()) {
                TopoDS_Wire wire = wireMaker.Wire();
                if (wire.Closed()) {
                    Bnd_Box bbox;
                    BRepBndLib::Add(wire, bbox);
                    if (!bbox.IsVoid()) {
                        double xmin, ymin, zmin, xmax, ymax, zmax;
                        bbox.Get(xmin, ymin, zmin, xmax, ymax, zmax);

                        NestPart part;
                        part.id = "sketch_wire_0";
                        part.bounds.width = xmax - xmin;
                        part.bounds.height = ymax - ymin;
                        part.quantity = 1;
                        parts.push_back(std::move(part));
                    }
                }
            }
        } catch (...) {}
    }

    return parts;
}

std::vector<NestPart> ProfileImporter::fromPartFaces(const TopoDS_Shape &shape)
{
    std::vector<NestPart> parts;

    if (shape.IsNull())
        return parts;

    // Extract planar faces from the shape
    for (TopExp_Explorer ex(shape, TopAbs_FACE); ex.More(); ex.Next()) {
        const TopoDS_Face &face = TopoDS::Face(ex.Current());

        Bnd_Box bbox;
        BRepBndLib::Add(face, bbox);
        if (bbox.IsVoid())
            continue;

        double xmin, ymin, zmin, xmax, ymax, zmax;
        bbox.Get(xmin, ymin, zmin, xmax, ymax, zmax);

        // Only consider faces with significant area (not slivers)
        double width = xmax - xmin;
        double height = ymax - ymin;
        if (width < 0.1 || height < 0.1)
            continue;

        NestPart part;
        part.id = "face_" + std::to_string(parts.size());
        part.bounds.width = width;
        part.bounds.height = height;
        part.quantity = 1;
        parts.push_back(std::move(part));
    }

    return parts;
}

} // namespace MilCAD
