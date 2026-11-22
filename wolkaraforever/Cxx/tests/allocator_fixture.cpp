#include <atomic>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <new>
#include <string>
#include <dlfcn.h>
#include <thread>
#include <future>
#include <vector>
static void *owned[1024];
static std::atomic_flag guard=ATOMIC_FLAG_INIT;
static std::atomic<bool> observing{false};
static unsigned allocated, released, foreign;
static void lock() { while(guard.test_and_set(std::memory_order_acquire)){} }
static void unlock() { guard.clear(std::memory_order_release); }
void *operator new(std::size_t n) {
    void *p=std::malloc(n?n:1); if(!p)throw std::bad_alloc();
    if(observing.load()) {
        lock(); bool stored=false;
        for(void *&slot:owned)if(!slot){slot=p;stored=true;break;}
        if(!stored)std::abort(); allocated++; unlock();
    }
    return p;
}
void operator delete(void *p) noexcept {
    if(!p)return;
    if(observing.load()) {
        lock();bool found=false;
        for(void *&slot:owned)if(slot==p){slot=nullptr;found=true;break;}
        if(found)released++;else foreign++;
        unlock();
    }
    std::free(p);
}
void *operator new[](std::size_t n){return ::operator new(n);}
void operator delete[](void *p) noexcept {::operator delete(p);}
extern "C" int fixture_run() {
    observing.store(true);
    {
        std::string s;
        for(unsigned i=0;i<64;i++)s.append(257,static_cast<char>('a'+i%20));
        if(s.size()!=64*257)std::abort();
        s.reserve(32768);
        s.resize(19);
        s.shrink_to_fit();
    }
    observing.store(false);
    unsigned outstanding=0;for(void *p:owned)if(p)outstanding++;
    std::printf("fixture allocations=%u releases=%u untracked_releases=%u outstanding=%u\n",allocated,released,foreign,outstanding);
    return foreign || outstanding;
}
extern "C" int fixture_run_direct() {
    observing.store(true);
    void *p=::operator new(4096);
    std::memset(p,0x5a,4096);
    ::operator delete(p);
    observing.store(false);
    std::printf("direct allocations=%u releases=%u untracked_releases=%u\n",allocated,released,foreign);
    return allocated!=1 || released!=1 || foreign;
}
extern "C" int fixture_run_threads() {
    observing.store(true);
    {
        std::vector<std::thread> workers;
        for(unsigned i=0;i<8;i++)workers.emplace_back([]{
            std::string text(2048,'x');text.append(8192,'y');
            if(text.size()!=10240)std::abort();
        });
        for(auto &worker:workers)worker.join();
        std::promise<int> promise;
        auto future=promise.get_future();
        std::thread worker([&]{promise.set_value_at_thread_exit(42);});
        worker.join();if(future.get()!=42)std::abort();
    }
    observing.store(false);
    unsigned outstanding=0;for(void *p:owned)if(p)outstanding++;
    std::printf("thread allocations=%u releases=%u untracked_releases=%u outstanding=%u\n",allocated,released,foreign,outstanding);
    return foreign || outstanding;
}
#ifndef FIXTURE_DYLIB
int main(int argc,char **){return argc>1?fixture_run_threads():fixture_run();}
#endif
