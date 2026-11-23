#include "ArenaMapping.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
static void *map_using_policy(void *hint,size_t size,int flags) {
    if(wk_arena_mapping_replacement(flags)) {memset(hint,0,size);return hint;}
    return mmap(hint,size,PROT_READ|PROT_WRITE,flags,-1,0);
}
int main(void) {
    size_t page=(size_t)getpagesize();
    unsigned char *arena=mmap(NULL,page*3,PROT_READ|PROT_WRITE,MAP_ANON|MAP_PRIVATE,-1,0);
    assert(arena!=MAP_FAILED);memset(arena,0xa5,page*3);
    // These are actual OS mappings. A hint into occupied memory must relocate,
    // leaving all bytes and neighboring pages in the original mapping intact.
    void *p=map_using_policy(arena+page,page,MAP_ANON|MAP_PRIVATE);
    assert(p!=MAP_FAILED && p!=arena+page);
    memset(p,0x5a,page);
    for(size_t i=0;i<page*3;i++)assert(arena[i]==0xa5);
    assert(!munmap(p,page));
    // Existing explicit replacement and startup MAP_JIT compatibility remain.
    p=map_using_policy(arena+page,page,MAP_ANON|MAP_PRIVATE|MAP_FIXED);
    assert(p==arena+page && arena[page]==0 && arena[0]==0xa5 && arena[2*page]==0xa5);
    assert(wk_arena_mapping_replacement(MAP_ANON|MAP_PRIVATE|MAP_JIT));
    assert(!wk_arena_mapping_replacement(MAP_ANON|MAP_PRIVATE));
    assert(!munmap(arena,page*3));
    puts("arena mapping: real non-fixed hint relocation and existing-byte preservation PASS");
}
