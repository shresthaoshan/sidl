#include "CMultitouch.h"
#include <CoreFoundation/CoreFoundation.h>
#include <dlfcn.h>

typedef void *MTDeviceRef;
typedef int (*MTContactCallback)(MTDeviceRef, MTTouch *, int, double, int);

static CFArrayRef (*MTDeviceCreateList)(void);
static void (*MTRegisterContactFrameCallback)(MTDeviceRef, MTContactCallback);
static void (*MTDeviceStart)(MTDeviceRef, int);
static void (*MTDeviceStop)(MTDeviceRef);

static CFArrayRef devices;
static MTFrameCallback userCallback;

static int contactCallback(MTDeviceRef device, MTTouch *touches, int count, double timestamp, int frame) {
    if (userCallback) userCallback(touches, count, timestamp);
    return 0;
}

int mt_start(MTFrameCallback callback) {
    void *lib = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_NOW);
    if (!lib) return -1;
    MTDeviceCreateList = dlsym(lib, "MTDeviceCreateList");
    MTRegisterContactFrameCallback = dlsym(lib, "MTRegisterContactFrameCallback");
    MTDeviceStart = dlsym(lib, "MTDeviceStart");
    MTDeviceStop = dlsym(lib, "MTDeviceStop");
    if (!MTDeviceCreateList || !MTRegisterContactFrameCallback || !MTDeviceStart || !MTDeviceStop) return -1;

    userCallback = callback;
    devices = MTDeviceCreateList();
    CFIndex n = devices ? CFArrayGetCount(devices) : 0;
    for (CFIndex i = 0; i < n; i++) {
        MTDeviceRef dev = (MTDeviceRef)CFArrayGetValueAtIndex(devices, i);
        MTRegisterContactFrameCallback(dev, contactCallback);
        MTDeviceStart(dev, 0);
    }
    return (int)n;
}

void mt_stop(void) {
    if (!devices) return;
    for (CFIndex i = 0; i < CFArrayGetCount(devices); i++)
        MTDeviceStop((MTDeviceRef)CFArrayGetValueAtIndex(devices, i));
    CFRelease(devices);
    devices = NULL;
}
