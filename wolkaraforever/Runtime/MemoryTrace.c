#include "MemoryTrace.h"
#include <errno.h>
#include <inttypes.h>
#include <pthread.h>
#include <string.h>
#include <sys/mman.h>

static pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;
static FILE *output;
static WKMemoryEvent history[WK_MEMORY_HISTORY];
static uint64_t sequence;
static unsigned reports, failures;
static bool overlap(uintptr_t a, size_t n, uintptr_t b, size_t m) {
    if (!n || !m) return false;
    return a <= b ? b-a < n : a-b < m;
}
static bool contains(uintptr_t a, size_t n, uintptr_t b, size_t m) {
    return b >= a && b-a <= n && m <= n-(b-a);
}
void wk_memory_trace_start(FILE *log) {
    int saved=errno;
    pthread_mutex_lock(&lock);
    output=log; sequence=0; reports=0; failures=0;
    memset(history,0,sizeof history);
    if(output) {
        fprintf(output,"[memory-permission] enabled; history=%u reports=%u; caller image 0=host/unknown 1=main 2+=carried; metadata only\n",
                WK_MEMORY_HISTORY,WK_MEMORY_REPORT_LIMIT);
        fflush(output);
    }
    pthread_mutex_unlock(&lock);
    errno=saved;
}
void wk_memory_trace_record(WKMemoryEvent e) {
    int saved=errno;
    pthread_mutex_lock(&lock);
    if(!output) goto done;
    // Retain a separate failure budget so successful executable requests cannot hide a failure.
    bool report=e.failed ? failures<8 :
        (e.operation!=WK_MEMORY_UNMAP && (e.protection&PROT_EXEC) && reports<WK_MEMORY_REPORT_LIMIT);
    if(report) {
        if(e.failed) failures++; else reports++;
        const char *names[]={"mmap","mprotect","munmap"};
        fprintf(output,"[memory-permission] seq=%" PRIu64 " op=%s address=%#" PRIxPTR " size=%#zx prot=%d flags=%#x result=%#" PRIxPTR " errno=%d arena=%d caller=%d+%#" PRIxPTR "\n",
            sequence,names[e.operation],e.address,e.size,e.protection,e.flags,e.result,
            e.error,e.arena,e.caller_image,e.caller_offset);
        if(e.operation==WK_MEMORY_PROTECT) {
            bool found=false;
            uint64_t count=sequence<WK_MEMORY_HISTORY?sequence:WK_MEMORY_HISTORY;
            for(uint64_t i=0;i<count;i++) {
                uint64_t n=sequence-1-i;
                WKMemoryEvent p=history[n%WK_MEMORY_HISTORY];
                if(p.failed || p.operation==WK_MEMORY_PROTECT)continue;
                uintptr_t start=p.operation==WK_MEMORY_MAP?p.result:p.address;
                if(!overlap(start,p.size,e.address,e.size))continue;
                if(p.operation==WK_MEMORY_MAP && contains(start,p.size,e.address,e.size)) {
                    fprintf(output,"[memory-permission] origin seq=%" PRIu64 " requested=%#" PRIxPTR " address=%#" PRIxPTR " size=%#zx prot=%d flags=%#x arena=%d caller=%d+%#" PRIxPTR "\n",
                        n,p.address,start,p.size,p.protection,p.flags,p.arena,p.caller_image,p.caller_offset);
                    found=true;
                }
                break; // A partial unmap/replacement makes older provenance ambiguous.
            }
            if(!found)fprintf(output,"[memory-permission] origin=unknown retained=%" PRIu64 "; no inference about unobserved mappings\n",count);
        }
        fflush(output);
    }
    history[sequence%WK_MEMORY_HISTORY]=e;
    sequence++;
done:
    pthread_mutex_unlock(&lock);
    errno=saved;
}
