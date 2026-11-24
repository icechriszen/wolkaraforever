#include "OwnedCxx.h"
#include <atomic>
#include <cstdlib>
#include <new>
#include <string>
static_assert(_LIBCPP_VERSION == 220106, "Revalidate vendored libc++ against this SDK before building");
static_assert(_LIBCPP_ABI_VERSION == 1 && sizeof(std::string)==24 && alignof(std::string)==8,
              "The isolated adapter requires the tested Darwin arm64 libc++ ABI");
static std::atomic_flag configuring=ATOMIC_FLAG_INIT;
static std::atomic<bool> ready{false};
static WKCppAllocate allocator;
static WKCppRelease releaser;
static WKCppEvent event;
static std::atomic<uint64_t> allocations{0}, releases{0};
static int configure(WKCppAllocate allocate,WKCppRelease release,WKCppEvent observer) {
    if(!allocate || !release || configuring.test_and_set(std::memory_order_acquire))return 0;
    allocator=allocate;releaser=release;event=observer;
    ready.store(true,std::memory_order_release);return 1;
}
void *operator new(std::size_t size) {
    if(!ready.load(std::memory_order_acquire))std::abort();
    if(allocations.fetch_add(1,std::memory_order_relaxed)==0 && event)event(1);
    return allocator(size);
}
void operator delete(void *pointer) noexcept {
    if(!pointer)return;
    if(!ready.load(std::memory_order_acquire))std::abort();
    if(releases.fetch_add(1,std::memory_order_relaxed)==0 && event)event(2);
    releaser(pointer);
}
void *operator new[](std::size_t size) { return ::operator new(size); }
void operator delete[](void *pointer) noexcept { ::operator delete(pointer); }
void operator delete(void *pointer,std::size_t) noexcept { ::operator delete(pointer); }
void operator delete[](void *pointer,std::size_t) noexcept { ::operator delete(pointer); }
void *operator new(std::size_t size,const std::nothrow_t&) noexcept {
    try { return ::operator new(size); } catch(...) { return nullptr; }
}
void *operator new[](std::size_t size,const std::nothrow_t&) noexcept {
    try { return ::operator new(size); } catch(...) { return nullptr; }
}
void operator delete(void *pointer,const std::nothrow_t&) noexcept { ::operator delete(pointer); }
void operator delete[](void *pointer,const std::nothrow_t&) noexcept { ::operator delete(pointer); }
extern "C" void *WKLookupOwnedCxx(const char *);
static void counts(uint64_t *allocated,uint64_t *released) {
    if(allocated)*allocated=allocations.load(std::memory_order_relaxed);
    if(released)*released=releases.load(std::memory_order_relaxed);
}
extern "C" const WKOwnedCxxAPI *WKGetOwnedCxxAPI() {
    static const WKOwnedCxxAPI api={1,_LIBCPP_VERSION,sizeof(std::string),alignof(std::string),configure,WKLookupOwnedCxx,counts};
    return &api;
}
