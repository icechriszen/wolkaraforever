#include "GuestTLS.h"
#include <assert.h>
#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
static GuestTLS tls;
static uint64_t descriptor[3];
static uintptr_t pointers[16];
static void *worker(void *arg) {
    size_t i=(size_t)arg;
    unsigned char *storage=gt_address(&tls,descriptor);
    assert(storage && storage[0]==42);
    pointers[i]=(uintptr_t)storage;
    storage[0]=(unsigned char)i;
    assert(gt_address(&tls,descriptor)==storage);
    return NULL;
}
int main(void) {
    FILE *capture=tmpfile();assert(capture);
    int original=dup(STDERR_FILENO);assert(original>=0);
    assert(dup2(fileno(capture),STDERR_FILENO)>=0);
    unsigned char initial[128]={42};
    assert(gt_create(&tls,initial,sizeof initial,64,(uintptr_t)descriptor,sizeof descriptor));
    // Disabled by default, including the destructor.
    worker(NULL);gt_destroy(&tls);
    assert(ftell(capture)==0);
    assert(gt_create(&tls,initial,sizeof initial,64,(uintptr_t)descriptor,sizeof descriptor));
    gt_set_lifetime_trace(true);
    pthread_t workers[16];
    for(size_t i=0;i<16;i++)assert(!pthread_create(&workers[i],NULL,worker,(void *)i));
    for(size_t i=0;i<16;i++)assert(!pthread_join(workers[i],NULL));
    assert(dup2(original,STDERR_FILENO)>=0);close(original);
    rewind(capture);
    char line[256];unsigned allocations=0,begins=0,ends=0;
    struct { uintptr_t address; unsigned long long thread; int state; } records[16]={0};
    while(fgets(line,sizeof line,capture)) {
        unsigned long long uptime,thread;uintptr_t address;size_t size;char event[32];
        assert(sscanf(line,"[host-tls] uptime_ms=%llu event=%31s thread=%llu pointer=0x%" SCNxPTR " size=%zu",
                      &uptime,event,&thread,&address,&size)==5);
        if(!strcmp(event,"allocate")) {
            assert(allocations<16 && size==128);
            records[allocations].address=address;records[allocations].thread=thread;records[allocations++].state=1;
        } else {
            size_t i=0;while(i<allocations && (records[i].address!=address || records[i].thread!=thread))i++;
            assert(i<allocations && size==0);
            if(!strcmp(event,"release-begin")) { assert(records[i].state==1);records[i].state=2;begins++; }
            else { assert(!strcmp(event,"release-end") && records[i].state==2);records[i].state=3;ends++; }
        }
    }
    assert(allocations==16 && begins==16 && ends==16);
    for(size_t i=0;i<16;i++)assert(records[i].state==3);
    gt_set_lifetime_trace(false);gt_destroy(&tls);fclose(capture);
    puts("PASS: Mac pthread exit records pair every runtime-owned TLS allocation and release; disabled mode stays silent");
}
