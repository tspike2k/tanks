/*
Copyright (c) 2025 tspike2k@github.com
Distributed under the Boost Software License, Version 1.0.
See accompanying file LICENSE_BOOST.txt or copy at http://www.boost.org/LICENSE_1_0.txt
*/

module bind.glx;

extern (C):

import core.stdc.config : c_ulong, c_long;
import bind.xlib;

/*
 * Tokens for glXChooseVisual and glXGetConfig:
 */
enum
{
    GLX_USE_GL           = 1,
    GLX_BUFFER_SIZE      = 2,
    GLX_LEVEL            = 3,
    GLX_RGBA             = 4,
    GLX_DOUBLEBUFFER     = 5,
    GLX_STEREO           = 6,
    GLX_AUX_BUFFERS      = 7,
    GLX_RED_SIZE         = 8,
    GLX_GREEN_SIZE       = 9,
    GLX_BLUE_SIZE        = 10,
    GLX_ALPHA_SIZE       = 11,
    GLX_DEPTH_SIZE       = 12,
    GLX_STENCIL_SIZE     = 13,
    GLX_ACCUM_RED_SIZE   = 14,
    GLX_ACCUM_GREEN_SIZE = 15,
    GLX_ACCUM_BLUE_SIZE	 = 16,
    GLX_ACCUM_ALPHA_SIZE = 17,
}


/*
 * Error codes returned by glXGetConfig:
 */
enum
{
    GLX_BAD_SCREEN    = 1,
    GLX_BAD_ATTRIBUTE = 2,
    GLX_NO_EXTENSION  = 3,
    GLX_BAD_VISUAL    = 4,
    GLX_BAD_CONTEXT   = 5,
    GLX_BAD_VALUE     = 6,
    GLX_BAD_ENUM      = 7,
}


/*
 * GLX 1.1 and later:
 */
enum
{
    GLX_VENDOR     = 1,
    GLX_VERSION    = 2,
    GLX_EXTENSIONS = 3,
}


/*
 * GLX 1.3 and later:
 */
enum
{
    GLX_CONFIG_CAVEAT           = 0x20,
    GLX_DONT_CARE               = 0xFFFFFFFF,
    GLX_X_VISUAL_TYPE           = 0x22,
    GLX_TRANSPARENT_TYPE        = 0x23,
    GLX_TRANSPARENT_INDEX_VALUE = 0x24,
    GLX_TRANSPARENT_RED_VALUE   = 0x25,
    GLX_TRANSPARENT_GREEN_VALUE = 0x26,
    GLX_TRANSPARENT_BLUE_VALUE  = 0x27,
    GLX_TRANSPARENT_ALPHA_VALUE = 0x28,
    GLX_WINDOW_BIT              = 0x00000001,
    GLX_PIXMAP_BIT              = 0x00000002,
    GLX_PBUFFER_BIT             = 0x00000004,
    GLX_AUX_BUFFERS_BIT         = 0x00000010,
    GLX_FRONT_LEFT_BUFFER_BIT   = 0x00000001,
    GLX_FRONT_RIGHT_BUFFER_BIT  = 0x00000002,
    GLX_BACK_LEFT_BUFFER_BIT    = 0x00000004,
    GLX_BACK_RIGHT_BUFFER_BIT   = 0x00000008,
    GLX_DEPTH_BUFFER_BIT        = 0x00000020,
    GLX_STENCIL_BUFFER_BIT      = 0x00000040,
    GLX_ACCUM_BUFFER_BIT        = 0x00000080,
    GLX_NONE                    = 0x8000,
    GLX_SLOW_CONFIG             = 0x8001,
    GLX_TRUE_COLOR              = 0x8002,
    GLX_DIRECT_COLOR            = 0x8003,
    GLX_PSEUDO_COLOR            = 0x8004,
    GLX_STATIC_COLOR            = 0x8005,
    GLX_GRAY_SCALE              = 0x8006,
    GLX_STATIC_GRAY             = 0x8007,
    GLX_TRANSPARENT_RGB         = 0x8008,
    GLX_TRANSPARENT_INDEX       = 0x8009,
    GLX_VISUAL_ID               = 0x800B,
    GLX_SCREEN                  = 0x800C,
    GLX_NON_CONFORMANT_CONFIG   = 0x800D,
    GLX_DRAWABLE_TYPE           = 0x8010,
    GLX_RENDER_TYPE             = 0x8011,
    GLX_X_RENDERABLE            = 0x8012,
    GLX_FBCONFIG_ID	            = 0x8013,
    GLX_RGBA_TYPE               = 0x8014,
    GLX_COLOR_INDEX_TYPE        = 0x8015,
    GLX_MAX_PBUFFER_WIDTH       = 0x8016,
    GLX_MAX_PBUFFER_HEIGHT      = 0x8017,
    GLX_MAX_PBUFFER_PIXELS      = 0x8018,
    GLX_PRESERVED_CONTENTS      = 0x801B,
    GLX_LARGEST_PBUFFER         = 0x801C,
    GLX_WIDTH                   = 0x801D,
    GLX_HEIGHT                  = 0x801E,
    GLX_EVENT_MASK              = 0x801F,
    GLX_DAMAGED                 = 0x8020,
    GLX_SAVED                   = 0x8021,
    GLX_WINDOW                  = 0x8022,
    GLX_PBUFFER                 = 0x8023,
    GLX_PBUFFER_HEIGHT          = 0x8040,
    GLX_PBUFFER_WIDTH           = 0x8041,
    GLX_RGBA_BIT                = 0x00000001,
    GLX_COLOR_INDEX_BIT         = 0x00000002,
    GLX_PBUFFER_CLOBBER_MASK    = 0x08000000,
}

/*
 * GLX 1.4 and later:
 */
enum
{
    GLX_SAMPLE_BUFFERS              = 0x186a0, /*100000*/
    GLX_SAMPLES                     = 0x186a1, /*100001*/
}

enum
{
    GLX_CONTEXT_DEBUG_BIT_ARB              = 0x00000001,
    GLX_CONTEXT_FORWARD_COMPATIBLE_BIT_ARB = 0x00000002,
    GLX_CONTEXT_MAJOR_VERSION_ARB          = 0x2091,
    GLX_CONTEXT_MINOR_VERSION_ARB          = 0x2092,
    GLX_CONTEXT_FLAGS_ARB                  = 0x2094,
    GLX_CONTEXT_CORE_PROFILE_BIT_ARB       = 0x00000001,
    GLX_CONTEXT_COMPATIBILITY_PROFILE_BIT_ARB = 0x00000002,
    GLX_CONTEXT_PROFILE_MASK_ARB           = 0x9126,
}

private struct __GLXcontextRec {};
alias __GLXcontextRec* GLXContext;
alias XID GLXPixmap;
alias XID GLXDrawable;
/* GLX 1.3 and later */
private struct __GLXFBConfigRec {};
alias __GLXFBConfigRec* GLXFBConfig;
alias XID GLXFBConfigID;
alias XID GLXContextID;
alias XID GLXWindow;
alias XID GLXPbuffer;

alias GLXextFuncPtr = void function() ;
alias glXCreateContextAttribsARBFunc = GLXContext function(XDisplay*, GLXFBConfig, GLXContext, Bool, const(int)*) ;
alias glXSwapIntervalEXTFunc = void function(XDisplay* display, GLXDrawable drawable, int interval);
alias glXSwapIntervalMESAFunc = int function(uint interval) ;
alias glXSwapIntervalSGIFunc = int function(int interval);

GLXFBConfig* glXChooseFBConfig(XDisplay* dpy, int screen, const(int)* attribList, int* nitems);
XVisualInfo* glXGetVisualFromFBConfig(XDisplay *dpy, GLXFBConfig config);
const(char)* glXQueryExtensionsString(XDisplay *dpy, int screen);
Bool glXMakeCurrent(XDisplay *dpy, GLXDrawable drawable, GLXContext ctx);
void glXDestroyContext(XDisplay *dpy, GLXContext ctx);
void glXSwapBuffers(XDisplay *dpy, GLXDrawable drawable);
GLXextFuncPtr glXGetProcAddressARB(const(ubyte)*);
