#pragma once
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>

enum { WK_MEMORY_HISTORY = 512, WK_MEMORY_REPORT_LIMIT = 64 };
typedef enum { WK_MEMORY_MAP, WK_MEMORY_PROTECT, WK_MEMORY_UNMAP } WKMemoryOperation;
// Only API arguments/results and loader metadata. Never dereference these addresses.
typedef struct {
    WKMemoryOperation operation;
    uintptr_t address, result, caller_offset;
    size_t size;
    int protection, flags, error, caller_image;
    bool arena, failed;
} WKMemoryEvent;
void wk_memory_trace_start(FILE *log);
void wk_memory_trace_record(WKMemoryEvent event); // Preserves errno; bounded, thread-safe.
