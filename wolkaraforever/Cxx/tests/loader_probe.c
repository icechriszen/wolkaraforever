#include "GuestImage.h"
#include "GuestFixups.h"
#include "GuestLink.h"
#include "NativeCxx.h"
#include <dlfcn.h>
#include <libkern/OSCacheControl.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
static GuestImage image;
static GuestLinkSet links;
static void *libraries[GI_MAX_DYLIBS];
static const char *fixture_path;
static WKNativeCxx isolated;
extern void host_before(void);
extern int host_after(void);
static bool bind_symbol(const char *symbol,int ordinal,bool weak,bool lazy,uint64_t *value,void *context) {
    (void)lazy;(void)context;
    const char *owner=NULL;
    if(gl_lookup(&links,&image,fixture_path,ordinal,symbol,value,&owner))return true;
    const char *name=symbol[0]=='_'?symbol+1:symbol;
    bool named=ordinal>0 && (size_t)ordinal<=image.dylib_count;
    void *p=(!named || wk_cxx_library(image.dylibs[ordinal-1]))?wk_cxx_lookup(&isolated,name):NULL;
    if(p){*value=(uintptr_t)p;return true;}
    if(ordinal>0 && (size_t)ordinal<=image.dylib_count && libraries[ordinal-1])p=dlsym(libraries[ordinal-1],name);
    if(!p)p=dlsym(RTLD_DEFAULT,name);
    if(!p && !weak)fprintf(stderr,"unresolved fixture import %s\n",symbol);
    *value=(uintptr_t)p;return p||weak;
}
int main(int argc,char **argv) {
    if(argc!=4)return 2;
    host_before();
    void *host_new=dlsym(RTLD_DEFAULT,"_Znwm");
    void *host_tls=dlsym(RTLD_DEFAULT,"_ZNSt3__119__thread_local_dataEv");
    fixture_path=argv[1];char error[1024]={0};
    if(!gi_load(fixture_path,&image,error,sizeof error)){fprintf(stderr,"%s\n",error);return 2;}
    if(image.has_tls || image.initializer_count){fprintf(stderr,"fixture needs unsupported initialization\n");return 2;}
    uint64_t low=0;size_t size=(size_t)gi_extent(&image,&low);
    void *arena=mmap(NULL,size,PROT_READ|PROT_WRITE,MAP_PRIVATE|MAP_ANON,-1,0);
    if(arena==MAP_FAILED){perror("fixture memory");return 2;}
    uint64_t slide=(uintptr_t)arena-low;
    links.executable_image=&image;links.executable=argv[1];links.executable_slide=slide;
    for(size_t i=0;i<image.dylib_count;i++)libraries[i]=dlopen(image.dylibs[i],RTLD_NOW|RTLD_LOCAL);
    if(strcmp(argv[2],"legacy") && !wk_cxx_prepare(&isolated,&links,argv[2],NULL,error,sizeof error)) {
        fprintf(stderr,"%s\n",error);return 2;
    }
    if(isolated.api) {
        if(isolated.api->configure(NULL,NULL,NULL))return 3;
        if(isolated.api->configure(malloc,free,NULL))return 3;
        if(isolated.api->lookup("malloc") || isolated.api->lookup(NULL))return 3;
        if(wk_cxx_prepare(&isolated,&links,argv[2],NULL,error,sizeof error))return 3;
    }
    GFStats stats;
    if(!gf_apply(&image,slide,bind_symbol,NULL,&stats,error,sizeof error)){fprintf(stderr,"%s\n",error);return 2;}
    for(size_t i=0;i<image.segment_count;i++) {
        GISegment *s=&image.segments[i];if(!s->prot || !s->size)continue;
        if(gm_read(&image.memory,s->address,(char *)arena+(s->address-low),(size_t)s->size)!=GM_OK){fprintf(stderr,"fixture segment read failed\n");return 2;}
    }
    for(size_t i=0;i<image.segment_count;i++) {
        GISegment *s=&image.segments[i];if(!s->prot || !s->size)continue;
        if(mprotect((char *)arena+(s->address-low),(size_t)s->size,(int)s->prot)){perror("fixture segment protections");return 2;}
    }
    sys_icache_invalidate(arena,size);
    GIExport run;
    if(gi_export(&image,!strcmp(argv[3],"threads")?"_fixture_run_threads":!strcmp(argv[3],"direct")?"_fixture_run_direct":"_fixture_run",&run,error,sizeof error)!=GI_EXPORT_FOUND){fprintf(stderr,"missing fixture export\n");return 2;}
    printf("Wolkara loader components: rebases=%zu binds=%zu fixture only\n",stats.rebases,stats.binds);fflush(stdout);
    int result=((int(*)(void))(uintptr_t)(run.address+slide))();
    if(host_new!=dlsym(RTLD_DEFAULT,"_Znwm") || host_tls!=dlsym(RTLD_DEFAULT,"_ZNSt3__119__thread_local_dataEv") || host_after())return 4;
    uint64_t allocations=0,releases=0;
    if(isolated.api)isolated.api->counts(&allocations,&releases);
    printf("loader fixture_result=%d isolated_bindings=%zu module_allocations=%llu module_releases=%llu host_unchanged=1\n",
        result,isolated.bindings,(unsigned long long)allocations,(unsigned long long)releases);fflush(stdout);
    return result;
}
