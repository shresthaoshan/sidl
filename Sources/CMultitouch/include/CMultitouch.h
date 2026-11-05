#ifndef CMULTITOUCH_H
#define CMULTITOUCH_H

// Layout of the private MultitouchSupport contact struct (reverse engineered).
typedef struct { float x, y; } MTPoint;
typedef struct { MTPoint position, velocity; } MTVector;

typedef struct {
    int frame;
    double timestamp;
    int identifier;
    int state;      // 1 = not tracking ... 4 = touching, 7 = leaving
    int fingerId;
    int handId;
    MTVector normalized; // position 0..1, origin bottom-left
    float size;
    int zero1;
    float angle;
    float majorAxis;
    float minorAxis;
    MTVector mm;
    int zero2[2];
    float unk2;
} MTTouch;

#include <stdint.h>

// `device` identifies the trackpad that sent the frame. It stays the same until the next mt_start.
typedef void (*MTFrameCallback)(uintptr_t device, const MTTouch *touches, int count, double timestamp);

// Starts all multitouch devices connected now. Stops devices from an earlier call first.
// Returns the number of devices started, or -1 on load failure.
int mt_start(MTFrameCallback callback);
void mt_stop(void);

// Plays haptic waveform `actuation` on the trackpad `device` (from the frame callback).
// Returns 0 on success. Call it on the frame callback thread, while `device` is valid.
int mt_actuate(uintptr_t device, int32_t actuation);

// Size of the default trackpad's touch surface, in 1/100 mm. Returns 0 on success.
int mt_surface_size(int32_t *width, int32_t *height);

#endif
