#pragma once
#include <stdbool.h>
#include <sys/mman.h>

// Ordinary non-fixed mmap addresses are hints, even inside an existing arena.
// Only fixed replacements and the existing MAP_JIT image-rewrite adapter may
// reuse its backing. In particular, RW anonymous hints must never zero live pages.
static inline bool wk_arena_mapping_replacement(int flags) {
    return (flags & MAP_FIXED) || (flags & MAP_JIT);
}
