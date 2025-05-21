
#include "DrawFunctions.h"

#include "../lib/syscalls.h"
#include "math.c"
#include <fcntl.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define WIDTH 200
#define HEIGHT 200
static char global_window_name[256] = {};
void CNFGGetDimensions(short *x, short *y) {
  *x = WIDTH;
  *y = HEIGHT;
}

void CNFGSetupFullscreen(const char *window_name, int screen_no) {}

void CNFGSetup(const char *window_name, int w, int h) {
  // width = w;
  // height = h;

  strncpy(global_window_name, window_name, 255);
}

char key = '\0';
void CNFGHandleInput() {
  if (key != '\0') {
    HandleKey(key, 1);
    key = '\0';
  }

  key = sys_char();
  if (key != 0) {
    HandleKey(key, 0);
  }
  // TODO: create some semblance of working in terminal
  // HandleKey(XLookupKeysym(&report.xkey, 0), bKeyDirection);
  // HandleButton(report.xbutton.x, report.xbutton.y, report.xbutton.button,
  // HandleMotion(report.xmotion.x, report.xmotion.y, ButtonsDown >> 1);
}

// RENDERING CODE
#define BUFFER_SIZE WIDTH *HEIGHT
uint32_t back_buffer[BUFFER_SIZE];
uint32_t drawing_buffer[BUFFER_SIZE];
uint32_t get_index(short x, short y) {
  uint32_t bounded_x = min(x, WIDTH - 1);
  uint32_t bounded_y = min(y, HEIGHT - 1);
  return bounded_x + bounded_y * WIDTH;
}

void CNFGUpdateScreenWithBitmap(unsigned long *data, int w, int h) {
  size_t max_pixel_size = strlen("\x1b[38;2;255;255;255m█\x1b[0m");
  size_t max_buffer_size = max_pixel_size * (w / 5) * (h / 10);
  char write_buffer[max_pixel_size * w * h];
  size_t cursor = 0;
  for (int y = 0; y < h; y += 10) {
    for (int x = 0; x < w; x += 5) {
      uint32_t base_color = data[x + y * w];
      unsigned char red = base_color & 0xFF; // red and blue channels swapped!!
      unsigned char grn = (base_color >> 8) & 0xFF;
      unsigned char blu = (base_color >> 16) & 0xFF;
      cursor +=
          snprintf((char *)&write_buffer + cursor, max_buffer_size - cursor,
                   "\x1b[38;2;%i;%i;%im█\x1b[0m", blu, grn, red);
    }
    cursor += snprintf((char *)&write_buffer + cursor, max_buffer_size - cursor,
                       "\n");
  }
  puts(write_buffer);
}

static uint32_t saved_color = 0;
uint32_t CNFGColor(uint32_t RGB) {
  unsigned char red = RGB & 0xFF;
  unsigned char grn = (RGB >> 8) & 0xFF;
  unsigned char blu = (RGB >> 16) & 0xFF;
  CNFGLastColor = RGB;
  unsigned long color = (red << 16) | (grn << 8) | (blu);
  saved_color = color;
  // XSetForeground(CNFGDisplay, CNFGGC, color);
  return color;
}

void CNFGClearFrame() {
  memset(back_buffer, CNFGColor(CNFGBGColor), WIDTH * HEIGHT);
}

void CNFGSwapBuffers() { memcpy(drawing_buffer, back_buffer, BUFFER_SIZE); }

void CNFGTackSegment(short x1, short y1, short x2, short y2) {
  printf("implement me!\n");
}

void CNFGTackPixel(short x1, short y1) {
  back_buffer[get_index(x1, y1)] = saved_color;
}

void CNFGTackRectangle(short x1, short y1, short x2, short y2) {
  printf("implement me!\n");
  // XFillRectangle(CNFGDisplay, CNFGPixmap, CNFGGC, x1, y1, x2 - x1, y2 - y1);
}

void CNFGTackPoly(RDPoint *points, int verts) {
  printf("implement me!\n");
  // XFillPolygon(CNFGDisplay, CNFGPixmap, CNFGGC, (XPoint *)points, 3, Convex,
  //              CoordModeOrigin);
}
