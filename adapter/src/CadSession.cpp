#include "CadSession.h"
#include "CadDocument.h"

#include <CXX/WrapPython.h>
#include <Base/Console.h>
#include <App/Application.h>

// Module init functions — register with Python before Py_Initialize
extern "C" PyObject* PyInit_Part();
extern "C" PyObject* PyInit_Sketcher();
extern "C" PyObject* PyInit_Materials();
extern "C" PyObject* PyInit__PartDesign();

namespace CADNC {

CadSession::CadSession() = default;

CadSession::~CadSession() { shutdown(); }

bool CadSession::initialize(int argc, char** argv)
{
    if (initialized_) return true;

    try {
        // Register FreeCAD module Python entry points before Py_Initialize
        PyImport_AppendInittab("Part", PyInit_Part);
        PyImport_AppendInittab("Sketcher", PyInit_Sketcher);
        PyImport_AppendInittab("Materials", PyInit_Materials);
        PyImport_AppendInittab("_PartDesign", PyInit__PartDesign);

        // Full FreeCAD application init (Python, types, config, scripts)
        App::Application::init(argc, argv);

        // Note: PartDesign types (Body, Pad, etc.) may not be registered in
        // FreeCAD's type system yet because that requires Python module import.
        // CadDocument::ensureBody() and PartFacade use direct C++ instantiation
        // as a fallback when type-registry addObject fails.

        Base::Console().log("CADNC: FreeCAD backend initialized\n");
        initialized_ = true;
        return true;
    }
    catch (const Base::Exception& e) {
        fprintf(stderr, "CADNC: FreeCAD init failed: %s\n", e.what());
        return false;
    }
    catch (const std::exception& e) {
        fprintf(stderr, "CADNC: init failed: %s\n", e.what());
        return false;
    }
}

void CadSession::shutdown()
{
    if (!initialized_) return;

    documents_.clear();

    try {
        App::Application::destruct();
    } catch (...) {}

    initialized_ = false;
}

std::shared_ptr<CadDocument> CadSession::newDocument(const std::string& name)
{
    auto doc = std::make_shared<CadDocument>(name);
    documents_.push_back(doc);
    return doc;
}

void CadSession::closeDocument(const std::string& name)
{
    documents_.erase(
        std::remove_if(documents_.begin(), documents_.end(),
            [&](const auto& d) { return d->name() == name; }),
        documents_.end());

    try {
        App::GetApplication().closeDocument(name.c_str());
    } catch (...) {}
}

std::vector<std::string> CadSession::documentNames() const
{
    std::vector<std::string> names;
    names.reserve(documents_.size());
    for (const auto& d : documents_) {
        names.push_back(d->name());
    }
    return names;
}

} // namespace CADNC
