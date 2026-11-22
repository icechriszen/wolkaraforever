#include <string>
#include <thread>
static std::string *kept;
extern "C" void host_before() {
    kept=new std::string(4096,'h');
    std::thread([]{std::string value(8192,'a');if(value[0]!='a')std::terminate();}).join();
}
extern "C" int host_after() {
    kept->append(4096,'s');
    bool ok=kept->size()==8192 && (*kept)[0]=='h' && kept->back()=='s';
    delete kept;kept=nullptr;
    std::thread([]{std::string value(8192,'b');if(value.back()!='b')std::terminate();}).join();
    return ok?0:1;
}
