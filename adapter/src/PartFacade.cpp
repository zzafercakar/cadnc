#include "PartFacade.h"

#include <App/Document.h>
#include <App/DocumentObject.h>
#include <Base/Console.h>
#include <Mod/PartDesign/App/FeaturePad.h>
#include <Mod/PartDesign/App/FeaturePocket.h>
#include <Mod/PartDesign/App/FeatureRevolution.h>
#include <Mod/PartDesign/App/FeatureFillet.h>
#include <Mod/PartDesign/App/FeatureChamfer.h>

namespace CADNC {

struct PartFacade::Impl {
    App::Document* doc = nullptr;
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

    auto* obj = impl_->doc->addObject("PartDesign::Pad", "Pad");
    if (!obj) return {};

    auto* pad = dynamic_cast<PartDesign::Pad*>(obj);
    if (!pad) return {};

    // Link to sketch
    auto* sketch = impl_->doc->getObject(sketchName.c_str());
    if (sketch) {
        pad->Profile.setValue(sketch);
    }
    pad->Length.setValue(length);

    impl_->doc->recompute();
    return obj->getNameInDocument();
}

std::string PartFacade::pocket(const std::string& sketchName, double depth)
{
    if (!impl_->doc) return {};

    auto* obj = impl_->doc->addObject("PartDesign::Pocket", "Pocket");
    if (!obj) return {};

    auto* pocket = dynamic_cast<PartDesign::Pocket*>(obj);
    if (!pocket) return {};

    auto* sketch = impl_->doc->getObject(sketchName.c_str());
    if (sketch) {
        pocket->Profile.setValue(sketch);
    }
    pocket->Length.setValue(depth);

    impl_->doc->recompute();
    return obj->getNameInDocument();
}

std::string PartFacade::revolution(const std::string& sketchName, double angleDeg)
{
    if (!impl_->doc) return {};

    auto* obj = impl_->doc->addObject("PartDesign::Revolution", "Revolution");
    if (!obj) return {};

    auto* rev = dynamic_cast<PartDesign::Revolution*>(obj);
    if (!rev) return {};

    auto* sketch = impl_->doc->getObject(sketchName.c_str());
    if (sketch) {
        rev->Profile.setValue(sketch);
    }
    rev->Angle.setValue(angleDeg);

    impl_->doc->recompute();
    return obj->getNameInDocument();
}

std::string PartFacade::fillet(const std::vector<std::string>& /*edgeRefs*/, double /*radius*/)
{
    // TODO: edge reference resolution needed
    Base::Console().warning("CADNC: PartFacade::fillet not yet implemented\n");
    return {};
}

std::string PartFacade::chamfer(const std::vector<std::string>& /*edgeRefs*/, double /*size*/)
{
    // TODO: edge reference resolution needed
    Base::Console().warning("CADNC: PartFacade::chamfer not yet implemented\n");
    return {};
}

std::string PartFacade::linearPattern(const std::string& /*featureName*/,
                                      double /*dirX*/, double /*dirY*/, double /*dirZ*/,
                                      double /*length*/, int /*occurrences*/)
{
    // TODO: implement
    return {};
}

std::string PartFacade::polarPattern(const std::string& /*featureName*/,
                                     double /*axisX*/, double /*axisY*/, double /*axisZ*/,
                                     double /*angleDeg*/, int /*occurrences*/)
{
    // TODO: implement
    return {};
}

std::string PartFacade::mirror(const std::string& /*featureName*/,
                               double /*planeNormX*/, double /*planeNormY*/, double /*planeNormZ*/)
{
    // TODO: implement
    return {};
}

} // namespace CADNC
