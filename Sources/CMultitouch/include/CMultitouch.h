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

typedef void (*MTFrameCallback)(const MTTouch *touches, int count, double timestamp);

// Starts all multitouch devices. Returns the number of devices started, or -1 on load failure.
int mt_start(MTFrameCallback callback);
void mt_stop(void);

#endif
