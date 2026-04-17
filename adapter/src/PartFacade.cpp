#include "PartFacade.h"

#include <App/Document.h>
#include <App/DocumentObject.h>
#include <App/PropertyGeo.h>
#include <App/PropertyLinks.h>
#include <App/PropertyStandard.h>
#include <App/PropertyUnits.h>
#include <Base/Console.h>
#include <Base/Exception.h>
#include <Base/Vector3D.h>
#include <Mod/Part/App/FeatureExtrusion.h>
#include <Mod/Part/App/FeatureRevolution.h>
#include <Mod/PartDesign/App/Body.h>
#include <Mod/PartDesign/App/FeaturePad.h>
#include <Mod/PartDesign/App/FeaturePocket.h>
#include <Mod/PartDesign/App/FeatureRevolution.h>
#include <Mod/PartDesign/App/FeatureFillet.h>
#include <Mod/PartDesign/App/FeatureChamfer.h>

#include <cstdio>

namespace CADNC {

struct PartFacade::Impl {
    App::Document* doc = nullptr;

    // Find PartDesign::Body if it exists
    PartDesign::Body* findBody() {
        if (!doc) return nullptr;
        for (auto* obj : doc->getObjects()) {
            auto* b = dynamic_cast<PartDesign::Body*>(obj);
            if (b) return b;
        }
        return nullptr;
    }
};

PartFacade::PartFacade(void* document)
    : impl_(std::make_unique<Impl>())
{
    impl_->doc = static_cast<App::Document*>(document);
}

PartFacade::~PartFacade() = default;

std::string PartFacade::pad(const std::string& sketchName, double length)
{
    if (!impl_->doc) return {};

    auto* sketch = impl_->doc->getObject(sketchName.c_str());
    if (!sketch) {
        std::fprintf(stderr, "CADNC: Pad failed — sketch '%s' not found\n", sketchName.c_str());
        return {};
    }

    // Try PartDesign::Pad first (proper Body chain), fall back to Part::Extrusion
    auto* body = impl_->findBody();
    if (body) {
        try {
            auto* padObj = new PartDesign::Pad();
            impl_->doc->addObject(padObj, "Pad");
            padObj->Profile.setValue(sketch);
            padObj->Type.setValue("Length");
            padObj->Length.setValue(length);
            body->addObject(padObj);
            impl_->doc->recompute();

            if (!padObj->Shape.getShape().getShape().IsNull())
                return padObj->getNameInDocument();

            // Shape is null — cleanup and fall through to Part::Extrusion
            impl_->doc->removeObject(padObj->getNameInDocument());
        } catch (...) {
            // PartDesign::Pad failed — fall through
        }
    }

    // Fallback: Part::Extrusion (works without Body/type registry)
    auto* obj = impl_->doc->addObject("Part::Extrusion", "Pad");
    if (!obj) return {};

    auto* extrusion = dynamic_cast<Part::Extrusion*>(obj);
    if (!extrusion) return {};

    extrusion->Base.setValue(sketch);
    extrusion->Dir.setValue(Base::Vector3d(0, 0, 1));
    extrusion->LengthFwd.setValue(length);
    extrusion->Solid.setValue(true);

    try {
        impl_->doc->recompute();
    } catch (...) {
        impl_->doc->removeObject(obj->getNameInDocument());
        return {};
    }
    return obj->getNameInDocument();
}

std::string PartFacade::pocket(const std::string& sketchName, double depth)
{
    if (!impl_->doc) return {};

    auto* sketch = impl_->doc->getObject(sketchName.c_str());
    if (!sketch) return {};

    auto* body = impl_->findBody();
    if (body) {
        try {
            auto* pocketObj = new PartDesign::Pocket();
            impl_->doc->addObject(pocketObj, "Pocket");
            pocketObj->Profile.setValue(sketch);
            pocketObj->Type.setValue("Length");
            pocketObj->Length.setValue(depth);
            body->addObject(pocketObj);
            impl_->doc->recompute();

            if (!pocketObj->Shape.getShape().getShape().IsNull())
                return pocketObj->getNameInDocument();

            impl_->doc->removeObject(pocketObj->getNameInDocument());
        } catch (...) {}
    }

    // Fallback: Part::Extrusion negative Z
    auto* obj = impl_->doc->addObject("Part::Extrusion", "Pocket");
    if (!obj) return {};
    auto* extrusion = dynamic_cast<Part::Extrusion*>(obj);
    if (!extrusion) return {};

    extrusion->Base.setValue(sketch);
    extrusion->Dir.setValue(Base::Vector3d(0, 0, -1));
    extrusion->LengthFwd.setValue(depth);
    extrusion->Solid.setValue(true);

    try { impl_->doc->recompute(); }
    catch (...) { impl_->doc->removeObject(obj->getNameInDocument()); return {}; }
    return obj->getNameInDocument();
}

std::string PartFacade::revolution(const std::string& sketchName, double angleDeg)
{
    if (!impl_->doc) return {};

    auto* sketch = impl_->doc->getObject(sketchName.c_str());
    if (!sketch) return {};

    auto* body = impl_->findBody();
    if (body) {
        try {
            auto* revObj = new PartDesign::Revolution();
            impl_->doc->addObject(revObj, "Revolution");
            revObj->Profile.setValue(sketch);
            revObj->Type.setValue("Angle");
            revObj->Angle.setValue(angleDeg);
            revObj->Axis.setValue(Base::Vector3d(0, 1, 0));
            revObj->Base.setValue(Base::Vector3d(0, 0, 0));
            body->addObject(revObj);
            impl_->doc->recompute();

            if (!revObj->Shape.getShape().getShape().IsNull())
                return revObj->getNameInDocument();

            impl_->doc->removeObject(revObj->getNameInDocument());
        } catch (...) {}
    }

    // Fallback: Part::Revolution
    auto* obj = impl_->doc->addObject("Part::Revolution", "Revolution");
    if (!obj) return {};

    auto* sourceLink = dynamic_cast<App::PropertyLink*>(obj->getPropertyByName("Source"));
    if (sourceLink) sourceLink->setValue(sketch);
    auto* angleProp = dynamic_cast<App::PropertyFloatConstraint*>(obj->getPropertyByName("Angle"));
    if (angleProp) angleProp->setValue(angleDeg);

    try { impl_->doc->recompute(); }
    catch (...) { impl_->doc->removeObject(obj->getNameInDocument()); return {}; }
    return obj->getNameInDocument();
}

std::string PartFacade::fillet(const std::vector<std::string>& /*edgeRefs*/, double /*radius*/)
{
    Base::Console().warning("CADNC: PartFacade::fillet not yet implemented\n");
    return {};
}

std::string PartFacade::chamfer(const std::vector<std::string>& /*edgeRefs*/, double /*size*/)
{
    Base::Console().warning("CADNC: PartFacade::chamfer not yet implemented\n");
    return {};
}

std::string PartFacade::linearPattern(const std::string&, double, double, double, double, int) { return {}; }
std::string PartFacade::polarPattern(const std::string&, double, double, double, double, int) { return {}; }
std::string PartFacade::mirror(const std::string&, double, double, double) { return {}; }

} // namespace CADNC
