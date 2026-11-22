#include "NativeCxx.h"
#include <dlfcn.h>
#include <mach-o/loader.h>
#include <stdio.h>
#include <string.h>
static bool fail(char *error,size_t size,const char *reason) {
    if(error && size)snprintf(error,size,"%s",reason);return false;
}
bool wk_cxx_library(const char *path) {
    if(!path)return false;
    const char *leaf=strrchr(path,'/');leaf=leaf?leaf+1:path;
    return !strcmp(leaf,"libc++.1.dylib") || !strcmp(leaf,"libc++.dylib");
}
bool wk_cxx_prepare(WKNativeCxx *state,const GuestLinkSet *set,const char *module,
                    WKCppEvent observer,char *error,size_t size) {
    if(!state || !set || !set->executable_image || !module || state->attempted)
        return fail(error,size,"invalid or repeated C++ allocator preparation");
    state->attempted=true;
    uint64_t allocate=0,release=0;
    bool own_allocate=gl_lookup(set,set->executable_image,set->executable,
        BIND_SPECIAL_DYLIB_WEAK_LOOKUP,"__Znwm",&allocate,NULL);
    bool own_release=gl_lookup(set,set->executable_image,set->executable,
        BIND_SPECIAL_DYLIB_WEAK_LOOKUP,"__ZdlPv",&release,NULL);
    if(!own_allocate && !own_release)return true;
    if(!own_allocate)allocate=(uintptr_t)dlsym(RTLD_DEFAULT,"_Znwm");
    if(!own_release)release=(uintptr_t)dlsym(RTLD_DEFAULT,"_ZdlPv");
    if(!allocate || !release)return fail(error,size,"C++ allocator pair is incomplete");
    state->handle=dlopen(module,RTLD_NOW|RTLD_LOCAL);
    if(!state->handle)return fail(error,size,"isolated C++ adapter could not be loaded");
    const struct WKOwnedCxxAPI *(*get_api)(void)=dlsym(state->handle,"WKGetOwnedCxxAPI");
    if(!get_api)return fail(error,size,"isolated C++ adapter API is missing");
    const struct WKOwnedCxxAPI *api=get_api();
    if(!api || api->version!=1 || api->libcxx_version!=220106 || api->string_size!=24 || api->string_alignment!=8 ||
       !api->configure || !api->lookup || !api->counts)
        return fail(error,size,"isolated C++ adapter ABI does not match");
    if(!api->configure((WKCppAllocate)(uintptr_t)allocate,(WKCppRelease)(uintptr_t)release,observer))
        return fail(error,size,"isolated C++ allocator was already configured");
    state->api=api;return true;
}
void *wk_cxx_lookup(WKNativeCxx *state,const char *name) {
    if(!state || !state->api || !name)return NULL;
    void *result=state->api->lookup(name);
    if(result)__atomic_add_fetch(&state->bindings,1,__ATOMIC_RELAXED);
    return result;
}
