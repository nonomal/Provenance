//
//  PVStellaCPP.hxx
//
//
//  Created by Joseph Mattiello on 5/30/24.
//

#ifndef PVStellaCPP_hxx
#define PVStellaCPP_hxx

#import <Foundation/Foundation.h>
#import <libstella/libstella.h>
#import <libstella/libretro/libretro.h>
@import libstella;

#warning "This needs to be fixed"
// This should show up from the imports above,
// but XCode and spm still complain?
#define RETRO_DEVICE_ID_JOYPAD_B        0
#define RETRO_DEVICE_ID_JOYPAD_Y        1
#define RETRO_DEVICE_ID_JOYPAD_SELECT   2
#define RETRO_DEVICE_ID_JOYPAD_START    3
#define RETRO_DEVICE_ID_JOYPAD_UP       4
#define RETRO_DEVICE_ID_JOYPAD_DOWN     5
#define RETRO_DEVICE_ID_JOYPAD_LEFT     6
#define RETRO_DEVICE_ID_JOYPAD_RIGHT    7
#define RETRO_DEVICE_ID_JOYPAD_A        8
#define RETRO_DEVICE_ID_JOYPAD_X        9
#define RETRO_DEVICE_ID_JOYPAD_L       10
#define RETRO_DEVICE_ID_JOYPAD_R       11
#define RETRO_DEVICE_ID_JOYPAD_L2      12
#define RETRO_DEVICE_ID_JOYPAD_R2      13
#define RETRO_DEVICE_ID_JOYPAD_L3      14
#define RETRO_DEVICE_ID_JOYPAD_R3      15

#define RETRO_DEVICE_ID_JOYPAD_MASK    256
// END Warning


// Size and screen buffer consants
typedef                         uint32_t     stellabuffer_t;
#define STELLA_PITCH_SHIFT      2
#define STELLA_PIXEL_TYPE       GL_UNSIGNED_BYTE
#if TARGET_OS_MACCATALYST
#define STELLA_PIXEL_FORMAT     GL_UNSIGNED_SHORT_5_6_5
#define STELLA_INTERNAL_FORMAT  GL_UNSIGNED_SHORT_5_6_5
#else
#define STELLA_PIXEL_FORMAT     GL_RGB565
#define STELLA_INTERNAL_FORMAT  GL_RGB565
#endif

#define STELLA_WIDTH 160
#define STELLA_HEIGHT 256

const NSUInteger A2600EmulatorValues[] = {
    RETRO_DEVICE_ID_JOYPAD_UP,
    RETRO_DEVICE_ID_JOYPAD_DOWN,
    RETRO_DEVICE_ID_JOYPAD_LEFT,
    RETRO_DEVICE_ID_JOYPAD_RIGHT,
    RETRO_DEVICE_ID_JOYPAD_B,
    RETRO_DEVICE_ID_JOYPAD_L,
    RETRO_DEVICE_ID_JOYPAD_L2,
    RETRO_DEVICE_ID_JOYPAD_R,
    RETRO_DEVICE_ID_JOYPAD_R2,
    RETRO_DEVICE_ID_JOYPAD_START,
    RETRO_DEVICE_ID_JOYPAD_SELECT
};

#define NUMBER_OF_PADS 2
#define NUMBER_OF_PAD_INPUTS 16

#endif /* PVStellaCPP_hxx */