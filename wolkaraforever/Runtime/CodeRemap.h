#pragma once
#include "NativeCodeMemory.h"
#include <stdbool.h>
#include <stdio.h>

// Replace an exclusively owned, page-aligned mapping with a shared view of
// already prepared pages. Never creates execute permission or attaches a helper.
int wk_code_remap(void *target, const void *source, size_t size, int protection);
// Only our generated return-value fixtures; no guest image is loaded or inspected.
bool wk_code_remap_probe(NativeCodeMemory *memory, FILE *log);
