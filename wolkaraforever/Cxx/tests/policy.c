#include "NativeCxx.h"
#include <assert.h>
#include <string.h>
int main(void) {
    static GuestImage image;
    static GuestLinkSet set;
    WKNativeCxx state={0};char error[256];
    set.executable_image=&image;set.executable="/synthetic/no-custom-allocator";
    assert(wk_cxx_library("/usr/lib/libc++.1.dylib"));
    assert(wk_cxx_library("libc++.dylib"));
    assert(!wk_cxx_library(NULL));assert(!wk_cxx_library("libc++.1.dylib.backup"));
    assert(!wk_cxx_lookup(&state,"_Znwm"));
    assert(!wk_cxx_prepare(NULL,&set,"missing",NULL,error,sizeof error));
    // Programs without replacement operators need neither the adapter nor a file.
    assert(wk_cxx_prepare(&state,&set,"/does-not-exist",NULL,error,sizeof error));
    assert(!state.api && !state.handle);
    assert(!wk_cxx_prepare(&state,&set,"/does-not-exist",NULL,error,sizeof error));
    assert(strstr(error,"repeated"));
}
