#include "MemoryTrace.h"
#include <assert.h>
#include <errno.h>
#include <pthread.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
static WKMemoryEvent map(uintptr_t at) {
    return (WKMemoryEvent){.operation=WK_MEMORY_MAP,.result=at,.size=0x4000,
        .protection=PROT_READ|PROT_WRITE,.flags=MAP_PRIVATE|MAP_ANON,.caller_image=2,.caller_offset=0x1234};
}
static WKMemoryEvent failure(uintptr_t at) {
    return (WKMemoryEvent){.operation=WK_MEMORY_PROTECT,.address=at,.size=0x4000,
        .protection=PROT_READ|PROT_EXEC,.result=(uintptr_t)-1,.failed=true,.error=EACCES};
}
static char *read_log(FILE *f) {
    fflush(f); long end=ftell(f); rewind(f);
    char *s=calloc((size_t)end+1,1);assert(s);assert(fread(s,1,(size_t)end,f)==(size_t)end);
    fseek(f,0,SEEK_END);return s;
}
static void *worker(void *unused) {
    (void)unused;
    for(unsigned i=0;i<2000;i++){errno=EDOM;wk_memory_trace_record(map(0x800000+i*0x4000));assert(errno==EDOM);}
    return NULL;
}
int main(void) {
    FILE *f=tmpfile();assert(f);errno=ERANGE;wk_memory_trace_start(f);assert(errno==ERANGE);
    wk_memory_trace_record(map(0x100000));errno=EACCES;wk_memory_trace_record(failure(0x100000));assert(errno==EACCES);
    char *s=read_log(f);assert(strstr(s,"origin seq=0") && strstr(s,"caller=2+0x1234"));free(s);
    // A successful partial unmap must prevent a stale origin match.
    wk_memory_trace_record((WKMemoryEvent){.operation=WK_MEMORY_UNMAP,.address=0x101000,.size=0x1000});
    wk_memory_trace_record(failure(0x100000));s=read_log(f);assert(strstr(s,"origin=unknown"));free(s);
    // Failed unmap does not invalidate the mapping.
    wk_memory_trace_start(f);wk_memory_trace_record(map(0x200000));
    wk_memory_trace_record((WKMemoryEvent){.operation=WK_MEMORY_UNMAP,.address=0x200000,.size=0x4000,.failed=true,.error=EINVAL});
    wk_memory_trace_record(failure(0x200000));s=read_log(f);assert(strstr(s,"origin seq=0 address=0x200000"));free(s);
    // Wrap and concurrent traffic remain bounded; errno is thread-local and unchanged.
    pthread_t threads[4];for(int i=0;i<4;i++)assert(!pthread_create(&threads[i],NULL,worker,NULL));
    for(int i=0;i<4;i++)assert(!pthread_join(threads[i],NULL));
    wk_memory_trace_record(failure(0x200000));
    // Executable success budget does not consume the separate failure budget.
    wk_memory_trace_start(f);
    for(unsigned i=0;i<WK_MEMORY_REPORT_LIMIT+20;i++) {
        WKMemoryEvent e=map(0x300000);e.protection=PROT_READ|PROT_EXEC;wk_memory_trace_record(e);
    }
    wk_memory_trace_record(failure(0x300000));s=read_log(f);assert(strstr(s,"seq=84 op=mprotect"));free(s);
    wk_memory_trace_start(NULL);fclose(f);puts("memory trace: origin, invalidation, bounds, concurrency and errno PASS");
}
