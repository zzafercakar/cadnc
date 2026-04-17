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
#include <Mod/PartDesign/App/FeatureGroove.h>
#include <Mod/PartDesign/App/FeatureLinearPattern.h>
#include <Mod/PartDesign/App/FeaturePolarPattern.h>
#include <Mod/PartDesign/App/FeatureMirrored.h>
#include <Mod/Part/App/FeaturePartBoolean.h>
#include <Mod/Part/App/FeaturePartCut.h>
#include <Mod/Part/App/FeaturePartFuse.h>
#include <Mod/Part/App/FeaturePartCommon.h>
#include <Mod/Part/App/FeaturePartBox.h>
#include <Mod/Part/App/PrimitiveFeature.h>

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

std::string PartFacade::linearPattern(const std::string& featureName,
                                       double dirX, double dirY, double dirZ,
                                       double length, int occurrences)
{
    if (!impl_->doc) return {};
    auto* feature = impl_->doc->getObject(featureName.c_str());
    if (!feature) return {};

    auto* body = impl_->findBody();
    if (!body) return {};

    try {
        auto* obj = new PartDesign::LinearPattern();
        impl_->doc->addObject(obj, "LinearPattern");
        // Set originals list
        std::vector<App::DocumentObject*> originals = {feature};
        obj->Originals.setValues(originals);
        obj->Length.setValue(length);
        obj->Occurrences.setValue(occurrences);
        body->addObject(obj);
        impl_->doc->recompute();
        if (!obj->Shape.getShape().getShape().IsNull())
            return obj->getNameInDocument();
        impl_->doc->removeObject(obj->getNameInDocument());
    } catch (...) {}
    return {};
}

std::string PartFacade::polarPattern(const std::string& featureName,
                                      double axisX, double axisY, double axisZ,
                                      double angleDeg, int occurrences)
{
    if (!impl_->doc) return {};
    auto* feature = impl_->doc->getObject(featureName.c_str());
    if (!feature) return {};

    auto* body = impl_->findBody();
    if (!body) return {};

    try {
        auto* obj = new PartDesign::PolarPattern();
        impl_->doc->addObject(obj, "PolarPattern");
        std::vector<App::DocumentObject*> originals = {feature};
        obj->Originals.setValues(originals);
        obj->Angle.setValue(angleDeg);
        obj->Occurrences.setValue(occurrences);
        body->addObject(obj);
        impl_->doc->recompute();
        if (!obj->Shape.getShape().getShape().IsNull())
            return obj->getNameInDocument();
        impl_->doc->removeObject(obj->getNameInDocument());
    } catch (...) {}
    return {};
}

std::string PartFacade::mirror(const std::string& featureName,
                                double planeNormX, double planeNormY, double planeNormZ)
{
    if (!impl_->doc) return {};
    auto* feature = impl_->doc->getObject(featureName.c_str());
    if (!feature) return {};

    auto* body = impl_->findBody();
    if (!body) return {};

    try {
        auto* obj = new PartDesign::Mirrored();
        impl_->doc->addObject(obj, "Mirrored");
        std::vector<App::DocumentObject*> originals = {feature};
        obj->Originals.setValues(originals);
        body->addObject(obj);
        impl_->doc->recompute();
        if (!obj->Shape.getShape().getShape().IsNull())
            return obj->getNameInDocument();
        impl_->doc->removeObject(obj->getNameInDocument());
    } catch (...) {}
    return {};
}

std::string PartFacade::groove(const std::string& sketchName, double angleDeg)
{
    if (!impl_->doc) return {};
    auto* sketch = impl_->doc->getObject(sketchName.c_str());
    if (!sketch) return {};

    auto* body = impl_->findBody();
    if (body) {
        try {
            auto* obj = new PartDesign::Groove();
            impl_->doc->addObject(obj, "Groove");
            obj->Profile.setValue(sketch);
            obj->Type.setValue("Angle");
            obj->Angle.setValue(angleDeg);
            obj->Axis.setValue(Base::Vector3d(0, 1, 0));
            obj->Base.setValue(Base::Vector3d(0, 0, 0));
            body->addObject(obj);
            impl_->doc->recompute();
            if (!obj->Shape.getShape().getShape().IsNull())
                return obj->getNameInDocument();
            impl_->doc->removeObject(obj->getNameInDocument());
        } catch (...) {}
    }

    // Fallback: Part::Revolution reversed
    auto* obj = impl_->doc->addObject("Part::Revolution", "Groove");
    if (!obj) return {};
    auto* sourceLink = dynamic_cast<App::PropertyLink*>(obj->getPropertyByName("Source"));
    if (sourceLink) sourceLink->setValue(sketch);
    auto* angleProp = dynamic_cast<App::PropertyFloatConstraint*>(obj->getPropertyByName("Angle"));
    if (angleProp) angleProp->setValue(angleDeg);

    try { impl_->doc->recompute(); }
    catch (...) { impl_->doc->removeObject(obj->getNameInDocument()); return {}; }
    return obj->getNameInDocument();
}

std::string PartFacade::booleanFuse(const std::string& baseName, const std::string& toolName)
{
    if (!impl_->doc) return {};
    auto* base = impl_->doc->getObject(baseName.c_str());
    auto* tool = impl_->doc->getObject(toolName.c_str());
    if (!base || !tool) return {};

    auto* obj = impl_->doc->addObject("Part::Fuse", "Fuse");
    if (!obj) return {};
    auto* fuse = dynamic_cast<Part::Fuse*>(obj);
    if (!fuse) return {};
    fuse->Base.setValue(base);
    fuse->Tool.setValue(tool);

    try { impl_->doc->recompute(); }
    catch (...) { impl_->doc->removeObject(obj->getNameInDocument()); return {}; }
    return obj->getNameInDocument();
}

std::string PartFacade::booleanCut(const std::string& baseName, const std::string& toolName)
{
    if (!impl_->doc) return {};
    auto* base = impl_->doc->getObject(baseName.c_str());
    auto* tool = impl_->doc->getObject(toolName.c_str());
    if (!base || !tool) return {};

    auto* obj = impl_->doc->addObject("Part::Cut", "Cut");
    if (!obj) return {};
    auto* cut = dynamic_cast<Part::Cut*>(obj);
    if (!cut) return {};
    cut->Base.setValue(base);
    cut->Tool.setValue(tool);

    try { impl_->doc->recompute(); }
    catch (...) { impl_->doc->removeObject(obj->getNameInDocument()); return {}; }
    return obj->getNameInDocument();
}

std::string PartFacade::booleanCommon(const std::string& baseName, const std::string& toolName)
{
    if (!impl_->doc) return {};
    auto* base = impl_->doc->getObject(baseName.c_str());
    auto* tool = impl_->doc->getObject(toolName.c_str());
    if (!base || !tool) return {};

    auto* obj = impl_->doc->addObject("Part::Common", "Common");
    if (!obj) return {};
    auto* common = dynamic_cast<Part::Common*>(obj);
    if (!common) return {};
    common->Base.setValue(base);
    common->Tool.setValue(tool);

    try { impl_->doc->recompute(); }
    catch (...) { impl_->doc->removeObject(obj->getNameInDocument()); return {}; }
    return obj->getNameInDocument();
}

std::string PartFacade::addBox(double length, double width, double height)
{
    if (!impl_->doc) return {};
    auto* obj = impl_->doc->addObject("Part::Box", "Box");
    if (!obj) return {};
    auto* box = dynamic_cast<Part::Box*>(obj);
    if (!box) return {};
    box->Length.setValue(length);
    box->Width.setValue(width);
    box->Height.setValue(height);

    try { impl_->doc->recompute(); }
    catch (...) { impl_->doc->removeObject(obj->getNameInDocument()); return {}; }
    return obj->getNameInDocument();
}

std::string PartFacade::addCylinder(double radius, double height, double angle)
{
    if (!impl_->doc) return {};
    auto* obj = impl_->doc->addObject("Part::Cylinder", "Cylinder");
    if (!obj) return {};
    auto* cyl = dynamic_cast<Part::Cylinder*>(obj);
    if (!cyl) return {};
    cyl->Radius.setValue(radius);
    cyl->Height.setValue(height);
    cyl->Angle.setValue(angle);

    try { impl_->doc->recompute(); }
    catch (...) { impl_->doc->removeObject(obj->getNameInDocument()); return {}; }
    return obj->getNameInDocument();
}

std::string PartFacade::addSphere(double radius)
{
    if (!impl_->doc) return {};
    auto* obj = impl_->doc->addObject("Part::Sphere", "Sphere");
    if (!obj) return {};
    auto* sphere = dynamic_cast<Part::Sphere*>(obj);
    if (!sphere) return {};
    sphere->Radius.setValue(radius);

    try { impl_->doc->recompute(); }
    catch (...) { impl_->doc->removeObject(obj->getNameInDocument()); return {}; }
    return obj->getNameInDocument();
}

std::string PartFacade::addCone(double radius1, double radius2, double height)
{
    if (!impl_->doc) return {};
    auto* obj = impl_->doc->addObject("Part::Cone", "Cone");
    if (!obj) return {};
    auto* cone = dynamic_cast<Part::Cone*>(obj);
    if (!cone) return {};
    cone->Radius1.setValue(radius1);
    cone->Radius2.setValue(radius2);
    cone->Height.setValue(height);

    try { impl_->doc->recompute(); }
    catch (...) { impl_->doc->removeObject(obj->getNameInDocument()); return {}; }
    return obj->getNameInDocument();
}

std::string PartFacade::filletAll(const std::string& featureName, double radius)
{
    if (!impl_->doc) return {};
    auto* feature = impl_->doc->getObject(featureName.c_str());
    if (!feature) return {};

    auto* body = impl_->findBody();
    if (body) {
        try {
            auto* obj = new PartDesign::Fillet();
            impl_->doc->addObject(obj, "Fillet");
            obj->Base.setValue(feature);
            obj->Radius.setValue(radius);
            obj->UseAllEdges.setValue(true);
            body->addObject(obj);
            impl_->doc->recompute();
            if (!obj->Shape.getShape().getShape().IsNull())
                return obj->getNameInDocument();
            impl_->doc->removeObject(obj->getNameInDocument());
        } catch (...) {}
    }
    return {};
}

std::string PartFacade::chamferAll(const std::string& featureName, double size)
{
    if (!impl_->doc) return {};
    auto* feature = impl_->doc->getObject(featureName.c_str());
    if (!feature) return {};

    auto* body = impl_->findBody();
    if (body) {
        try {
            auto* obj = new PartDesign::Chamfer();
            impl_->doc->addObject(obj, "Chamfer");
            obj->Base.setValue(feature);
            obj->Size.setValue(size);
            obj->UseAllEdges.setValue(true);
            body->addObject(obj);
            impl_->doc->recompute();
            if (!obj->Shape.getShape().getShape().IsNull())
                return obj->getNameInDocument();
            impl_->doc->removeObject(obj->getNameInDocument());
        } catch (...) {}
    }
    return {};
}

} // namespace CADNC
