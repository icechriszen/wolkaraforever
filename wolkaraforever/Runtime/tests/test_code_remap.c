#include "CodeRemap.h"
#include <assert.h>
#include <errno.h>
#include <mach/mach.h>
#include <sys/mman.h>
#include <unistd.h>

int main(void) {
    size_t size=(size_t)getpagesize()*2;
    void *rx=mmap(NULL,size,PROT_READ|PROT_WRITE,MAP_ANON|MAP_PRIVATE,-1,0);
    assert(rx!=MAP_FAILED);
    vm_address_t rw=0;vm_prot_t current=0,maximum=0;
    assert(vm_remap(mach_task_self(),&rw,size,0,VM_FLAGS_ANYWHERE,mach_task_self(),
        (vm_address_t)rx,false,&current,&maximum,VM_INHERIT_NONE)==KERN_SUCCESS);
    assert(!mprotect(rx,size,PROT_READ|PROT_EXEC));
    NativeCodeMemory memory={.executable=rx,.writable=(void *)rw,.size=size,.published=true};
    assert(wk_code_remap_probe(&memory,stdout));
    errno=0;assert(wk_code_remap(rx,rx,size,PROT_READ|PROT_EXEC)==-1 && errno==EINVAL);
    assert(wk_code_remap(rx,(void *)rw,size,PROT_READ|PROT_WRITE|PROT_EXEC)==-1);
    assert(wk_code_remap((char *)rx+1,(void *)rw,size,PROT_READ|PROT_EXEC)==-1);
    assert(!munmap(rx,size));assert(vm_deallocate(mach_task_self(),rw,size)==KERN_SUCCESS);
    puts("PASS: prepared-page remapping, repeated execution, adjacent-page preservation and invalid requests (Mac arm64)");
}
