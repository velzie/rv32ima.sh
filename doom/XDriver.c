// Copyright (c) 2011 <>< Charles Lohr - Under the MIT/x11 or NewBSD License you
// choose. portions from
// http://www.xmission.com/~georgeps/documentation/tutorials/Xlib_Beginner.html

// #define HAS_XINERAMA

#include "DrawFunctions.h"

#include <X11/Xatom.h>
#include <X11/Xlib.h>
#include <X11/Xos.h>
#include <X11/Xutil.h>
#include <X11/keysym.h>
#ifdef HAS_XINERAMA
#include <X11/extensions/Xinerama.h>
#include <X11/extensions/shape.h>
#endif
#include <stdio.h>
#include <stdlib.h>

XWindowAttributes CNFGWinAtt;
Display *CNFGDisplay;
Window CNFGWindow;
Pixmap CNFGPixmap;
GC CNFGGC;
GC CNFGWindowGC;
int FullScreen = 0;

void CNFGGetDimensions(short *x, short *y) {
  *x = CNFGWinAtt.width;
  *y = CNFGWinAtt.height;
}

static void InternalLinkScreenAndGo(const char *WindowName) {
  XGetWindowAttributes(CNFGDisplay, CNFGWindow, &CNFGWinAtt);

  XSelectInput(CNFGDisplay, CNFGWindow,
               KeyPressMask | KeyReleaseMask | ButtonPressMask |
                   ButtonReleaseMask | ExposureMask | PointerMotionMask);
  XSetStandardProperties(CNFGDisplay, CNFGWindow, WindowName, WindowName, None,
                         NULL, 0, NULL);

  CNFGWindowGC = XCreateGC(CNFGDisplay, CNFGWindow, 0, 0);

  CNFGPixmap = XCreatePixmap(CNFGDisplay, CNFGWindow, CNFGWinAtt.width,
                             CNFGWinAtt.height, CNFGWinAtt.depth);
  CNFGGC = XCreateGC(CNFGDisplay, CNFGPixmap, 0, 0);
}

void CNFGSetupFullscreen(const char *WindowName, int screen_no) {
#ifdef HAS_XINERAMA
  XineramaScreenInfo *screeninfo = NULL;
  int screens;
  int event_basep, error_basep, a, b;
  CNFGDisplay = XOpenDisplay(NULL);
  int screen = XDefaultScreen(CNFGDisplay);
  int xpos, ypos;

  if (!XShapeQueryExtension(CNFGDisplay, &event_basep, &error_basep)) {
    fprintf(stderr, "X-Server does not support shape extension");
    exit(1);
  }

  Visual *visual = DefaultVisual(CNFGDisplay, screen);
  CNFGWinAtt.depth = DefaultDepth(CNFGDisplay, screen);

  if (XineramaQueryExtension(CNFGDisplay, &a, &b) &&
      (screeninfo = XineramaQueryScreens(CNFGDisplay, &screens)) &&
      XineramaIsActive(CNFGDisplay) && screen_no >= 0 && screen_no < screens) {

    CNFGWinAtt.width = screeninfo[screen_no].width;
    CNFGWinAtt.height = screeninfo[screen_no].height;
    xpos = screeninfo[screen_no].x_org;
    ypos = screeninfo[screen_no].y_org;
  } else {
    CNFGWinAtt.width = XDisplayWidth(CNFGDisplay, screen);
    CNFGWinAtt.height = XDisplayHeight(CNFGDisplay, screen);
    xpos = 0;
    ypos = 0;
  }
  if (screeninfo)
    XFree(screeninfo);

  XSetWindowAttributes setwinattr;
  setwinattr.override_redirect = 1;
  setwinattr.save_under = 1;
  setwinattr.event_mask =
      StructureNotifyMask | SubstructureNotifyMask | ExposureMask |
      ButtonPressMask | ButtonReleaseMask | ButtonPressMask |
      PointerMotionMask | ButtonMotionMask | EnterWindowMask | LeaveWindowMask |
      KeyPressMask | KeyReleaseMask | SubstructureNotifyMask | FocusChangeMask;
  setwinattr.border_pixel = 0;

  CNFGWindow = XCreateWindow(
      CNFGDisplay, XRootWindow(CNFGDisplay, screen), xpos, ypos,
      CNFGWinAtt.width, CNFGWinAtt.height, 0, CNFGWinAtt.depth, InputOutput,
      visual, CWBorderPixel | CWEventMask | CWOverrideRedirect | CWSaveUnder,
      &setwinattr);

  XMapWindow(CNFGDisplay, CNFGWindow);
  XSetInputFocus(CNFGDisplay, CNFGWindow, RevertToParent, CurrentTime);
  XFlush(CNFGDisplay);
  FullScreen = 1;
  // printf( "%d %d %d %d\n", xpos, ypos, CNFGWinAtt.width, CNFGWinAtt.height );
  InternalLinkScreenAndGo(WindowName);
/*
        setwinattr.override_redirect = 1;
        XChangeWindowAttributes(
                CNFGDisplay, CNFGWindow,
                CWBorderPixel | CWEventMask | CWOverrideRedirect, &setwinattr);
*/
#else
  CNFGSetup(WindowName, 640, 480);
#endif
}

void CNFGSetup(const char *WindowName, int w, int h) {
  CNFGDisplay = XOpenDisplay(NULL);
  XGetWindowAttributes(CNFGDisplay, RootWindow(CNFGDisplay, 0), &CNFGWinAtt);

  int depth = CNFGWinAtt.depth;
  CNFGWindow = XCreateWindow(CNFGDisplay, RootWindow(CNFGDisplay, 0), 1, 1, w,
                             h, 0, depth, InputOutput, CopyFromParent, 0, 0);
  XMapWindow(CNFGDisplay, CNFGWindow);
  XFlush(CNFGDisplay);

  InternalLinkScreenAndGo(WindowName);
}

void CNFGHandleInput() {
  static int ButtonsDown;
  XEvent report;

  int bKeyDirection = 1;
  int r;
  while ((r = XCheckMaskEvent(CNFGDisplay,
                              KeyPressMask | KeyReleaseMask | ButtonPressMask |
                                  ButtonReleaseMask | ExposureMask |
                                  PointerMotionMask,
                              &report))) {
    //		XEvent nev;
    //		XPeekEvent(CNFGDisplay, &nev);

    // printf( "EVENT %d\n", report.type );
    // XMaskEvent(CNFGDisplay, KeyPressMask | KeyReleaseMask | ButtonPressMask |
    // ButtonReleaseMask | ExposureMask, &report);

    bKeyDirection = 1;
    switch (report.type) {
    case NoExpose:
      break;
    case Expose:
      XGetWindowAttributes(CNFGDisplay, CNFGWindow, &CNFGWinAtt);
      if (CNFGPixmap)
        XFreePixmap(CNFGDisplay, CNFGPixmap);
      CNFGPixmap = XCreatePixmap(CNFGDisplay, CNFGWindow, CNFGWinAtt.width,
                                 CNFGWinAtt.height, CNFGWinAtt.depth);
      if (CNFGGC)
        XFreeGC(CNFGDisplay, CNFGGC);
      CNFGGC = XCreateGC(CNFGDisplay, CNFGPixmap, 0, 0);
      break;
    case KeyRelease:
      bKeyDirection = 0;
    case KeyPress:
      HandleKey(XLookupKeysym(&report.xkey, 0), bKeyDirection);
      break;
    case ButtonRelease:
      bKeyDirection = 0;
    case ButtonPress:
      HandleButton(report.xbutton.x, report.xbutton.y, report.xbutton.button,
                   bKeyDirection);
      ButtonsDown = (ButtonsDown & (~(1 << report.xbutton.button))) |
                    (bKeyDirection << report.xbutton.button);

      // Intentionall fall through -- we want to send a motion in event of a
      // button as well.
    case MotionNotify:
      HandleMotion(report.xmotion.x, report.xmotion.y, ButtonsDown >> 1);
      break;
    default:
      printf("Event: %d\n", report.type);
    }
  }
}

void CNFGUpdateScreenWithBitmap(unsigned long *data, int w, int h) {
  static XImage *xi;
  static int depth;
  static int lw, lh;
  static unsigned char *lbuffer;
  int r, ls;

  if (!xi) {
    int screen = DefaultScreen(CNFGDisplay);
    Visual *visual = DefaultVisual(CNFGDisplay, screen);
    depth = DefaultDepth(CNFGDisplay, screen) / 8;
    //		xi = XCreateImage(CNFGDisplay, DefaultVisual( CNFGDisplay,
    //DefaultScreen(CNFGDisplay) ), depth*8, ZPixmap, 0, (char*)data, w, h, 32,
    //w*4 ); 		lw = w; 		lh = h;
  }

  if (lw != w || lh != h) {
    if (xi)
      free(xi);
    xi = XCreateImage(CNFGDisplay,
                      DefaultVisual(CNFGDisplay, DefaultScreen(CNFGDisplay)),
                      depth * 8, ZPixmap, 0, (char *)data, w, h, 32, w * 4);
    lw = w;
    lh = h;
  }

  ls = lw * lh;

  XPutImage(CNFGDisplay, CNFGWindow, CNFGWindowGC, xi, 0, 0, 0, 0, w, h);
}

#ifndef RASTERIZER

uint32_t CNFGColor(uint32_t RGB) {
  unsigned char red = RGB & 0xFF;
  unsigned char grn = (RGB >> 8) & 0xFF;
  unsigned char blu = (RGB >> 16) & 0xFF;
  CNFGLastColor = RGB;
  unsigned long color = (red << 16) | (grn << 8) | (blu);
  XSetForeground(CNFGDisplay, CNFGGC, color);
  return color;
}

void CNFGClearFrame() {
  XGetWindowAttributes(CNFGDisplay, CNFGWindow, &CNFGWinAtt);
  XSetForeground(CNFGDisplay, CNFGGC, CNFGColor(CNFGBGColor));
  XFillRectangle(CNFGDisplay, CNFGPixmap, CNFGGC, 0, 0, CNFGWinAtt.width,
                 CNFGWinAtt.height);
}

void CNFGSwapBuffers() {
  XCopyArea(CNFGDisplay, CNFGPixmap, CNFGWindow, CNFGWindowGC, 0, 0,
            CNFGWinAtt.width, CNFGWinAtt.height, 0, 0);
  XFlush(CNFGDisplay);
  if (FullScreen)
    XSetInputFocus(CNFGDisplay, CNFGWindow, RevertToParent, CurrentTime);
}

void CNFGTackSegment(short x1, short y1, short x2, short y2) {
  XDrawLine(CNFGDisplay, CNFGPixmap, CNFGGC, x1, y1, x2, y2);
}

void CNFGTackPixel(short x1, short y1) {
  XDrawPoint(CNFGDisplay, CNFGPixmap, CNFGGC, x1, y1);
}

void CNFGTackRectangle(short x1, short y1, short x2, short y2) {
  XFillRectangle(CNFGDisplay, CNFGPixmap, CNFGGC, x1, y1, x2 - x1, y2 - y1);
}

void CNFGTackPoly(RDPoint *points, int verts) {
  XFillPolygon(CNFGDisplay, CNFGPixmap, CNFGGC, (XPoint *)points, 3, Convex,
               CoordModeOrigin);
}

#endif
