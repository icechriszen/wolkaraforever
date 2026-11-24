#pragma once
#include <stddef.h>
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
// The module owns no application state before configuration. Its callbacks and
// the application's mappings remain valid for this process's only native run.
typedef void *(*WKCppAllocate)(size_t);
typedef void (*WKCppRelease)(void *);
typedef void (*WKCppEvent)(unsigned); // 1: first allocation, 2: first release; no pointers/data
struct WKOwnedCxxAPI {
    uint32_t version, libcxx_version;
    size_t string_size, string_alignment;
    int (*configure)(WKCppAllocate, WKCppRelease, WKCppEvent);
    void *(*lookup)(const char *); // dlsym spelling, without Mach-O's leading underscore
    void (*counts)(uint64_t *, uint64_t *);
};
__attribute__((visibility("default"))) const struct WKOwnedCxxAPI *WKGetOwnedCxxAPI(void);
#ifdef __cplusplus
}
#endif
