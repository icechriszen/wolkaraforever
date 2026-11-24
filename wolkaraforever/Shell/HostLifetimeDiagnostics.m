#import <Foundation/Foundation.h>
#import "HostLifetimeDiagnostics.h"
#include <fcntl.h>
#include <mach/mach.h>
#include <math.h>
#include <os/proc.h>
#include <stdarg.h>
#include <stdatomic.h>
#include <stdio.h>
#include <time.h>
#include <unistd.h>
#include <TargetConditionals.h>
#ifndef WK_HOST_DIAGNOSTICS
#define WK_HOST_DIAGNOSTICS 0
#endif
static int diagnosticFD=-1;
static atomic_bool active, attempted;
static atomic_uint_fast64_t queuedAt, lastDelay;
static dispatch_source_t sampler;
static uint64_t milliseconds(void) {
    struct timespec now={0}; clock_gettime(CLOCK_MONOTONIC,&now);
    return (uint64_t)now.tv_sec*1000+(uint64_t)now.tv_nsec/1000000;
}
static void record(const char *format, ...) {
    if(diagnosticFD<0)return;
    char line[640];
    int prefix=snprintf(line,sizeof line,"uptime_ms=%llu ",(unsigned long long)milliseconds());
    if(prefix<0 || (size_t)prefix>=sizeof line)return;
    va_list args; va_start(args,format);
    int count=vsnprintf(line+prefix,sizeof line-(size_t)prefix,format,args);va_end(args);
    if(count<0)return;
    size_t length=(size_t)prefix+(size_t)count;
    if(length>=sizeof line-1)length=sizeof line-2;
    line[length++]='\n';
    (void)write(diagnosticFD,line,length);
}
bool WKHostDiagnosticsEnabled(void) {
    return WK_HOST_DIAGNOSTICS ||
        [NSProcessInfo.processInfo.arguments containsObject:@"--host-lifetime-diagnostics"];
}
void WKHostDiagnosticsCheckpoint(const char *event) {
    if(atomic_load(&active))record("event=%s",event);
}
void WKHostDiagnosticsMemory(const char *event) {
    if(!atomic_load(&active))return;
    task_vm_info_data_t info={0};mach_msg_type_number_t count=TASK_VM_INFO_COUNT;
    kern_return_t status=task_info(mach_task_self(),TASK_VM_INFO,(task_info_t)&info,&count);
    size_t available=0;
#if TARGET_OS_IPHONE
    available=os_proc_available_memory();
#endif
    uint64_t queued=atomic_load(&queuedAt);
    uint64_t pending=queued?milliseconds()-queued:0;
    record("event=%s memory_status=%d footprint=%llu resident=%llu available=%zu main_pending_ms=%llu main_last_delay_ms=%llu",
        event,status,(unsigned long long)info.phys_footprint,(unsigned long long)info.resident_size,
        available,(unsigned long long)pending,(unsigned long long)atomic_load(&lastDelay));
}
bool WKHostDiagnosticsStart(const char *path,double interval,unsigned samples) {
    if(!path || !*path || !isfinite(interval) || interval<0.01 || interval>60 || !samples || samples>1200)return false;
    // A native game session belongs to one process. Do not truncate its evidence
    // if a failed startup asks again in the same process.
    if(atomic_exchange(&attempted,true))return false;
    diagnosticFD=open(path,O_WRONLY|O_CREAT|O_TRUNC|O_APPEND|O_CLOEXEC,0600);
    if(diagnosticFD<0)return false;
    atomic_store(&active,true);
    record("event=begin mode=developer-service interval_ms=%.0f samples=%u",interval*1000,samples);
    WKHostDiagnosticsMemory("startup");
    dispatch_queue_t queue=dispatch_queue_create("wolkara.host-lifetime",DISPATCH_QUEUE_SERIAL);
    sampler=dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,0,0,queue);
    uint64_t nanos=(uint64_t)(interval*NSEC_PER_SEC);
    dispatch_source_set_timer(sampler,dispatch_time(DISPATCH_TIME_NOW,nanos),nanos,nanos/10);
    __block unsigned ticks=0;
    dispatch_source_set_event_handler(sampler,^{
        if(!atomic_load(&active)) { dispatch_source_cancel(sampler);return; }
        WKHostDiagnosticsMemory("sample");
        uint_fast64_t expected=0, queued=milliseconds();
        if(atomic_compare_exchange_strong(&queuedAt,&expected,queued)) {
            dispatch_async(dispatch_get_main_queue(),^{
                atomic_store(&lastDelay,milliseconds()-queued);
                atomic_store(&queuedAt,0);
            });
        }
        if(++ticks>=samples) {
            record("event=sampling-limit");
            dispatch_source_cancel(sampler);
        }
    });
    dispatch_resume(sampler);
    return true;
}
void WKHostDiagnosticsFinish(int code) {
    // Stop after a normal return. Fatal exits keep the last completed sample;
    // this module installs no exit observer or signal handler.
    if(atomic_exchange(&active,false))record("event=return code=%d",code);
}
