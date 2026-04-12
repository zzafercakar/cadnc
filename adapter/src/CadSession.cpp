#include "CadSession.h"

namespace CADNC {

CadSession::CadSession() = default;
CadSession::~CadSession() { shutdown(); }

bool CadSession::initialize()
{
    if (initialized_) return true;

    // TODO: Initialize FreeCAD Base and App modules
    // - FreeCAD::Base::Console
    // - FreeCAD::App::Application::init()

    initialized_ = true;
    return true;
}

void CadSession::shutdown()
{
    if (!initialized_) return;

    // TODO: Cleanup FreeCAD application state

    initialized_ = false;
}

} // namespace CADNC
