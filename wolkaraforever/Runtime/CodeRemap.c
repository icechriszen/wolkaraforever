#include "CodeRemap.h"
#include <errno.h>
#include <libkern/OSCacheControl.h>
#include <mach/mach.h>
#include <stdint.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>

int wk_code_remap(void *target, const void *source, size_t size, int protection) {
    size_t page=(size_t)getpagesize();
    uintptr_t dst=(uintptr_t)target, src=(uintptr_t)source;
    if(!dst || !src || !size || dst%page || src%page || size%page ||
       dst>UINTPTR_MAX-size || src>UINTPTR_MAX-size ||
       (dst<src+size && src<dst+size) ||
       (protection!=(PROT_READ|PROT_WRITE) && protection!=(PROT_READ|PROT_EXEC))) {
        errno=EINVAL;return -1;
    }
    vm_address_t address=dst;
    vm_prot_t current=0, maximum=0;
    kern_return_t result=vm_remap(mach_task_self(),&address,size,0,
        VM_FLAGS_FIXED|VM_FLAGS_OVERWRITE,mach_task_self(),src,false,
        &current,&maximum,VM_INHERIT_NONE);
    if(result!=KERN_SUCCESS) { errno=result==KERN_NO_SPACE?ENOMEM:EACCES;return -1; }
    if(address!=dst || current!=protection) { errno=EACCES;return -1; }
    if(protection&PROT_EXEC)sys_icache_invalidate(target,size);
    return 0;
}

bool wk_code_remap_probe(NativeCodeMemory *memory, FILE *log) {
    size_t page=(size_t)getpagesize(), size=page*2;
    if(!memory || !memory->published || memory->quarantined || memory->size<size || !log)return false;
    void *target=mmap(NULL,size,PROT_READ|PROT_WRITE,MAP_ANON|MAP_PRIVATE,-1,0);
    if(target==MAP_FAILED)return false;
    bool ok=false;
    fprintf(log,"[code-remap-probe] begin; prepared pages; host fixtures only\n");fflush(log);
    uint32_t sample[]={0x52800540,0xd65f03c0}; // mov w0,#42; ret
    memcpy(target,sample,sizeof sample);
    memcpy((char *)target+page,sample,sizeof sample);
    memcpy(memory->writable,target,size);
    sys_dcache_flush(memory->writable,size);
    if(wk_code_remap(target,memory->executable,size,PROT_READ|PROT_EXEC))goto done;
    fprintf(log,"[code-remap-probe] RX alias at original address; calling return-42\n");fflush(log);
    if(((int (*)(void))target)()!=42 || ((int (*)(void))((char *)target+page))()!=42)goto done;
    fprintf(log,"[code-remap-probe] initial execute PASS\n");fflush(log);
    for(unsigned i=0;i<128;i++) {
        if(wk_code_remap(target,memory->writable,page,PROT_READ|PROT_WRITE))goto done;
        *(uint32_t *)target=0x52800000|(i<<5);
        sys_dcache_flush(target,page);
        if(wk_code_remap(target,memory->executable,page,PROT_READ|PROT_EXEC))goto done;
        if(((int (*)(void))target)()!=(int)i || ((int (*)(void))((char *)target+page))()!=42)goto done;
    }
    fprintf(log,"[code-remap-probe] 128 RW/RX cycles and unchanged adjacent page PASS\n");fflush(log);
    ok=true;
done:
    fprintf(log,"[code-remap-probe] result=%s errno=%d\n",ok?"PASS":"FAIL",ok?0:errno);fflush(log);
    munmap(target,size);
    return ok;
}
