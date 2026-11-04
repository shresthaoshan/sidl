#include "CMultitouch.h"
#include <CoreFoundation/CoreFoundation.h>
#include <dlfcn.h>

typedef void *MTDeviceRef;
typedef int (*MTContactCallback)(MTDeviceRef, MTTouch *, int, double, int);

static CFArrayRef (*MTDeviceCreateList)(void);
static void (*MTRegisterContactFrameCallback)(MTDeviceRef, MTContactCallback);
static void (*MTUnregisterContactFrameCallback)(MTDeviceRef, MTContactCallback);  // optional
static void (*MTDeviceStart)(MTDeviceRef, int);
static void (*MTDeviceStop)(MTDeviceRef);

static CFArrayRef devices;
static MTFrameCallback userCallback;

static int contactCallback(MTDeviceRef device, MTTouch *touches, int count, double timestamp, int frame) {
    MTFrameCallback cb = userCallback;
    if (cb) cb((uintptr_t)device, touches, count, timestamp);
    return 0;
}

static int load(void) {
    if (MTDeviceCreateList) return 1;
    void *lib = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_NOW);
    if (!lib) return 0;
    MTDeviceCreateList = dlsym(lib, "MTDeviceCreateList");
    MTRegisterContactFrameCallback = dlsym(lib, "MTRegisterContactFrameCallback");
    MTUnregisterContactFrameCallback = dlsym(lib, "MTUnregisterContactFrameCallback");
    MTDeviceStart = dlsym(lib, "MTDeviceStart");
    MTDeviceStop = dlsym(lib, "MTDeviceStop");
    if (!MTDeviceCreateList || !MTRegisterContactFrameCallback || !MTDeviceStart || !MTDeviceStop) {
        MTDeviceCreateList = NULL;
        return 0;
    }
    return 1;
}

int mt_start(MTFrameCallback callback) {
    if (!load()) return -1;
    mt_stop();

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
    for (CFIndex i = 0; i < CFArrayGetCount(devices); i++) {
        MTDeviceRef dev = (MTDeviceRef)CFArrayGetValueAtIndex(devices, i);
        if (MTUnregisterContactFrameCallback) MTUnregisterContactFrameCallback(dev, contactCallback);
        MTDeviceStop(dev);
    }
    CFRelease(devices);
    devices = NULL;
}

// Haptics through the trackpad's actuator. The public NSHapticFeedbackManager has no strength setting.
static OSStatus (*MTDeviceGetDeviceID)(MTDeviceRef, uint64_t *);
static CFTypeRef (*MTActuatorCreateFromDeviceID)(uint64_t);
static int (*MTActuatorOpen)(CFTypeRef);
static int (*MTActuatorClose)(CFTypeRef);
static int (*MTActuatorActuate)(CFTypeRef, int32_t, uint32_t, float, float);

int mt_actuate(uintptr_t device, int32_t actuation) {
    if (!MTActuatorActuate) {
        void *lib = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_NOW);
        if (!lib) return -1;
        MTDeviceGetDeviceID = dlsym(lib, "MTDeviceGetDeviceID");
        MTActuatorCreateFromDeviceID = dlsym(lib, "MTActuatorCreateFromDeviceID");
        MTActuatorOpen = dlsym(lib, "MTActuatorOpen");
        MTActuatorClose = dlsym(lib, "MTActuatorClose");
        MTActuatorActuate = dlsym(lib, "MTActuatorActuate");
        if (!MTDeviceGetDeviceID || !MTActuatorCreateFromDeviceID || !MTActuatorOpen || !MTActuatorClose || !MTActuatorActuate) {
            MTActuatorActuate = NULL;
            return -1;
        }
    }
    uint64_t id = 0;
    if (MTDeviceGetDeviceID((MTDeviceRef)device, &id) != 0) return -2;
    CFTypeRef actuator = MTActuatorCreateFromDeviceID(id);
    if (!actuator) return -3;  // this trackpad has no actuator (not Force Touch)
    // ponytail: opens the actuator on each swipe, cache one per device if this is slow
    int result = MTActuatorOpen(actuator);
    if (result == 0) {
        result = MTActuatorActuate(actuator, actuation, 0, 0, 0);
        MTActuatorClose(actuator);
    }
    CFRelease(actuator);
    return result;
}
