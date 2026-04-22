# Pre-build helper: increment .build_number and regenerate AppVersion.h.
#
# Invoked via `cmake -P` from a custom target that runs on every build.
# Reads SOURCE_DIR / BINARY_DIR / BASE_VERSION from -D flags.
#
# On first build .build_number doesn't exist, so we seed it at 0 and
# increment to 1 — the resulting version becomes "${BASE_VERSION}.1".
#
# We write to build/ not source/ so the counter lives with the build tree
# (survives clean rebuilds via CMake cache but isn't committed to git).

if(NOT DEFINED SOURCE_DIR OR NOT DEFINED BINARY_DIR OR NOT DEFINED BASE_VERSION)
    message(FATAL_ERROR "BumpBuildNumber.cmake requires -DSOURCE_DIR, -DBINARY_DIR, -DBASE_VERSION")
endif()

set(COUNTER_FILE "${BINARY_DIR}/.build_number")
set(HEADER_OUT   "${BINARY_DIR}/generated/AppVersion.h")

if(EXISTS "${COUNTER_FILE}")
    file(READ "${COUNTER_FILE}" _num)
    string(STRIP "${_num}" _num)
    if(NOT _num MATCHES "^[0-9]+$")
        set(_num 0)
    endif()
else()
    set(_num 0)
endif()

math(EXPR _num "${_num} + 1")
file(WRITE "${COUNTER_FILE}" "${_num}\n")

set(_full_version "${BASE_VERSION}.${_num}")

# Only touch the header if the contents actually changed — avoids a spurious
# mtime update that would force main.cpp to recompile on every build.
set(_new_contents "#pragma once\n#define CADNC_APP_VERSION \"${_full_version}\"\n#define CADNC_APP_BUILD_NUMBER ${_num}\n")

if(EXISTS "${HEADER_OUT}")
    file(READ "${HEADER_OUT}" _old_contents)
    if(_old_contents STREQUAL _new_contents)
        return()
    endif()
endif()

file(WRITE "${HEADER_OUT}" "${_new_contents}")
message(STATUS "CADNC build #${_num} → ${_full_version}")
