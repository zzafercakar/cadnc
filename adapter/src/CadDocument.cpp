#include "CadDocument.h"
#include "SketchFacade.h"
#include "PartFacade.h"

#include <cctype>
#include <App/Application.h>
#include <App/Document.h>
#include <App/DocumentObject.h>
#include <App/PropertyGeo.h>
#include <Base/Console.h>
#include <Base/Placement.h>
#include <Base/Rotation.h>
#include <Mod/Sketcher/App/SketchObject.h>
#include <Mod/Part/App/PartFeature.h>
#include <Mod/Part/App/TopoShape.h>
#include <Mod/PartDesign/App/Body.h>

namespace CADNC {

struct CadDocument::Impl {
    App::Document* doc = nullptr;
    PartDesign::Body* body = nullptr;  // PartDesign body (created on demand)

    // Ensure a PartDesign::Body exists in the document.
    // Uses direct C++ instantiation because PartDesign types may not be
    // registered in FreeCAD's type system (that requires Python module import).
    PartDesign::Body* ensureBody() {
        if (body) return body;
        if (!doc) return nullptr;

        // Look for existing body
        for (auto* obj : doc->getObjects()) {
            auto* b = dynamic_cast<PartDesign::Body*>(obj);
            if (b) { body = b; return body; }
        }

        // Create Body via direct C++ construction + document registration
        try {
            auto* b = new PartDesign::Body();
            doc->addObject(b, "Body");
            body = b;
        } catch (...) {
            Base::Console().warning("CADNC: Could not create PartDesign::Body\n");
            body = nullptr;
        }
        return body;
    }
};

CadDocument::CadDocument(const std::string& name)
    : impl_(std::make_unique<Impl>())
{
    try {
        impl_->doc = App::GetApplication().newDocument(name.c_str(), name.c_str());
    } catch (const Base::Exception& e) {
        Base::Console().error("CADNC: newDocument failed: %s\n", e.what());
    } catch (...) {
        Base::Console().error("CADNC: newDocument failed (unknown exception)\n");
    }
}

CadDocument::~CadDocument() = default;

std::string CadDocument::name() const
{
    if (!impl_->doc) return {};
    return impl_->doc->getName();
}

bool CadDocument::save(const std::string& path)
{
    if (!impl_->doc) return false;
    try {
        impl_->doc->saveAs(path.c_str());
        return true;
    } catch (...) {
        return false;
    }
}

bool CadDocument::load(const std::string& path)
{
    try {
        auto* doc = App::GetApplication().openDocument(path.c_str());
        if (doc) {
            impl_->doc = doc;
            return true;
        }
    } catch (const Base::Exception& e) {
        Base::Console().error("CADNC: Failed to open %s: %s\n", path.c_str(), e.what());
    } catch (...) {
        Base::Console().error("CADNC: Failed to open %s\n", path.c_str());
    }
    return false;
}

bool CadDocument::exportTo(const std::string& path) const
{
    if (!impl_->doc) return false;

    // Determine format from file extension
    std::string ext;
    auto dot = path.rfind('.');
    if (dot != std::string::npos) {
        ext = path.substr(dot + 1);
        // Lowercase
        for (auto& c : ext) c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
    }

    // For FCStd, use native FreeCAD save
    if (ext == "fcstd") {
        try {
            impl_->doc->saveCopy(path.c_str());
            return true;
        } catch (...) {
            Base::Console().error("CADNC: FCStd export failed\n");
            return false;
        }
    }

    // For geometry formats, find the last Part::Feature with a valid shape
    Part::Feature* bestFeature = nullptr;
    for (auto* obj : impl_->doc->getObjects()) {
        auto* pf = dynamic_cast<Part::Feature*>(obj);
        if (pf && !pf->Shape.getShape().getShape().IsNull()) {
            bestFeature = pf;  // keep last valid — usually the Tip
        }
    }

    if (!bestFeature) {
        Base::Console().error("CADNC: Export failed — no shape found in document\n");
        return false;
    }

    try {
        const auto& topoShape = bestFeature->Shape.getShape();

        if (ext == "step" || ext == "stp") {
            topoShape.exportStep(path.c_str());
        } else if (ext == "iges" || ext == "igs") {
            topoShape.exportIges(path.c_str());
        } else if (ext == "brep" || ext == "brp") {
            topoShape.exportBrep(path.c_str());
        } else if (ext == "stl") {
            topoShape.exportStl(path.c_str(), 0.1);  // 0.1mm deflection
        } else {
            Base::Console().error("CADNC: Unknown export format: %s\n", ext.c_str());
            return false;
        }
        return true;
    } catch (const Base::Exception& e) {
        Base::Console().error("CADNC: Export failed: %s\n", e.what());
    } catch (...) {
        Base::Console().error("CADNC: Export failed\n");
    }
    return false;
}

bool CadDocument::importFrom(const std::string& path)
{
    if (!impl_->doc) return false;

    // Determine format from file extension
    std::string ext;
    auto dot = path.rfind('.');
    if (dot != std::string::npos) {
        ext = path.substr(dot + 1);
        for (auto& c : ext) c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
    }

    try {
        Part::TopoShape shape;

        if (ext == "step" || ext == "stp") {
            shape.importStep(path.c_str());
        } else if (ext == "iges" || ext == "igs") {
            shape.importIges(path.c_str());
        } else if (ext == "brep" || ext == "brp") {
            shape.importBrep(path.c_str());
        } else {
            Base::Console().error("CADNC: Unsupported import format: %s\n", ext.c_str());
            return false;
        }

        if (shape.getShape().IsNull()) {
            Base::Console().error("CADNC: Import produced empty shape\n");
            return false;
        }

        // Create a Part::Feature to hold the imported shape
        auto* obj = impl_->doc->addObject("Part::Feature", "Import");
        if (!obj) return false;

        auto* feature = dynamic_cast<Part::Feature*>(obj);
        if (!feature) return false;

        feature->Shape.setValue(shape);
        impl_->doc->recompute();
        return true;
    } catch (const Base::Exception& e) {
        Base::Console().error("CADNC: Import failed: %s\n", e.what());
    } catch (...) {
        Base::Console().error("CADNC: Import failed\n");
    }
    return false;
}

void* CadDocument::internalDoc() const
{
    return static_cast<void*>(impl_->doc);
}

std::vector<FeatureInfo> CadDocument::featureTree() const
{
    std::vector<FeatureInfo> tree;
    if (!impl_->doc) return tree;

    for (auto* obj : impl_->doc->getObjects()) {
        FeatureInfo info;
        info.name = obj->getNameInDocument();
        info.label = obj->Label.getValue();
        info.typeName = obj->getTypeId().getName();
        tree.push_back(std::move(info));
    }
    return tree;
}

int CadDocument::featureCount() const
{
    if (!impl_->doc) return 0;
    return static_cast<int>(impl_->doc->getObjects().size());
}

bool CadDocument::deleteFeature(const std::string& name)
{
    if (!impl_->doc) return false;
    auto* obj = impl_->doc->getObject(name.c_str());
    if (!obj) return false;

    try {
        impl_->doc->removeObject(name.c_str());
        impl_->doc->recompute();
        return true;
    } catch (const Base::Exception& e) {
        Base::Console().error("CADNC: Delete failed: %s\n", e.what());
    } catch (...) {
        Base::Console().error("CADNC: Delete failed\n");
    }
    return false;
}

bool CadDocument::renameFeature(const std::string& name, const std::string& newLabel)
{
    if (!impl_->doc) return false;
    auto* obj = impl_->doc->getObject(name.c_str());
    if (!obj) return false;

    obj->Label.setValue(newLabel);
    return true;
}

void CadDocument::undo()
{
    if (impl_->doc) impl_->doc->undo();
}

void CadDocument::redo()
{
    if (impl_->doc) impl_->doc->redo();
}

bool CadDocument::canUndo() const
{
    return impl_->doc && impl_->doc->getAvailableUndos() > 0;
}

bool CadDocument::canRedo() const
{
    return impl_->doc && impl_->doc->getAvailableRedos() > 0;
}

std::shared_ptr<SketchFacade> CadDocument::addSketch(const std::string& name, int planeType)
{
    if (!impl_->doc) return nullptr;

    // Ensure a PartDesign::Body exists (required for Pad/Pocket/Revolution)
    auto* body = impl_->ensureBody();

    auto* obj = impl_->doc->addObject("Sketcher::SketchObject", name.c_str());
    if (!obj) return nullptr;

    // Add sketch to the Body so PartDesign features can find it
    if (body) {
        body->addObject(obj);
    }

    // Set sketch placement based on plane type:
    // 0 = XY (default, no rotation)
    // 1 = XZ (rotate -90° around X)
    // 2 = YZ (rotate 90° around Z, then -90° around X)
    if (planeType != 0) {
        auto* prop = dynamic_cast<App::PropertyPlacement*>(
            obj->getPropertyByName("Placement"));
        if (prop) {
            Base::Placement placement;
            if (planeType == 1) {
                placement.setRotation(Base::Rotation(Base::Vector3d(1, 0, 0), -M_PI / 2.0));
            } else if (planeType == 2) {
                Base::Rotation r1(Base::Vector3d(0, 0, 1), M_PI / 2.0);
                Base::Rotation r2(Base::Vector3d(1, 0, 0), -M_PI / 2.0);
                placement.setRotation(r2 * r1);
            }
            prop->setValue(placement);
        }
    }

    return std::make_shared<SketchFacade>(static_cast<void*>(obj));
}

std::shared_ptr<SketchFacade> CadDocument::getSketch(const std::string& name)
{
    if (!impl_->doc) return nullptr;

    auto* obj = impl_->doc->getObject(name.c_str());
    if (!obj) return nullptr;

    auto* sketch = dynamic_cast<Sketcher::SketchObject*>(obj);
    if (!sketch) return nullptr;

    return std::make_shared<SketchFacade>(static_cast<void*>(sketch));
}

std::shared_ptr<PartFacade> CadDocument::partDesign()
{
    if (!impl_->doc) return nullptr;
    return std::make_shared<PartFacade>(static_cast<void*>(impl_->doc));
}

void* CadDocument::getFeatureShape(const std::string& name) const
{
    if (!impl_->doc) return nullptr;
    auto* obj = impl_->doc->getObject(name.c_str());
    if (!obj) return nullptr;

    // Return pointer to Part::Feature itself (not the transient TopoDS_Shape).
    // Caller extracts the shape on the render-thread side where it's safe.
    auto* partFeature = dynamic_cast<Part::Feature*>(obj);
    if (partFeature && !partFeature->Shape.getShape().getShape().IsNull()) {
        return static_cast<void*>(partFeature);
    }
    return nullptr;
}

void CadDocument::recompute()
{
    if (impl_->doc) impl_->doc->recompute();
}

} // namespace CADNC
