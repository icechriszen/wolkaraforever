#pragma once
#include "GuestLink.h"
#include "OwnedCxx.h"
typedef struct {
    void *handle;
    const struct WKOwnedCxxAPI *api;
    size_t bindings;
    bool attempted;
} WKNativeCxx;
// Select the same canonical scalar new/delete as the loader's weak binding.
// No application code is called during preparation. The handle is retained.
bool wk_cxx_prepare(WKNativeCxx *, const GuestLinkSet *, const char *module,
                    WKCppEvent, char *error, size_t error_size);
void *wk_cxx_lookup(WKNativeCxx *, const char *name);
bool wk_cxx_library(const char *path);
