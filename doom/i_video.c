// Stubbed Video.c

// Emacs style mode select   -*- C++ -*-
//-----------------------------------------------------------------------------
//
// $Id:$
//
// Copyright (C) 1993-1996 by id Software, Inc.
//
// This source is available for distribution and/or modification
// only under the terms of the DOOM Source Code License as
// published by id Software. All rights reserved.
//
// The source is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// FITNESS FOR A PARTICULAR PURPOSE. See the DOOM Source Code License
// for more details.
//
// $Log:$
//
// DESCRIPTION:
//	DOOM graphics stuff for X11, UNIX.
//
//-----------------------------------------------------------------------------

// static const char
// rcsid[] = "$Id: i_x.c,v 1.6 1997/02/03 22:45:10 b1 Exp $";

#include "d_main.h"
#include "doomstat.h"
#include "i_system.h"
#include "m_argv.h"
#include "v_video.h"
#include <netinet/in.h>
#include <stdlib.h>
#include <sys/ipc.h>
#include <sys/shm.h>
#include <unistd.h>

#include "doomdef.h"
#include "z_zone.h"

#define POINTER_WARP_COUNTDOWN 1

#include "DrawFunctions.c"
#include "os_generic.c"

void HandleKey(int keycode, int bDown) {
  //
  int rc;

  switch (rc = keycode) {
  case '4':
    rc = KEY_LEFTARROW;
    break;
  case '6':
    rc = KEY_RIGHTARROW;
    break;
  case '2':
    rc = KEY_DOWNARROW;
    break;
  case '8':
    rc = KEY_UPARROW;
    break;
  case '7':
    rc = KEY_ESCAPE;
    break;
  case '\n':
    rc = KEY_ENTER;
    break;
  case '1':
    rc = KEY_TAB;
    break;
  case '!':
    rc = KEY_F1;
    break;
  case '@':
    rc = KEY_F2;
    break;
  case '#':
    rc = KEY_F3;
    break;
  case '$':
    rc = KEY_F4;
    break;
  case '%':
    rc = KEY_F5;
    break;
  case '^':
    rc = KEY_F6;
    break;
  case '&':
    rc = KEY_F7;
    break;
  case '*':
    rc = KEY_F8;
    break;
  case '(':
    rc = KEY_F9;
    break;
  case ')':
    rc = KEY_F10;
    break;
  case '_':
    rc = KEY_F11;
    break;
  case '+':
    rc = KEY_F12;
    break;

  case '-':
    rc = KEY_BACKSPACE;
    break;

  case 'p':
    rc = KEY_PAUSE;
    break;

  case '=':
    rc = KEY_EQUALS;
    break;

  case ']':
    rc = KEY_MINUS;
    break;

    // case XK_Shift_L:
    // case XK_Shift_R:
    //   rc = KEY_RSHIFT;
    //   break;
    //
    // case XK_Control_L:
    // case XK_Control_R:
    //   rc = KEY_RCTRL;
    //   break;
    //
    // case XK_Alt_L:
    // case XK_Meta_L:
    // case XK_Alt_R:
    // case XK_Meta_R:
    //   rc = KEY_RALT;
    //   break;

  default:
    rc = KEY_ENTER;
    break;
  }

  event_t event;
  event.type = bDown ? ev_keydown : ev_keyup;
  event.data1 = rc;
  D_PostEvent(&event);
}

static int lastmousex = 0;
static int lastmousey = 0;
boolean mousemoved = false;

int mousemask = 0;

void HandleButton(int x, int y, int button, int bDown) {
  int dx = x - lastmousex;
  int dy = y - lastmousey;

  if (bDown) {
    mousemask |= 1 << button;
  } else {
    mousemask &= ~(1 << button);
  }

  event_t event;
  event.type = ev_mouse;
  event.data1 = mousemask;
  event.data2 = dx * 10;
  event.data3 = dy * 10;
  D_PostEvent(&event);

  lastmousex = x;
  lastmousey = y;
}

void HandleMotion(int x, int y, int mask) {
  int dx = x - lastmousex;
  int dy = y - lastmousey;

  mousemask = mask;

  event_t event;
  event.type = ev_mouse;
  event.data1 = mousemask;
  event.data2 = dx * 10;
  event.data3 = dy * 10;
  D_PostEvent(&event);

  lastmousex = x;
  lastmousey = y;
}

//
// I_SetPalette
//

static byte lpalette[256 * 3];

void I_SetPalette(byte *palette) {
  memcpy(lpalette, palette, sizeof(lpalette));
  // UploadNewPalette(X_cmap, palette);
}

#define OUTSCALE 1

//
// I_UpdateNoBlit
//
void I_UpdateNoBlit(void) {
  // what is this?
}

void I_InitGraphics(void) {
  CNFGSetup("EmbeddedDoom", SCREENWIDTH * OUTSCALE, SCREENHEIGHT * OUTSCALE);
}

void I_StartTic(void) { CNFGHandleInput(); }
void I_StartFrame() {}

void I_FinishUpdate(void) {

  static int lasttic;
  int tics;
  int i;
  // UNUSED static unsigned char *bigscreen=0;

#if 0
    // draws little dots on the bottom of the screen
    if (devparm)
    {
		i = I_GetTime();
		tics = i - lasttic;
		lasttic = i;
		if (tics > 20) tics = 20;

		for (i=0 ; i<tics*2 ; i+=2)
			screens[0][ (SCREENHEIGHT-1)*SCREENWIDTH + i] = 0xff;
		for ( ; i<20*2 ; i+=2)
			screens[0][ (SCREENHEIGHT-1)*SCREENWIDTH + i] = 0x0;	
    }
#endif

  // This is for display on PC only.  Don't worry about the output staging
  // buffer being big!

  static uint32_t *bmdata;
  if (!bmdata)
    bmdata = Z_Malloc(SCREENWIDTH * SCREENHEIGHT * OUTSCALE * OUTSCALE * 4,
                      PU_STATIC, 0);

  int y, x;
  for (y = 0; y < SCREENHEIGHT; y++) {
    const uint8_t *screenline = &screens[0][y * SCREENWIDTH];
    uint32_t *outline = &bmdata[y * SCREENWIDTH * OUTSCALE * OUTSCALE];
    int xt2 = 0;
    for (x = 0; x < SCREENWIDTH; x++, xt2 += OUTSCALE) {
      // lpalette
      int col = screenline[x];
      int lx, ly;
      uint32_t rgb = (lpalette[col * 3 + 0] << 16) |
                     (lpalette[col * 3 + 1] << 8) |
                     (lpalette[col * 3 + 2] << 0) | 0xff000000;
      for (ly = 0; ly < OUTSCALE; ly++)
        for (lx = 0; lx < OUTSCALE; lx++)
          outline[xt2 + SCREENWIDTH * OUTSCALE * ly + lx] = rgb;
    }
  }

  CNFGUpdateScreenWithBitmap(bmdata, SCREENWIDTH * OUTSCALE,
                             SCREENHEIGHT * OUTSCALE);
}
