/**
 * @file main.cpp
 * @brief Entry point for cadnc_parity_sketch_tests.
 *
 * Each test_<tool>.cpp in this directory registers its CADNC_PARITY_TEST
 * cases via static initialisation; the harness here iterates the
 * registry and reports pass/fail counts.
 */

#include "test_helpers.h"

CADNC_PARITY_MAIN()
