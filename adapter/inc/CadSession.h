#pragma once

/**
 * @file CadSession.h
 * @brief Top-level session managing FreeCAD application lifecycle.
 *
 * CadSession initializes the FreeCAD App framework (Base, App modules),
 * manages document creation/loading, and provides the entry point for
 * all CAD operations. UI code should only interact through this facade.
 */

namespace CADNC {

class CadSession {
public:
    CadSession();
    ~CadSession();

    // Initialize FreeCAD application framework
    bool initialize();

    // Shutdown and cleanup
    void shutdown();

    // Document management
    // TODO: createDocument(), openDocument(), saveDocument()

private:
    bool initialized_ = false;
};

} // namespace CADNC
