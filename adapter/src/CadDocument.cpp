#include "CadDocument.h"
#include "SketchFacade.h"
#include "PartFacade.h"

#include <App/Application.h>
#include <App/Document.h>
#include <App/DocumentObject.h>
#include <Base/Console.h>
#include <Mod/Sketcher/App/SketchObject.h>

namespace CADNC {

struct CadDocument::Impl {
    App::Document* doc = nullptr;
};

CadDocument::CadDocument(const std::string& name)
    : impl_(std::make_unique<Impl>())
{
    impl_->doc = App::GetApplication().newDocument(name.c_str(), name.c_str());
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

bool CadDocument::load(const std::string& /*path*/)
{
    // TODO: App::GetApplication().openDocument(path)
    return false;
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

std::shared_ptr<SketchFacade> CadDocument::addSketch(const std::string& name)
{
    if (!impl_->doc) return nullptr;

    auto* obj = impl_->doc->addObject("Sketcher::SketchObject", name.c_str());
    if (!obj) return nullptr;

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

void CadDocument::recompute()
{
    if (impl_->doc) impl_->doc->recompute();
}

} // namespace CADNC
