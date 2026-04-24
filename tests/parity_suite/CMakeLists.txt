# CADNC Parity Test Suite
#
# Per WRAPPER_CONTRACT § 10.1: per-workbench parity-test subdirectories.
# Each <workbench>/ hosts one test_<tool>.cpp per catalog row, compiled
# into a single cadnc_parity_<wb>_tests executable that ctest runs.
#
# The sketch/ suite is bootstrapped in sub-phase 1-Zero and populated
# during Phase 1 (Sketcher parity, 161 tools).
#
# Phase 2 and Phase 3 will add part/ and cam/ subdirectories.

add_subdirectory(sketch)
# add_subdirectory(part)  # enabled in Phase 2
# add_subdirectory(cam)   # enabled in Phase 3
