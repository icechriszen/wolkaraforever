#import <Foundation/Foundation.h>
#import "HostLifetimeDiagnostics.h"
#include <assert.h>
#include <math.h>
#include <unistd.h>
#include <sys/stat.h>

int main(void) {
    @autoreleasepool {
        assert(!WKHostDiagnosticsEnabled());
        NSString *directory=[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
        assert([NSFileManager.defaultManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil]);
        NSString *path=[directory stringByAppendingPathComponent:@"host.log"];
        assert(!WKHostDiagnosticsStart(NULL,0.025,20));
        assert(!WKHostDiagnosticsStart(path.fileSystemRepresentation,NAN,20));
        assert(!WKHostDiagnosticsStart(path.fileSystemRepresentation,0.025,0));
        assert(WKHostDiagnosticsStart(path.fileSystemRepresentation,0.025,20));
        // Hold only our fixture's main thread. The sampler must keep reporting it.
        usleep(250000);
        NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:3];
        NSString *log=nil;
        do {
            [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.025]];
            log=[NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
        } while (![log containsString:@"event=sampling-limit"] && deadline.timeIntervalSinceNow>0);
        assert([log containsString:@"event=sampling-limit"]);
        assert([log containsString:@"event=startup memory_status=0"]);
        NSRegularExpression *pending=[NSRegularExpression regularExpressionWithPattern:@"main_pending_ms=[1-9][0-9]+" options:0 error:nil];
        assert([pending numberOfMatchesInString:log options:0 range:NSMakeRange(0,log.length)]>0);
        assert([log componentsSeparatedByString:@"event=sample "].count-1==20);
        assert([log componentsSeparatedByString:@"event=begin "].count-1==1);
        WKHostDiagnosticsCheckpoint("fixture-finished");
        WKHostDiagnosticsFinish(7);
        WKHostDiagnosticsCheckpoint("must-not-record");
        assert(!WKHostDiagnosticsStart(path.fileSystemRepresentation,0.025,20));
        log=[NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
        assert([log containsString:@"event=fixture-finished"]);
        assert([log containsString:@"event=return code=7"]);
        assert(![log containsString:@"must-not-record"]);
        struct stat st={0};assert(!stat(path.fileSystemRepresentation,&st));
        assert((st.st_mode&0777)==0600);
        assert([NSFileManager.defaultManager removeItemAtPath:directory error:nil]);
        puts("PASS: Mac host counters, blocked-main heartbeat, sampling bound, single-session retention and opt-in default");
    }
}
