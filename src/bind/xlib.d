/*
Copyright (c) 2025 tspike2k@github.com
Distributed under the Boost Software License, Version 1.0.
See accompanying file LICENSE_BOOST.txt or copy at http://www.boost.org/LICENSE_1_0.txt
*/

module bind.xlib;

pragma(lib, "X11");

import core.stdc.config : c_ulong, c_long;

// Conversion from C Macros

Window DefaultRootWindow(XDisplay* display){
    return display.screens[display.default_screen].root;
}

Window RootWindow(XDisplay* display, int screen){
    return display.screens[screen].root;
}

int DefaultScreen(XDisplay* display){
    return display.default_screen;
}

GC DefaultGC(Display* display, int screen){
    return display.screens[screen].default_gc;
}

Visual* DefaultVisual(Display* display, int screen){
    return display.screens[screen].root_visual;
}

int DefaultDepth(Display* display, int screen){
    return display.screens[screen].root_depth;
}

auto BlackPixel(Display* display, int screen){
    return display.screens[screen].black_pixel;
}

auto WhitePixel(Display* display, int screen){
    return display.screens[screen].white_pixel;
}

extern (C):

alias Atom     = c_ulong;
alias XID      = c_ulong;
alias Time     = c_ulong;
alias Window   = XID;
alias Drawable = XID;
alias Font     = XID;
alias Pixmap   = XID;
alias Cursor   = XID;
alias Colormap = XID;
alias GContext = XID;
alias KeySym   = XID;
alias XPointer = char*;
alias VisualID = c_ulong;
alias Display  = XDisplay;
alias GC       = void*;
alias XIC      = _XIC*;
alias XIM      = _XIM*;

private struct _XIM;
private struct _XIC;
struct XComposeStatus;

alias int Status;
alias int Bool;
enum True  = 1;
enum False = 0;

enum XYBitmap = 0;	/* depth 1, XYFormat */
enum XYPixmap = 1;	/* depth == drawable depth */
enum ZPixmap  = 2;	/* depth == drawable depth */

alias int function(XDisplay*, XErrorEvent*) XErrorHandler; 	    /* WARNING, this type not in Xlib spec */

/* For CreateColormap */
enum
{
    AllocNone		= 0,	/* create map with no entries */
    AllocAll		= 1,	/* allocate entire map writeable */
}

/* Window classes used by CreateWindow */
/* Note that CopyFromParent is already defined as 0 above */
enum
{
    InputOutput	= 1,
    InputOnly   = 2,
}

/* Display classes  used in opening the connection
 * Note that the statically allocated ones are even numbered and the
 * dynamically changeable ones are odd numbered */
enum
{
    StaticGray		= 0,
    GrayScale		= 1,
    StaticColor		= 2,
    PseudoColor		= 3,
    TrueColor		= 4,
    DirectColor		= 5,
}

/* Input Event Masks. Used as event-mask window attribute and as arguments
   to Grab requests.  Not to be confused with event names.  */
enum
{
    NoEventMask			= 0,
    KeyPressMask			= 1<<0,
    KeyReleaseMask			= 1<<1,
    ButtonPressMask			= 1<<2,
    ButtonReleaseMask		= 1<<3,
    EnterWindowMask			= 1<<4,
    LeaveWindowMask			= 1<<5,
    PointerMotionMask		= 1<<6,
    PointerMotionHintMask		= 1<<7,
    Button1MotionMask		= 1<<8,
    Button2MotionMask		= 1<<9,
    Button3MotionMask		= 1<<10,
    Button4MotionMask		= 1<<11,
    Button5MotionMask		= 1<<12,
    ButtonMotionMask		= 1<<13,
    KeymapStateMask			= 1<<14,
    ExposureMask			= 1<<15,
    VisibilityChangeMask		= 1<<16,
    StructureNotifyMask		= 1<<17,
    ResizeRedirectMask		= 1<<18,
    SubstructureNotifyMask		= 1<<19,
    SubstructureRedirectMask	= 1<<20,
    FocusChangeMask			= 1<<21,
    PropertyChangeMask		= 1<<22,
    ColormapChangeMask		= 1<<23,
    OwnerGrabButtonMask		= 1<<24,
}

/* Window attributes for CreateWindow and ChangeWindowAttributes */
enum
{
    CWBackPixmap		= 1<<0,
    CWBackPixel		= 1<<1,
    CWBorderPixmap		= 1<<2,
    CWBorderPixel           = 1<<3,
    CWBitGravity		= 1<<4,
    CWWinGravity		= 1<<5,
    CWBackingStore          = 1<<6,
    CWBackingPlanes	        = 1<<7,
    CWBackingPixel	        = 1<<8,
    CWOverrideRedirect	= 1<<9,
    CWSaveUnder		= 1<<10,
    CWEventMask		= 1<<11,
    CWDontPropagate	        = 1<<12,
    CWColormap		= 1<<13,
    CWCursor	        = 1<<14,
}

enum
{
    VisualNoMask           = 0x0,
    VisualIDMask           = 0x1,
    VisualScreenMask       = 0x2,
    VisualDepthMask        = 0x4,
    VisualClassMask        = 0x8,
    VisualRedMaskMask      = 0x10,
    VisualGreenMaskMask    = 0x20,
    VisualBlueMaskMask	   = 0x40,
    VisualColormapSizeMask = 0x80,
    VisualBitsPerRGBMask   = 0x100,
    VisualAllMask          = 0x1FF,
}

enum
{
    QueuedAlready      = 0,
    QueuedAfterReading = 1,
    QueuedAfterFlush   = 2,
}

enum
{
    KeyPress		= 2,
    KeyRelease		= 3,
    ButtonPress		= 4,
    ButtonRelease		= 5,
    MotionNotify		= 6,
    EnterNotify		= 7,
    LeaveNotify		= 8,
    FocusIn			= 9,
    FocusOut		= 10,
    KeymapNotify		= 11,
    Expose			= 12,
    GraphicsExpose		= 13,
    NoExpose		= 14,
    VisibilityNotify	= 15,
    CreateNotify		= 16,
    DestroyNotify		= 17,
    UnmapNotify		= 18,
    MapNotify		= 19,
    MapRequest		= 20,
    ReparentNotify		= 21,
    ConfigureNotify		= 22,
    ConfigureRequest	= 23,
    GravityNotify		= 24,
    ResizeRequest		= 25,
    CirculateNotify		= 26,
    CirculateRequest	= 27,
    PropertyNotify		= 28,
    SelectionClear		= 29,
    SelectionRequest	= 30,
    SelectionNotify		= 31,
    ColormapNotify		= 32,
    ClientMessage		= 33,
    MappingNotify		= 34,
    GenericEvent		= 35,
    LASTEvent		= 36,	/* must be bigger than any event # */
}

enum
{
    ShiftMask		= (1<<0),
    LockMask		= (1<<1),
    ControlMask		= (1<<2),
    Mod1Mask		= (1<<3),
    Mod2Mask		= (1<<4),
    Mod3Mask		= (1<<5),
    Mod4Mask		= (1<<6),
    Mod5Mask		= (1<<7),
}

/* Property modes */
enum
{
    PropModeReplace         = 0,
    PropModePrepend         = 1,
    PropModeAppend          = 2,
}

enum ParentRelative = 1L;
enum CopyFromParent = 0L;
enum PointerWindow = 0L;
enum InputFocus = 1L;
enum PointerRoot = 1L;
enum AnyPropertyType = 0L;
enum AnyKey = 0L;
enum AnyButton = 0L;
enum AllTemporary = 0L;
enum CurrentTime = 0L;
enum NoSymbol = 0L;
enum None = 0L;

enum
{
    Button1Mask		= (1<<8),
    Button2Mask		= (1<<9),
    Button3Mask		= (1<<10),
    Button4Mask		= (1<<11),
    Button5Mask		= (1<<12),
}

/* button names. Used as arguments to GrabButton and as detail in ButtonPress
   and ButtonRelease events.  Not to be confused with button masks above.
   Note that 0 is already defined above as "AnyButton".  */

enum Button1 = 1;
enum Button2 = 2;
enum Button3 = 3;
enum Button4 = 4;
enum Button5 = 5;

/* GrabPointer, GrabButton, GrabKeyboard, GrabKey Modes */
enum
{
    GrabModeSync		= 0,
    GrabModeAsync		= 1,
}

/* GrabPointer, GrabKeyboard reply status */
enum
{
    GrabSuccess		= 0,
    AlreadyGrabbed		= 1,
    GrabInvalidTime		= 2,
    GrabNotViewable		= 3,
    GrabFrozen		= 4,
}

enum
{
    GCFunction          = (1L<<0),
    GCPlaneMask         = (1L<<1),
    GCForeground        = (1L<<2),
    GCBackground        = (1L<<3),
    GCLineWidth         = (1L<<4),
    GCLineStyle         = (1L<<5),
    GCCapStyle          = (1L<<6),
    GCJoinStyle         = (1L<<7),
    GCFillStyle         = (1L<<8),
    GCFillRule          = (1L<<9),
    GCTile              = (1L<<10),
    GCStipple           = (1L<<11),
    GCTileStipXOrigin   = (1L<<12),
    GCTileStipYOrigin   = (1L<<13),
    GCFont              = (1L<<14),
    GCSubwindowMode     = (1L<<15),
    GCGraphicsExposures = (1L<<16),
    GCClipXOrigin       = (1L<<17),
    GCClipYOrigin       = (1L<<18),
    GCClipMask          = (1L<<19),
    GCDashOffset        = (1L<<20),
    GCDashList          = (1L<<21),
    GCArcMode           = (1L<<22),
}

/* Error codes */
enum
{
    Success		  =  0,	/* everything's okay */
    BadRequest	  =  1,	/* bad request code */
    BadValue	  =  2,	/* int parameter out of range */
    BadWindow	  =  3,	/* parameter not a Window */
    BadPixmap	  =  4,	/* parameter not a Pixmap */
    BadAtom		  =  5,	/* parameter not an Atom */
    BadCursor	  =  6,	/* parameter not a Cursor */
    BadFont		  =  7,	/* parameter not a Font */
    BadMatch	  =  8,	/* parameter mismatch */
    BadDrawable	  =  9,	/* parameter not a Pixmap or Window */
    BadAccess	  = 10,	/* depending on context:
                     - key/button already grabbed
                     - attempt to free an illegal
                       cmap entry
                    - attempt to store into a read-only
                       color map entry.
                    - attempt to modify the access control
                       list from other than the local host.
                    */
    BadAlloc	  = 11,	/* insufficient resources */
    BadColor	  = 12,	/* no such colormap */
    BadGC		  = 13,	/* parameter not a GC */
    BadIDChoice	  = 14,	/* choice not in range or already used */
    BadName		  = 15,	/* font or color name doesn't exist */
    BadLength	  = 16,	/* Request length incorrect */
    BadImplementation = 17,	/* server is defective */

    FirstExtensionError	= 128,
    LastExtensionError	= 255,

}

enum ForgetGravity    = 0;
enum NorthWestGravity = 1;
enum NorthGravity     = 2;
enum NorthEastGravity = 3;
enum WestGravity      = 4;
enum CenterGravity    = 5;
enum EastGravity      = 6;
enum SouthWestGravity = 7;
enum SouthGravity     = 8;
enum SouthEastGravity = 9;
enum StaticGravity    = 10;

// TODO: Determine what integer sizes should be used as function parameters

XDisplay* XOpenDisplay(const(char)*);
int XCloseDisplay(XDisplay*);
Colormap XCreateColormap(XDisplay* display, Window window, Visual* visual, int alloc);
int XFreeColormap(XDisplay*, Colormap);
Status XMatchVisualInfo(XDisplay* display, int screen, int colorDepth, int c_class, XVisualInfo* result);
Window XCreateWindow(XDisplay* display, Window window, int x, int y, uint width, uint height, uint borderWidth, int colorDepth, uint c_class, Visual* visual, c_ulong	valueMask, XSetWindowAttributes* winAttributes);
int XDestroyWindow(XDisplay*, Window);
int XMapRaised(Display*, Window);
int XFlush(Display*);
int XEventsQueued(XDisplay* display, int mode);
int XNextEvent(Display*, XEvent*);
Atom XInternAtom(Display* display, const(char)* name, Bool ifExists);
Status XSetWMProtocols(Display* display, Window window, Atom* protocols, int count);
int XStoreName(Display*, Window, const(char)*);
int XFree(void*);
int XChangeProperty(XDisplay* display, Window w, Atom property, Atom type, int format, int mode, const(ubyte)* data, int nElements);
XErrorHandler XSetErrorHandler (XErrorHandler);
int XSync(XDisplay* display, Bool discard);
Pixmap XCreateBitmapFromData(Display*, Drawable, const (char)*, uint, uint);
int XFreePixmap(Display*, Pixmap);
Cursor XCreatePixmapCursor(Display*, Pixmap, Pixmap, XColor*, XColor*, uint, uint);
int XDefineCursor(Display*, Window, Cursor);
int XUndefineCursor(Display*, Window);
int XFreeCursor(Display*, Cursor);
Bool XGetEventData(Display*, XGenericEventCookie*);
void XFreeEventData(Display*, XGenericEventCookie*);
KeySym XLookupKeysym(XKeyEvent*, int);
int XPeekEvent(Display*, XEvent*);
Status XSendEvent(Display*, Window, Bool, long, XEvent*);
int XGrabPointer(Display*, Window, Bool, uint, int, int, Window, Cursor, Time);
int XUngrabPointer(Display*, Time);
Bool XQueryPointer(Display*, Window, Window*, Window*, int*, int*, int*, int*, uint*);
int XWarpPointer(Display*, Window, Window, int, int, uint, uint, int, int);
int XGetWindowProperty(Display*, Window, Atom, c_long, c_long, Bool, Atom, Atom*, int*, c_ulong*, c_ulong*, ubyte**);
//Status XGetWindowAttributes(Display*, Window, XWindowAttributes*);
int XChangeWindowAttributes(Display*, Window, c_ulong, XSetWindowAttributes*);
int XMoveWindow(Display*, Window, int, int);
int XResizeWindow(Display*, Window, uint, uint);
int XCopyArea(Display* display, Drawable src, Drawable dest, GC gc, int	src_x, int src_y, uint width, uint height, int dest_x, int dest_y);
extern Pixmap XCreatePixmap(Display* display, Drawable drawable, uint width, uint height, uint colorDepth);
extern XImage* XCreateImage(Display* display, Visual* visual, uint colorDepth, int format, int offset, char* data, uint width, uint height, int bitmap_pad, int bytes_per_line);
int XDestroyImage(XImage* ximage);
XVisualInfo *XGetVisualInfo(Display* display, c_long vinfo_mask, XVisualInfo* vinfo_template, int* nitems_return);
extern int XConvertSelection(Display*, Atom, Atom, Atom, Window, Time);
GC XCreateGC(Display* display, Drawable d, c_ulong valuemask, XGCValues* values);
Bool XQueryExtension(Display*, const(char)*, int*, int*, int*);
int XPutImage(Display* display, Drawable d, GC gc, XImage* image, int src_x, int src_y, int dest_x, int dest_y, uint width, uint height);
int XMapWindow(Display*, Window);
int XGetErrorText(Display* display, int code, char* buffer, int length); // TODO: What length?
int XSetInputFocus(Display* display, Window focus, int revert_to, Time time);
int XGetInputFocus(Display* display, Window* focus, int* revert_to);

int XLookupString(XKeyEvent* event_struct, char* buffer_return, int	bytes_buffer, KeySym* keysym_return, XComposeStatus* status_in_out);
char* XSetLocaleModifiers(const(char)* modifier_list);
XIM XOpenIM(Display* dpy, _XrmHashBucketRec* rdb, char* res_name, char* res_class);
Status XCloseIM(XIM im);
char* XGetIMValues(XIM im, ...);
char* XSetIMValues(XIM im, ...);
XIC XCreateIC(XIM im , ...);
void XDestroyIC(XIC ic);
void XSetICFocus(XIC ic);
void XUnsetICFocus(XIC ic);
char* Xutf8ResetIC(XIC ic);
char* XSetICValues(XIC ic, ...);
char *XGetICValues(XIC ic , ...);
extern XIM XIMOfIC(XIC ic);
Bool XFilterEvent(XEvent* event, Window	window);
int Xutf8LookupString(XIC ic, XKeyPressedEvent* event, char* buffer_return, int bytes_buffer, KeySym* keysym_return, Status* status_return);

private struct _XPrivate;
private struct _XrmHashBucketRec;
struct Depth;
struct ScreenFormat;
struct XExtData;
struct Visual;

struct Screen
{
    XExtData *ext_data;	/* hook for extension to hang data */
    XDisplay *display;/* back pointer to display structure */
    Window root;		/* Root window id. */
    int width, height;	/* width and height of screen */
    int mwidth, mheight;	/* width and height of  in millimeters */
    int ndepths;		/* number of depths possible */
    Depth *depths;		/* list of allowable depths on the screen */
    int root_depth;		/* bits per pixel */
    Visual *root_visual;	/* root visual */
    GC default_gc;		/* GC for the root root visual */
    Colormap cmap;		/* default color map */
    c_ulong white_pixel;
    c_ulong black_pixel;	/* White and Black pixel values */
    int max_maps, min_maps;	/* max and min color maps */
    int backing_store;	/* Never, WhenMapped, Always */
    Bool save_unders;
    c_long root_input_mask;	/* initial root input mask */
}

struct XColor
{
    c_ulong pixel;
    ushort red, green, blue;
    char flags;  /* do_red, do_green, do_blue */
    char pad;
}

struct XGCValues
{
    int c_function;		/* logical operation */
    c_ulong plane_mask;/* plane mask */
    c_ulong foreground;/* foreground pixel */
    c_ulong background;/* background pixel */
    int line_width;		/* line width */
    int line_style;	 	/* LineSolid, LineOnOffDash, LineDoubleDash */
    int cap_style;	  	/* CapNotLast, CapButt,
                   CapRound, CapProjecting */
    int join_style;	 	/* JoinMiter, JoinRound, JoinBevel */
    int fill_style;	 	/* FillSolid, FillTiled,
                   FillStippled, FillOpaqueStippled */
    int fill_rule;	  	/* EvenOddRule, WindingRule */
    int arc_mode;		/* ArcChord, ArcPieSlice */
    Pixmap tile;		/* tile pixmap for tiling operations */
    Pixmap stipple;		/* stipple 1 plane pixmap for stippling */
    int ts_x_origin;	/* offset for tile or stipple operations */
    int ts_y_origin;
        Font font;	        /* default text font for text operations */
    int subwindow_mode;     /* ClipByChildren, IncludeInferiors */
    Bool graphics_exposures;/* boolean, should exposures be generated */
    int clip_x_origin;	/* origin for clipping */
    int clip_y_origin;
    Pixmap clip_mask;	/* bitmap clipping; other calls for rects */
    int dash_offset;	/* patterned/dashed line information */
    char dashes;
};

struct XImage
{
    int width, height;		/* size of image */
    int xoffset;		/* number of pixels offset in X direction */
    int format;			/* XYBitmap, XYPixmap, ZPixmap */
    char* data;			/* pointer to image data */
    int byte_order;		/* data byte order, LSBFirst, MSBFirst */
    int bitmap_unit;		/* quant. of scanline 8, 16, 32 */
    int bitmap_bit_order;	/* LSBFirst, MSBFirst */
    int bitmap_pad;		/* 8, 16, 32 either XY or ZPixmap */
    int depth;			/* depth of image */
    int bytes_per_line;		/* accelerator to next line */
    int bits_per_pixel;		/* bits per pixel (ZPixmap) */
    c_ulong red_mask;	/* bits in z arrangement */
    c_ulong green_mask;
    c_ulong blue_mask;
    XPointer obdata;		/* hook for the object routines to hang on */
    struct funcs
    {		/* image manipulation routines */

        XImage* function(XDisplay* /* display */,
            Visual*		/* visual */,
            uint	/* depth */,
            int		/* format */,
            int		/* offset */,
            char*		/* data */,
            uint	/* width */,
            uint	/* height */,
            int		/* bitmap_pad */,
            int		/* bytes_per_line */) createImage;
        int function(XImage*) destroy_image;
        c_ulong function(XImage *, int, int) get_pixel;
        int function(XImage *, int, int, c_ulong) put_pixel;
        XImage* function(XImage *, int, int, uint, uint) sub_image;
        int function(XImage*, long) add_pixel;
    }
    funcs f;
}

struct XDisplay
{
    XExtData *ext_data;	/* hook for extension to hang data */
    _XPrivate *private1;
    int fd;			/* Network socket. */
    int private2;
    int proto_major_version;/* major version of server's X protocol */
    int proto_minor_version;/* minor version of servers X protocol */
    char *vendor;		/* vendor of the server hardware */
        XID private3;
    XID private4;
    XID private5;
    int private6;
    extern (C) XID function (XDisplay*) resource_alloc;	/* allocator function */
    int byte_order;		/* screen byte order, LSBFirst, MSBFirst */
    int bitmap_unit;	/* padding and data requirements */
    int bitmap_pad;		/* padding requirements on bitmaps */
    int bitmap_bit_order;	/* LeastSignificant or MostSignificant */
    int nformats;		/* number of pixmap formats in list */
    ScreenFormat *pixmap_format;	/* pixmap format list */
    int private8;
    int release;		/* release of the server */
    _XPrivate *private9;
    _XPrivate *private10;
    int qlen;		/* Length of input event queue */
    c_ulong last_request_read; /* seq number of last event read */
    c_ulong request;	/* sequence number of last request. */
    XPointer private11;
    XPointer private12;
    XPointer private13;
    XPointer private14;
    uint max_request_size; /* maximum number 32 bit words in request*/
    _XrmHashBucketRec *db;
    extern (C) int function(XDisplay*) private15;
    char* display_name;	/* "host:display" string used on this connect*/
    int default_screen;	/* default screen for operations */
    int nscreens;		/* number of screens on this server*/
    Screen* screens;	/* pointer to list of screens */
    c_ulong motion_buffer;	/* size of motion buffer */
    c_ulong private16;
    int min_keycode;	/* minimum defined keycode */
    int max_keycode;	/* maximum defined keycode */
    XPointer private17;
    XPointer private18;
    int private19;
    char *xdefaults;	/* contents of defaults from server */
    /* there is more to this structure, but it is private to Xlib */
}

struct XSetWindowAttributes
{
    Pixmap background_pixmap;	/* background or None or ParentRelative */
    c_ulong background_pixel;	/* background pixel */
    Pixmap border_pixmap;	/* border of the window */
    c_ulong border_pixel;	/* border pixel value */
    int bit_gravity;		/* one of bit gravity values */
    int win_gravity;		/* one of the window gravity values */
    int backing_store;		/* NotUseful, WhenMapped, Always */
    c_ulong backing_planes;/* planes to be preseved if possible */
    c_ulong backing_pixel;/* value to use in restoring planes */
    Bool save_under;		/* should bits under be saved? (popups) */
    c_long event_mask;		/* set of events that should be saved */
    c_long do_not_propagate_mask;	/* set of events that should not propagate */
    Bool override_redirect;	/* boolean value for override-redirect */
    Colormap colormap;		/* color map to be associated with window */
    Cursor cursor;		/* cursor to be displayed (or None) */
}

struct XVisualInfo
{
  Visual *visual;
  VisualID visualid;
  int screen;
  int depth;
  int c_class;
  c_ulong red_mask;
  c_ulong green_mask;
  c_ulong blue_mask;
  int colormap_size;
  int bits_per_rgb;
}

struct XKeyEvent
{
    int type;		/* of event */
    c_ulong serial;	/* # of last request processed by server */
    Bool send_event;	/* true if this came from a SendEvent request */
    Display *display;	/* Display the event was read from */
    Window window;	        /* "event" window it is reported relative to */
    Window root;	        /* root window that the event occurred on */
    Window subwindow;	/* child window */
    Time time;		/* milliseconds */
    int x, y;		/* pointer x, y coordinates in event window */
    int x_root, y_root;	/* coordinates relative to root */
    uint state;	/* key or button mask */
    uint keycode;	/* detail */
    Bool same_screen;	/* same screen flag */
}
alias XKeyEvent XKeyPressedEvent;
alias XKeyEvent XKeyReleasedEvent;

struct XButtonEvent
{
    int type;		/* of event */
    c_ulong serial;	/* # of last request processed by server */
    Bool send_event;	/* true if this came from a SendEvent request */
    Display *display;	/* Display the event was read from */
    Window window;	        /* "event" window it is reported relative to */
    Window root;	        /* root window that the event occurred on */
    Window subwindow;	/* child window */
    Time time;		/* milliseconds */
    int x, y;		/* pointer x, y coordinates in event window */
    int x_root, y_root;	/* coordinates relative to root */
    uint state;	/* key or button mask */
    uint button;	/* detail */
    Bool same_screen;	/* same screen flag */
}
alias XButtonEvent XButtonPressedEvent;
alias XButtonEvent XButtonReleasedEvent;

struct XMotionEvent
{
    int type;		/* of event */
    c_ulong serial;	/* # of last request processed by server */
    Bool send_event;	/* true if this came from a SendEvent request */
    Display *display;	/* Display the event was read from */
    Window window;	        /* "event" window reported relative to */
    Window root;	        /* root window that the event occurred on */
    Window subwindow;	/* child window */
    Time time;		/* milliseconds */
    int x, y;		/* pointer x, y coordinates in event window */
    int x_root, y_root;	/* coordinates relative to root */
    uint state;	/* key or button mask */
    char is_hint;		/* detail */
    Bool same_screen;	/* same screen flag */
}
alias XMotionEvent XPointerMovedEvent;

struct XCrossingEvent
{
    int type;		/* of event */
    c_ulong serial;	/* # of last request processed by server */
    Bool send_event;	/* true if this came from a SendEvent request */
    Display *display;	/* Display the event was read from */
    Window window;	        /* "event" window reported relative to */
    Window root;	        /* root window that the event occurred on */
    Window subwindow;	/* child window */
    Time time;		/* milliseconds */
    int x, y;		/* pointer x, y coordinates in event window */
    int x_root, y_root;	/* coordinates relative to root */
    int mode;		/* NotifyNormal, NotifyGrab, NotifyUngrab */
    int detail;
    /*
     * NotifyAncestor, NotifyVirtual, NotifyInferior,
     * NotifyNonlinear,NotifyNonlinearVirtual
     */
    Bool same_screen;	/* same screen flag */
    Bool focus;		/* boolean focus */
    uint state;	/* key or button mask */
}
alias XCrossingEvent XEnterWindowEvent;
alias XCrossingEvent XLeaveWindowEvent;

struct XFocusChangeEvent
{
    int type;		/* FocusIn or FocusOut */
    c_ulong serial;	/* # of last request processed by server */
    Bool send_event;	/* true if this came from a SendEvent request */
    Display *display;	/* Display the event was read from */
    Window window;		/* window of event */
    int mode;		/* NotifyNormal, NotifyWhileGrabbed,
                   NotifyGrab, NotifyUngrab */
    int detail;
    /*
     * NotifyAncestor, NotifyVirtual, NotifyInferior,
     * NotifyNonlinear,NotifyNonlinearVirtual, NotifyPointer,
     * NotifyPointerRoot, NotifyDetailNone
     */
}
alias XFocusChangeEvent XFocusInEvent;
alias XFocusChangeEvent XFocusOutEvent;

/* generated on EnterWindow and FocusIn  when KeyMapState selected */
struct XKeymapEvent
{
    int type;
    c_ulong serial;	/* # of last request processed by server */
    Bool send_event;	/* true if this came from a SendEvent request */
    Display *display;	/* Display the event was read from */
    Window window;
    char[32] key_vector;
}

struct XExposeEvent
{
    int type;
    c_ulong serial;	/* # of last request processed by server */
    Bool send_event;	/* true if this came from a SendEvent request */
    Display *display;	/* Display the event was read from */
    Window window;
    int x, y;
    int width, height;
    int count;		/* if non-zero, at least this many more */
}

struct XGraphicsExposeEvent
{
    int type;
    c_ulong serial;	/* # of last request processed by server */
    Bool send_event;	/* true if this came from a SendEvent request */
    Display *display;	/* Display the event was read from */
    Drawable drawable;
    int x, y;
    int width, height;
    int count;		/* if non-zero, at least this many more */
    int major_code;		/* core is CopyArea or CopyPlane */
    int minor_code;		/* not defined in the core */
}

struct XNoExposeEvent
{
    int type;
    c_ulong serial;	/* # of last request processed by server */
    Bool send_event;	/* true if this came from a SendEvent request */
    Display *display;	/* Display the event was read from */
    Drawable drawable;
    int major_code;		/* core is CopyArea or CopyPlane */
    int minor_code;		/* not defined in the core */
}

struct  XVisibilityEvent {
    int type;
    c_ulong serial;	/* # of last request processed by server */
    Bool send_event;	/* true if this came from a SendEvent request */
    Display *display;	/* Display the event was read from */
    Window window;
    int state;		/* Visibility state */
}

struct XCreateWindowEvent
{
    int type;
    c_ulong serial;	/* # of last request processed by server */
    Bool send_event;	/* true if this came from a SendEvent request */
    Display *display;	/* Display the event was read from */
    Window parent;		/* parent of the window */
    Window window;		/* window id of window created */
    int x, y;		/* window location */
    int width, height;	/* size of window */
    int border_width;	/* border width */
    Bool override_redirect;	/* creation should be overridden */
}

struct XDestroyWindowEvent
{
    int type;
    c_ulong serial;	/* # of last request processed by server */
    Bool send_event;	/* true if this came from a SendEvent request */
    Display *display;	/* Display the event was read from */
    Window event;
    Window window;
}

struct XUnmapEvent
{
    int type;
    c_ulong serial;	/* # of last request processed by server */
    Bool send_event;	/* true if this came from a SendEvent request */
    Display *display;	/* Display the event was read from */
    Window event;
    Window window;
    Bool from_configure;
}

struct XMapEvent
{
    int type;
    c_ulong serial;	/* # of last request processed by server */
    Bool send_event;	/* true if this came from a SendEvent request */
    Display *display;	/* Display the event was read from */
    Window event;
    Window window;
    Bool override_redirect;	/* boolean, is override set... */
}

struct XMapRequestEvent
{
    int type;
    c_ulong serial;	/* # of last request processed by server */
    Bool send_event;	/* true if this came from a SendEvent request */
    Display *display;	/* Display the event was read from */
    Window parent;
    Window window;
}

struct XReparentEvent
{
    int type;
    c_ulong serial;	/* # of last request processed by server */
    Bool send_event;	/* true if this came from a SendEvent request */
    Display *display;	/* Display the event was read from */
    Window event;
    Window window;
    Window parent;
    int x, y;
    Bool override_redirect;
}

struct XConfigureEvent
{
    int type;
    c_ulong serial;	/* # of last request processed by server */
    Bool send_event;	/* true if this came from a SendEvent request */
    Display *display;	/* Display the event was read from */
    Window event;
    Window window;
    int x, y;
    int width, height;
    int border_width;
    Window above;
    Bool override_redirect;
}

struct XGravityEvent
{
    int type;
    c_ulong serial;	/* # of last request processed by server */
    Bool send_event;	/* true if this came from a SendEvent request */
    Display *display;	/* Display the event was read from */
    Window event;
    Window window;
    int x, y;
}

struct XResizeRequestEvent
{
    int type;
    c_ulong serial;	/* # of last request processed by server */
    Bool send_event;	/* true if this came from a SendEvent request */
    Display *display;	/* Display the event was read from */
    Window window;
    int width, height;
}

struct XConfigureRequestEvent
{
    int type;
    c_ulong serial;	/* # of last request processed by server */
    Bool send_event;	/* true if this came from a SendEvent request */
    Display *display;	/* Display the event was read from */
    Window parent;
    Window window;
    int x, y;
    int width, height;
    int border_width;
    Window above;
    int detail;		/* Above, Below, TopIf, BottomIf, Opposite */
    c_ulong value_mask;
}

struct XCirculateEvent
{
    int type;
    c_ulong serial;	/* # of last request processed by server */
    Bool send_event;	/* true if this came from a SendEvent request */
    Display *display;	/* Display the event was read from */
    Window event;
    Window window;
    int place;		/* PlaceOnTop, PlaceOnBottom */
}

struct XCirculateRequestEvent
{
    int type;
    c_ulong serial;	/* # of last request processed by server */
    Bool send_event;	/* true if this came from a SendEvent request */
    Display *display;	/* Display the event was read from */
    Window parent;
    Window window;
    int place;		/* PlaceOnTop, PlaceOnBottom */
}

struct XPropertyEvent
{
    int type;
    c_ulong serial;	/* # of last request processed by server */
    Bool send_event;	/* true if this came from a SendEvent request */
    Display *display;	/* Display the event was read from */
    Window window;
    Atom atom;
    Time time;
    int state;		/* NewValue, Deleted */
}

struct XSelectionClearEvent
{
    int type;
    c_ulong serial;	/* # of last request processed by server */
    Bool send_event;	/* true if this came from a SendEvent request */
    Display *display;	/* Display the event was read from */
    Window window;
    Atom selection;
    Time time;
}

struct XSelectionRequestEvent
{
    int type;
    c_ulong serial;	/* # of last request processed by server */
    Bool send_event;	/* true if this came from a SendEvent request */
    Display *display;	/* Display the event was read from */
    Window owner;
    Window requestor;
    Atom selection;
    Atom target;
    Atom property;
    Time time;
};

struct XSelectionEvent
{
    int type;
    c_ulong serial;	/* # of last request processed by server */
    Bool send_event;	/* true if this came from a SendEvent request */
    Display *display;	/* Display the event was read from */
    Window requestor;
    Atom selection;
    Atom target;
    Atom property;		/* ATOM or None */
    Time time;
}

struct XColormapEvent
{
    int type;
    c_ulong serial;	/* # of last request processed by server */
    Bool send_event;	/* true if this came from a SendEvent request */
    Display *display;	/* Display the event was read from */
    Window window;
    Colormap colormap;	/* COLORMAP or None */
    Bool c_new;		/* C++ */
    int state;		/* ColormapInstalled, ColormapUninstalled */
}

struct XClientMessageEvent
{
    int type;
    c_ulong serial;	/* # of last request processed by server */
    Bool send_event;	/* true if this came from a SendEvent request */
    Display *display;	/* Display the event was read from */
    Window window;
    Atom message_type;
    int format;
    union EvtData
    {
        char[20] b;
        short[10] s;
        c_long[5] l;
    }
    EvtData data;
}

struct XMappingEvent
{
    int type;
    c_ulong serial;	/* # of last request processed by server */
    Bool send_event;	/* true if this came from a SendEvent request */
    Display *display;	/* Display the event was read from */
    Window window;		/* unused */
    int request;		/* one of MappingModifier, MappingKeyboard,
                   MappingPointer */
    int first_keycode;	/* first keycode */
    int count;		/* defines range of change w. first_keycode*/
}

struct XErrorEvent
{
    int type;
    Display *display;	/* Display the event was read from */
    XID resourceid;		/* resource id */
    c_ulong serial;	/* serial number of failed request */
    ubyte error_code;	/* error code of failed request */
    ubyte request_code;	/* Major op-code of failed request */
    ubyte minor_code;	/* Minor op-code of failed request */
}

struct XAnyEvent
{
    int type;
    c_ulong serial;	/* # of last request processed by server */
    Bool send_event;	/* true if this came from a SendEvent request */
    Display *display;/* Display the event was read from */
    Window window;	/* window on which event was requested in event mask */
}


/***************************************************************
 *
 * GenericEvent.  This event is the standard event for all newer extensions.
 */

struct XGenericEvent
{
    int            type;         /* of event. Always GenericEvent */
    c_ulong  serial;       /* # of last request processed */
    Bool           send_event;   /* true if from SendEvent request */
    Display        *display;     /* Display the event was read from */
    int            extension;    /* major opcode of extension that caused the event */
    int            evtype;       /* actual event type. */
}

struct XGenericEventCookie
{
    int            type;         /* of event. Always GenericEvent */
    c_ulong  serial;       /* # of last request processed */
    Bool           send_event;   /* true if from SendEvent request */
    Display        *display;     /* Display the event was read from */
    int            extension;    /* major opcode of extension that caused the event */
    int            evtype;       /* actual event type. */
    uint   cookie;
    void           *data;
}

/*
 * this union is defined so Xlib can always use the same sized
 * event structure internally, to avoid memory fragmentation.
 */
union XEvent
{
    int type;		/* must not be changed; first element */
    XAnyEvent xany;
    XKeyEvent xkey;
    XButtonEvent xbutton;
    XMotionEvent xmotion;
    XCrossingEvent xcrossing;
    XFocusChangeEvent xfocus;
    XExposeEvent xexpose;
    XGraphicsExposeEvent xgraphicsexpose;
    XNoExposeEvent xnoexpose;
    XVisibilityEvent xvisibility;
    XCreateWindowEvent xcreatewindow;
    XDestroyWindowEvent xdestroywindow;
    XUnmapEvent xunmap;
    XMapEvent xmap;
    XMapRequestEvent xmaprequest;
    XReparentEvent xreparent;
    XConfigureEvent xconfigure;
    XGravityEvent xgravity;
    XResizeRequestEvent xresizerequest;
    XConfigureRequestEvent xconfigurerequest;
    XCirculateEvent xcirculate;
    XCirculateRequestEvent xcirculaterequest;
    XPropertyEvent xproperty;
    XSelectionClearEvent xselectionclear;
    XSelectionRequestEvent xselectionrequest;
    XSelectionEvent xselection;
    XColormapEvent xcolormap;
    XClientMessageEvent xclient;
    XMappingEvent xmapping;
    XErrorEvent xerror;
    XKeymapEvent xkeymap;
    XGenericEvent xgeneric;
    XGenericEventCookie xcookie;
    c_long[24] pad;
}

//
// XExt interface
//

alias int function(Display* display, const(char)* extensionName, const(char)* failureReason) XextErrorHandler;
XextErrorHandler XSetExtensionErrorHandler(XextErrorHandler handler);

//
// XInput 1/2 interface
//

/* Device types */
enum
{
    XIMasterPointer                         = 1,
    XIMasterKeyboard                        = 2,
    XISlavePointer                          = 3,
    XISlaveKeyboard                         = 4,
    XIFloatingSlave                         = 5,
}

enum
{
    XIAllDevices                            = 0,
    XIAllMasterDevices                      = 1,
}

struct XIAnyClassInfo;

struct XIEventMask
{
    int deviceid;
    int mask_len;
    ubyte* mask;
}

struct XIDeviceInfo
{
    int deviceid;
    char* name;
    int use;
    int attachment;
    Bool enabled;
    int num_classes;
    XIAnyClassInfo **classes;
}

int XISelectEvents(Display* display, Window window, XIEventMask* masks, int numMasks);
Status XIQueryVersion(Display* display, int* majorVersion, int* minorVersion);
XIDeviceInfo* XIQueryDevice(Display* display, int deviceID, int* devicesReturnedNumber);
void XIFreeDeviceInfo(XIDeviceInfo* info);

void XISetMask(ubyte* ptr, int event)
{
    ptr[(event)>>3] |=  (1 << ((event) & 7));
}

struct XIValuatorState
{
    int           mask_len;
    ubyte         *mask;
    double        *values;
}

struct XIRawEvent
{
    int           type;         /* GenericEvent */
    ulong serial;               /* # of last request processed by server */
    Bool          send_event;   /* true if this came from a SendEvent request */
    Display       *display;     /* Display the event was read from */
    int           extension;    /* XI extension offset */
    int           evtype;       /* XI_RawKeyPress, XI_RawKeyRelease, etc. */
    Time          time;
    int           deviceid;
    int           sourceid;     /* Bug: Always 0. https://bugs.freedesktop.org//show_bug.cgi?id=34240 */
    int           detail;
    int           flags;
    XIValuatorState valuators;
    double        *raw_values;
}

/* Used in SetInputFocus, GetInputFocus */
enum RevertToNone		 = cast(int)None;
enum RevertToPointerRoot = cast(int)PointerRoot;
enum RevertToParent      = 2;

/* Event types */
enum XI_DeviceChanged                 = 1;
enum XI_KeyPress                      = 2;
enum XI_KeyRelease                    = 3;
enum XI_ButtonPress                   = 4;
enum XI_ButtonRelease                 = 5;
enum XI_Motion                        = 6;
enum XI_Enter                         = 7;
enum XI_Leave                         = 8;
enum XI_FocusIn                       = 9;
enum XI_FocusOut                      = 10;
enum XI_HierarchyChanged              = 11;
enum XI_PropertyEvent                 = 12;
enum XI_RawKeyPress                   = 13;
enum XI_RawKeyRelease                 = 14;
enum XI_RawButtonPress                = 15;
enum XI_RawButtonRelease              = 16;
enum XI_RawMotion                     = 17;
enum XI_TouchBegin                    = 18; /* XI 2.2 */
enum XI_TouchUpdate                   = 19;
enum XI_TouchEnd                      = 20;
enum XI_TouchOwnership                = 21;
enum XI_RawTouchBegin                 = 22;
enum XI_RawTouchUpdate                = 23;
enum XI_RawTouchEnd                   = 24;
enum XI_BarrierHit                    = 25; /* XI 2.3 */
enum XI_BarrierLeave                  = 26;
enum XI_LASTEVENT                     = XI_BarrierLeave;

bool XIMaskIsSet(ubyte* ptr, uint event)
{
    //((unsigned char*)(ptr))[(event)>>3] &   (1 << ((event) & 7))
    return cast(bool)( (cast(ubyte*)(ptr))[(event)>>3] & (1 << ((event) & 7)));
}

// Xatom.h
enum Atom XA_PRIMARY = 1;
enum Atom XA_SECONDARY = 2;
enum Atom XA_ARC = 3;
enum Atom XA_ATOM = 4;
enum Atom XA_BITMAP = 5;
enum Atom XA_CARDINAL = 6;
enum Atom XA_COLORMAP = 7;
enum Atom XA_CURSOR = 8;
enum Atom XA_CUT_BUFFER0 = 9;
enum Atom XA_CUT_BUFFER1 = 10;
enum Atom XA_CUT_BUFFER2 = 11;
enum Atom XA_CUT_BUFFER3 = 12;
enum Atom XA_CUT_BUFFER4 = 13;
enum Atom XA_CUT_BUFFER5 = 14;
enum Atom XA_CUT_BUFFER6 = 15;
enum Atom XA_CUT_BUFFER7 = 16;
enum Atom XA_DRAWABLE = 17;
enum Atom XA_FONT = 18;
enum Atom XA_INTEGER = 19;
enum Atom XA_PIXMAP = 20;
enum Atom XA_POINT = 21;
enum Atom XA_RECTANGLE = 22;
enum Atom XA_RESOURCE_MANAGER = 23;
enum Atom XA_RGB_COLOR_MAP = 24;
enum Atom XA_RGB_BEST_MAP = 25;
enum Atom XA_RGB_BLUE_MAP = 26;
enum Atom XA_RGB_DEFAULT_MAP = 27;
enum Atom XA_RGB_GRAY_MAP = 28;
enum Atom XA_RGB_GREEN_MAP = 29;
enum Atom XA_RGB_RED_MAP = 30;
enum Atom XA_STRING = 31;
enum Atom XA_VISUALID = 32;
enum Atom XA_WINDOW = 33;
enum Atom XA_WM_COMMAND = 34;
enum Atom XA_WM_HINTS = 35;
enum Atom XA_WM_CLIENT_MACHINE = 36;
enum Atom XA_WM_ICON_NAME = 37;
enum Atom XA_WM_ICON_SIZE = 38;
enum Atom XA_WM_NAME = 39;
enum Atom XA_WM_NORMAL_HINTS = 40;
enum Atom XA_WM_SIZE_HINTS = 41;
enum Atom XA_WM_ZOOM_HINTS = 42;
enum Atom XA_MIN_SPACE = 43;
enum Atom XA_NORM_SPACE = 44;
enum Atom XA_MAX_SPACE = 45;
enum Atom XA_END_SPACE = 46;
enum Atom XA_SUPERSCRIPT_X = 47;
enum Atom XA_SUPERSCRIPT_Y = 48;
enum Atom XA_SUBSCRIPT_X = 49;
enum Atom XA_SUBSCRIPT_Y = 50;
enum Atom XA_UNDERLINE_POSITION = 51;
enum Atom XA_UNDERLINE_THICKNESS = 52;
enum Atom XA_STRIKEOUT_ASCENT = 53;
enum Atom XA_STRIKEOUT_DESCENT = 54;
enum Atom XA_ITALIC_ANGLE = 55;
enum Atom XA_X_HEIGHT = 56;
enum Atom XA_QUAD_WIDTH = 57;
enum Atom XA_WEIGHT = 58;
enum Atom XA_POINT_SIZE = 59;
enum Atom XA_RESOLUTION = 60;
enum Atom XA_COPYRIGHT = 61;
enum Atom XA_NOTICE = 62;
enum Atom XA_FONT_NAME = 63;
enum Atom XA_FAMILY_NAME = 64;
enum Atom XA_FULL_NAME = 65;
enum Atom XA_CAP_HEIGHT = 66;
enum Atom XA_WM_CLASS = 67;
enum Atom XA_WM_TRANSIENT_FOR = 68;

enum Atom XA_LAST_PREDEFINED = 68;


/*
enum XI_DeviceChangedMask             = (1 << XI_DeviceChanged);
enum XI_KeyPressMask                  = (1 << XI_KeyPress);
enum XI_KeyReleaseMask                = (1 << XI_KeyRelease);
enum XI_ButtonPressMask               = (1 << XI_ButtonPress);
enum XI_ButtonReleaseMask             = (1 << XI_ButtonRelease);
enum XI_MotionMask                    = (1 << XI_Motion);
enum XI_EnterMask                     = (1 << XI_Enter);
enum XI_LeaveMask                     = (1 << XI_Leave);
enum XI_FocusInMask                   = (1 << XI_FocusIn);
enum XI_FocusOutMask                  = (1 << XI_FocusOut);
enum XI_HierarchyChangedMask          = (1 << XI_HierarchyChanged);
enum XI_PropertyEventMask             = (1 << XI_PropertyEvent);
enum XI_RawKeyPressMask               = (1 << XI_RawKeyPress);
enum XI_RawKeyReleaseMask             = (1 << XI_RawKeyRelease);
enum XI_RawButtonPressMask            = (1 << XI_RawButtonPress);
enum XI_RawButtonReleaseMask          = (1 << XI_RawButtonRelease);
enum XI_RawMotionMask                 = (1 << XI_RawMotion);
enum XI_TouchBeginMask                = (1 << XI_TouchBegin);
enum XI_TouchEndMask                  = (1 << XI_TouchEnd);
enum XI_TouchOwnershipChangedMask     = (1 << XI_TouchOwnership);
enum XI_TouchUpdateMask               = (1 << XI_TouchUpdate);
enum XI_RawTouchBeginMask             = (1 << XI_RawTouchBegin);
enum XI_RawTouchEndMask               = (1 << XI_RawTouchEnd);
enum XI_RawTouchUpdateMask            = (1 << XI_RawTouchUpdate);
enum XI_BarrierHitMask                = (1 << XI_BarrierHit);
enum XI_BarrierLeaveMask              = (1 << XI_BarrierLeave);*/


// Keysyms from keysymdef. Translated to D automatically by dstep.

enum XK_VoidSymbol = 0xffffff; /* Void symbol */

/*
 * TTY function keys, cleverly chosen to map to ASCII, for convenience of
 * programming, but could have been arbitrary (at the cost of lookup
 * tables in client code).
 */

enum XK_BackSpace = 0xff08; /* U+0008 BACKSPACE */
enum XK_Tab = 0xff09; /* U+0009 CHARACTER TABULATION */
enum XK_Linefeed = 0xff0a; /* U+000A LINE FEED */
enum XK_Clear = 0xff0b; /* U+000B LINE TABULATION */
enum XK_Return = 0xff0d; /* U+000D CARRIAGE RETURN */
enum XK_Pause = 0xff13; /* Pause, hold */
enum XK_Scroll_Lock = 0xff14;
enum XK_Sys_Req = 0xff15;
enum XK_Escape = 0xff1b; /* U+001B ESCAPE */
enum XK_Delete = 0xffff; /* U+007F DELETE */

/* International & multi-key character composition */

enum XK_Multi_key = 0xff20; /* Multi-key character compose */
enum XK_Codeinput = 0xff37;
enum XK_SingleCandidate = 0xff3c;
enum XK_MultipleCandidate = 0xff3d;
enum XK_PreviousCandidate = 0xff3e;

/* Japanese keyboard support */

enum XK_Kanji = 0xff21; /* Kanji, Kanji convert */
enum XK_Muhenkan = 0xff22; /* Cancel Conversion */
enum XK_Henkan_Mode = 0xff23; /* Start/Stop Conversion */
enum XK_Henkan = 0xff23; /* non-deprecated alias for Henkan_Mode */
enum XK_Romaji = 0xff24; /* to Romaji */
enum XK_Hiragana = 0xff25; /* to Hiragana */
enum XK_Katakana = 0xff26; /* to Katakana */
enum XK_Hiragana_Katakana = 0xff27; /* Hiragana/Katakana toggle */
enum XK_Zenkaku = 0xff28; /* to Zenkaku */
enum XK_Hankaku = 0xff29; /* to Hankaku */
enum XK_Zenkaku_Hankaku = 0xff2a; /* Zenkaku/Hankaku toggle */
enum XK_Touroku = 0xff2b; /* Add to Dictionary */
enum XK_Massyo = 0xff2c; /* Delete from Dictionary */
enum XK_Kana_Lock = 0xff2d; /* Kana Lock */
enum XK_Kana_Shift = 0xff2e; /* Kana Shift */
enum XK_Eisu_Shift = 0xff2f; /* Alphanumeric Shift */
enum XK_Eisu_toggle = 0xff30; /* Alphanumeric toggle */
enum XK_Kanji_Bangou = 0xff37; /* Codeinput */
enum XK_Zen_Koho = 0xff3d; /* Multiple/All Candidate(s) */
enum XK_Mae_Koho = 0xff3e; /* Previous Candidate */

/* 0xff31 thru 0xff3f are under XK_KOREAN */

/* Cursor control & motion */

enum XK_Home = 0xff50;
enum XK_Left = 0xff51; /* Move left, left arrow */
enum XK_Up = 0xff52; /* Move up, up arrow */
enum XK_Right = 0xff53; /* Move right, right arrow */
enum XK_Down = 0xff54; /* Move down, down arrow */
enum XK_Prior = 0xff55; /* Prior, previous */
enum XK_Page_Up = 0xff55; /* deprecated alias for Prior */
enum XK_Next = 0xff56; /* Next */
enum XK_Page_Down = 0xff56; /* deprecated alias for Next */
enum XK_End = 0xff57; /* EOL */
enum XK_Begin = 0xff58; /* BOL */

/* Misc functions */

enum XK_Select = 0xff60; /* Select, mark */
enum XK_Print = 0xff61;
enum XK_Execute = 0xff62; /* Execute, run, do */
enum XK_Insert = 0xff63; /* Insert, insert here */
enum XK_Undo = 0xff65;
enum XK_Redo = 0xff66; /* Redo, again */
enum XK_Menu = 0xff67;
enum XK_Find = 0xff68; /* Find, search */
enum XK_Cancel = 0xff69; /* Cancel, stop, abort, exit */
enum XK_Help = 0xff6a; /* Help */
enum XK_Break = 0xff6b;
enum XK_Mode_switch = 0xff7e; /* Character set switch */
enum XK_script_switch = 0xff7e; /* non-deprecated alias for Mode_switch */
enum XK_Num_Lock = 0xff7f;

/* Keypad functions, keypad numbers cleverly chosen to map to ASCII */

enum XK_KP_Space = 0xff80; /*<U+0020 SPACE>*/
enum XK_KP_Tab = 0xff89; /*<U+0009 CHARACTER TABULATION>*/
enum XK_KP_Enter = 0xff8d; /*<U+000D CARRIAGE RETURN>*/
enum XK_KP_F1 = 0xff91; /* PF1, KP_A, ... */
enum XK_KP_F2 = 0xff92;
enum XK_KP_F3 = 0xff93;
enum XK_KP_F4 = 0xff94;
enum XK_KP_Home = 0xff95;
enum XK_KP_Left = 0xff96;
enum XK_KP_Up = 0xff97;
enum XK_KP_Right = 0xff98;
enum XK_KP_Down = 0xff99;
enum XK_KP_Prior = 0xff9a;
enum XK_KP_Page_Up = 0xff9a; /* deprecated alias for KP_Prior */
enum XK_KP_Next = 0xff9b;
enum XK_KP_Page_Down = 0xff9b; /* deprecated alias for KP_Next */
enum XK_KP_End = 0xff9c;
enum XK_KP_Begin = 0xff9d;
enum XK_KP_Insert = 0xff9e;
enum XK_KP_Delete = 0xff9f;
enum XK_KP_Equal = 0xffbd; /*<U+003D EQUALS SIGN>*/
enum XK_KP_Multiply = 0xffaa; /*<U+002A ASTERISK>*/
enum XK_KP_Add = 0xffab; /*<U+002B PLUS SIGN>*/
enum XK_KP_Separator = 0xffac; /*<U+002C COMMA>*/
enum XK_KP_Subtract = 0xffad; /*<U+002D HYPHEN-MINUS>*/
enum XK_KP_Decimal = 0xffae; /*<U+002E FULL STOP>*/
enum XK_KP_Divide = 0xffaf; /*<U+002F SOLIDUS>*/

enum XK_KP_0 = 0xffb0; /*<U+0030 DIGIT ZERO>*/
enum XK_KP_1 = 0xffb1; /*<U+0031 DIGIT ONE>*/
enum XK_KP_2 = 0xffb2; /*<U+0032 DIGIT TWO>*/
enum XK_KP_3 = 0xffb3; /*<U+0033 DIGIT THREE>*/
enum XK_KP_4 = 0xffb4; /*<U+0034 DIGIT FOUR>*/
enum XK_KP_5 = 0xffb5; /*<U+0035 DIGIT FIVE>*/
enum XK_KP_6 = 0xffb6; /*<U+0036 DIGIT SIX>*/
enum XK_KP_7 = 0xffb7; /*<U+0037 DIGIT SEVEN>*/
enum XK_KP_8 = 0xffb8; /*<U+0038 DIGIT EIGHT>*/
enum XK_KP_9 = 0xffb9; /*<U+0039 DIGIT NINE>*/

/*
 * Auxiliary functions; note the duplicate definitions for left and right
 * function keys;  Sun keyboards and a few other manufacturers have such
 * function key groups on the left and/or right sides of the keyboard.
 * We've not found a keyboard with more than 35 function keys total.
 */

enum XK_F1 = 0xffbe;
enum XK_F2 = 0xffbf;
enum XK_F3 = 0xffc0;
enum XK_F4 = 0xffc1;
enum XK_F5 = 0xffc2;
enum XK_F6 = 0xffc3;
enum XK_F7 = 0xffc4;
enum XK_F8 = 0xffc5;
enum XK_F9 = 0xffc6;
enum XK_F10 = 0xffc7;
enum XK_F11 = 0xffc8;
enum XK_L1 = 0xffc8; /* deprecated alias for F11 */
enum XK_F12 = 0xffc9;
enum XK_L2 = 0xffc9; /* deprecated alias for F12 */
enum XK_F13 = 0xffca;
enum XK_L3 = 0xffca; /* deprecated alias for F13 */
enum XK_F14 = 0xffcb;
enum XK_L4 = 0xffcb; /* deprecated alias for F14 */
enum XK_F15 = 0xffcc;
enum XK_L5 = 0xffcc; /* deprecated alias for F15 */
enum XK_F16 = 0xffcd;
enum XK_L6 = 0xffcd; /* deprecated alias for F16 */
enum XK_F17 = 0xffce;
enum XK_L7 = 0xffce; /* deprecated alias for F17 */
enum XK_F18 = 0xffcf;
enum XK_L8 = 0xffcf; /* deprecated alias for F18 */
enum XK_F19 = 0xffd0;
enum XK_L9 = 0xffd0; /* deprecated alias for F19 */
enum XK_F20 = 0xffd1;
enum XK_L10 = 0xffd1; /* deprecated alias for F20 */
enum XK_F21 = 0xffd2;
enum XK_R1 = 0xffd2; /* deprecated alias for F21 */
enum XK_F22 = 0xffd3;
enum XK_R2 = 0xffd3; /* deprecated alias for F22 */
enum XK_F23 = 0xffd4;
enum XK_R3 = 0xffd4; /* deprecated alias for F23 */
enum XK_F24 = 0xffd5;
enum XK_R4 = 0xffd5; /* deprecated alias for F24 */
enum XK_F25 = 0xffd6;
enum XK_R5 = 0xffd6; /* deprecated alias for F25 */
enum XK_F26 = 0xffd7;
enum XK_R6 = 0xffd7; /* deprecated alias for F26 */
enum XK_F27 = 0xffd8;
enum XK_R7 = 0xffd8; /* deprecated alias for F27 */
enum XK_F28 = 0xffd9;
enum XK_R8 = 0xffd9; /* deprecated alias for F28 */
enum XK_F29 = 0xffda;
enum XK_R9 = 0xffda; /* deprecated alias for F29 */
enum XK_F30 = 0xffdb;
enum XK_R10 = 0xffdb; /* deprecated alias for F30 */
enum XK_F31 = 0xffdc;
enum XK_R11 = 0xffdc; /* deprecated alias for F31 */
enum XK_F32 = 0xffdd;
enum XK_R12 = 0xffdd; /* deprecated alias for F32 */
enum XK_F33 = 0xffde;
enum XK_R13 = 0xffde; /* deprecated alias for F33 */
enum XK_F34 = 0xffdf;
enum XK_R14 = 0xffdf; /* deprecated alias for F34 */
enum XK_F35 = 0xffe0;
enum XK_R15 = 0xffe0; /* deprecated alias for F35 */

/* Modifiers */

enum XK_Shift_L = 0xffe1; /* Left shift */
enum XK_Shift_R = 0xffe2; /* Right shift */
enum XK_Control_L = 0xffe3; /* Left control */
enum XK_Control_R = 0xffe4; /* Right control */
enum XK_Caps_Lock = 0xffe5; /* Caps lock */
enum XK_Shift_Lock = 0xffe6; /* Shift lock */

enum XK_Meta_L = 0xffe7; /* Left meta */
enum XK_Meta_R = 0xffe8; /* Right meta */
enum XK_Alt_L = 0xffe9; /* Left alt */
enum XK_Alt_R = 0xffea; /* Right alt */
enum XK_Super_L = 0xffeb; /* Left super */
enum XK_Super_R = 0xffec; /* Right super */
enum XK_Hyper_L = 0xffed; /* Left hyper */
enum XK_Hyper_R = 0xffee; /* Right hyper */
/* XK_MISCELLANY */

/*
 * Keyboard (XKB) Extension function and modifier keys
 * (from Appendix C of "The X Keyboard Extension: Protocol Specification")
 * Byte 3 = 0xfe
 */

enum XK_ISO_Lock = 0xfe01;
enum XK_ISO_Level2_Latch = 0xfe02;
enum XK_ISO_Level3_Shift = 0xfe03;
enum XK_ISO_Level3_Latch = 0xfe04;
enum XK_ISO_Level3_Lock = 0xfe05;
enum XK_ISO_Level5_Shift = 0xfe11;
enum XK_ISO_Level5_Latch = 0xfe12;
enum XK_ISO_Level5_Lock = 0xfe13;
enum XK_ISO_Group_Shift = 0xff7e; /* non-deprecated alias for Mode_switch */
enum XK_ISO_Group_Latch = 0xfe06;
enum XK_ISO_Group_Lock = 0xfe07;
enum XK_ISO_Next_Group = 0xfe08;
enum XK_ISO_Next_Group_Lock = 0xfe09;
enum XK_ISO_Prev_Group = 0xfe0a;
enum XK_ISO_Prev_Group_Lock = 0xfe0b;
enum XK_ISO_First_Group = 0xfe0c;
enum XK_ISO_First_Group_Lock = 0xfe0d;
enum XK_ISO_Last_Group = 0xfe0e;
enum XK_ISO_Last_Group_Lock = 0xfe0f;

enum XK_ISO_Left_Tab = 0xfe20;
enum XK_ISO_Move_Line_Up = 0xfe21;
enum XK_ISO_Move_Line_Down = 0xfe22;
enum XK_ISO_Partial_Line_Up = 0xfe23;
enum XK_ISO_Partial_Line_Down = 0xfe24;
enum XK_ISO_Partial_Space_Left = 0xfe25;
enum XK_ISO_Partial_Space_Right = 0xfe26;
enum XK_ISO_Set_Margin_Left = 0xfe27;
enum XK_ISO_Set_Margin_Right = 0xfe28;
enum XK_ISO_Release_Margin_Left = 0xfe29;
enum XK_ISO_Release_Margin_Right = 0xfe2a;
enum XK_ISO_Release_Both_Margins = 0xfe2b;
enum XK_ISO_Fast_Cursor_Left = 0xfe2c;
enum XK_ISO_Fast_Cursor_Right = 0xfe2d;
enum XK_ISO_Fast_Cursor_Up = 0xfe2e;
enum XK_ISO_Fast_Cursor_Down = 0xfe2f;
enum XK_ISO_Continuous_Underline = 0xfe30;
enum XK_ISO_Discontinuous_Underline = 0xfe31;
enum XK_ISO_Emphasize = 0xfe32;
enum XK_ISO_Center_Object = 0xfe33;
enum XK_ISO_Enter = 0xfe34;

enum XK_dead_grave = 0xfe50;
enum XK_dead_acute = 0xfe51;
enum XK_dead_circumflex = 0xfe52;
enum XK_dead_tilde = 0xfe53;
enum XK_dead_perispomeni = 0xfe53; /* non-deprecated alias for dead_tilde */
enum XK_dead_macron = 0xfe54;
enum XK_dead_breve = 0xfe55;
enum XK_dead_abovedot = 0xfe56;
enum XK_dead_diaeresis = 0xfe57;
enum XK_dead_abovering = 0xfe58;
enum XK_dead_doubleacute = 0xfe59;
enum XK_dead_caron = 0xfe5a;
enum XK_dead_cedilla = 0xfe5b;
enum XK_dead_ogonek = 0xfe5c;
enum XK_dead_iota = 0xfe5d;
enum XK_dead_voiced_sound = 0xfe5e;
enum XK_dead_semivoiced_sound = 0xfe5f;
enum XK_dead_belowdot = 0xfe60;
enum XK_dead_hook = 0xfe61;
enum XK_dead_horn = 0xfe62;
enum XK_dead_stroke = 0xfe63;
enum XK_dead_abovecomma = 0xfe64;
enum XK_dead_psili = 0xfe64; /* non-deprecated alias for dead_abovecomma */
enum XK_dead_abovereversedcomma = 0xfe65;
enum XK_dead_dasia = 0xfe65; /* non-deprecated alias for dead_abovereversedcomma */
enum XK_dead_doublegrave = 0xfe66;
enum XK_dead_belowring = 0xfe67;
enum XK_dead_belowmacron = 0xfe68;
enum XK_dead_belowcircumflex = 0xfe69;
enum XK_dead_belowtilde = 0xfe6a;
enum XK_dead_belowbreve = 0xfe6b;
enum XK_dead_belowdiaeresis = 0xfe6c;
enum XK_dead_invertedbreve = 0xfe6d;
enum XK_dead_belowcomma = 0xfe6e;
enum XK_dead_currency = 0xfe6f;

/* extra dead elements for German T3 layout */
enum XK_dead_lowline = 0xfe90;
enum XK_dead_aboveverticalline = 0xfe91;
enum XK_dead_belowverticalline = 0xfe92;
enum XK_dead_longsolidusoverlay = 0xfe93;

/* dead vowels for universal syllable entry */
enum XK_dead_a = 0xfe80;
enum XK_dead_A = 0xfe81;
enum XK_dead_e = 0xfe82;
enum XK_dead_E = 0xfe83;
enum XK_dead_i = 0xfe84;
enum XK_dead_I = 0xfe85;
enum XK_dead_o = 0xfe86;
enum XK_dead_O = 0xfe87;
enum XK_dead_u = 0xfe88;
enum XK_dead_U = 0xfe89;
enum XK_dead_small_schwa = 0xfe8a; /* deprecated alias for dead_schwa */
enum XK_dead_schwa = 0xfe8a;
enum XK_dead_capital_schwa = 0xfe8b; /* deprecated alias for dead_SCHWA */
enum XK_dead_SCHWA = 0xfe8b;

enum XK_dead_greek = 0xfe8c;
enum XK_dead_hamza = 0xfe8d;

enum XK_First_Virtual_Screen = 0xfed0;
enum XK_Prev_Virtual_Screen = 0xfed1;
enum XK_Next_Virtual_Screen = 0xfed2;
enum XK_Last_Virtual_Screen = 0xfed4;
enum XK_Terminate_Server = 0xfed5;

enum XK_AccessX_Enable = 0xfe70;
enum XK_AccessX_Feedback_Enable = 0xfe71;
enum XK_RepeatKeys_Enable = 0xfe72;
enum XK_SlowKeys_Enable = 0xfe73;
enum XK_BounceKeys_Enable = 0xfe74;
enum XK_StickyKeys_Enable = 0xfe75;
enum XK_MouseKeys_Enable = 0xfe76;
enum XK_MouseKeys_Accel_Enable = 0xfe77;
enum XK_Overlay1_Enable = 0xfe78;
enum XK_Overlay2_Enable = 0xfe79;
enum XK_AudibleBell_Enable = 0xfe7a;

enum XK_Pointer_Left = 0xfee0;
enum XK_Pointer_Right = 0xfee1;
enum XK_Pointer_Up = 0xfee2;
enum XK_Pointer_Down = 0xfee3;
enum XK_Pointer_UpLeft = 0xfee4;
enum XK_Pointer_UpRight = 0xfee5;
enum XK_Pointer_DownLeft = 0xfee6;
enum XK_Pointer_DownRight = 0xfee7;
enum XK_Pointer_Button_Dflt = 0xfee8;
enum XK_Pointer_Button1 = 0xfee9;
enum XK_Pointer_Button2 = 0xfeea;
enum XK_Pointer_Button3 = 0xfeeb;
enum XK_Pointer_Button4 = 0xfeec;
enum XK_Pointer_Button5 = 0xfeed;
enum XK_Pointer_DblClick_Dflt = 0xfeee;
enum XK_Pointer_DblClick1 = 0xfeef;
enum XK_Pointer_DblClick2 = 0xfef0;
enum XK_Pointer_DblClick3 = 0xfef1;
enum XK_Pointer_DblClick4 = 0xfef2;
enum XK_Pointer_DblClick5 = 0xfef3;
enum XK_Pointer_Drag_Dflt = 0xfef4;
enum XK_Pointer_Drag1 = 0xfef5;
enum XK_Pointer_Drag2 = 0xfef6;
enum XK_Pointer_Drag3 = 0xfef7;
enum XK_Pointer_Drag4 = 0xfef8;
enum XK_Pointer_Drag5 = 0xfefd;

enum XK_Pointer_EnableKeys = 0xfef9;
enum XK_Pointer_Accelerate = 0xfefa;
enum XK_Pointer_DfltBtnNext = 0xfefb;
enum XK_Pointer_DfltBtnPrev = 0xfefc;

/* Single-Stroke Multiple-Character N-Graph Keysyms For The X Input Method */

enum XK_ch = 0xfea0;
enum XK_Ch = 0xfea1;
enum XK_CH = 0xfea2;
enum XK_c_h = 0xfea3;
enum XK_C_h = 0xfea4;
enum XK_C_H = 0xfea5;

/* XK_XKB_KEYS */

/*
 * 3270 Terminal Keys
 * Byte 3 = 0xfd
 */

/* XK_3270 */

/*
 * Latin 1
 * (ISO/IEC 8859-1 = Unicode U+0020..U+00FF)
 * Byte 3 = 0
 */
enum XK_space = 0x0020; /* U+0020 SPACE */
enum XK_exclam = 0x0021; /* U+0021 EXCLAMATION MARK */
enum XK_quotedbl = 0x0022; /* U+0022 QUOTATION MARK */
enum XK_numbersign = 0x0023; /* U+0023 NUMBER SIGN */
enum XK_dollar = 0x0024; /* U+0024 DOLLAR SIGN */
enum XK_percent = 0x0025; /* U+0025 PERCENT SIGN */
enum XK_ampersand = 0x0026; /* U+0026 AMPERSAND */
enum XK_apostrophe = 0x0027; /* U+0027 APOSTROPHE */
enum XK_quoteright = 0x0027; /* deprecated */
enum XK_parenleft = 0x0028; /* U+0028 LEFT PARENTHESIS */
enum XK_parenright = 0x0029; /* U+0029 RIGHT PARENTHESIS */
enum XK_asterisk = 0x002a; /* U+002A ASTERISK */
enum XK_plus = 0x002b; /* U+002B PLUS SIGN */
enum XK_comma = 0x002c; /* U+002C COMMA */
enum XK_minus = 0x002d; /* U+002D HYPHEN-MINUS */
enum XK_period = 0x002e; /* U+002E FULL STOP */
enum XK_slash = 0x002f; /* U+002F SOLIDUS */
enum XK_0 = 0x0030; /* U+0030 DIGIT ZERO */
enum XK_1 = 0x0031; /* U+0031 DIGIT ONE */
enum XK_2 = 0x0032; /* U+0032 DIGIT TWO */
enum XK_3 = 0x0033; /* U+0033 DIGIT THREE */
enum XK_4 = 0x0034; /* U+0034 DIGIT FOUR */
enum XK_5 = 0x0035; /* U+0035 DIGIT FIVE */
enum XK_6 = 0x0036; /* U+0036 DIGIT SIX */
enum XK_7 = 0x0037; /* U+0037 DIGIT SEVEN */
enum XK_8 = 0x0038; /* U+0038 DIGIT EIGHT */
enum XK_9 = 0x0039; /* U+0039 DIGIT NINE */
enum XK_colon = 0x003a; /* U+003A COLON */
enum XK_semicolon = 0x003b; /* U+003B SEMICOLON */
enum XK_less = 0x003c; /* U+003C LESS-THAN SIGN */
enum XK_equal = 0x003d; /* U+003D EQUALS SIGN */
enum XK_greater = 0x003e; /* U+003E GREATER-THAN SIGN */
enum XK_question = 0x003f; /* U+003F QUESTION MARK */
enum XK_at = 0x0040; /* U+0040 COMMERCIAL AT */
enum XK_A = 0x0041; /* U+0041 LATIN CAPITAL LETTER A */
enum XK_B = 0x0042; /* U+0042 LATIN CAPITAL LETTER B */
enum XK_C = 0x0043; /* U+0043 LATIN CAPITAL LETTER C */
enum XK_D = 0x0044; /* U+0044 LATIN CAPITAL LETTER D */
enum XK_E = 0x0045; /* U+0045 LATIN CAPITAL LETTER E */
enum XK_F = 0x0046; /* U+0046 LATIN CAPITAL LETTER F */
enum XK_G = 0x0047; /* U+0047 LATIN CAPITAL LETTER G */
enum XK_H = 0x0048; /* U+0048 LATIN CAPITAL LETTER H */
enum XK_I = 0x0049; /* U+0049 LATIN CAPITAL LETTER I */
enum XK_J = 0x004a; /* U+004A LATIN CAPITAL LETTER J */
enum XK_K = 0x004b; /* U+004B LATIN CAPITAL LETTER K */
enum XK_L = 0x004c; /* U+004C LATIN CAPITAL LETTER L */
enum XK_M = 0x004d; /* U+004D LATIN CAPITAL LETTER M */
enum XK_N = 0x004e; /* U+004E LATIN CAPITAL LETTER N */
enum XK_O = 0x004f; /* U+004F LATIN CAPITAL LETTER O */
enum XK_P = 0x0050; /* U+0050 LATIN CAPITAL LETTER P */
enum XK_Q = 0x0051; /* U+0051 LATIN CAPITAL LETTER Q */
enum XK_R = 0x0052; /* U+0052 LATIN CAPITAL LETTER R */
enum XK_S = 0x0053; /* U+0053 LATIN CAPITAL LETTER S */
enum XK_T = 0x0054; /* U+0054 LATIN CAPITAL LETTER T */
enum XK_U = 0x0055; /* U+0055 LATIN CAPITAL LETTER U */
enum XK_V = 0x0056; /* U+0056 LATIN CAPITAL LETTER V */
enum XK_W = 0x0057; /* U+0057 LATIN CAPITAL LETTER W */
enum XK_X = 0x0058; /* U+0058 LATIN CAPITAL LETTER X */
enum XK_Y = 0x0059; /* U+0059 LATIN CAPITAL LETTER Y */
enum XK_Z = 0x005a; /* U+005A LATIN CAPITAL LETTER Z */
enum XK_bracketleft = 0x005b; /* U+005B LEFT SQUARE BRACKET */
enum XK_backslash = 0x005c; /* U+005C REVERSE SOLIDUS */
enum XK_bracketright = 0x005d; /* U+005D RIGHT SQUARE BRACKET */
enum XK_asciicircum = 0x005e; /* U+005E CIRCUMFLEX ACCENT */
enum XK_underscore = 0x005f; /* U+005F LOW LINE */
enum XK_grave = 0x0060; /* U+0060 GRAVE ACCENT */
enum XK_quoteleft = 0x0060; /* deprecated */
enum XK_a = 0x0061; /* U+0061 LATIN SMALL LETTER A */
enum XK_b = 0x0062; /* U+0062 LATIN SMALL LETTER B */
enum XK_c = 0x0063; /* U+0063 LATIN SMALL LETTER C */
enum XK_d = 0x0064; /* U+0064 LATIN SMALL LETTER D */
enum XK_e = 0x0065; /* U+0065 LATIN SMALL LETTER E */
enum XK_f = 0x0066; /* U+0066 LATIN SMALL LETTER F */
enum XK_g = 0x0067; /* U+0067 LATIN SMALL LETTER G */
enum XK_h = 0x0068; /* U+0068 LATIN SMALL LETTER H */
enum XK_i = 0x0069; /* U+0069 LATIN SMALL LETTER I */
enum XK_j = 0x006a; /* U+006A LATIN SMALL LETTER J */
enum XK_k = 0x006b; /* U+006B LATIN SMALL LETTER K */
enum XK_l = 0x006c; /* U+006C LATIN SMALL LETTER L */
enum XK_m = 0x006d; /* U+006D LATIN SMALL LETTER M */
enum XK_n = 0x006e; /* U+006E LATIN SMALL LETTER N */
enum XK_o = 0x006f; /* U+006F LATIN SMALL LETTER O */
enum XK_p = 0x0070; /* U+0070 LATIN SMALL LETTER P */
enum XK_q = 0x0071; /* U+0071 LATIN SMALL LETTER Q */
enum XK_r = 0x0072; /* U+0072 LATIN SMALL LETTER R */
enum XK_s = 0x0073; /* U+0073 LATIN SMALL LETTER S */
enum XK_t = 0x0074; /* U+0074 LATIN SMALL LETTER T */
enum XK_u = 0x0075; /* U+0075 LATIN SMALL LETTER U */
enum XK_v = 0x0076; /* U+0076 LATIN SMALL LETTER V */
enum XK_w = 0x0077; /* U+0077 LATIN SMALL LETTER W */
enum XK_x = 0x0078; /* U+0078 LATIN SMALL LETTER X */
enum XK_y = 0x0079; /* U+0079 LATIN SMALL LETTER Y */
enum XK_z = 0x007a; /* U+007A LATIN SMALL LETTER Z */
enum XK_braceleft = 0x007b; /* U+007B LEFT CURLY BRACKET */
enum XK_bar = 0x007c; /* U+007C VERTICAL LINE */
enum XK_braceright = 0x007d; /* U+007D RIGHT CURLY BRACKET */
enum XK_asciitilde = 0x007e; /* U+007E TILDE */

enum XK_nobreakspace = 0x00a0; /* U+00A0 NO-BREAK SPACE */
enum XK_exclamdown = 0x00a1; /* U+00A1 INVERTED EXCLAMATION MARK */
enum XK_cent = 0x00a2; /* U+00A2 CENT SIGN */
enum XK_sterling = 0x00a3; /* U+00A3 POUND SIGN */
enum XK_currency = 0x00a4; /* U+00A4 CURRENCY SIGN */
enum XK_yen = 0x00a5; /* U+00A5 YEN SIGN */
enum XK_brokenbar = 0x00a6; /* U+00A6 BROKEN BAR */
enum XK_section = 0x00a7; /* U+00A7 SECTION SIGN */
enum XK_diaeresis = 0x00a8; /* U+00A8 DIAERESIS */
enum XK_copyright = 0x00a9; /* U+00A9 COPYRIGHT SIGN */
enum XK_ordfeminine = 0x00aa; /* U+00AA FEMININE ORDINAL INDICATOR */
enum XK_guillemotleft = 0x00ab; /* deprecated alias for guillemetleft (misspelling) */
enum XK_guillemetleft = 0x00ab; /* U+00AB LEFT-POINTING DOUBLE ANGLE QUOTATION MARK */
enum XK_notsign = 0x00ac; /* U+00AC NOT SIGN */
enum XK_hyphen = 0x00ad; /* U+00AD SOFT HYPHEN */
enum XK_registered = 0x00ae; /* U+00AE REGISTERED SIGN */
enum XK_macron = 0x00af; /* U+00AF MACRON */
enum XK_degree = 0x00b0; /* U+00B0 DEGREE SIGN */
enum XK_plusminus = 0x00b1; /* U+00B1 PLUS-MINUS SIGN */
enum XK_twosuperior = 0x00b2; /* U+00B2 SUPERSCRIPT TWO */
enum XK_threesuperior = 0x00b3; /* U+00B3 SUPERSCRIPT THREE */
enum XK_acute = 0x00b4; /* U+00B4 ACUTE ACCENT */
enum XK_mu = 0x00b5; /* U+00B5 MICRO SIGN */
enum XK_paragraph = 0x00b6; /* U+00B6 PILCROW SIGN */
enum XK_periodcentered = 0x00b7; /* U+00B7 MIDDLE DOT */
enum XK_cedilla = 0x00b8; /* U+00B8 CEDILLA */
enum XK_onesuperior = 0x00b9; /* U+00B9 SUPERSCRIPT ONE */
enum XK_masculine = 0x00ba; /* deprecated alias for ordmasculine (inconsistent name) */
enum XK_ordmasculine = 0x00ba; /* U+00BA MASCULINE ORDINAL INDICATOR */
enum XK_guillemotright = 0x00bb; /* deprecated alias for guillemetright (misspelling) */
enum XK_guillemetright = 0x00bb; /* U+00BB RIGHT-POINTING DOUBLE ANGLE QUOTATION MARK */
enum XK_onequarter = 0x00bc; /* U+00BC VULGAR FRACTION ONE QUARTER */
enum XK_onehalf = 0x00bd; /* U+00BD VULGAR FRACTION ONE HALF */
enum XK_threequarters = 0x00be; /* U+00BE VULGAR FRACTION THREE QUARTERS */
enum XK_questiondown = 0x00bf; /* U+00BF INVERTED QUESTION MARK */
enum XK_Agrave = 0x00c0; /* U+00C0 LATIN CAPITAL LETTER A WITH GRAVE */
enum XK_Aacute = 0x00c1; /* U+00C1 LATIN CAPITAL LETTER A WITH ACUTE */
enum XK_Acircumflex = 0x00c2; /* U+00C2 LATIN CAPITAL LETTER A WITH CIRCUMFLEX */
enum XK_Atilde = 0x00c3; /* U+00C3 LATIN CAPITAL LETTER A WITH TILDE */
enum XK_Adiaeresis = 0x00c4; /* U+00C4 LATIN CAPITAL LETTER A WITH DIAERESIS */
enum XK_Aring = 0x00c5; /* U+00C5 LATIN CAPITAL LETTER A WITH RING ABOVE */
enum XK_AE = 0x00c6; /* U+00C6 LATIN CAPITAL LETTER AE */
enum XK_Ccedilla = 0x00c7; /* U+00C7 LATIN CAPITAL LETTER C WITH CEDILLA */
enum XK_Egrave = 0x00c8; /* U+00C8 LATIN CAPITAL LETTER E WITH GRAVE */
enum XK_Eacute = 0x00c9; /* U+00C9 LATIN CAPITAL LETTER E WITH ACUTE */
enum XK_Ecircumflex = 0x00ca; /* U+00CA LATIN CAPITAL LETTER E WITH CIRCUMFLEX */
enum XK_Ediaeresis = 0x00cb; /* U+00CB LATIN CAPITAL LETTER E WITH DIAERESIS */
enum XK_Igrave = 0x00cc; /* U+00CC LATIN CAPITAL LETTER I WITH GRAVE */
enum XK_Iacute = 0x00cd; /* U+00CD LATIN CAPITAL LETTER I WITH ACUTE */
enum XK_Icircumflex = 0x00ce; /* U+00CE LATIN CAPITAL LETTER I WITH CIRCUMFLEX */
enum XK_Idiaeresis = 0x00cf; /* U+00CF LATIN CAPITAL LETTER I WITH DIAERESIS */
enum XK_ETH = 0x00d0; /* U+00D0 LATIN CAPITAL LETTER ETH */
enum XK_Eth = 0x00d0; /* deprecated */
enum XK_Ntilde = 0x00d1; /* U+00D1 LATIN CAPITAL LETTER N WITH TILDE */
enum XK_Ograve = 0x00d2; /* U+00D2 LATIN CAPITAL LETTER O WITH GRAVE */
enum XK_Oacute = 0x00d3; /* U+00D3 LATIN CAPITAL LETTER O WITH ACUTE */
enum XK_Ocircumflex = 0x00d4; /* U+00D4 LATIN CAPITAL LETTER O WITH CIRCUMFLEX */
enum XK_Otilde = 0x00d5; /* U+00D5 LATIN CAPITAL LETTER O WITH TILDE */
enum XK_Odiaeresis = 0x00d6; /* U+00D6 LATIN CAPITAL LETTER O WITH DIAERESIS */
enum XK_multiply = 0x00d7; /* U+00D7 MULTIPLICATION SIGN */
enum XK_Oslash = 0x00d8; /* U+00D8 LATIN CAPITAL LETTER O WITH STROKE */
enum XK_Ooblique = 0x00d8; /* deprecated alias for Oslash */
enum XK_Ugrave = 0x00d9; /* U+00D9 LATIN CAPITAL LETTER U WITH GRAVE */
enum XK_Uacute = 0x00da; /* U+00DA LATIN CAPITAL LETTER U WITH ACUTE */
enum XK_Ucircumflex = 0x00db; /* U+00DB LATIN CAPITAL LETTER U WITH CIRCUMFLEX */
enum XK_Udiaeresis = 0x00dc; /* U+00DC LATIN CAPITAL LETTER U WITH DIAERESIS */
enum XK_Yacute = 0x00dd; /* U+00DD LATIN CAPITAL LETTER Y WITH ACUTE */
enum XK_THORN = 0x00de; /* U+00DE LATIN CAPITAL LETTER THORN */
enum XK_Thorn = 0x00de; /* deprecated */
enum XK_ssharp = 0x00df; /* U+00DF LATIN SMALL LETTER SHARP S */
enum XK_agrave = 0x00e0; /* U+00E0 LATIN SMALL LETTER A WITH GRAVE */
enum XK_aacute = 0x00e1; /* U+00E1 LATIN SMALL LETTER A WITH ACUTE */
enum XK_acircumflex = 0x00e2; /* U+00E2 LATIN SMALL LETTER A WITH CIRCUMFLEX */
enum XK_atilde = 0x00e3; /* U+00E3 LATIN SMALL LETTER A WITH TILDE */
enum XK_adiaeresis = 0x00e4; /* U+00E4 LATIN SMALL LETTER A WITH DIAERESIS */
enum XK_aring = 0x00e5; /* U+00E5 LATIN SMALL LETTER A WITH RING ABOVE */
enum XK_ae = 0x00e6; /* U+00E6 LATIN SMALL LETTER AE */
enum XK_ccedilla = 0x00e7; /* U+00E7 LATIN SMALL LETTER C WITH CEDILLA */
enum XK_egrave = 0x00e8; /* U+00E8 LATIN SMALL LETTER E WITH GRAVE */
enum XK_eacute = 0x00e9; /* U+00E9 LATIN SMALL LETTER E WITH ACUTE */
enum XK_ecircumflex = 0x00ea; /* U+00EA LATIN SMALL LETTER E WITH CIRCUMFLEX */
enum XK_ediaeresis = 0x00eb; /* U+00EB LATIN SMALL LETTER E WITH DIAERESIS */
enum XK_igrave = 0x00ec; /* U+00EC LATIN SMALL LETTER I WITH GRAVE */
enum XK_iacute = 0x00ed; /* U+00ED LATIN SMALL LETTER I WITH ACUTE */
enum XK_icircumflex = 0x00ee; /* U+00EE LATIN SMALL LETTER I WITH CIRCUMFLEX */
enum XK_idiaeresis = 0x00ef; /* U+00EF LATIN SMALL LETTER I WITH DIAERESIS */
enum XK_eth = 0x00f0; /* U+00F0 LATIN SMALL LETTER ETH */
enum XK_ntilde = 0x00f1; /* U+00F1 LATIN SMALL LETTER N WITH TILDE */
enum XK_ograve = 0x00f2; /* U+00F2 LATIN SMALL LETTER O WITH GRAVE */
enum XK_oacute = 0x00f3; /* U+00F3 LATIN SMALL LETTER O WITH ACUTE */
enum XK_ocircumflex = 0x00f4; /* U+00F4 LATIN SMALL LETTER O WITH CIRCUMFLEX */
enum XK_otilde = 0x00f5; /* U+00F5 LATIN SMALL LETTER O WITH TILDE */
enum XK_odiaeresis = 0x00f6; /* U+00F6 LATIN SMALL LETTER O WITH DIAERESIS */
enum XK_division = 0x00f7; /* U+00F7 DIVISION SIGN */
enum XK_oslash = 0x00f8; /* U+00F8 LATIN SMALL LETTER O WITH STROKE */
enum XK_ooblique = 0x00f8; /* deprecated alias for oslash */
enum XK_ugrave = 0x00f9; /* U+00F9 LATIN SMALL LETTER U WITH GRAVE */
enum XK_uacute = 0x00fa; /* U+00FA LATIN SMALL LETTER U WITH ACUTE */
enum XK_ucircumflex = 0x00fb; /* U+00FB LATIN SMALL LETTER U WITH CIRCUMFLEX */
enum XK_udiaeresis = 0x00fc; /* U+00FC LATIN SMALL LETTER U WITH DIAERESIS */
enum XK_yacute = 0x00fd; /* U+00FD LATIN SMALL LETTER Y WITH ACUTE */
enum XK_thorn = 0x00fe; /* U+00FE LATIN SMALL LETTER THORN */
enum XK_ydiaeresis = 0x00ff; /* U+00FF LATIN SMALL LETTER Y WITH DIAERESIS */
/* XK_LATIN1 */

/*
 * Latin 2
 * Byte 3 = 1
 */

enum XK_Aogonek = 0x01a1; /* U+0104 LATIN CAPITAL LETTER A WITH OGONEK */
enum XK_breve = 0x01a2; /* U+02D8 BREVE */
enum XK_Lstroke = 0x01a3; /* U+0141 LATIN CAPITAL LETTER L WITH STROKE */
enum XK_Lcaron = 0x01a5; /* U+013D LATIN CAPITAL LETTER L WITH CARON */
enum XK_Sacute = 0x01a6; /* U+015A LATIN CAPITAL LETTER S WITH ACUTE */
enum XK_Scaron = 0x01a9; /* U+0160 LATIN CAPITAL LETTER S WITH CARON */
enum XK_Scedilla = 0x01aa; /* U+015E LATIN CAPITAL LETTER S WITH CEDILLA */
enum XK_Tcaron = 0x01ab; /* U+0164 LATIN CAPITAL LETTER T WITH CARON */
enum XK_Zacute = 0x01ac; /* U+0179 LATIN CAPITAL LETTER Z WITH ACUTE */
enum XK_Zcaron = 0x01ae; /* U+017D LATIN CAPITAL LETTER Z WITH CARON */
enum XK_Zabovedot = 0x01af; /* U+017B LATIN CAPITAL LETTER Z WITH DOT ABOVE */
enum XK_aogonek = 0x01b1; /* U+0105 LATIN SMALL LETTER A WITH OGONEK */
enum XK_ogonek = 0x01b2; /* U+02DB OGONEK */
enum XK_lstroke = 0x01b3; /* U+0142 LATIN SMALL LETTER L WITH STROKE */
enum XK_lcaron = 0x01b5; /* U+013E LATIN SMALL LETTER L WITH CARON */
enum XK_sacute = 0x01b6; /* U+015B LATIN SMALL LETTER S WITH ACUTE */
enum XK_caron = 0x01b7; /* U+02C7 CARON */
enum XK_scaron = 0x01b9; /* U+0161 LATIN SMALL LETTER S WITH CARON */
enum XK_scedilla = 0x01ba; /* U+015F LATIN SMALL LETTER S WITH CEDILLA */
enum XK_tcaron = 0x01bb; /* U+0165 LATIN SMALL LETTER T WITH CARON */
enum XK_zacute = 0x01bc; /* U+017A LATIN SMALL LETTER Z WITH ACUTE */
enum XK_doubleacute = 0x01bd; /* U+02DD DOUBLE ACUTE ACCENT */
enum XK_zcaron = 0x01be; /* U+017E LATIN SMALL LETTER Z WITH CARON */
enum XK_zabovedot = 0x01bf; /* U+017C LATIN SMALL LETTER Z WITH DOT ABOVE */
enum XK_Racute = 0x01c0; /* U+0154 LATIN CAPITAL LETTER R WITH ACUTE */
enum XK_Abreve = 0x01c3; /* U+0102 LATIN CAPITAL LETTER A WITH BREVE */
enum XK_Lacute = 0x01c5; /* U+0139 LATIN CAPITAL LETTER L WITH ACUTE */
enum XK_Cacute = 0x01c6; /* U+0106 LATIN CAPITAL LETTER C WITH ACUTE */
enum XK_Ccaron = 0x01c8; /* U+010C LATIN CAPITAL LETTER C WITH CARON */
enum XK_Eogonek = 0x01ca; /* U+0118 LATIN CAPITAL LETTER E WITH OGONEK */
enum XK_Ecaron = 0x01cc; /* U+011A LATIN CAPITAL LETTER E WITH CARON */
enum XK_Dcaron = 0x01cf; /* U+010E LATIN CAPITAL LETTER D WITH CARON */
enum XK_Dstroke = 0x01d0; /* U+0110 LATIN CAPITAL LETTER D WITH STROKE */
enum XK_Nacute = 0x01d1; /* U+0143 LATIN CAPITAL LETTER N WITH ACUTE */
enum XK_Ncaron = 0x01d2; /* U+0147 LATIN CAPITAL LETTER N WITH CARON */
enum XK_Odoubleacute = 0x01d5; /* U+0150 LATIN CAPITAL LETTER O WITH DOUBLE ACUTE */
enum XK_Rcaron = 0x01d8; /* U+0158 LATIN CAPITAL LETTER R WITH CARON */
enum XK_Uring = 0x01d9; /* U+016E LATIN CAPITAL LETTER U WITH RING ABOVE */
enum XK_Udoubleacute = 0x01db; /* U+0170 LATIN CAPITAL LETTER U WITH DOUBLE ACUTE */
enum XK_Tcedilla = 0x01de; /* U+0162 LATIN CAPITAL LETTER T WITH CEDILLA */
enum XK_racute = 0x01e0; /* U+0155 LATIN SMALL LETTER R WITH ACUTE */
enum XK_abreve = 0x01e3; /* U+0103 LATIN SMALL LETTER A WITH BREVE */
enum XK_lacute = 0x01e5; /* U+013A LATIN SMALL LETTER L WITH ACUTE */
enum XK_cacute = 0x01e6; /* U+0107 LATIN SMALL LETTER C WITH ACUTE */
enum XK_ccaron = 0x01e8; /* U+010D LATIN SMALL LETTER C WITH CARON */
enum XK_eogonek = 0x01ea; /* U+0119 LATIN SMALL LETTER E WITH OGONEK */
enum XK_ecaron = 0x01ec; /* U+011B LATIN SMALL LETTER E WITH CARON */
enum XK_dcaron = 0x01ef; /* U+010F LATIN SMALL LETTER D WITH CARON */
enum XK_dstroke = 0x01f0; /* U+0111 LATIN SMALL LETTER D WITH STROKE */
enum XK_nacute = 0x01f1; /* U+0144 LATIN SMALL LETTER N WITH ACUTE */
enum XK_ncaron = 0x01f2; /* U+0148 LATIN SMALL LETTER N WITH CARON */
enum XK_odoubleacute = 0x01f5; /* U+0151 LATIN SMALL LETTER O WITH DOUBLE ACUTE */
enum XK_rcaron = 0x01f8; /* U+0159 LATIN SMALL LETTER R WITH CARON */
enum XK_uring = 0x01f9; /* U+016F LATIN SMALL LETTER U WITH RING ABOVE */
enum XK_udoubleacute = 0x01fb; /* U+0171 LATIN SMALL LETTER U WITH DOUBLE ACUTE */
enum XK_tcedilla = 0x01fe; /* U+0163 LATIN SMALL LETTER T WITH CEDILLA */
enum XK_abovedot = 0x01ff; /* U+02D9 DOT ABOVE */
/* XK_LATIN2 */

/*
 * Latin 3
 * Byte 3 = 2
 */

enum XK_Hstroke = 0x02a1; /* U+0126 LATIN CAPITAL LETTER H WITH STROKE */
enum XK_Hcircumflex = 0x02a6; /* U+0124 LATIN CAPITAL LETTER H WITH CIRCUMFLEX */
enum XK_Iabovedot = 0x02a9; /* U+0130 LATIN CAPITAL LETTER I WITH DOT ABOVE */
enum XK_Gbreve = 0x02ab; /* U+011E LATIN CAPITAL LETTER G WITH BREVE */
enum XK_Jcircumflex = 0x02ac; /* U+0134 LATIN CAPITAL LETTER J WITH CIRCUMFLEX */
enum XK_hstroke = 0x02b1; /* U+0127 LATIN SMALL LETTER H WITH STROKE */
enum XK_hcircumflex = 0x02b6; /* U+0125 LATIN SMALL LETTER H WITH CIRCUMFLEX */
enum XK_idotless = 0x02b9; /* U+0131 LATIN SMALL LETTER DOTLESS I */
enum XK_gbreve = 0x02bb; /* U+011F LATIN SMALL LETTER G WITH BREVE */
enum XK_jcircumflex = 0x02bc; /* U+0135 LATIN SMALL LETTER J WITH CIRCUMFLEX */
enum XK_Cabovedot = 0x02c5; /* U+010A LATIN CAPITAL LETTER C WITH DOT ABOVE */
enum XK_Ccircumflex = 0x02c6; /* U+0108 LATIN CAPITAL LETTER C WITH CIRCUMFLEX */
enum XK_Gabovedot = 0x02d5; /* U+0120 LATIN CAPITAL LETTER G WITH DOT ABOVE */
enum XK_Gcircumflex = 0x02d8; /* U+011C LATIN CAPITAL LETTER G WITH CIRCUMFLEX */
enum XK_Ubreve = 0x02dd; /* U+016C LATIN CAPITAL LETTER U WITH BREVE */
enum XK_Scircumflex = 0x02de; /* U+015C LATIN CAPITAL LETTER S WITH CIRCUMFLEX */
enum XK_cabovedot = 0x02e5; /* U+010B LATIN SMALL LETTER C WITH DOT ABOVE */
enum XK_ccircumflex = 0x02e6; /* U+0109 LATIN SMALL LETTER C WITH CIRCUMFLEX */
enum XK_gabovedot = 0x02f5; /* U+0121 LATIN SMALL LETTER G WITH DOT ABOVE */
enum XK_gcircumflex = 0x02f8; /* U+011D LATIN SMALL LETTER G WITH CIRCUMFLEX */
enum XK_ubreve = 0x02fd; /* U+016D LATIN SMALL LETTER U WITH BREVE */
enum XK_scircumflex = 0x02fe; /* U+015D LATIN SMALL LETTER S WITH CIRCUMFLEX */
/* XK_LATIN3 */

/*
 * Latin 4
 * Byte 3 = 3
 */

enum XK_kra = 0x03a2; /* U+0138 LATIN SMALL LETTER KRA */
enum XK_kappa = 0x03a2; /* deprecated */
enum XK_Rcedilla = 0x03a3; /* U+0156 LATIN CAPITAL LETTER R WITH CEDILLA */
enum XK_Itilde = 0x03a5; /* U+0128 LATIN CAPITAL LETTER I WITH TILDE */
enum XK_Lcedilla = 0x03a6; /* U+013B LATIN CAPITAL LETTER L WITH CEDILLA */
enum XK_Emacron = 0x03aa; /* U+0112 LATIN CAPITAL LETTER E WITH MACRON */
enum XK_Gcedilla = 0x03ab; /* U+0122 LATIN CAPITAL LETTER G WITH CEDILLA */
enum XK_Tslash = 0x03ac; /* U+0166 LATIN CAPITAL LETTER T WITH STROKE */
enum XK_rcedilla = 0x03b3; /* U+0157 LATIN SMALL LETTER R WITH CEDILLA */
enum XK_itilde = 0x03b5; /* U+0129 LATIN SMALL LETTER I WITH TILDE */
enum XK_lcedilla = 0x03b6; /* U+013C LATIN SMALL LETTER L WITH CEDILLA */
enum XK_emacron = 0x03ba; /* U+0113 LATIN SMALL LETTER E WITH MACRON */
enum XK_gcedilla = 0x03bb; /* U+0123 LATIN SMALL LETTER G WITH CEDILLA */
enum XK_tslash = 0x03bc; /* U+0167 LATIN SMALL LETTER T WITH STROKE */
enum XK_ENG = 0x03bd; /* U+014A LATIN CAPITAL LETTER ENG */
enum XK_eng = 0x03bf; /* U+014B LATIN SMALL LETTER ENG */
enum XK_Amacron = 0x03c0; /* U+0100 LATIN CAPITAL LETTER A WITH MACRON */
enum XK_Iogonek = 0x03c7; /* U+012E LATIN CAPITAL LETTER I WITH OGONEK */
enum XK_Eabovedot = 0x03cc; /* U+0116 LATIN CAPITAL LETTER E WITH DOT ABOVE */
enum XK_Imacron = 0x03cf; /* U+012A LATIN CAPITAL LETTER I WITH MACRON */
enum XK_Ncedilla = 0x03d1; /* U+0145 LATIN CAPITAL LETTER N WITH CEDILLA */
enum XK_Omacron = 0x03d2; /* U+014C LATIN CAPITAL LETTER O WITH MACRON */
enum XK_Kcedilla = 0x03d3; /* U+0136 LATIN CAPITAL LETTER K WITH CEDILLA */
enum XK_Uogonek = 0x03d9; /* U+0172 LATIN CAPITAL LETTER U WITH OGONEK */
enum XK_Utilde = 0x03dd; /* U+0168 LATIN CAPITAL LETTER U WITH TILDE */
enum XK_Umacron = 0x03de; /* U+016A LATIN CAPITAL LETTER U WITH MACRON */
enum XK_amacron = 0x03e0; /* U+0101 LATIN SMALL LETTER A WITH MACRON */
enum XK_iogonek = 0x03e7; /* U+012F LATIN SMALL LETTER I WITH OGONEK */
enum XK_eabovedot = 0x03ec; /* U+0117 LATIN SMALL LETTER E WITH DOT ABOVE */
enum XK_imacron = 0x03ef; /* U+012B LATIN SMALL LETTER I WITH MACRON */
enum XK_ncedilla = 0x03f1; /* U+0146 LATIN SMALL LETTER N WITH CEDILLA */
enum XK_omacron = 0x03f2; /* U+014D LATIN SMALL LETTER O WITH MACRON */
enum XK_kcedilla = 0x03f3; /* U+0137 LATIN SMALL LETTER K WITH CEDILLA */
enum XK_uogonek = 0x03f9; /* U+0173 LATIN SMALL LETTER U WITH OGONEK */
enum XK_utilde = 0x03fd; /* U+0169 LATIN SMALL LETTER U WITH TILDE */
enum XK_umacron = 0x03fe; /* U+016B LATIN SMALL LETTER U WITH MACRON */
/* XK_LATIN4 */

/*
 * Latin 8
 */
enum XK_Wcircumflex = 0x1000174; /* U+0174 LATIN CAPITAL LETTER W WITH CIRCUMFLEX */
enum XK_wcircumflex = 0x1000175; /* U+0175 LATIN SMALL LETTER W WITH CIRCUMFLEX */
enum XK_Ycircumflex = 0x1000176; /* U+0176 LATIN CAPITAL LETTER Y WITH CIRCUMFLEX */
enum XK_ycircumflex = 0x1000177; /* U+0177 LATIN SMALL LETTER Y WITH CIRCUMFLEX */
enum XK_Babovedot = 0x1001e02; /* U+1E02 LATIN CAPITAL LETTER B WITH DOT ABOVE */
enum XK_babovedot = 0x1001e03; /* U+1E03 LATIN SMALL LETTER B WITH DOT ABOVE */
enum XK_Dabovedot = 0x1001e0a; /* U+1E0A LATIN CAPITAL LETTER D WITH DOT ABOVE */
enum XK_dabovedot = 0x1001e0b; /* U+1E0B LATIN SMALL LETTER D WITH DOT ABOVE */
enum XK_Fabovedot = 0x1001e1e; /* U+1E1E LATIN CAPITAL LETTER F WITH DOT ABOVE */
enum XK_fabovedot = 0x1001e1f; /* U+1E1F LATIN SMALL LETTER F WITH DOT ABOVE */
enum XK_Mabovedot = 0x1001e40; /* U+1E40 LATIN CAPITAL LETTER M WITH DOT ABOVE */
enum XK_mabovedot = 0x1001e41; /* U+1E41 LATIN SMALL LETTER M WITH DOT ABOVE */
enum XK_Pabovedot = 0x1001e56; /* U+1E56 LATIN CAPITAL LETTER P WITH DOT ABOVE */
enum XK_pabovedot = 0x1001e57; /* U+1E57 LATIN SMALL LETTER P WITH DOT ABOVE */
enum XK_Sabovedot = 0x1001e60; /* U+1E60 LATIN CAPITAL LETTER S WITH DOT ABOVE */
enum XK_sabovedot = 0x1001e61; /* U+1E61 LATIN SMALL LETTER S WITH DOT ABOVE */
enum XK_Tabovedot = 0x1001e6a; /* U+1E6A LATIN CAPITAL LETTER T WITH DOT ABOVE */
enum XK_tabovedot = 0x1001e6b; /* U+1E6B LATIN SMALL LETTER T WITH DOT ABOVE */
enum XK_Wgrave = 0x1001e80; /* U+1E80 LATIN CAPITAL LETTER W WITH GRAVE */
enum XK_wgrave = 0x1001e81; /* U+1E81 LATIN SMALL LETTER W WITH GRAVE */
enum XK_Wacute = 0x1001e82; /* U+1E82 LATIN CAPITAL LETTER W WITH ACUTE */
enum XK_wacute = 0x1001e83; /* U+1E83 LATIN SMALL LETTER W WITH ACUTE */
enum XK_Wdiaeresis = 0x1001e84; /* U+1E84 LATIN CAPITAL LETTER W WITH DIAERESIS */
enum XK_wdiaeresis = 0x1001e85; /* U+1E85 LATIN SMALL LETTER W WITH DIAERESIS */
enum XK_Ygrave = 0x1001ef2; /* U+1EF2 LATIN CAPITAL LETTER Y WITH GRAVE */
enum XK_ygrave = 0x1001ef3; /* U+1EF3 LATIN SMALL LETTER Y WITH GRAVE */
/* XK_LATIN8 */

/*
 * Latin 9
 * Byte 3 = 0x13
 */

enum XK_OE = 0x13bc; /* U+0152 LATIN CAPITAL LIGATURE OE */
enum XK_oe = 0x13bd; /* U+0153 LATIN SMALL LIGATURE OE */
enum XK_Ydiaeresis = 0x13be; /* U+0178 LATIN CAPITAL LETTER Y WITH DIAERESIS */
/* XK_LATIN9 */

/*
 * Katakana
 * Byte 3 = 4
 */

enum XK_overline = 0x047e; /* U+203E OVERLINE */
enum XK_kana_fullstop = 0x04a1; /* U+3002 IDEOGRAPHIC FULL STOP */
enum XK_kana_openingbracket = 0x04a2; /* U+300C LEFT CORNER BRACKET */
enum XK_kana_closingbracket = 0x04a3; /* U+300D RIGHT CORNER BRACKET */
enum XK_kana_comma = 0x04a4; /* U+3001 IDEOGRAPHIC COMMA */
enum XK_kana_conjunctive = 0x04a5; /* U+30FB KATAKANA MIDDLE DOT */
enum XK_kana_middledot = 0x04a5; /* deprecated */
enum XK_kana_WO = 0x04a6; /* U+30F2 KATAKANA LETTER WO */
enum XK_kana_a = 0x04a7; /* U+30A1 KATAKANA LETTER SMALL A */
enum XK_kana_i = 0x04a8; /* U+30A3 KATAKANA LETTER SMALL I */
enum XK_kana_u = 0x04a9; /* U+30A5 KATAKANA LETTER SMALL U */
enum XK_kana_e = 0x04aa; /* U+30A7 KATAKANA LETTER SMALL E */
enum XK_kana_o = 0x04ab; /* U+30A9 KATAKANA LETTER SMALL O */
enum XK_kana_ya = 0x04ac; /* U+30E3 KATAKANA LETTER SMALL YA */
enum XK_kana_yu = 0x04ad; /* U+30E5 KATAKANA LETTER SMALL YU */
enum XK_kana_yo = 0x04ae; /* U+30E7 KATAKANA LETTER SMALL YO */
enum XK_kana_tsu = 0x04af; /* U+30C3 KATAKANA LETTER SMALL TU */
enum XK_kana_tu = 0x04af; /* deprecated */
enum XK_prolongedsound = 0x04b0; /* U+30FC KATAKANA-HIRAGANA PROLONGED SOUND MARK */
enum XK_kana_A = 0x04b1; /* U+30A2 KATAKANA LETTER A */
enum XK_kana_I = 0x04b2; /* U+30A4 KATAKANA LETTER I */
enum XK_kana_U = 0x04b3; /* U+30A6 KATAKANA LETTER U */
enum XK_kana_E = 0x04b4; /* U+30A8 KATAKANA LETTER E */
enum XK_kana_O = 0x04b5; /* U+30AA KATAKANA LETTER O */
enum XK_kana_KA = 0x04b6; /* U+30AB KATAKANA LETTER KA */
enum XK_kana_KI = 0x04b7; /* U+30AD KATAKANA LETTER KI */
enum XK_kana_KU = 0x04b8; /* U+30AF KATAKANA LETTER KU */
enum XK_kana_KE = 0x04b9; /* U+30B1 KATAKANA LETTER KE */
enum XK_kana_KO = 0x04ba; /* U+30B3 KATAKANA LETTER KO */
enum XK_kana_SA = 0x04bb; /* U+30B5 KATAKANA LETTER SA */
enum XK_kana_SHI = 0x04bc; /* U+30B7 KATAKANA LETTER SI */
enum XK_kana_SU = 0x04bd; /* U+30B9 KATAKANA LETTER SU */
enum XK_kana_SE = 0x04be; /* U+30BB KATAKANA LETTER SE */
enum XK_kana_SO = 0x04bf; /* U+30BD KATAKANA LETTER SO */
enum XK_kana_TA = 0x04c0; /* U+30BF KATAKANA LETTER TA */
enum XK_kana_CHI = 0x04c1; /* U+30C1 KATAKANA LETTER TI */
enum XK_kana_TI = 0x04c1; /* deprecated */
enum XK_kana_TSU = 0x04c2; /* U+30C4 KATAKANA LETTER TU */
enum XK_kana_TU = 0x04c2; /* deprecated */
enum XK_kana_TE = 0x04c3; /* U+30C6 KATAKANA LETTER TE */
enum XK_kana_TO = 0x04c4; /* U+30C8 KATAKANA LETTER TO */
enum XK_kana_NA = 0x04c5; /* U+30CA KATAKANA LETTER NA */
enum XK_kana_NI = 0x04c6; /* U+30CB KATAKANA LETTER NI */
enum XK_kana_NU = 0x04c7; /* U+30CC KATAKANA LETTER NU */
enum XK_kana_NE = 0x04c8; /* U+30CD KATAKANA LETTER NE */
enum XK_kana_NO = 0x04c9; /* U+30CE KATAKANA LETTER NO */
enum XK_kana_HA = 0x04ca; /* U+30CF KATAKANA LETTER HA */
enum XK_kana_HI = 0x04cb; /* U+30D2 KATAKANA LETTER HI */
enum XK_kana_FU = 0x04cc; /* U+30D5 KATAKANA LETTER HU */
enum XK_kana_HU = 0x04cc; /* deprecated */
enum XK_kana_HE = 0x04cd; /* U+30D8 KATAKANA LETTER HE */
enum XK_kana_HO = 0x04ce; /* U+30DB KATAKANA LETTER HO */
enum XK_kana_MA = 0x04cf; /* U+30DE KATAKANA LETTER MA */
enum XK_kana_MI = 0x04d0; /* U+30DF KATAKANA LETTER MI */
enum XK_kana_MU = 0x04d1; /* U+30E0 KATAKANA LETTER MU */
enum XK_kana_ME = 0x04d2; /* U+30E1 KATAKANA LETTER ME */
enum XK_kana_MO = 0x04d3; /* U+30E2 KATAKANA LETTER MO */
enum XK_kana_YA = 0x04d4; /* U+30E4 KATAKANA LETTER YA */
enum XK_kana_YU = 0x04d5; /* U+30E6 KATAKANA LETTER YU */
enum XK_kana_YO = 0x04d6; /* U+30E8 KATAKANA LETTER YO */
enum XK_kana_RA = 0x04d7; /* U+30E9 KATAKANA LETTER RA */
enum XK_kana_RI = 0x04d8; /* U+30EA KATAKANA LETTER RI */
enum XK_kana_RU = 0x04d9; /* U+30EB KATAKANA LETTER RU */
enum XK_kana_RE = 0x04da; /* U+30EC KATAKANA LETTER RE */
enum XK_kana_RO = 0x04db; /* U+30ED KATAKANA LETTER RO */
enum XK_kana_WA = 0x04dc; /* U+30EF KATAKANA LETTER WA */
enum XK_kana_N = 0x04dd; /* U+30F3 KATAKANA LETTER N */
enum XK_voicedsound = 0x04de; /* U+309B KATAKANA-HIRAGANA VOICED SOUND MARK */
enum XK_semivoicedsound = 0x04df; /* U+309C KATAKANA-HIRAGANA SEMI-VOICED SOUND MARK */
enum XK_kana_switch = 0xff7e; /* non-deprecated alias for Mode_switch */
/* XK_KATAKANA */

/*
 * Arabic
 * Byte 3 = 5
 */

enum XK_Farsi_0 = 0x10006f0; /* U+06F0 EXTENDED ARABIC-INDIC DIGIT ZERO */
enum XK_Farsi_1 = 0x10006f1; /* U+06F1 EXTENDED ARABIC-INDIC DIGIT ONE */
enum XK_Farsi_2 = 0x10006f2; /* U+06F2 EXTENDED ARABIC-INDIC DIGIT TWO */
enum XK_Farsi_3 = 0x10006f3; /* U+06F3 EXTENDED ARABIC-INDIC DIGIT THREE */
enum XK_Farsi_4 = 0x10006f4; /* U+06F4 EXTENDED ARABIC-INDIC DIGIT FOUR */
enum XK_Farsi_5 = 0x10006f5; /* U+06F5 EXTENDED ARABIC-INDIC DIGIT FIVE */
enum XK_Farsi_6 = 0x10006f6; /* U+06F6 EXTENDED ARABIC-INDIC DIGIT SIX */
enum XK_Farsi_7 = 0x10006f7; /* U+06F7 EXTENDED ARABIC-INDIC DIGIT SEVEN */
enum XK_Farsi_8 = 0x10006f8; /* U+06F8 EXTENDED ARABIC-INDIC DIGIT EIGHT */
enum XK_Farsi_9 = 0x10006f9; /* U+06F9 EXTENDED ARABIC-INDIC DIGIT NINE */
enum XK_Arabic_percent = 0x100066a; /* U+066A ARABIC PERCENT SIGN */
enum XK_Arabic_superscript_alef = 0x1000670; /* U+0670 ARABIC LETTER SUPERSCRIPT ALEF */
enum XK_Arabic_tteh = 0x1000679; /* U+0679 ARABIC LETTER TTEH */
enum XK_Arabic_peh = 0x100067e; /* U+067E ARABIC LETTER PEH */
enum XK_Arabic_tcheh = 0x1000686; /* U+0686 ARABIC LETTER TCHEH */
enum XK_Arabic_ddal = 0x1000688; /* U+0688 ARABIC LETTER DDAL */
enum XK_Arabic_rreh = 0x1000691; /* U+0691 ARABIC LETTER RREH */
enum XK_Arabic_comma = 0x05ac; /* U+060C ARABIC COMMA */
enum XK_Arabic_fullstop = 0x10006d4; /* U+06D4 ARABIC FULL STOP */
enum XK_Arabic_0 = 0x1000660; /* U+0660 ARABIC-INDIC DIGIT ZERO */
enum XK_Arabic_1 = 0x1000661; /* U+0661 ARABIC-INDIC DIGIT ONE */
enum XK_Arabic_2 = 0x1000662; /* U+0662 ARABIC-INDIC DIGIT TWO */
enum XK_Arabic_3 = 0x1000663; /* U+0663 ARABIC-INDIC DIGIT THREE */
enum XK_Arabic_4 = 0x1000664; /* U+0664 ARABIC-INDIC DIGIT FOUR */
enum XK_Arabic_5 = 0x1000665; /* U+0665 ARABIC-INDIC DIGIT FIVE */
enum XK_Arabic_6 = 0x1000666; /* U+0666 ARABIC-INDIC DIGIT SIX */
enum XK_Arabic_7 = 0x1000667; /* U+0667 ARABIC-INDIC DIGIT SEVEN */
enum XK_Arabic_8 = 0x1000668; /* U+0668 ARABIC-INDIC DIGIT EIGHT */
enum XK_Arabic_9 = 0x1000669; /* U+0669 ARABIC-INDIC DIGIT NINE */
enum XK_Arabic_semicolon = 0x05bb; /* U+061B ARABIC SEMICOLON */
enum XK_Arabic_question_mark = 0x05bf; /* U+061F ARABIC QUESTION MARK */
enum XK_Arabic_hamza = 0x05c1; /* U+0621 ARABIC LETTER HAMZA */
enum XK_Arabic_maddaonalef = 0x05c2; /* U+0622 ARABIC LETTER ALEF WITH MADDA ABOVE */
enum XK_Arabic_hamzaonalef = 0x05c3; /* U+0623 ARABIC LETTER ALEF WITH HAMZA ABOVE */
enum XK_Arabic_hamzaonwaw = 0x05c4; /* U+0624 ARABIC LETTER WAW WITH HAMZA ABOVE */
enum XK_Arabic_hamzaunderalef = 0x05c5; /* U+0625 ARABIC LETTER ALEF WITH HAMZA BELOW */
enum XK_Arabic_hamzaonyeh = 0x05c6; /* U+0626 ARABIC LETTER YEH WITH HAMZA ABOVE */
enum XK_Arabic_alef = 0x05c7; /* U+0627 ARABIC LETTER ALEF */
enum XK_Arabic_beh = 0x05c8; /* U+0628 ARABIC LETTER BEH */
enum XK_Arabic_tehmarbuta = 0x05c9; /* U+0629 ARABIC LETTER TEH MARBUTA */
enum XK_Arabic_teh = 0x05ca; /* U+062A ARABIC LETTER TEH */
enum XK_Arabic_theh = 0x05cb; /* U+062B ARABIC LETTER THEH */
enum XK_Arabic_jeem = 0x05cc; /* U+062C ARABIC LETTER JEEM */
enum XK_Arabic_hah = 0x05cd; /* U+062D ARABIC LETTER HAH */
enum XK_Arabic_khah = 0x05ce; /* U+062E ARABIC LETTER KHAH */
enum XK_Arabic_dal = 0x05cf; /* U+062F ARABIC LETTER DAL */
enum XK_Arabic_thal = 0x05d0; /* U+0630 ARABIC LETTER THAL */
enum XK_Arabic_ra = 0x05d1; /* U+0631 ARABIC LETTER REH */
enum XK_Arabic_zain = 0x05d2; /* U+0632 ARABIC LETTER ZAIN */
enum XK_Arabic_seen = 0x05d3; /* U+0633 ARABIC LETTER SEEN */
enum XK_Arabic_sheen = 0x05d4; /* U+0634 ARABIC LETTER SHEEN */
enum XK_Arabic_sad = 0x05d5; /* U+0635 ARABIC LETTER SAD */
enum XK_Arabic_dad = 0x05d6; /* U+0636 ARABIC LETTER DAD */
enum XK_Arabic_tah = 0x05d7; /* U+0637 ARABIC LETTER TAH */
enum XK_Arabic_zah = 0x05d8; /* U+0638 ARABIC LETTER ZAH */
enum XK_Arabic_ain = 0x05d9; /* U+0639 ARABIC LETTER AIN */
enum XK_Arabic_ghain = 0x05da; /* U+063A ARABIC LETTER GHAIN */
enum XK_Arabic_tatweel = 0x05e0; /* U+0640 ARABIC TATWEEL */
enum XK_Arabic_feh = 0x05e1; /* U+0641 ARABIC LETTER FEH */
enum XK_Arabic_qaf = 0x05e2; /* U+0642 ARABIC LETTER QAF */
enum XK_Arabic_kaf = 0x05e3; /* U+0643 ARABIC LETTER KAF */
enum XK_Arabic_lam = 0x05e4; /* U+0644 ARABIC LETTER LAM */
enum XK_Arabic_meem = 0x05e5; /* U+0645 ARABIC LETTER MEEM */
enum XK_Arabic_noon = 0x05e6; /* U+0646 ARABIC LETTER NOON */
enum XK_Arabic_ha = 0x05e7; /* U+0647 ARABIC LETTER HEH */
enum XK_Arabic_heh = 0x05e7; /* deprecated */
enum XK_Arabic_waw = 0x05e8; /* U+0648 ARABIC LETTER WAW */
enum XK_Arabic_alefmaksura = 0x05e9; /* U+0649 ARABIC LETTER ALEF MAKSURA */
enum XK_Arabic_yeh = 0x05ea; /* U+064A ARABIC LETTER YEH */
enum XK_Arabic_fathatan = 0x05eb; /* U+064B ARABIC FATHATAN */
enum XK_Arabic_dammatan = 0x05ec; /* U+064C ARABIC DAMMATAN */
enum XK_Arabic_kasratan = 0x05ed; /* U+064D ARABIC KASRATAN */
enum XK_Arabic_fatha = 0x05ee; /* U+064E ARABIC FATHA */
enum XK_Arabic_damma = 0x05ef; /* U+064F ARABIC DAMMA */
enum XK_Arabic_kasra = 0x05f0; /* U+0650 ARABIC KASRA */
enum XK_Arabic_shadda = 0x05f1; /* U+0651 ARABIC SHADDA */
enum XK_Arabic_sukun = 0x05f2; /* U+0652 ARABIC SUKUN */
enum XK_Arabic_madda_above = 0x1000653; /* U+0653 ARABIC MADDAH ABOVE */
enum XK_Arabic_hamza_above = 0x1000654; /* U+0654 ARABIC HAMZA ABOVE */
enum XK_Arabic_hamza_below = 0x1000655; /* U+0655 ARABIC HAMZA BELOW */
enum XK_Arabic_jeh = 0x1000698; /* U+0698 ARABIC LETTER JEH */
enum XK_Arabic_veh = 0x10006a4; /* U+06A4 ARABIC LETTER VEH */
enum XK_Arabic_keheh = 0x10006a9; /* U+06A9 ARABIC LETTER KEHEH */
enum XK_Arabic_gaf = 0x10006af; /* U+06AF ARABIC LETTER GAF */
enum XK_Arabic_noon_ghunna = 0x10006ba; /* U+06BA ARABIC LETTER NOON GHUNNA */
enum XK_Arabic_heh_doachashmee = 0x10006be; /* U+06BE ARABIC LETTER HEH DOACHASHMEE */
enum XK_Farsi_yeh = 0x10006cc; /* U+06CC ARABIC LETTER FARSI YEH */
enum XK_Arabic_farsi_yeh = 0x10006cc; /* deprecated alias for Farsi_yeh */
enum XK_Arabic_yeh_baree = 0x10006d2; /* U+06D2 ARABIC LETTER YEH BARREE */
enum XK_Arabic_heh_goal = 0x10006c1; /* U+06C1 ARABIC LETTER HEH GOAL */
enum XK_Arabic_switch = 0xff7e; /* non-deprecated alias for Mode_switch */
/* XK_ARABIC */

/*
 * Cyrillic
 * Byte 3 = 6
 */
enum XK_Cyrillic_GHE_bar = 0x1000492; /* U+0492 CYRILLIC CAPITAL LETTER GHE WITH STROKE */
enum XK_Cyrillic_ghe_bar = 0x1000493; /* U+0493 CYRILLIC SMALL LETTER GHE WITH STROKE */
enum XK_Cyrillic_ZHE_descender = 0x1000496; /* U+0496 CYRILLIC CAPITAL LETTER ZHE WITH DESCENDER */
enum XK_Cyrillic_zhe_descender = 0x1000497; /* U+0497 CYRILLIC SMALL LETTER ZHE WITH DESCENDER */
enum XK_Cyrillic_KA_descender = 0x100049a; /* U+049A CYRILLIC CAPITAL LETTER KA WITH DESCENDER */
enum XK_Cyrillic_ka_descender = 0x100049b; /* U+049B CYRILLIC SMALL LETTER KA WITH DESCENDER */
enum XK_Cyrillic_KA_vertstroke = 0x100049c; /* U+049C CYRILLIC CAPITAL LETTER KA WITH VERTICAL STROKE */
enum XK_Cyrillic_ka_vertstroke = 0x100049d; /* U+049D CYRILLIC SMALL LETTER KA WITH VERTICAL STROKE */
enum XK_Cyrillic_EN_descender = 0x10004a2; /* U+04A2 CYRILLIC CAPITAL LETTER EN WITH DESCENDER */
enum XK_Cyrillic_en_descender = 0x10004a3; /* U+04A3 CYRILLIC SMALL LETTER EN WITH DESCENDER */
enum XK_Cyrillic_U_straight = 0x10004ae; /* U+04AE CYRILLIC CAPITAL LETTER STRAIGHT U */
enum XK_Cyrillic_u_straight = 0x10004af; /* U+04AF CYRILLIC SMALL LETTER STRAIGHT U */
enum XK_Cyrillic_U_straight_bar = 0x10004b0; /* U+04B0 CYRILLIC CAPITAL LETTER STRAIGHT U WITH STROKE */
enum XK_Cyrillic_u_straight_bar = 0x10004b1; /* U+04B1 CYRILLIC SMALL LETTER STRAIGHT U WITH STROKE */
enum XK_Cyrillic_HA_descender = 0x10004b2; /* U+04B2 CYRILLIC CAPITAL LETTER HA WITH DESCENDER */
enum XK_Cyrillic_ha_descender = 0x10004b3; /* U+04B3 CYRILLIC SMALL LETTER HA WITH DESCENDER */
enum XK_Cyrillic_CHE_descender = 0x10004b6; /* U+04B6 CYRILLIC CAPITAL LETTER CHE WITH DESCENDER */
enum XK_Cyrillic_che_descender = 0x10004b7; /* U+04B7 CYRILLIC SMALL LETTER CHE WITH DESCENDER */
enum XK_Cyrillic_CHE_vertstroke = 0x10004b8; /* U+04B8 CYRILLIC CAPITAL LETTER CHE WITH VERTICAL STROKE */
enum XK_Cyrillic_che_vertstroke = 0x10004b9; /* U+04B9 CYRILLIC SMALL LETTER CHE WITH VERTICAL STROKE */
enum XK_Cyrillic_SHHA = 0x10004ba; /* U+04BA CYRILLIC CAPITAL LETTER SHHA */
enum XK_Cyrillic_shha = 0x10004bb; /* U+04BB CYRILLIC SMALL LETTER SHHA */

enum XK_Cyrillic_SCHWA = 0x10004d8; /* U+04D8 CYRILLIC CAPITAL LETTER SCHWA */
enum XK_Cyrillic_schwa = 0x10004d9; /* U+04D9 CYRILLIC SMALL LETTER SCHWA */
enum XK_Cyrillic_I_macron = 0x10004e2; /* U+04E2 CYRILLIC CAPITAL LETTER I WITH MACRON */
enum XK_Cyrillic_i_macron = 0x10004e3; /* U+04E3 CYRILLIC SMALL LETTER I WITH MACRON */
enum XK_Cyrillic_O_bar = 0x10004e8; /* U+04E8 CYRILLIC CAPITAL LETTER BARRED O */
enum XK_Cyrillic_o_bar = 0x10004e9; /* U+04E9 CYRILLIC SMALL LETTER BARRED O */
enum XK_Cyrillic_U_macron = 0x10004ee; /* U+04EE CYRILLIC CAPITAL LETTER U WITH MACRON */
enum XK_Cyrillic_u_macron = 0x10004ef; /* U+04EF CYRILLIC SMALL LETTER U WITH MACRON */

enum XK_Serbian_dje = 0x06a1; /* U+0452 CYRILLIC SMALL LETTER DJE */
enum XK_Macedonia_gje = 0x06a2; /* U+0453 CYRILLIC SMALL LETTER GJE */
enum XK_Cyrillic_io = 0x06a3; /* U+0451 CYRILLIC SMALL LETTER IO */
enum XK_Ukrainian_ie = 0x06a4; /* U+0454 CYRILLIC SMALL LETTER UKRAINIAN IE */
enum XK_Ukranian_je = 0x06a4; /* deprecated */
enum XK_Macedonia_dse = 0x06a5; /* U+0455 CYRILLIC SMALL LETTER DZE */
enum XK_Ukrainian_i = 0x06a6; /* U+0456 CYRILLIC SMALL LETTER BYELORUSSIAN-UKRAINIAN I */
enum XK_Ukranian_i = 0x06a6; /* deprecated */
enum XK_Ukrainian_yi = 0x06a7; /* U+0457 CYRILLIC SMALL LETTER YI */
enum XK_Ukranian_yi = 0x06a7; /* deprecated */
enum XK_Cyrillic_je = 0x06a8; /* U+0458 CYRILLIC SMALL LETTER JE */
enum XK_Serbian_je = 0x06a8; /* deprecated */
enum XK_Cyrillic_lje = 0x06a9; /* U+0459 CYRILLIC SMALL LETTER LJE */
enum XK_Serbian_lje = 0x06a9; /* deprecated */
enum XK_Cyrillic_nje = 0x06aa; /* U+045A CYRILLIC SMALL LETTER NJE */
enum XK_Serbian_nje = 0x06aa; /* deprecated */
enum XK_Serbian_tshe = 0x06ab; /* U+045B CYRILLIC SMALL LETTER TSHE */
enum XK_Macedonia_kje = 0x06ac; /* U+045C CYRILLIC SMALL LETTER KJE */
enum XK_Ukrainian_ghe_with_upturn = 0x06ad; /* U+0491 CYRILLIC SMALL LETTER GHE WITH UPTURN */
enum XK_Byelorussian_shortu = 0x06ae; /* U+045E CYRILLIC SMALL LETTER SHORT U */
enum XK_Cyrillic_dzhe = 0x06af; /* U+045F CYRILLIC SMALL LETTER DZHE */
enum XK_Serbian_dze = 0x06af; /* deprecated */
enum XK_numerosign = 0x06b0; /* U+2116 NUMERO SIGN */
enum XK_Serbian_DJE = 0x06b1; /* U+0402 CYRILLIC CAPITAL LETTER DJE */
enum XK_Macedonia_GJE = 0x06b2; /* U+0403 CYRILLIC CAPITAL LETTER GJE */
enum XK_Cyrillic_IO = 0x06b3; /* U+0401 CYRILLIC CAPITAL LETTER IO */
enum XK_Ukrainian_IE = 0x06b4; /* U+0404 CYRILLIC CAPITAL LETTER UKRAINIAN IE */
enum XK_Ukranian_JE = 0x06b4; /* deprecated */
enum XK_Macedonia_DSE = 0x06b5; /* U+0405 CYRILLIC CAPITAL LETTER DZE */
enum XK_Ukrainian_I = 0x06b6; /* U+0406 CYRILLIC CAPITAL LETTER BYELORUSSIAN-UKRAINIAN I */
enum XK_Ukranian_I = 0x06b6; /* deprecated */
enum XK_Ukrainian_YI = 0x06b7; /* U+0407 CYRILLIC CAPITAL LETTER YI */
enum XK_Ukranian_YI = 0x06b7; /* deprecated */
enum XK_Cyrillic_JE = 0x06b8; /* U+0408 CYRILLIC CAPITAL LETTER JE */
enum XK_Serbian_JE = 0x06b8; /* deprecated */
enum XK_Cyrillic_LJE = 0x06b9; /* U+0409 CYRILLIC CAPITAL LETTER LJE */
enum XK_Serbian_LJE = 0x06b9; /* deprecated */
enum XK_Cyrillic_NJE = 0x06ba; /* U+040A CYRILLIC CAPITAL LETTER NJE */
enum XK_Serbian_NJE = 0x06ba; /* deprecated */
enum XK_Serbian_TSHE = 0x06bb; /* U+040B CYRILLIC CAPITAL LETTER TSHE */
enum XK_Macedonia_KJE = 0x06bc; /* U+040C CYRILLIC CAPITAL LETTER KJE */
enum XK_Ukrainian_GHE_WITH_UPTURN = 0x06bd; /* U+0490 CYRILLIC CAPITAL LETTER GHE WITH UPTURN */
enum XK_Byelorussian_SHORTU = 0x06be; /* U+040E CYRILLIC CAPITAL LETTER SHORT U */
enum XK_Cyrillic_DZHE = 0x06bf; /* U+040F CYRILLIC CAPITAL LETTER DZHE */
enum XK_Serbian_DZE = 0x06bf; /* deprecated */
enum XK_Cyrillic_yu = 0x06c0; /* U+044E CYRILLIC SMALL LETTER YU */
enum XK_Cyrillic_a = 0x06c1; /* U+0430 CYRILLIC SMALL LETTER A */
enum XK_Cyrillic_be = 0x06c2; /* U+0431 CYRILLIC SMALL LETTER BE */
enum XK_Cyrillic_tse = 0x06c3; /* U+0446 CYRILLIC SMALL LETTER TSE */
enum XK_Cyrillic_de = 0x06c4; /* U+0434 CYRILLIC SMALL LETTER DE */
enum XK_Cyrillic_ie = 0x06c5; /* U+0435 CYRILLIC SMALL LETTER IE */
enum XK_Cyrillic_ef = 0x06c6; /* U+0444 CYRILLIC SMALL LETTER EF */
enum XK_Cyrillic_ghe = 0x06c7; /* U+0433 CYRILLIC SMALL LETTER GHE */
enum XK_Cyrillic_ha = 0x06c8; /* U+0445 CYRILLIC SMALL LETTER HA */
enum XK_Cyrillic_i = 0x06c9; /* U+0438 CYRILLIC SMALL LETTER I */
enum XK_Cyrillic_shorti = 0x06ca; /* U+0439 CYRILLIC SMALL LETTER SHORT I */
enum XK_Cyrillic_ka = 0x06cb; /* U+043A CYRILLIC SMALL LETTER KA */
enum XK_Cyrillic_el = 0x06cc; /* U+043B CYRILLIC SMALL LETTER EL */
enum XK_Cyrillic_em = 0x06cd; /* U+043C CYRILLIC SMALL LETTER EM */
enum XK_Cyrillic_en = 0x06ce; /* U+043D CYRILLIC SMALL LETTER EN */
enum XK_Cyrillic_o = 0x06cf; /* U+043E CYRILLIC SMALL LETTER O */
enum XK_Cyrillic_pe = 0x06d0; /* U+043F CYRILLIC SMALL LETTER PE */
enum XK_Cyrillic_ya = 0x06d1; /* U+044F CYRILLIC SMALL LETTER YA */
enum XK_Cyrillic_er = 0x06d2; /* U+0440 CYRILLIC SMALL LETTER ER */
enum XK_Cyrillic_es = 0x06d3; /* U+0441 CYRILLIC SMALL LETTER ES */
enum XK_Cyrillic_te = 0x06d4; /* U+0442 CYRILLIC SMALL LETTER TE */
enum XK_Cyrillic_u = 0x06d5; /* U+0443 CYRILLIC SMALL LETTER U */
enum XK_Cyrillic_zhe = 0x06d6; /* U+0436 CYRILLIC SMALL LETTER ZHE */
enum XK_Cyrillic_ve = 0x06d7; /* U+0432 CYRILLIC SMALL LETTER VE */
enum XK_Cyrillic_softsign = 0x06d8; /* U+044C CYRILLIC SMALL LETTER SOFT SIGN */
enum XK_Cyrillic_yeru = 0x06d9; /* U+044B CYRILLIC SMALL LETTER YERU */
enum XK_Cyrillic_ze = 0x06da; /* U+0437 CYRILLIC SMALL LETTER ZE */
enum XK_Cyrillic_sha = 0x06db; /* U+0448 CYRILLIC SMALL LETTER SHA */
enum XK_Cyrillic_e = 0x06dc; /* U+044D CYRILLIC SMALL LETTER E */
enum XK_Cyrillic_shcha = 0x06dd; /* U+0449 CYRILLIC SMALL LETTER SHCHA */
enum XK_Cyrillic_che = 0x06de; /* U+0447 CYRILLIC SMALL LETTER CHE */
enum XK_Cyrillic_hardsign = 0x06df; /* U+044A CYRILLIC SMALL LETTER HARD SIGN */
enum XK_Cyrillic_YU = 0x06e0; /* U+042E CYRILLIC CAPITAL LETTER YU */
enum XK_Cyrillic_A = 0x06e1; /* U+0410 CYRILLIC CAPITAL LETTER A */
enum XK_Cyrillic_BE = 0x06e2; /* U+0411 CYRILLIC CAPITAL LETTER BE */
enum XK_Cyrillic_TSE = 0x06e3; /* U+0426 CYRILLIC CAPITAL LETTER TSE */
enum XK_Cyrillic_DE = 0x06e4; /* U+0414 CYRILLIC CAPITAL LETTER DE */
enum XK_Cyrillic_IE = 0x06e5; /* U+0415 CYRILLIC CAPITAL LETTER IE */
enum XK_Cyrillic_EF = 0x06e6; /* U+0424 CYRILLIC CAPITAL LETTER EF */
enum XK_Cyrillic_GHE = 0x06e7; /* U+0413 CYRILLIC CAPITAL LETTER GHE */
enum XK_Cyrillic_HA = 0x06e8; /* U+0425 CYRILLIC CAPITAL LETTER HA */
enum XK_Cyrillic_I = 0x06e9; /* U+0418 CYRILLIC CAPITAL LETTER I */
enum XK_Cyrillic_SHORTI = 0x06ea; /* U+0419 CYRILLIC CAPITAL LETTER SHORT I */
enum XK_Cyrillic_KA = 0x06eb; /* U+041A CYRILLIC CAPITAL LETTER KA */
enum XK_Cyrillic_EL = 0x06ec; /* U+041B CYRILLIC CAPITAL LETTER EL */
enum XK_Cyrillic_EM = 0x06ed; /* U+041C CYRILLIC CAPITAL LETTER EM */
enum XK_Cyrillic_EN = 0x06ee; /* U+041D CYRILLIC CAPITAL LETTER EN */
enum XK_Cyrillic_O = 0x06ef; /* U+041E CYRILLIC CAPITAL LETTER O */
enum XK_Cyrillic_PE = 0x06f0; /* U+041F CYRILLIC CAPITAL LETTER PE */
enum XK_Cyrillic_YA = 0x06f1; /* U+042F CYRILLIC CAPITAL LETTER YA */
enum XK_Cyrillic_ER = 0x06f2; /* U+0420 CYRILLIC CAPITAL LETTER ER */
enum XK_Cyrillic_ES = 0x06f3; /* U+0421 CYRILLIC CAPITAL LETTER ES */
enum XK_Cyrillic_TE = 0x06f4; /* U+0422 CYRILLIC CAPITAL LETTER TE */
enum XK_Cyrillic_U = 0x06f5; /* U+0423 CYRILLIC CAPITAL LETTER U */
enum XK_Cyrillic_ZHE = 0x06f6; /* U+0416 CYRILLIC CAPITAL LETTER ZHE */
enum XK_Cyrillic_VE = 0x06f7; /* U+0412 CYRILLIC CAPITAL LETTER VE */
enum XK_Cyrillic_SOFTSIGN = 0x06f8; /* U+042C CYRILLIC CAPITAL LETTER SOFT SIGN */
enum XK_Cyrillic_YERU = 0x06f9; /* U+042B CYRILLIC CAPITAL LETTER YERU */
enum XK_Cyrillic_ZE = 0x06fa; /* U+0417 CYRILLIC CAPITAL LETTER ZE */
enum XK_Cyrillic_SHA = 0x06fb; /* U+0428 CYRILLIC CAPITAL LETTER SHA */
enum XK_Cyrillic_E = 0x06fc; /* U+042D CYRILLIC CAPITAL LETTER E */
enum XK_Cyrillic_SHCHA = 0x06fd; /* U+0429 CYRILLIC CAPITAL LETTER SHCHA */
enum XK_Cyrillic_CHE = 0x06fe; /* U+0427 CYRILLIC CAPITAL LETTER CHE */
enum XK_Cyrillic_HARDSIGN = 0x06ff; /* U+042A CYRILLIC CAPITAL LETTER HARD SIGN */
/* XK_CYRILLIC */

/*
 * Greek
 * (based on an early draft of, and not quite identical to, ISO/IEC 8859-7)
 * Byte 3 = 7
 */

enum XK_Greek_ALPHAaccent = 0x07a1; /* U+0386 GREEK CAPITAL LETTER ALPHA WITH TONOS */
enum XK_Greek_EPSILONaccent = 0x07a2; /* U+0388 GREEK CAPITAL LETTER EPSILON WITH TONOS */
enum XK_Greek_ETAaccent = 0x07a3; /* U+0389 GREEK CAPITAL LETTER ETA WITH TONOS */
enum XK_Greek_IOTAaccent = 0x07a4; /* U+038A GREEK CAPITAL LETTER IOTA WITH TONOS */
enum XK_Greek_IOTAdieresis = 0x07a5; /* U+03AA GREEK CAPITAL LETTER IOTA WITH DIALYTIKA */
enum XK_Greek_IOTAdiaeresis = 0x07a5; /* deprecated (old typo) */
enum XK_Greek_OMICRONaccent = 0x07a7; /* U+038C GREEK CAPITAL LETTER OMICRON WITH TONOS */
enum XK_Greek_UPSILONaccent = 0x07a8; /* U+038E GREEK CAPITAL LETTER UPSILON WITH TONOS */
enum XK_Greek_UPSILONdieresis = 0x07a9; /* U+03AB GREEK CAPITAL LETTER UPSILON WITH DIALYTIKA */
enum XK_Greek_OMEGAaccent = 0x07ab; /* U+038F GREEK CAPITAL LETTER OMEGA WITH TONOS */
enum XK_Greek_accentdieresis = 0x07ae; /* U+0385 GREEK DIALYTIKA TONOS */
enum XK_Greek_horizbar = 0x07af; /* U+2015 HORIZONTAL BAR */
enum XK_Greek_alphaaccent = 0x07b1; /* U+03AC GREEK SMALL LETTER ALPHA WITH TONOS */
enum XK_Greek_epsilonaccent = 0x07b2; /* U+03AD GREEK SMALL LETTER EPSILON WITH TONOS */
enum XK_Greek_etaaccent = 0x07b3; /* U+03AE GREEK SMALL LETTER ETA WITH TONOS */
enum XK_Greek_iotaaccent = 0x07b4; /* U+03AF GREEK SMALL LETTER IOTA WITH TONOS */
enum XK_Greek_iotadieresis = 0x07b5; /* U+03CA GREEK SMALL LETTER IOTA WITH DIALYTIKA */
enum XK_Greek_iotaaccentdieresis = 0x07b6; /* U+0390 GREEK SMALL LETTER IOTA WITH DIALYTIKA AND TONOS */
enum XK_Greek_omicronaccent = 0x07b7; /* U+03CC GREEK SMALL LETTER OMICRON WITH TONOS */
enum XK_Greek_upsilonaccent = 0x07b8; /* U+03CD GREEK SMALL LETTER UPSILON WITH TONOS */
enum XK_Greek_upsilondieresis = 0x07b9; /* U+03CB GREEK SMALL LETTER UPSILON WITH DIALYTIKA */
enum XK_Greek_upsilonaccentdieresis = 0x07ba; /* U+03B0 GREEK SMALL LETTER UPSILON WITH DIALYTIKA AND TONOS */
enum XK_Greek_omegaaccent = 0x07bb; /* U+03CE GREEK SMALL LETTER OMEGA WITH TONOS */
enum XK_Greek_ALPHA = 0x07c1; /* U+0391 GREEK CAPITAL LETTER ALPHA */
enum XK_Greek_BETA = 0x07c2; /* U+0392 GREEK CAPITAL LETTER BETA */
enum XK_Greek_GAMMA = 0x07c3; /* U+0393 GREEK CAPITAL LETTER GAMMA */
enum XK_Greek_DELTA = 0x07c4; /* U+0394 GREEK CAPITAL LETTER DELTA */
enum XK_Greek_EPSILON = 0x07c5; /* U+0395 GREEK CAPITAL LETTER EPSILON */
enum XK_Greek_ZETA = 0x07c6; /* U+0396 GREEK CAPITAL LETTER ZETA */
enum XK_Greek_ETA = 0x07c7; /* U+0397 GREEK CAPITAL LETTER ETA */
enum XK_Greek_THETA = 0x07c8; /* U+0398 GREEK CAPITAL LETTER THETA */
enum XK_Greek_IOTA = 0x07c9; /* U+0399 GREEK CAPITAL LETTER IOTA */
enum XK_Greek_KAPPA = 0x07ca; /* U+039A GREEK CAPITAL LETTER KAPPA */
enum XK_Greek_LAMDA = 0x07cb; /* U+039B GREEK CAPITAL LETTER LAMDA */
enum XK_Greek_LAMBDA = 0x07cb; /* non-deprecated alias for Greek_LAMDA */
enum XK_Greek_MU = 0x07cc; /* U+039C GREEK CAPITAL LETTER MU */
enum XK_Greek_NU = 0x07cd; /* U+039D GREEK CAPITAL LETTER NU */
enum XK_Greek_XI = 0x07ce; /* U+039E GREEK CAPITAL LETTER XI */
enum XK_Greek_OMICRON = 0x07cf; /* U+039F GREEK CAPITAL LETTER OMICRON */
enum XK_Greek_PI = 0x07d0; /* U+03A0 GREEK CAPITAL LETTER PI */
enum XK_Greek_RHO = 0x07d1; /* U+03A1 GREEK CAPITAL LETTER RHO */
enum XK_Greek_SIGMA = 0x07d2; /* U+03A3 GREEK CAPITAL LETTER SIGMA */
enum XK_Greek_TAU = 0x07d4; /* U+03A4 GREEK CAPITAL LETTER TAU */
enum XK_Greek_UPSILON = 0x07d5; /* U+03A5 GREEK CAPITAL LETTER UPSILON */
enum XK_Greek_PHI = 0x07d6; /* U+03A6 GREEK CAPITAL LETTER PHI */
enum XK_Greek_CHI = 0x07d7; /* U+03A7 GREEK CAPITAL LETTER CHI */
enum XK_Greek_PSI = 0x07d8; /* U+03A8 GREEK CAPITAL LETTER PSI */
enum XK_Greek_OMEGA = 0x07d9; /* U+03A9 GREEK CAPITAL LETTER OMEGA */
enum XK_Greek_alpha = 0x07e1; /* U+03B1 GREEK SMALL LETTER ALPHA */
enum XK_Greek_beta = 0x07e2; /* U+03B2 GREEK SMALL LETTER BETA */
enum XK_Greek_gamma = 0x07e3; /* U+03B3 GREEK SMALL LETTER GAMMA */
enum XK_Greek_delta = 0x07e4; /* U+03B4 GREEK SMALL LETTER DELTA */
enum XK_Greek_epsilon = 0x07e5; /* U+03B5 GREEK SMALL LETTER EPSILON */
enum XK_Greek_zeta = 0x07e6; /* U+03B6 GREEK SMALL LETTER ZETA */
enum XK_Greek_eta = 0x07e7; /* U+03B7 GREEK SMALL LETTER ETA */
enum XK_Greek_theta = 0x07e8; /* U+03B8 GREEK SMALL LETTER THETA */
enum XK_Greek_iota = 0x07e9; /* U+03B9 GREEK SMALL LETTER IOTA */
enum XK_Greek_kappa = 0x07ea; /* U+03BA GREEK SMALL LETTER KAPPA */
enum XK_Greek_lamda = 0x07eb; /* U+03BB GREEK SMALL LETTER LAMDA */
enum XK_Greek_lambda = 0x07eb; /* non-deprecated alias for Greek_lamda */
enum XK_Greek_mu = 0x07ec; /* U+03BC GREEK SMALL LETTER MU */
enum XK_Greek_nu = 0x07ed; /* U+03BD GREEK SMALL LETTER NU */
enum XK_Greek_xi = 0x07ee; /* U+03BE GREEK SMALL LETTER XI */
enum XK_Greek_omicron = 0x07ef; /* U+03BF GREEK SMALL LETTER OMICRON */
enum XK_Greek_pi = 0x07f0; /* U+03C0 GREEK SMALL LETTER PI */
enum XK_Greek_rho = 0x07f1; /* U+03C1 GREEK SMALL LETTER RHO */
enum XK_Greek_sigma = 0x07f2; /* U+03C3 GREEK SMALL LETTER SIGMA */
enum XK_Greek_finalsmallsigma = 0x07f3; /* U+03C2 GREEK SMALL LETTER FINAL SIGMA */
enum XK_Greek_tau = 0x07f4; /* U+03C4 GREEK SMALL LETTER TAU */
enum XK_Greek_upsilon = 0x07f5; /* U+03C5 GREEK SMALL LETTER UPSILON */
enum XK_Greek_phi = 0x07f6; /* U+03C6 GREEK SMALL LETTER PHI */
enum XK_Greek_chi = 0x07f7; /* U+03C7 GREEK SMALL LETTER CHI */
enum XK_Greek_psi = 0x07f8; /* U+03C8 GREEK SMALL LETTER PSI */
enum XK_Greek_omega = 0x07f9; /* U+03C9 GREEK SMALL LETTER OMEGA */
enum XK_Greek_switch = 0xff7e; /* non-deprecated alias for Mode_switch */
/* XK_GREEK */

/*
 * Technical
 * (from the DEC VT330/VT420 Technical Character Set, http://vt100.net/charsets/technical.html)
 * Byte 3 = 8
 */

/* U+23B7 RADICAL SYMBOL BOTTOM */
/*(U+250C BOX DRAWINGS LIGHT DOWN AND RIGHT)*/
/*(U+2500 BOX DRAWINGS LIGHT HORIZONTAL)*/
/* U+2320 TOP HALF INTEGRAL */
/* U+2321 BOTTOM HALF INTEGRAL */
/*(U+2502 BOX DRAWINGS LIGHT VERTICAL)*/
/* U+23A1 LEFT SQUARE BRACKET UPPER CORNER */
/* U+23A3 LEFT SQUARE BRACKET LOWER CORNER */
/* U+23A4 RIGHT SQUARE BRACKET UPPER CORNER */
/* U+23A6 RIGHT SQUARE BRACKET LOWER CORNER */
/* U+239B LEFT PARENTHESIS UPPER HOOK */
/* U+239D LEFT PARENTHESIS LOWER HOOK */
/* U+239E RIGHT PARENTHESIS UPPER HOOK */
/* U+23A0 RIGHT PARENTHESIS LOWER HOOK */
/* U+23A8 LEFT CURLY BRACKET MIDDLE PIECE */
/* U+23AC RIGHT CURLY BRACKET MIDDLE PIECE */

/* U+2264 LESS-THAN OR EQUAL TO */
/* U+2260 NOT EQUAL TO */
/* U+2265 GREATER-THAN OR EQUAL TO */
/* U+222B INTEGRAL */
/* U+2234 THEREFORE */
/* U+221D PROPORTIONAL TO */
/* U+221E INFINITY */
/* U+2207 NABLA */
/* U+223C TILDE OPERATOR */
/* U+2243 ASYMPTOTICALLY EQUAL TO */
/* U+21D4 LEFT RIGHT DOUBLE ARROW */
/* U+21D2 RIGHTWARDS DOUBLE ARROW */
/* U+2261 IDENTICAL TO */
/* U+221A SQUARE ROOT */
/* U+2282 SUBSET OF */
/* U+2283 SUPERSET OF */
/* U+2229 INTERSECTION */
/* U+222A UNION */
/* U+2227 LOGICAL AND */
/* U+2228 LOGICAL OR */
/* U+2202 PARTIAL DIFFERENTIAL */
/* U+0192 LATIN SMALL LETTER F WITH HOOK */
/* U+2190 LEFTWARDS ARROW */
/* U+2191 UPWARDS ARROW */
/* U+2192 RIGHTWARDS ARROW */
/* U+2193 DOWNWARDS ARROW */
/* XK_TECHNICAL */

/*
 * Special
 * (from the DEC VT100 Special Graphics Character Set)
 * Byte 3 = 9
 */

/* U+25C6 BLACK DIAMOND */
/* U+2592 MEDIUM SHADE */
/* U+2409 SYMBOL FOR HORIZONTAL TABULATION */
/* U+240C SYMBOL FOR FORM FEED */
/* U+240D SYMBOL FOR CARRIAGE RETURN */
/* U+240A SYMBOL FOR LINE FEED */
/* U+2424 SYMBOL FOR NEWLINE */
/* U+240B SYMBOL FOR VERTICAL TABULATION */
/* U+2518 BOX DRAWINGS LIGHT UP AND LEFT */
/* U+2510 BOX DRAWINGS LIGHT DOWN AND LEFT */
/* U+250C BOX DRAWINGS LIGHT DOWN AND RIGHT */
/* U+2514 BOX DRAWINGS LIGHT UP AND RIGHT */
/* U+253C BOX DRAWINGS LIGHT VERTICAL AND HORIZONTAL */
/* U+23BA HORIZONTAL SCAN LINE-1 */
/* U+23BB HORIZONTAL SCAN LINE-3 */
/* U+2500 BOX DRAWINGS LIGHT HORIZONTAL */
/* U+23BC HORIZONTAL SCAN LINE-7 */
/* U+23BD HORIZONTAL SCAN LINE-9 */
/* U+251C BOX DRAWINGS LIGHT VERTICAL AND RIGHT */
/* U+2524 BOX DRAWINGS LIGHT VERTICAL AND LEFT */
/* U+2534 BOX DRAWINGS LIGHT UP AND HORIZONTAL */
/* U+252C BOX DRAWINGS LIGHT DOWN AND HORIZONTAL */
/* U+2502 BOX DRAWINGS LIGHT VERTICAL */
/* XK_SPECIAL */

/*
 * Publishing
 * (these are probably from a long forgotten DEC Publishing
 * font that once shipped with DECwrite)
 * Byte 3 = 0x0a
 */

/* U+2003 EM SPACE */
/* U+2002 EN SPACE */
/* U+2004 THREE-PER-EM SPACE */
/* U+2005 FOUR-PER-EM SPACE */
/* U+2007 FIGURE SPACE */
/* U+2008 PUNCTUATION SPACE */
/* U+2009 THIN SPACE */
/* U+200A HAIR SPACE */
/* U+2014 EM DASH */
/* U+2013 EN DASH */
/*(U+2423 OPEN BOX)*/
/* U+2026 HORIZONTAL ELLIPSIS */
/* U+2025 TWO DOT LEADER */
/* U+2153 VULGAR FRACTION ONE THIRD */
/* U+2154 VULGAR FRACTION TWO THIRDS */
/* U+2155 VULGAR FRACTION ONE FIFTH */
/* U+2156 VULGAR FRACTION TWO FIFTHS */
/* U+2157 VULGAR FRACTION THREE FIFTHS */
/* U+2158 VULGAR FRACTION FOUR FIFTHS */
/* U+2159 VULGAR FRACTION ONE SIXTH */
/* U+215A VULGAR FRACTION FIVE SIXTHS */
/* U+2105 CARE OF */
/* U+2012 FIGURE DASH */
/*(U+2329 LEFT-POINTING ANGLE BRACKET)*/
/*(U+002E FULL STOP)*/
/*(U+232A RIGHT-POINTING ANGLE BRACKET)*/

/* U+215B VULGAR FRACTION ONE EIGHTH */
/* U+215C VULGAR FRACTION THREE EIGHTHS */
/* U+215D VULGAR FRACTION FIVE EIGHTHS */
/* U+215E VULGAR FRACTION SEVEN EIGHTHS */
/* U+2122 TRADE MARK SIGN */
/*(U+2613 SALTIRE)*/

/*(U+25C1 WHITE LEFT-POINTING TRIANGLE)*/
/*(U+25B7 WHITE RIGHT-POINTING TRIANGLE)*/
/*(U+25CB WHITE CIRCLE)*/
/*(U+25AF WHITE VERTICAL RECTANGLE)*/
/* U+2018 LEFT SINGLE QUOTATION MARK */
/* U+2019 RIGHT SINGLE QUOTATION MARK */
/* U+201C LEFT DOUBLE QUOTATION MARK */
/* U+201D RIGHT DOUBLE QUOTATION MARK */
/* U+211E PRESCRIPTION TAKE */
/* U+2030 PER MILLE SIGN */
/* U+2032 PRIME */
/* U+2033 DOUBLE PRIME */
/* U+271D LATIN CROSS */

/*(U+25AC BLACK RECTANGLE)*/
/*(U+25C0 BLACK LEFT-POINTING TRIANGLE)*/
/*(U+25B6 BLACK RIGHT-POINTING TRIANGLE)*/
/*(U+25CF BLACK CIRCLE)*/
/*(U+25AE BLACK VERTICAL RECTANGLE)*/
/*(U+25E6 WHITE BULLET)*/
/*(U+25AB WHITE SMALL SQUARE)*/
/*(U+25AD WHITE RECTANGLE)*/
/*(U+25B3 WHITE UP-POINTING TRIANGLE)*/
/*(U+25BD WHITE DOWN-POINTING TRIANGLE)*/
/*(U+2606 WHITE STAR)*/
/*(U+2022 BULLET)*/
/*(U+25AA BLACK SMALL SQUARE)*/
/*(U+25B2 BLACK UP-POINTING TRIANGLE)*/
/*(U+25BC BLACK DOWN-POINTING TRIANGLE)*/
/*(U+261C WHITE LEFT POINTING INDEX)*/
/*(U+261E WHITE RIGHT POINTING INDEX)*/
/* U+2663 BLACK CLUB SUIT */
/* U+2666 BLACK DIAMOND SUIT */
/* U+2665 BLACK HEART SUIT */
/* U+2720 MALTESE CROSS */
/* U+2020 DAGGER */
/* U+2021 DOUBLE DAGGER */
/* U+2713 CHECK MARK */
/* U+2717 BALLOT X */
/* U+266F MUSIC SHARP SIGN */
/* U+266D MUSIC FLAT SIGN */
/* U+2642 MALE SIGN */
/* U+2640 FEMALE SIGN */
/* U+260E BLACK TELEPHONE */
/* U+2315 TELEPHONE RECORDER */
/* U+2117 SOUND RECORDING COPYRIGHT */
/* U+2038 CARET */
/* U+201A SINGLE LOW-9 QUOTATION MARK */
/* U+201E DOUBLE LOW-9 QUOTATION MARK */

/* XK_PUBLISHING */

/*
 * APL
 * Byte 3 = 0x0b
 */

/*(U+003C LESS-THAN SIGN)*/
/*(U+003E GREATER-THAN SIGN)*/
/*(U+2228 LOGICAL OR)*/
/*(U+2227 LOGICAL AND)*/
/*(U+00AF MACRON)*/
/* U+22A4 DOWN TACK */
/*(U+2229 INTERSECTION)*/
/* U+230A LEFT FLOOR */
/*(U+005F LOW LINE)*/
/* U+2218 RING OPERATOR */
/* U+2395 APL FUNCTIONAL SYMBOL QUAD */
/* U+22A5 UP TACK */
/* U+25CB WHITE CIRCLE */
/* U+2308 LEFT CEILING */
/*(U+222A UNION)*/
/*(U+2283 SUPERSET OF)*/
/*(U+2282 SUBSET OF)*/
/* U+22A3 LEFT TACK */
/* U+22A2 RIGHT TACK */
/* XK_APL */

/*
 * Hebrew
 * Byte 3 = 0x0c
 */

enum XK_hebrew_doublelowline = 0x0cdf; /* U+2017 DOUBLE LOW LINE */
enum XK_hebrew_aleph = 0x0ce0; /* U+05D0 HEBREW LETTER ALEF */
enum XK_hebrew_bet = 0x0ce1; /* U+05D1 HEBREW LETTER BET */
enum XK_hebrew_beth = 0x0ce1; /* deprecated */
enum XK_hebrew_gimel = 0x0ce2; /* U+05D2 HEBREW LETTER GIMEL */
enum XK_hebrew_gimmel = 0x0ce2; /* deprecated */
enum XK_hebrew_dalet = 0x0ce3; /* U+05D3 HEBREW LETTER DALET */
enum XK_hebrew_daleth = 0x0ce3; /* deprecated */
enum XK_hebrew_he = 0x0ce4; /* U+05D4 HEBREW LETTER HE */
enum XK_hebrew_waw = 0x0ce5; /* U+05D5 HEBREW LETTER VAV */
enum XK_hebrew_zain = 0x0ce6; /* U+05D6 HEBREW LETTER ZAYIN */
enum XK_hebrew_zayin = 0x0ce6; /* deprecated */
enum XK_hebrew_chet = 0x0ce7; /* U+05D7 HEBREW LETTER HET */
enum XK_hebrew_het = 0x0ce7; /* deprecated */
enum XK_hebrew_tet = 0x0ce8; /* U+05D8 HEBREW LETTER TET */
enum XK_hebrew_teth = 0x0ce8; /* deprecated */
enum XK_hebrew_yod = 0x0ce9; /* U+05D9 HEBREW LETTER YOD */
enum XK_hebrew_finalkaph = 0x0cea; /* U+05DA HEBREW LETTER FINAL KAF */
enum XK_hebrew_kaph = 0x0ceb; /* U+05DB HEBREW LETTER KAF */
enum XK_hebrew_lamed = 0x0cec; /* U+05DC HEBREW LETTER LAMED */
enum XK_hebrew_finalmem = 0x0ced; /* U+05DD HEBREW LETTER FINAL MEM */
enum XK_hebrew_mem = 0x0cee; /* U+05DE HEBREW LETTER MEM */
enum XK_hebrew_finalnun = 0x0cef; /* U+05DF HEBREW LETTER FINAL NUN */
enum XK_hebrew_nun = 0x0cf0; /* U+05E0 HEBREW LETTER NUN */
enum XK_hebrew_samech = 0x0cf1; /* U+05E1 HEBREW LETTER SAMEKH */
enum XK_hebrew_samekh = 0x0cf1; /* deprecated */
enum XK_hebrew_ayin = 0x0cf2; /* U+05E2 HEBREW LETTER AYIN */
enum XK_hebrew_finalpe = 0x0cf3; /* U+05E3 HEBREW LETTER FINAL PE */
enum XK_hebrew_pe = 0x0cf4; /* U+05E4 HEBREW LETTER PE */
enum XK_hebrew_finalzade = 0x0cf5; /* U+05E5 HEBREW LETTER FINAL TSADI */
enum XK_hebrew_finalzadi = 0x0cf5; /* deprecated */
enum XK_hebrew_zade = 0x0cf6; /* U+05E6 HEBREW LETTER TSADI */
enum XK_hebrew_zadi = 0x0cf6; /* deprecated */
enum XK_hebrew_qoph = 0x0cf7; /* U+05E7 HEBREW LETTER QOF */
enum XK_hebrew_kuf = 0x0cf7; /* deprecated */
enum XK_hebrew_resh = 0x0cf8; /* U+05E8 HEBREW LETTER RESH */
enum XK_hebrew_shin = 0x0cf9; /* U+05E9 HEBREW LETTER SHIN */
enum XK_hebrew_taw = 0x0cfa; /* U+05EA HEBREW LETTER TAV */
enum XK_hebrew_taf = 0x0cfa; /* deprecated */
enum XK_Hebrew_switch = 0xff7e; /* non-deprecated alias for Mode_switch */
/* XK_HEBREW */

/*
 * Thai
 * Byte 3 = 0x0d
 */

enum XK_Thai_kokai = 0x0da1; /* U+0E01 THAI CHARACTER KO KAI */
enum XK_Thai_khokhai = 0x0da2; /* U+0E02 THAI CHARACTER KHO KHAI */
enum XK_Thai_khokhuat = 0x0da3; /* U+0E03 THAI CHARACTER KHO KHUAT */
enum XK_Thai_khokhwai = 0x0da4; /* U+0E04 THAI CHARACTER KHO KHWAI */
enum XK_Thai_khokhon = 0x0da5; /* U+0E05 THAI CHARACTER KHO KHON */
enum XK_Thai_khorakhang = 0x0da6; /* U+0E06 THAI CHARACTER KHO RAKHANG */
enum XK_Thai_ngongu = 0x0da7; /* U+0E07 THAI CHARACTER NGO NGU */
enum XK_Thai_chochan = 0x0da8; /* U+0E08 THAI CHARACTER CHO CHAN */
enum XK_Thai_choching = 0x0da9; /* U+0E09 THAI CHARACTER CHO CHING */
enum XK_Thai_chochang = 0x0daa; /* U+0E0A THAI CHARACTER CHO CHANG */
enum XK_Thai_soso = 0x0dab; /* U+0E0B THAI CHARACTER SO SO */
enum XK_Thai_chochoe = 0x0dac; /* U+0E0C THAI CHARACTER CHO CHOE */
enum XK_Thai_yoying = 0x0dad; /* U+0E0D THAI CHARACTER YO YING */
enum XK_Thai_dochada = 0x0dae; /* U+0E0E THAI CHARACTER DO CHADA */
enum XK_Thai_topatak = 0x0daf; /* U+0E0F THAI CHARACTER TO PATAK */
enum XK_Thai_thothan = 0x0db0; /* U+0E10 THAI CHARACTER THO THAN */
enum XK_Thai_thonangmontho = 0x0db1; /* U+0E11 THAI CHARACTER THO NANGMONTHO */
enum XK_Thai_thophuthao = 0x0db2; /* U+0E12 THAI CHARACTER THO PHUTHAO */
enum XK_Thai_nonen = 0x0db3; /* U+0E13 THAI CHARACTER NO NEN */
enum XK_Thai_dodek = 0x0db4; /* U+0E14 THAI CHARACTER DO DEK */
enum XK_Thai_totao = 0x0db5; /* U+0E15 THAI CHARACTER TO TAO */
enum XK_Thai_thothung = 0x0db6; /* U+0E16 THAI CHARACTER THO THUNG */
enum XK_Thai_thothahan = 0x0db7; /* U+0E17 THAI CHARACTER THO THAHAN */
enum XK_Thai_thothong = 0x0db8; /* U+0E18 THAI CHARACTER THO THONG */
enum XK_Thai_nonu = 0x0db9; /* U+0E19 THAI CHARACTER NO NU */
enum XK_Thai_bobaimai = 0x0dba; /* U+0E1A THAI CHARACTER BO BAIMAI */
enum XK_Thai_popla = 0x0dbb; /* U+0E1B THAI CHARACTER PO PLA */
enum XK_Thai_phophung = 0x0dbc; /* U+0E1C THAI CHARACTER PHO PHUNG */
enum XK_Thai_fofa = 0x0dbd; /* U+0E1D THAI CHARACTER FO FA */
enum XK_Thai_phophan = 0x0dbe; /* U+0E1E THAI CHARACTER PHO PHAN */
enum XK_Thai_fofan = 0x0dbf; /* U+0E1F THAI CHARACTER FO FAN */
enum XK_Thai_phosamphao = 0x0dc0; /* U+0E20 THAI CHARACTER PHO SAMPHAO */
enum XK_Thai_moma = 0x0dc1; /* U+0E21 THAI CHARACTER MO MA */
enum XK_Thai_yoyak = 0x0dc2; /* U+0E22 THAI CHARACTER YO YAK */
enum XK_Thai_rorua = 0x0dc3; /* U+0E23 THAI CHARACTER RO RUA */
enum XK_Thai_ru = 0x0dc4; /* U+0E24 THAI CHARACTER RU */
enum XK_Thai_loling = 0x0dc5; /* U+0E25 THAI CHARACTER LO LING */
enum XK_Thai_lu = 0x0dc6; /* U+0E26 THAI CHARACTER LU */
enum XK_Thai_wowaen = 0x0dc7; /* U+0E27 THAI CHARACTER WO WAEN */
enum XK_Thai_sosala = 0x0dc8; /* U+0E28 THAI CHARACTER SO SALA */
enum XK_Thai_sorusi = 0x0dc9; /* U+0E29 THAI CHARACTER SO RUSI */
enum XK_Thai_sosua = 0x0dca; /* U+0E2A THAI CHARACTER SO SUA */
enum XK_Thai_hohip = 0x0dcb; /* U+0E2B THAI CHARACTER HO HIP */
enum XK_Thai_lochula = 0x0dcc; /* U+0E2C THAI CHARACTER LO CHULA */
enum XK_Thai_oang = 0x0dcd; /* U+0E2D THAI CHARACTER O ANG */
enum XK_Thai_honokhuk = 0x0dce; /* U+0E2E THAI CHARACTER HO NOKHUK */
enum XK_Thai_paiyannoi = 0x0dcf; /* U+0E2F THAI CHARACTER PAIYANNOI */
enum XK_Thai_saraa = 0x0dd0; /* U+0E30 THAI CHARACTER SARA A */
enum XK_Thai_maihanakat = 0x0dd1; /* U+0E31 THAI CHARACTER MAI HAN-AKAT */
enum XK_Thai_saraaa = 0x0dd2; /* U+0E32 THAI CHARACTER SARA AA */
enum XK_Thai_saraam = 0x0dd3; /* U+0E33 THAI CHARACTER SARA AM */
enum XK_Thai_sarai = 0x0dd4; /* U+0E34 THAI CHARACTER SARA I */
enum XK_Thai_saraii = 0x0dd5; /* U+0E35 THAI CHARACTER SARA II */
enum XK_Thai_saraue = 0x0dd6; /* U+0E36 THAI CHARACTER SARA UE */
enum XK_Thai_sarauee = 0x0dd7; /* U+0E37 THAI CHARACTER SARA UEE */
enum XK_Thai_sarau = 0x0dd8; /* U+0E38 THAI CHARACTER SARA U */
enum XK_Thai_sarauu = 0x0dd9; /* U+0E39 THAI CHARACTER SARA UU */
enum XK_Thai_phinthu = 0x0dda; /* U+0E3A THAI CHARACTER PHINTHU */
enum XK_Thai_maihanakat_maitho = 0x0dde; /*(U+0E3E Unassigned code point)*/
enum XK_Thai_baht = 0x0ddf; /* U+0E3F THAI CURRENCY SYMBOL BAHT */
enum XK_Thai_sarae = 0x0de0; /* U+0E40 THAI CHARACTER SARA E */
enum XK_Thai_saraae = 0x0de1; /* U+0E41 THAI CHARACTER SARA AE */
enum XK_Thai_sarao = 0x0de2; /* U+0E42 THAI CHARACTER SARA O */
enum XK_Thai_saraaimaimuan = 0x0de3; /* U+0E43 THAI CHARACTER SARA AI MAIMUAN */
enum XK_Thai_saraaimaimalai = 0x0de4; /* U+0E44 THAI CHARACTER SARA AI MAIMALAI */
enum XK_Thai_lakkhangyao = 0x0de5; /* U+0E45 THAI CHARACTER LAKKHANGYAO */
enum XK_Thai_maiyamok = 0x0de6; /* U+0E46 THAI CHARACTER MAIYAMOK */
enum XK_Thai_maitaikhu = 0x0de7; /* U+0E47 THAI CHARACTER MAITAIKHU */
enum XK_Thai_maiek = 0x0de8; /* U+0E48 THAI CHARACTER MAI EK */
enum XK_Thai_maitho = 0x0de9; /* U+0E49 THAI CHARACTER MAI THO */
enum XK_Thai_maitri = 0x0dea; /* U+0E4A THAI CHARACTER MAI TRI */
enum XK_Thai_maichattawa = 0x0deb; /* U+0E4B THAI CHARACTER MAI CHATTAWA */
enum XK_Thai_thanthakhat = 0x0dec; /* U+0E4C THAI CHARACTER THANTHAKHAT */
enum XK_Thai_nikhahit = 0x0ded; /* U+0E4D THAI CHARACTER NIKHAHIT */
enum XK_Thai_leksun = 0x0df0; /* U+0E50 THAI DIGIT ZERO */
enum XK_Thai_leknung = 0x0df1; /* U+0E51 THAI DIGIT ONE */
enum XK_Thai_leksong = 0x0df2; /* U+0E52 THAI DIGIT TWO */
enum XK_Thai_leksam = 0x0df3; /* U+0E53 THAI DIGIT THREE */
enum XK_Thai_leksi = 0x0df4; /* U+0E54 THAI DIGIT FOUR */
enum XK_Thai_lekha = 0x0df5; /* U+0E55 THAI DIGIT FIVE */
enum XK_Thai_lekhok = 0x0df6; /* U+0E56 THAI DIGIT SIX */
enum XK_Thai_lekchet = 0x0df7; /* U+0E57 THAI DIGIT SEVEN */
enum XK_Thai_lekpaet = 0x0df8; /* U+0E58 THAI DIGIT EIGHT */
enum XK_Thai_lekkao = 0x0df9; /* U+0E59 THAI DIGIT NINE */
/* XK_THAI */

/*
 * Korean
 * Byte 3 = 0x0e
 */

enum XK_Hangul = 0xff31; /* Hangul start/stop(toggle) */
enum XK_Hangul_Start = 0xff32; /* Hangul start */
enum XK_Hangul_End = 0xff33; /* Hangul end, English start */
enum XK_Hangul_Hanja = 0xff34; /* Start Hangul->Hanja Conversion */
enum XK_Hangul_Jamo = 0xff35; /* Hangul Jamo mode */
enum XK_Hangul_Romaja = 0xff36; /* Hangul Romaja mode */
enum XK_Hangul_Codeinput = 0xff37; /* Hangul code input mode */
enum XK_Hangul_Jeonja = 0xff38; /* Jeonja mode */
enum XK_Hangul_Banja = 0xff39; /* Banja mode */
enum XK_Hangul_PreHanja = 0xff3a; /* Pre Hanja conversion */
enum XK_Hangul_PostHanja = 0xff3b; /* Post Hanja conversion */
enum XK_Hangul_SingleCandidate = 0xff3c; /* Single candidate */
enum XK_Hangul_MultipleCandidate = 0xff3d; /* Multiple candidate */
enum XK_Hangul_PreviousCandidate = 0xff3e; /* Previous candidate */
enum XK_Hangul_Special = 0xff3f; /* Special symbols */
enum XK_Hangul_switch = 0xff7e; /* non-deprecated alias for Mode_switch */

/* Hangul Consonant Characters */
enum XK_Hangul_Kiyeog = 0x0ea1; /* U+3131 HANGUL LETTER KIYEOK */
enum XK_Hangul_SsangKiyeog = 0x0ea2; /* U+3132 HANGUL LETTER SSANGKIYEOK */
enum XK_Hangul_KiyeogSios = 0x0ea3; /* U+3133 HANGUL LETTER KIYEOK-SIOS */
enum XK_Hangul_Nieun = 0x0ea4; /* U+3134 HANGUL LETTER NIEUN */
enum XK_Hangul_NieunJieuj = 0x0ea5; /* U+3135 HANGUL LETTER NIEUN-CIEUC */
enum XK_Hangul_NieunHieuh = 0x0ea6; /* U+3136 HANGUL LETTER NIEUN-HIEUH */
enum XK_Hangul_Dikeud = 0x0ea7; /* U+3137 HANGUL LETTER TIKEUT */
enum XK_Hangul_SsangDikeud = 0x0ea8; /* U+3138 HANGUL LETTER SSANGTIKEUT */
enum XK_Hangul_Rieul = 0x0ea9; /* U+3139 HANGUL LETTER RIEUL */
enum XK_Hangul_RieulKiyeog = 0x0eaa; /* U+313A HANGUL LETTER RIEUL-KIYEOK */
enum XK_Hangul_RieulMieum = 0x0eab; /* U+313B HANGUL LETTER RIEUL-MIEUM */
enum XK_Hangul_RieulPieub = 0x0eac; /* U+313C HANGUL LETTER RIEUL-PIEUP */
enum XK_Hangul_RieulSios = 0x0ead; /* U+313D HANGUL LETTER RIEUL-SIOS */
enum XK_Hangul_RieulTieut = 0x0eae; /* U+313E HANGUL LETTER RIEUL-THIEUTH */
enum XK_Hangul_RieulPhieuf = 0x0eaf; /* U+313F HANGUL LETTER RIEUL-PHIEUPH */
enum XK_Hangul_RieulHieuh = 0x0eb0; /* U+3140 HANGUL LETTER RIEUL-HIEUH */
enum XK_Hangul_Mieum = 0x0eb1; /* U+3141 HANGUL LETTER MIEUM */
enum XK_Hangul_Pieub = 0x0eb2; /* U+3142 HANGUL LETTER PIEUP */
enum XK_Hangul_SsangPieub = 0x0eb3; /* U+3143 HANGUL LETTER SSANGPIEUP */
enum XK_Hangul_PieubSios = 0x0eb4; /* U+3144 HANGUL LETTER PIEUP-SIOS */
enum XK_Hangul_Sios = 0x0eb5; /* U+3145 HANGUL LETTER SIOS */
enum XK_Hangul_SsangSios = 0x0eb6; /* U+3146 HANGUL LETTER SSANGSIOS */
enum XK_Hangul_Ieung = 0x0eb7; /* U+3147 HANGUL LETTER IEUNG */
enum XK_Hangul_Jieuj = 0x0eb8; /* U+3148 HANGUL LETTER CIEUC */
enum XK_Hangul_SsangJieuj = 0x0eb9; /* U+3149 HANGUL LETTER SSANGCIEUC */
enum XK_Hangul_Cieuc = 0x0eba; /* U+314A HANGUL LETTER CHIEUCH */
enum XK_Hangul_Khieuq = 0x0ebb; /* U+314B HANGUL LETTER KHIEUKH */
enum XK_Hangul_Tieut = 0x0ebc; /* U+314C HANGUL LETTER THIEUTH */
enum XK_Hangul_Phieuf = 0x0ebd; /* U+314D HANGUL LETTER PHIEUPH */
enum XK_Hangul_Hieuh = 0x0ebe; /* U+314E HANGUL LETTER HIEUH */

/* Hangul Vowel Characters */
enum XK_Hangul_A = 0x0ebf; /* U+314F HANGUL LETTER A */
enum XK_Hangul_AE = 0x0ec0; /* U+3150 HANGUL LETTER AE */
enum XK_Hangul_YA = 0x0ec1; /* U+3151 HANGUL LETTER YA */
enum XK_Hangul_YAE = 0x0ec2; /* U+3152 HANGUL LETTER YAE */
enum XK_Hangul_EO = 0x0ec3; /* U+3153 HANGUL LETTER EO */
enum XK_Hangul_E = 0x0ec4; /* U+3154 HANGUL LETTER E */
enum XK_Hangul_YEO = 0x0ec5; /* U+3155 HANGUL LETTER YEO */
enum XK_Hangul_YE = 0x0ec6; /* U+3156 HANGUL LETTER YE */
enum XK_Hangul_O = 0x0ec7; /* U+3157 HANGUL LETTER O */
enum XK_Hangul_WA = 0x0ec8; /* U+3158 HANGUL LETTER WA */
enum XK_Hangul_WAE = 0x0ec9; /* U+3159 HANGUL LETTER WAE */
enum XK_Hangul_OE = 0x0eca; /* U+315A HANGUL LETTER OE */
enum XK_Hangul_YO = 0x0ecb; /* U+315B HANGUL LETTER YO */
enum XK_Hangul_U = 0x0ecc; /* U+315C HANGUL LETTER U */
enum XK_Hangul_WEO = 0x0ecd; /* U+315D HANGUL LETTER WEO */
enum XK_Hangul_WE = 0x0ece; /* U+315E HANGUL LETTER WE */
enum XK_Hangul_WI = 0x0ecf; /* U+315F HANGUL LETTER WI */
enum XK_Hangul_YU = 0x0ed0; /* U+3160 HANGUL LETTER YU */
enum XK_Hangul_EU = 0x0ed1; /* U+3161 HANGUL LETTER EU */
enum XK_Hangul_YI = 0x0ed2; /* U+3162 HANGUL LETTER YI */
enum XK_Hangul_I = 0x0ed3; /* U+3163 HANGUL LETTER I */

/* Hangul syllable-final (JongSeong) Characters */
enum XK_Hangul_J_Kiyeog = 0x0ed4; /* U+11A8 HANGUL JONGSEONG KIYEOK */
enum XK_Hangul_J_SsangKiyeog = 0x0ed5; /* U+11A9 HANGUL JONGSEONG SSANGKIYEOK */
enum XK_Hangul_J_KiyeogSios = 0x0ed6; /* U+11AA HANGUL JONGSEONG KIYEOK-SIOS */
enum XK_Hangul_J_Nieun = 0x0ed7; /* U+11AB HANGUL JONGSEONG NIEUN */
enum XK_Hangul_J_NieunJieuj = 0x0ed8; /* U+11AC HANGUL JONGSEONG NIEUN-CIEUC */
enum XK_Hangul_J_NieunHieuh = 0x0ed9; /* U+11AD HANGUL JONGSEONG NIEUN-HIEUH */
enum XK_Hangul_J_Dikeud = 0x0eda; /* U+11AE HANGUL JONGSEONG TIKEUT */
enum XK_Hangul_J_Rieul = 0x0edb; /* U+11AF HANGUL JONGSEONG RIEUL */
enum XK_Hangul_J_RieulKiyeog = 0x0edc; /* U+11B0 HANGUL JONGSEONG RIEUL-KIYEOK */
enum XK_Hangul_J_RieulMieum = 0x0edd; /* U+11B1 HANGUL JONGSEONG RIEUL-MIEUM */
enum XK_Hangul_J_RieulPieub = 0x0ede; /* U+11B2 HANGUL JONGSEONG RIEUL-PIEUP */
enum XK_Hangul_J_RieulSios = 0x0edf; /* U+11B3 HANGUL JONGSEONG RIEUL-SIOS */
enum XK_Hangul_J_RieulTieut = 0x0ee0; /* U+11B4 HANGUL JONGSEONG RIEUL-THIEUTH */
enum XK_Hangul_J_RieulPhieuf = 0x0ee1; /* U+11B5 HANGUL JONGSEONG RIEUL-PHIEUPH */
enum XK_Hangul_J_RieulHieuh = 0x0ee2; /* U+11B6 HANGUL JONGSEONG RIEUL-HIEUH */
enum XK_Hangul_J_Mieum = 0x0ee3; /* U+11B7 HANGUL JONGSEONG MIEUM */
enum XK_Hangul_J_Pieub = 0x0ee4; /* U+11B8 HANGUL JONGSEONG PIEUP */
enum XK_Hangul_J_PieubSios = 0x0ee5; /* U+11B9 HANGUL JONGSEONG PIEUP-SIOS */
enum XK_Hangul_J_Sios = 0x0ee6; /* U+11BA HANGUL JONGSEONG SIOS */
enum XK_Hangul_J_SsangSios = 0x0ee7; /* U+11BB HANGUL JONGSEONG SSANGSIOS */
enum XK_Hangul_J_Ieung = 0x0ee8; /* U+11BC HANGUL JONGSEONG IEUNG */
enum XK_Hangul_J_Jieuj = 0x0ee9; /* U+11BD HANGUL JONGSEONG CIEUC */
enum XK_Hangul_J_Cieuc = 0x0eea; /* U+11BE HANGUL JONGSEONG CHIEUCH */
enum XK_Hangul_J_Khieuq = 0x0eeb; /* U+11BF HANGUL JONGSEONG KHIEUKH */
enum XK_Hangul_J_Tieut = 0x0eec; /* U+11C0 HANGUL JONGSEONG THIEUTH */
enum XK_Hangul_J_Phieuf = 0x0eed; /* U+11C1 HANGUL JONGSEONG PHIEUPH */
enum XK_Hangul_J_Hieuh = 0x0eee; /* U+11C2 HANGUL JONGSEONG HIEUH */

/* Ancient Hangul Consonant Characters */
enum XK_Hangul_RieulYeorinHieuh = 0x0eef; /* U+316D HANGUL LETTER RIEUL-YEORINHIEUH */
enum XK_Hangul_SunkyeongeumMieum = 0x0ef0; /* U+3171 HANGUL LETTER KAPYEOUNMIEUM */
enum XK_Hangul_SunkyeongeumPieub = 0x0ef1; /* U+3178 HANGUL LETTER KAPYEOUNPIEUP */
enum XK_Hangul_PanSios = 0x0ef2; /* U+317F HANGUL LETTER PANSIOS */
enum XK_Hangul_KkogjiDalrinIeung = 0x0ef3; /* U+3181 HANGUL LETTER YESIEUNG */
enum XK_Hangul_SunkyeongeumPhieuf = 0x0ef4; /* U+3184 HANGUL LETTER KAPYEOUNPHIEUPH */
enum XK_Hangul_YeorinHieuh = 0x0ef5; /* U+3186 HANGUL LETTER YEORINHIEUH */

/* Ancient Hangul Vowel Characters */
enum XK_Hangul_AraeA = 0x0ef6; /* U+318D HANGUL LETTER ARAEA */
enum XK_Hangul_AraeAE = 0x0ef7; /* U+318E HANGUL LETTER ARAEAE */

/* Ancient Hangul syllable-final (JongSeong) Characters */
enum XK_Hangul_J_PanSios = 0x0ef8; /* U+11EB HANGUL JONGSEONG PANSIOS */
enum XK_Hangul_J_KkogjiDalrinIeung = 0x0ef9; /* U+11F0 HANGUL JONGSEONG YESIEUNG */
enum XK_Hangul_J_YeorinHieuh = 0x0efa; /* U+11F9 HANGUL JONGSEONG YEORINHIEUH */

/* Korean currency symbol */
enum XK_Korean_Won = 0x0eff; /*(U+20A9 WON SIGN)*/

/* XK_KOREAN */

/*
 * Armenian
 */

enum XK_Armenian_ligature_ew = 0x1000587; /* U+0587 ARMENIAN SMALL LIGATURE ECH YIWN */
enum XK_Armenian_full_stop = 0x1000589; /* U+0589 ARMENIAN FULL STOP */
enum XK_Armenian_verjaket = 0x1000589; /* deprecated alias for Armenian_full_stop */
enum XK_Armenian_separation_mark = 0x100055d; /* U+055D ARMENIAN COMMA */
enum XK_Armenian_but = 0x100055d; /* deprecated alias for Armenian_separation_mark */
enum XK_Armenian_hyphen = 0x100058a; /* U+058A ARMENIAN HYPHEN */
enum XK_Armenian_yentamna = 0x100058a; /* deprecated alias for Armenian_hyphen */
enum XK_Armenian_exclam = 0x100055c; /* U+055C ARMENIAN EXCLAMATION MARK */
enum XK_Armenian_amanak = 0x100055c; /* deprecated alias for Armenian_exclam */
enum XK_Armenian_accent = 0x100055b; /* U+055B ARMENIAN EMPHASIS MARK */
enum XK_Armenian_shesht = 0x100055b; /* deprecated alias for Armenian_accent */
enum XK_Armenian_question = 0x100055e; /* U+055E ARMENIAN QUESTION MARK */
enum XK_Armenian_paruyk = 0x100055e; /* deprecated alias for Armenian_question */
enum XK_Armenian_AYB = 0x1000531; /* U+0531 ARMENIAN CAPITAL LETTER AYB */
enum XK_Armenian_ayb = 0x1000561; /* U+0561 ARMENIAN SMALL LETTER AYB */
enum XK_Armenian_BEN = 0x1000532; /* U+0532 ARMENIAN CAPITAL LETTER BEN */
enum XK_Armenian_ben = 0x1000562; /* U+0562 ARMENIAN SMALL LETTER BEN */
enum XK_Armenian_GIM = 0x1000533; /* U+0533 ARMENIAN CAPITAL LETTER GIM */
enum XK_Armenian_gim = 0x1000563; /* U+0563 ARMENIAN SMALL LETTER GIM */
enum XK_Armenian_DA = 0x1000534; /* U+0534 ARMENIAN CAPITAL LETTER DA */
enum XK_Armenian_da = 0x1000564; /* U+0564 ARMENIAN SMALL LETTER DA */
enum XK_Armenian_YECH = 0x1000535; /* U+0535 ARMENIAN CAPITAL LETTER ECH */
enum XK_Armenian_yech = 0x1000565; /* U+0565 ARMENIAN SMALL LETTER ECH */
enum XK_Armenian_ZA = 0x1000536; /* U+0536 ARMENIAN CAPITAL LETTER ZA */
enum XK_Armenian_za = 0x1000566; /* U+0566 ARMENIAN SMALL LETTER ZA */
enum XK_Armenian_E = 0x1000537; /* U+0537 ARMENIAN CAPITAL LETTER EH */
enum XK_Armenian_e = 0x1000567; /* U+0567 ARMENIAN SMALL LETTER EH */
enum XK_Armenian_AT = 0x1000538; /* U+0538 ARMENIAN CAPITAL LETTER ET */
enum XK_Armenian_at = 0x1000568; /* U+0568 ARMENIAN SMALL LETTER ET */
enum XK_Armenian_TO = 0x1000539; /* U+0539 ARMENIAN CAPITAL LETTER TO */
enum XK_Armenian_to = 0x1000569; /* U+0569 ARMENIAN SMALL LETTER TO */
enum XK_Armenian_ZHE = 0x100053a; /* U+053A ARMENIAN CAPITAL LETTER ZHE */
enum XK_Armenian_zhe = 0x100056a; /* U+056A ARMENIAN SMALL LETTER ZHE */
enum XK_Armenian_INI = 0x100053b; /* U+053B ARMENIAN CAPITAL LETTER INI */
enum XK_Armenian_ini = 0x100056b; /* U+056B ARMENIAN SMALL LETTER INI */
enum XK_Armenian_LYUN = 0x100053c; /* U+053C ARMENIAN CAPITAL LETTER LIWN */
enum XK_Armenian_lyun = 0x100056c; /* U+056C ARMENIAN SMALL LETTER LIWN */
enum XK_Armenian_KHE = 0x100053d; /* U+053D ARMENIAN CAPITAL LETTER XEH */
enum XK_Armenian_khe = 0x100056d; /* U+056D ARMENIAN SMALL LETTER XEH */
enum XK_Armenian_TSA = 0x100053e; /* U+053E ARMENIAN CAPITAL LETTER CA */
enum XK_Armenian_tsa = 0x100056e; /* U+056E ARMENIAN SMALL LETTER CA */
enum XK_Armenian_KEN = 0x100053f; /* U+053F ARMENIAN CAPITAL LETTER KEN */
enum XK_Armenian_ken = 0x100056f; /* U+056F ARMENIAN SMALL LETTER KEN */
enum XK_Armenian_HO = 0x1000540; /* U+0540 ARMENIAN CAPITAL LETTER HO */
enum XK_Armenian_ho = 0x1000570; /* U+0570 ARMENIAN SMALL LETTER HO */
enum XK_Armenian_DZA = 0x1000541; /* U+0541 ARMENIAN CAPITAL LETTER JA */
enum XK_Armenian_dza = 0x1000571; /* U+0571 ARMENIAN SMALL LETTER JA */
enum XK_Armenian_GHAT = 0x1000542; /* U+0542 ARMENIAN CAPITAL LETTER GHAD */
enum XK_Armenian_ghat = 0x1000572; /* U+0572 ARMENIAN SMALL LETTER GHAD */
enum XK_Armenian_TCHE = 0x1000543; /* U+0543 ARMENIAN CAPITAL LETTER CHEH */
enum XK_Armenian_tche = 0x1000573; /* U+0573 ARMENIAN SMALL LETTER CHEH */
enum XK_Armenian_MEN = 0x1000544; /* U+0544 ARMENIAN CAPITAL LETTER MEN */
enum XK_Armenian_men = 0x1000574; /* U+0574 ARMENIAN SMALL LETTER MEN */
enum XK_Armenian_HI = 0x1000545; /* U+0545 ARMENIAN CAPITAL LETTER YI */
enum XK_Armenian_hi = 0x1000575; /* U+0575 ARMENIAN SMALL LETTER YI */
enum XK_Armenian_NU = 0x1000546; /* U+0546 ARMENIAN CAPITAL LETTER NOW */
enum XK_Armenian_nu = 0x1000576; /* U+0576 ARMENIAN SMALL LETTER NOW */
enum XK_Armenian_SHA = 0x1000547; /* U+0547 ARMENIAN CAPITAL LETTER SHA */
enum XK_Armenian_sha = 0x1000577; /* U+0577 ARMENIAN SMALL LETTER SHA */
enum XK_Armenian_VO = 0x1000548; /* U+0548 ARMENIAN CAPITAL LETTER VO */
enum XK_Armenian_vo = 0x1000578; /* U+0578 ARMENIAN SMALL LETTER VO */
enum XK_Armenian_CHA = 0x1000549; /* U+0549 ARMENIAN CAPITAL LETTER CHA */
enum XK_Armenian_cha = 0x1000579; /* U+0579 ARMENIAN SMALL LETTER CHA */
enum XK_Armenian_PE = 0x100054a; /* U+054A ARMENIAN CAPITAL LETTER PEH */
enum XK_Armenian_pe = 0x100057a; /* U+057A ARMENIAN SMALL LETTER PEH */
enum XK_Armenian_JE = 0x100054b; /* U+054B ARMENIAN CAPITAL LETTER JHEH */
enum XK_Armenian_je = 0x100057b; /* U+057B ARMENIAN SMALL LETTER JHEH */
enum XK_Armenian_RA = 0x100054c; /* U+054C ARMENIAN CAPITAL LETTER RA */
enum XK_Armenian_ra = 0x100057c; /* U+057C ARMENIAN SMALL LETTER RA */
enum XK_Armenian_SE = 0x100054d; /* U+054D ARMENIAN CAPITAL LETTER SEH */
enum XK_Armenian_se = 0x100057d; /* U+057D ARMENIAN SMALL LETTER SEH */
enum XK_Armenian_VEV = 0x100054e; /* U+054E ARMENIAN CAPITAL LETTER VEW */
enum XK_Armenian_vev = 0x100057e; /* U+057E ARMENIAN SMALL LETTER VEW */
enum XK_Armenian_TYUN = 0x100054f; /* U+054F ARMENIAN CAPITAL LETTER TIWN */
enum XK_Armenian_tyun = 0x100057f; /* U+057F ARMENIAN SMALL LETTER TIWN */
enum XK_Armenian_RE = 0x1000550; /* U+0550 ARMENIAN CAPITAL LETTER REH */
enum XK_Armenian_re = 0x1000580; /* U+0580 ARMENIAN SMALL LETTER REH */
enum XK_Armenian_TSO = 0x1000551; /* U+0551 ARMENIAN CAPITAL LETTER CO */
enum XK_Armenian_tso = 0x1000581; /* U+0581 ARMENIAN SMALL LETTER CO */
enum XK_Armenian_VYUN = 0x1000552; /* U+0552 ARMENIAN CAPITAL LETTER YIWN */
enum XK_Armenian_vyun = 0x1000582; /* U+0582 ARMENIAN SMALL LETTER YIWN */
enum XK_Armenian_PYUR = 0x1000553; /* U+0553 ARMENIAN CAPITAL LETTER PIWR */
enum XK_Armenian_pyur = 0x1000583; /* U+0583 ARMENIAN SMALL LETTER PIWR */
enum XK_Armenian_KE = 0x1000554; /* U+0554 ARMENIAN CAPITAL LETTER KEH */
enum XK_Armenian_ke = 0x1000584; /* U+0584 ARMENIAN SMALL LETTER KEH */
enum XK_Armenian_O = 0x1000555; /* U+0555 ARMENIAN CAPITAL LETTER OH */
enum XK_Armenian_o = 0x1000585; /* U+0585 ARMENIAN SMALL LETTER OH */
enum XK_Armenian_FE = 0x1000556; /* U+0556 ARMENIAN CAPITAL LETTER FEH */
enum XK_Armenian_fe = 0x1000586; /* U+0586 ARMENIAN SMALL LETTER FEH */
enum XK_Armenian_apostrophe = 0x100055a; /* U+055A ARMENIAN APOSTROPHE */
/* XK_ARMENIAN */

/*
 * Georgian
 */

enum XK_Georgian_an = 0x10010d0; /* U+10D0 GEORGIAN LETTER AN */
enum XK_Georgian_ban = 0x10010d1; /* U+10D1 GEORGIAN LETTER BAN */
enum XK_Georgian_gan = 0x10010d2; /* U+10D2 GEORGIAN LETTER GAN */
enum XK_Georgian_don = 0x10010d3; /* U+10D3 GEORGIAN LETTER DON */
enum XK_Georgian_en = 0x10010d4; /* U+10D4 GEORGIAN LETTER EN */
enum XK_Georgian_vin = 0x10010d5; /* U+10D5 GEORGIAN LETTER VIN */
enum XK_Georgian_zen = 0x10010d6; /* U+10D6 GEORGIAN LETTER ZEN */
enum XK_Georgian_tan = 0x10010d7; /* U+10D7 GEORGIAN LETTER TAN */
enum XK_Georgian_in = 0x10010d8; /* U+10D8 GEORGIAN LETTER IN */
enum XK_Georgian_kan = 0x10010d9; /* U+10D9 GEORGIAN LETTER KAN */
enum XK_Georgian_las = 0x10010da; /* U+10DA GEORGIAN LETTER LAS */
enum XK_Georgian_man = 0x10010db; /* U+10DB GEORGIAN LETTER MAN */
enum XK_Georgian_nar = 0x10010dc; /* U+10DC GEORGIAN LETTER NAR */
enum XK_Georgian_on = 0x10010dd; /* U+10DD GEORGIAN LETTER ON */
enum XK_Georgian_par = 0x10010de; /* U+10DE GEORGIAN LETTER PAR */
enum XK_Georgian_zhar = 0x10010df; /* U+10DF GEORGIAN LETTER ZHAR */
enum XK_Georgian_rae = 0x10010e0; /* U+10E0 GEORGIAN LETTER RAE */
enum XK_Georgian_san = 0x10010e1; /* U+10E1 GEORGIAN LETTER SAN */
enum XK_Georgian_tar = 0x10010e2; /* U+10E2 GEORGIAN LETTER TAR */
enum XK_Georgian_un = 0x10010e3; /* U+10E3 GEORGIAN LETTER UN */
enum XK_Georgian_phar = 0x10010e4; /* U+10E4 GEORGIAN LETTER PHAR */
enum XK_Georgian_khar = 0x10010e5; /* U+10E5 GEORGIAN LETTER KHAR */
enum XK_Georgian_ghan = 0x10010e6; /* U+10E6 GEORGIAN LETTER GHAN */
enum XK_Georgian_qar = 0x10010e7; /* U+10E7 GEORGIAN LETTER QAR */
enum XK_Georgian_shin = 0x10010e8; /* U+10E8 GEORGIAN LETTER SHIN */
enum XK_Georgian_chin = 0x10010e9; /* U+10E9 GEORGIAN LETTER CHIN */
enum XK_Georgian_can = 0x10010ea; /* U+10EA GEORGIAN LETTER CAN */
enum XK_Georgian_jil = 0x10010eb; /* U+10EB GEORGIAN LETTER JIL */
enum XK_Georgian_cil = 0x10010ec; /* U+10EC GEORGIAN LETTER CIL */
enum XK_Georgian_char = 0x10010ed; /* U+10ED GEORGIAN LETTER CHAR */
enum XK_Georgian_xan = 0x10010ee; /* U+10EE GEORGIAN LETTER XAN */
enum XK_Georgian_jhan = 0x10010ef; /* U+10EF GEORGIAN LETTER JHAN */
enum XK_Georgian_hae = 0x10010f0; /* U+10F0 GEORGIAN LETTER HAE */
enum XK_Georgian_he = 0x10010f1; /* U+10F1 GEORGIAN LETTER HE */
enum XK_Georgian_hie = 0x10010f2; /* U+10F2 GEORGIAN LETTER HIE */
enum XK_Georgian_we = 0x10010f3; /* U+10F3 GEORGIAN LETTER WE */
enum XK_Georgian_har = 0x10010f4; /* U+10F4 GEORGIAN LETTER HAR */
enum XK_Georgian_hoe = 0x10010f5; /* U+10F5 GEORGIAN LETTER HOE */
enum XK_Georgian_fi = 0x10010f6; /* U+10F6 GEORGIAN LETTER FI */
/* XK_GEORGIAN */

/*
 * Azeri (and other Turkic or Caucasian languages)
 */

/* latin */
enum XK_Xabovedot = 0x1001e8a; /* U+1E8A LATIN CAPITAL LETTER X WITH DOT ABOVE */
enum XK_Ibreve = 0x100012c; /* U+012C LATIN CAPITAL LETTER I WITH BREVE */
enum XK_Zstroke = 0x10001b5; /* U+01B5 LATIN CAPITAL LETTER Z WITH STROKE */
enum XK_Gcaron = 0x10001e6; /* U+01E6 LATIN CAPITAL LETTER G WITH CARON */
enum XK_Ocaron = 0x10001d1; /* U+01D1 LATIN CAPITAL LETTER O WITH CARON */
enum XK_Obarred = 0x100019f; /* U+019F LATIN CAPITAL LETTER O WITH MIDDLE TILDE */
enum XK_xabovedot = 0x1001e8b; /* U+1E8B LATIN SMALL LETTER X WITH DOT ABOVE */
enum XK_ibreve = 0x100012d; /* U+012D LATIN SMALL LETTER I WITH BREVE */
enum XK_zstroke = 0x10001b6; /* U+01B6 LATIN SMALL LETTER Z WITH STROKE */
enum XK_gcaron = 0x10001e7; /* U+01E7 LATIN SMALL LETTER G WITH CARON */
enum XK_ocaron = 0x10001d2; /* U+01D2 LATIN SMALL LETTER O WITH CARON */
enum XK_obarred = 0x1000275; /* U+0275 LATIN SMALL LETTER BARRED O */
enum XK_SCHWA = 0x100018f; /* U+018F LATIN CAPITAL LETTER SCHWA */
enum XK_schwa = 0x1000259; /* U+0259 LATIN SMALL LETTER SCHWA */
enum XK_EZH = 0x10001b7; /* U+01B7 LATIN CAPITAL LETTER EZH */
enum XK_ezh = 0x1000292; /* U+0292 LATIN SMALL LETTER EZH */
/* those are not really Caucasus */
/* For Inupiak */
enum XK_Lbelowdot = 0x1001e36; /* U+1E36 LATIN CAPITAL LETTER L WITH DOT BELOW */
enum XK_lbelowdot = 0x1001e37; /* U+1E37 LATIN SMALL LETTER L WITH DOT BELOW */
/* XK_CAUCASUS */

/*
 * Vietnamese
 */

enum XK_Abelowdot = 0x1001ea0; /* U+1EA0 LATIN CAPITAL LETTER A WITH DOT BELOW */
enum XK_abelowdot = 0x1001ea1; /* U+1EA1 LATIN SMALL LETTER A WITH DOT BELOW */
enum XK_Ahook = 0x1001ea2; /* U+1EA2 LATIN CAPITAL LETTER A WITH HOOK ABOVE */
enum XK_ahook = 0x1001ea3; /* U+1EA3 LATIN SMALL LETTER A WITH HOOK ABOVE */
enum XK_Acircumflexacute = 0x1001ea4; /* U+1EA4 LATIN CAPITAL LETTER A WITH CIRCUMFLEX AND ACUTE */
enum XK_acircumflexacute = 0x1001ea5; /* U+1EA5 LATIN SMALL LETTER A WITH CIRCUMFLEX AND ACUTE */
enum XK_Acircumflexgrave = 0x1001ea6; /* U+1EA6 LATIN CAPITAL LETTER A WITH CIRCUMFLEX AND GRAVE */
enum XK_acircumflexgrave = 0x1001ea7; /* U+1EA7 LATIN SMALL LETTER A WITH CIRCUMFLEX AND GRAVE */
enum XK_Acircumflexhook = 0x1001ea8; /* U+1EA8 LATIN CAPITAL LETTER A WITH CIRCUMFLEX AND HOOK ABOVE */
enum XK_acircumflexhook = 0x1001ea9; /* U+1EA9 LATIN SMALL LETTER A WITH CIRCUMFLEX AND HOOK ABOVE */
enum XK_Acircumflextilde = 0x1001eaa; /* U+1EAA LATIN CAPITAL LETTER A WITH CIRCUMFLEX AND TILDE */
enum XK_acircumflextilde = 0x1001eab; /* U+1EAB LATIN SMALL LETTER A WITH CIRCUMFLEX AND TILDE */
enum XK_Acircumflexbelowdot = 0x1001eac; /* U+1EAC LATIN CAPITAL LETTER A WITH CIRCUMFLEX AND DOT BELOW */
enum XK_acircumflexbelowdot = 0x1001ead; /* U+1EAD LATIN SMALL LETTER A WITH CIRCUMFLEX AND DOT BELOW */
enum XK_Abreveacute = 0x1001eae; /* U+1EAE LATIN CAPITAL LETTER A WITH BREVE AND ACUTE */
enum XK_abreveacute = 0x1001eaf; /* U+1EAF LATIN SMALL LETTER A WITH BREVE AND ACUTE */
enum XK_Abrevegrave = 0x1001eb0; /* U+1EB0 LATIN CAPITAL LETTER A WITH BREVE AND GRAVE */
enum XK_abrevegrave = 0x1001eb1; /* U+1EB1 LATIN SMALL LETTER A WITH BREVE AND GRAVE */
enum XK_Abrevehook = 0x1001eb2; /* U+1EB2 LATIN CAPITAL LETTER A WITH BREVE AND HOOK ABOVE */
enum XK_abrevehook = 0x1001eb3; /* U+1EB3 LATIN SMALL LETTER A WITH BREVE AND HOOK ABOVE */
enum XK_Abrevetilde = 0x1001eb4; /* U+1EB4 LATIN CAPITAL LETTER A WITH BREVE AND TILDE */
enum XK_abrevetilde = 0x1001eb5; /* U+1EB5 LATIN SMALL LETTER A WITH BREVE AND TILDE */
enum XK_Abrevebelowdot = 0x1001eb6; /* U+1EB6 LATIN CAPITAL LETTER A WITH BREVE AND DOT BELOW */
enum XK_abrevebelowdot = 0x1001eb7; /* U+1EB7 LATIN SMALL LETTER A WITH BREVE AND DOT BELOW */
enum XK_Ebelowdot = 0x1001eb8; /* U+1EB8 LATIN CAPITAL LETTER E WITH DOT BELOW */
enum XK_ebelowdot = 0x1001eb9; /* U+1EB9 LATIN SMALL LETTER E WITH DOT BELOW */
enum XK_Ehook = 0x1001eba; /* U+1EBA LATIN CAPITAL LETTER E WITH HOOK ABOVE */
enum XK_ehook = 0x1001ebb; /* U+1EBB LATIN SMALL LETTER E WITH HOOK ABOVE */
enum XK_Etilde = 0x1001ebc; /* U+1EBC LATIN CAPITAL LETTER E WITH TILDE */
enum XK_etilde = 0x1001ebd; /* U+1EBD LATIN SMALL LETTER E WITH TILDE */
enum XK_Ecircumflexacute = 0x1001ebe; /* U+1EBE LATIN CAPITAL LETTER E WITH CIRCUMFLEX AND ACUTE */
enum XK_ecircumflexacute = 0x1001ebf; /* U+1EBF LATIN SMALL LETTER E WITH CIRCUMFLEX AND ACUTE */
enum XK_Ecircumflexgrave = 0x1001ec0; /* U+1EC0 LATIN CAPITAL LETTER E WITH CIRCUMFLEX AND GRAVE */
enum XK_ecircumflexgrave = 0x1001ec1; /* U+1EC1 LATIN SMALL LETTER E WITH CIRCUMFLEX AND GRAVE */
enum XK_Ecircumflexhook = 0x1001ec2; /* U+1EC2 LATIN CAPITAL LETTER E WITH CIRCUMFLEX AND HOOK ABOVE */
enum XK_ecircumflexhook = 0x1001ec3; /* U+1EC3 LATIN SMALL LETTER E WITH CIRCUMFLEX AND HOOK ABOVE */
enum XK_Ecircumflextilde = 0x1001ec4; /* U+1EC4 LATIN CAPITAL LETTER E WITH CIRCUMFLEX AND TILDE */
enum XK_ecircumflextilde = 0x1001ec5; /* U+1EC5 LATIN SMALL LETTER E WITH CIRCUMFLEX AND TILDE */
enum XK_Ecircumflexbelowdot = 0x1001ec6; /* U+1EC6 LATIN CAPITAL LETTER E WITH CIRCUMFLEX AND DOT BELOW */
enum XK_ecircumflexbelowdot = 0x1001ec7; /* U+1EC7 LATIN SMALL LETTER E WITH CIRCUMFLEX AND DOT BELOW */
enum XK_Ihook = 0x1001ec8; /* U+1EC8 LATIN CAPITAL LETTER I WITH HOOK ABOVE */
enum XK_ihook = 0x1001ec9; /* U+1EC9 LATIN SMALL LETTER I WITH HOOK ABOVE */
enum XK_Ibelowdot = 0x1001eca; /* U+1ECA LATIN CAPITAL LETTER I WITH DOT BELOW */
enum XK_ibelowdot = 0x1001ecb; /* U+1ECB LATIN SMALL LETTER I WITH DOT BELOW */
enum XK_Obelowdot = 0x1001ecc; /* U+1ECC LATIN CAPITAL LETTER O WITH DOT BELOW */
enum XK_obelowdot = 0x1001ecd; /* U+1ECD LATIN SMALL LETTER O WITH DOT BELOW */
enum XK_Ohook = 0x1001ece; /* U+1ECE LATIN CAPITAL LETTER O WITH HOOK ABOVE */
enum XK_ohook = 0x1001ecf; /* U+1ECF LATIN SMALL LETTER O WITH HOOK ABOVE */
enum XK_Ocircumflexacute = 0x1001ed0; /* U+1ED0 LATIN CAPITAL LETTER O WITH CIRCUMFLEX AND ACUTE */
enum XK_ocircumflexacute = 0x1001ed1; /* U+1ED1 LATIN SMALL LETTER O WITH CIRCUMFLEX AND ACUTE */
enum XK_Ocircumflexgrave = 0x1001ed2; /* U+1ED2 LATIN CAPITAL LETTER O WITH CIRCUMFLEX AND GRAVE */
enum XK_ocircumflexgrave = 0x1001ed3; /* U+1ED3 LATIN SMALL LETTER O WITH CIRCUMFLEX AND GRAVE */
enum XK_Ocircumflexhook = 0x1001ed4; /* U+1ED4 LATIN CAPITAL LETTER O WITH CIRCUMFLEX AND HOOK ABOVE */
enum XK_ocircumflexhook = 0x1001ed5; /* U+1ED5 LATIN SMALL LETTER O WITH CIRCUMFLEX AND HOOK ABOVE */
enum XK_Ocircumflextilde = 0x1001ed6; /* U+1ED6 LATIN CAPITAL LETTER O WITH CIRCUMFLEX AND TILDE */
enum XK_ocircumflextilde = 0x1001ed7; /* U+1ED7 LATIN SMALL LETTER O WITH CIRCUMFLEX AND TILDE */
enum XK_Ocircumflexbelowdot = 0x1001ed8; /* U+1ED8 LATIN CAPITAL LETTER O WITH CIRCUMFLEX AND DOT BELOW */
enum XK_ocircumflexbelowdot = 0x1001ed9; /* U+1ED9 LATIN SMALL LETTER O WITH CIRCUMFLEX AND DOT BELOW */
enum XK_Ohornacute = 0x1001eda; /* U+1EDA LATIN CAPITAL LETTER O WITH HORN AND ACUTE */
enum XK_ohornacute = 0x1001edb; /* U+1EDB LATIN SMALL LETTER O WITH HORN AND ACUTE */
enum XK_Ohorngrave = 0x1001edc; /* U+1EDC LATIN CAPITAL LETTER O WITH HORN AND GRAVE */
enum XK_ohorngrave = 0x1001edd; /* U+1EDD LATIN SMALL LETTER O WITH HORN AND GRAVE */
enum XK_Ohornhook = 0x1001ede; /* U+1EDE LATIN CAPITAL LETTER O WITH HORN AND HOOK ABOVE */
enum XK_ohornhook = 0x1001edf; /* U+1EDF LATIN SMALL LETTER O WITH HORN AND HOOK ABOVE */
enum XK_Ohorntilde = 0x1001ee0; /* U+1EE0 LATIN CAPITAL LETTER O WITH HORN AND TILDE */
enum XK_ohorntilde = 0x1001ee1; /* U+1EE1 LATIN SMALL LETTER O WITH HORN AND TILDE */
enum XK_Ohornbelowdot = 0x1001ee2; /* U+1EE2 LATIN CAPITAL LETTER O WITH HORN AND DOT BELOW */
enum XK_ohornbelowdot = 0x1001ee3; /* U+1EE3 LATIN SMALL LETTER O WITH HORN AND DOT BELOW */
enum XK_Ubelowdot = 0x1001ee4; /* U+1EE4 LATIN CAPITAL LETTER U WITH DOT BELOW */
enum XK_ubelowdot = 0x1001ee5; /* U+1EE5 LATIN SMALL LETTER U WITH DOT BELOW */
enum XK_Uhook = 0x1001ee6; /* U+1EE6 LATIN CAPITAL LETTER U WITH HOOK ABOVE */
enum XK_uhook = 0x1001ee7; /* U+1EE7 LATIN SMALL LETTER U WITH HOOK ABOVE */
enum XK_Uhornacute = 0x1001ee8; /* U+1EE8 LATIN CAPITAL LETTER U WITH HORN AND ACUTE */
enum XK_uhornacute = 0x1001ee9; /* U+1EE9 LATIN SMALL LETTER U WITH HORN AND ACUTE */
enum XK_Uhorngrave = 0x1001eea; /* U+1EEA LATIN CAPITAL LETTER U WITH HORN AND GRAVE */
enum XK_uhorngrave = 0x1001eeb; /* U+1EEB LATIN SMALL LETTER U WITH HORN AND GRAVE */
enum XK_Uhornhook = 0x1001eec; /* U+1EEC LATIN CAPITAL LETTER U WITH HORN AND HOOK ABOVE */
enum XK_uhornhook = 0x1001eed; /* U+1EED LATIN SMALL LETTER U WITH HORN AND HOOK ABOVE */
enum XK_Uhorntilde = 0x1001eee; /* U+1EEE LATIN CAPITAL LETTER U WITH HORN AND TILDE */
enum XK_uhorntilde = 0x1001eef; /* U+1EEF LATIN SMALL LETTER U WITH HORN AND TILDE */
enum XK_Uhornbelowdot = 0x1001ef0; /* U+1EF0 LATIN CAPITAL LETTER U WITH HORN AND DOT BELOW */
enum XK_uhornbelowdot = 0x1001ef1; /* U+1EF1 LATIN SMALL LETTER U WITH HORN AND DOT BELOW */
enum XK_Ybelowdot = 0x1001ef4; /* U+1EF4 LATIN CAPITAL LETTER Y WITH DOT BELOW */
enum XK_ybelowdot = 0x1001ef5; /* U+1EF5 LATIN SMALL LETTER Y WITH DOT BELOW */
enum XK_Yhook = 0x1001ef6; /* U+1EF6 LATIN CAPITAL LETTER Y WITH HOOK ABOVE */
enum XK_yhook = 0x1001ef7; /* U+1EF7 LATIN SMALL LETTER Y WITH HOOK ABOVE */
enum XK_Ytilde = 0x1001ef8; /* U+1EF8 LATIN CAPITAL LETTER Y WITH TILDE */
enum XK_ytilde = 0x1001ef9; /* U+1EF9 LATIN SMALL LETTER Y WITH TILDE */
enum XK_Ohorn = 0x10001a0; /* U+01A0 LATIN CAPITAL LETTER O WITH HORN */
enum XK_ohorn = 0x10001a1; /* U+01A1 LATIN SMALL LETTER O WITH HORN */
enum XK_Uhorn = 0x10001af; /* U+01AF LATIN CAPITAL LETTER U WITH HORN */
enum XK_uhorn = 0x10001b0; /* U+01B0 LATIN SMALL LETTER U WITH HORN */
enum XK_combining_tilde = 0x1000303; /* U+0303 COMBINING TILDE */
enum XK_combining_grave = 0x1000300; /* U+0300 COMBINING GRAVE ACCENT */
enum XK_combining_acute = 0x1000301; /* U+0301 COMBINING ACUTE ACCENT */
enum XK_combining_hook = 0x1000309; /* U+0309 COMBINING HOOK ABOVE */
enum XK_combining_belowdot = 0x1000323; /* U+0323 COMBINING DOT BELOW */

/* XK_VIETNAMESE */

enum XK_EcuSign = 0x10020a0; /* U+20A0 EURO-CURRENCY SIGN */
enum XK_ColonSign = 0x10020a1; /* U+20A1 COLON SIGN */
enum XK_CruzeiroSign = 0x10020a2; /* U+20A2 CRUZEIRO SIGN */
enum XK_FFrancSign = 0x10020a3; /* U+20A3 FRENCH FRANC SIGN */
enum XK_LiraSign = 0x10020a4; /* U+20A4 LIRA SIGN */
enum XK_MillSign = 0x10020a5; /* U+20A5 MILL SIGN */
enum XK_NairaSign = 0x10020a6; /* U+20A6 NAIRA SIGN */
enum XK_PesetaSign = 0x10020a7; /* U+20A7 PESETA SIGN */
enum XK_RupeeSign = 0x10020a8; /* U+20A8 RUPEE SIGN */
enum XK_WonSign = 0x10020a9; /* U+20A9 WON SIGN */
enum XK_NewSheqelSign = 0x10020aa; /* U+20AA NEW SHEQEL SIGN */
enum XK_DongSign = 0x10020ab; /* U+20AB DONG SIGN */
enum XK_EuroSign = 0x20ac; /* U+20AC EURO SIGN */
/* XK_CURRENCY */

/* one, two and three are defined above. */
enum XK_zerosuperior = 0x1002070; /* U+2070 SUPERSCRIPT ZERO */
enum XK_foursuperior = 0x1002074; /* U+2074 SUPERSCRIPT FOUR */
enum XK_fivesuperior = 0x1002075; /* U+2075 SUPERSCRIPT FIVE */
enum XK_sixsuperior = 0x1002076; /* U+2076 SUPERSCRIPT SIX */
enum XK_sevensuperior = 0x1002077; /* U+2077 SUPERSCRIPT SEVEN */
enum XK_eightsuperior = 0x1002078; /* U+2078 SUPERSCRIPT EIGHT */
enum XK_ninesuperior = 0x1002079; /* U+2079 SUPERSCRIPT NINE */
enum XK_zerosubscript = 0x1002080; /* U+2080 SUBSCRIPT ZERO */
enum XK_onesubscript = 0x1002081; /* U+2081 SUBSCRIPT ONE */
enum XK_twosubscript = 0x1002082; /* U+2082 SUBSCRIPT TWO */
enum XK_threesubscript = 0x1002083; /* U+2083 SUBSCRIPT THREE */
enum XK_foursubscript = 0x1002084; /* U+2084 SUBSCRIPT FOUR */
enum XK_fivesubscript = 0x1002085; /* U+2085 SUBSCRIPT FIVE */
enum XK_sixsubscript = 0x1002086; /* U+2086 SUBSCRIPT SIX */
enum XK_sevensubscript = 0x1002087; /* U+2087 SUBSCRIPT SEVEN */
enum XK_eightsubscript = 0x1002088; /* U+2088 SUBSCRIPT EIGHT */
enum XK_ninesubscript = 0x1002089; /* U+2089 SUBSCRIPT NINE */
enum XK_partdifferential = 0x1002202; /* U+2202 PARTIAL DIFFERENTIAL */
enum XK_emptyset = 0x1002205; /* U+2205 EMPTY SET */
enum XK_elementof = 0x1002208; /* U+2208 ELEMENT OF */
enum XK_notelementof = 0x1002209; /* U+2209 NOT AN ELEMENT OF */
enum XK_containsas = 0x100220b; /* U+220B CONTAINS AS MEMBER */
enum XK_squareroot = 0x100221a; /* U+221A SQUARE ROOT */
enum XK_cuberoot = 0x100221b; /* U+221B CUBE ROOT */
enum XK_fourthroot = 0x100221c; /* U+221C FOURTH ROOT */
enum XK_dintegral = 0x100222c; /* U+222C DOUBLE INTEGRAL */
enum XK_tintegral = 0x100222d; /* U+222D TRIPLE INTEGRAL */
enum XK_because = 0x1002235; /* U+2235 BECAUSE */
enum XK_approxeq = 0x1002248; /*(U+2248 ALMOST EQUAL TO)*/
enum XK_notapproxeq = 0x1002247; /*(U+2247 NEITHER APPROXIMATELY NOR ACTUALLY EQUAL TO)*/
enum XK_notidentical = 0x1002262; /* U+2262 NOT IDENTICAL TO */
enum XK_stricteq = 0x1002263; /* U+2263 STRICTLY EQUIVALENT TO */
/* XK_MATHEMATICAL */

enum XK_braille_dot_1 = 0xfff1;
enum XK_braille_dot_2 = 0xfff2;
enum XK_braille_dot_3 = 0xfff3;
enum XK_braille_dot_4 = 0xfff4;
enum XK_braille_dot_5 = 0xfff5;
enum XK_braille_dot_6 = 0xfff6;
enum XK_braille_dot_7 = 0xfff7;
enum XK_braille_dot_8 = 0xfff8;
enum XK_braille_dot_9 = 0xfff9;
enum XK_braille_dot_10 = 0xfffa;
enum XK_braille_blank = 0x1002800; /* U+2800 BRAILLE PATTERN BLANK */
enum XK_braille_dots_1 = 0x1002801; /* U+2801 BRAILLE PATTERN DOTS-1 */
enum XK_braille_dots_2 = 0x1002802; /* U+2802 BRAILLE PATTERN DOTS-2 */
enum XK_braille_dots_12 = 0x1002803; /* U+2803 BRAILLE PATTERN DOTS-12 */
enum XK_braille_dots_3 = 0x1002804; /* U+2804 BRAILLE PATTERN DOTS-3 */
enum XK_braille_dots_13 = 0x1002805; /* U+2805 BRAILLE PATTERN DOTS-13 */
enum XK_braille_dots_23 = 0x1002806; /* U+2806 BRAILLE PATTERN DOTS-23 */
enum XK_braille_dots_123 = 0x1002807; /* U+2807 BRAILLE PATTERN DOTS-123 */
enum XK_braille_dots_4 = 0x1002808; /* U+2808 BRAILLE PATTERN DOTS-4 */
enum XK_braille_dots_14 = 0x1002809; /* U+2809 BRAILLE PATTERN DOTS-14 */
enum XK_braille_dots_24 = 0x100280a; /* U+280A BRAILLE PATTERN DOTS-24 */
enum XK_braille_dots_124 = 0x100280b; /* U+280B BRAILLE PATTERN DOTS-124 */
enum XK_braille_dots_34 = 0x100280c; /* U+280C BRAILLE PATTERN DOTS-34 */
enum XK_braille_dots_134 = 0x100280d; /* U+280D BRAILLE PATTERN DOTS-134 */
enum XK_braille_dots_234 = 0x100280e; /* U+280E BRAILLE PATTERN DOTS-234 */
enum XK_braille_dots_1234 = 0x100280f; /* U+280F BRAILLE PATTERN DOTS-1234 */
enum XK_braille_dots_5 = 0x1002810; /* U+2810 BRAILLE PATTERN DOTS-5 */
enum XK_braille_dots_15 = 0x1002811; /* U+2811 BRAILLE PATTERN DOTS-15 */
enum XK_braille_dots_25 = 0x1002812; /* U+2812 BRAILLE PATTERN DOTS-25 */
enum XK_braille_dots_125 = 0x1002813; /* U+2813 BRAILLE PATTERN DOTS-125 */
enum XK_braille_dots_35 = 0x1002814; /* U+2814 BRAILLE PATTERN DOTS-35 */
enum XK_braille_dots_135 = 0x1002815; /* U+2815 BRAILLE PATTERN DOTS-135 */
enum XK_braille_dots_235 = 0x1002816; /* U+2816 BRAILLE PATTERN DOTS-235 */
enum XK_braille_dots_1235 = 0x1002817; /* U+2817 BRAILLE PATTERN DOTS-1235 */
enum XK_braille_dots_45 = 0x1002818; /* U+2818 BRAILLE PATTERN DOTS-45 */
enum XK_braille_dots_145 = 0x1002819; /* U+2819 BRAILLE PATTERN DOTS-145 */
enum XK_braille_dots_245 = 0x100281a; /* U+281A BRAILLE PATTERN DOTS-245 */
enum XK_braille_dots_1245 = 0x100281b; /* U+281B BRAILLE PATTERN DOTS-1245 */
enum XK_braille_dots_345 = 0x100281c; /* U+281C BRAILLE PATTERN DOTS-345 */
enum XK_braille_dots_1345 = 0x100281d; /* U+281D BRAILLE PATTERN DOTS-1345 */
enum XK_braille_dots_2345 = 0x100281e; /* U+281E BRAILLE PATTERN DOTS-2345 */
enum XK_braille_dots_12345 = 0x100281f; /* U+281F BRAILLE PATTERN DOTS-12345 */
enum XK_braille_dots_6 = 0x1002820; /* U+2820 BRAILLE PATTERN DOTS-6 */
enum XK_braille_dots_16 = 0x1002821; /* U+2821 BRAILLE PATTERN DOTS-16 */
enum XK_braille_dots_26 = 0x1002822; /* U+2822 BRAILLE PATTERN DOTS-26 */
enum XK_braille_dots_126 = 0x1002823; /* U+2823 BRAILLE PATTERN DOTS-126 */
enum XK_braille_dots_36 = 0x1002824; /* U+2824 BRAILLE PATTERN DOTS-36 */
enum XK_braille_dots_136 = 0x1002825; /* U+2825 BRAILLE PATTERN DOTS-136 */
enum XK_braille_dots_236 = 0x1002826; /* U+2826 BRAILLE PATTERN DOTS-236 */
enum XK_braille_dots_1236 = 0x1002827; /* U+2827 BRAILLE PATTERN DOTS-1236 */
enum XK_braille_dots_46 = 0x1002828; /* U+2828 BRAILLE PATTERN DOTS-46 */
enum XK_braille_dots_146 = 0x1002829; /* U+2829 BRAILLE PATTERN DOTS-146 */
enum XK_braille_dots_246 = 0x100282a; /* U+282A BRAILLE PATTERN DOTS-246 */
enum XK_braille_dots_1246 = 0x100282b; /* U+282B BRAILLE PATTERN DOTS-1246 */
enum XK_braille_dots_346 = 0x100282c; /* U+282C BRAILLE PATTERN DOTS-346 */
enum XK_braille_dots_1346 = 0x100282d; /* U+282D BRAILLE PATTERN DOTS-1346 */
enum XK_braille_dots_2346 = 0x100282e; /* U+282E BRAILLE PATTERN DOTS-2346 */
enum XK_braille_dots_12346 = 0x100282f; /* U+282F BRAILLE PATTERN DOTS-12346 */
enum XK_braille_dots_56 = 0x1002830; /* U+2830 BRAILLE PATTERN DOTS-56 */
enum XK_braille_dots_156 = 0x1002831; /* U+2831 BRAILLE PATTERN DOTS-156 */
enum XK_braille_dots_256 = 0x1002832; /* U+2832 BRAILLE PATTERN DOTS-256 */
enum XK_braille_dots_1256 = 0x1002833; /* U+2833 BRAILLE PATTERN DOTS-1256 */
enum XK_braille_dots_356 = 0x1002834; /* U+2834 BRAILLE PATTERN DOTS-356 */
enum XK_braille_dots_1356 = 0x1002835; /* U+2835 BRAILLE PATTERN DOTS-1356 */
enum XK_braille_dots_2356 = 0x1002836; /* U+2836 BRAILLE PATTERN DOTS-2356 */
enum XK_braille_dots_12356 = 0x1002837; /* U+2837 BRAILLE PATTERN DOTS-12356 */
enum XK_braille_dots_456 = 0x1002838; /* U+2838 BRAILLE PATTERN DOTS-456 */
enum XK_braille_dots_1456 = 0x1002839; /* U+2839 BRAILLE PATTERN DOTS-1456 */
enum XK_braille_dots_2456 = 0x100283a; /* U+283A BRAILLE PATTERN DOTS-2456 */
enum XK_braille_dots_12456 = 0x100283b; /* U+283B BRAILLE PATTERN DOTS-12456 */
enum XK_braille_dots_3456 = 0x100283c; /* U+283C BRAILLE PATTERN DOTS-3456 */
enum XK_braille_dots_13456 = 0x100283d; /* U+283D BRAILLE PATTERN DOTS-13456 */
enum XK_braille_dots_23456 = 0x100283e; /* U+283E BRAILLE PATTERN DOTS-23456 */
enum XK_braille_dots_123456 = 0x100283f; /* U+283F BRAILLE PATTERN DOTS-123456 */
enum XK_braille_dots_7 = 0x1002840; /* U+2840 BRAILLE PATTERN DOTS-7 */
enum XK_braille_dots_17 = 0x1002841; /* U+2841 BRAILLE PATTERN DOTS-17 */
enum XK_braille_dots_27 = 0x1002842; /* U+2842 BRAILLE PATTERN DOTS-27 */
enum XK_braille_dots_127 = 0x1002843; /* U+2843 BRAILLE PATTERN DOTS-127 */
enum XK_braille_dots_37 = 0x1002844; /* U+2844 BRAILLE PATTERN DOTS-37 */
enum XK_braille_dots_137 = 0x1002845; /* U+2845 BRAILLE PATTERN DOTS-137 */
enum XK_braille_dots_237 = 0x1002846; /* U+2846 BRAILLE PATTERN DOTS-237 */
enum XK_braille_dots_1237 = 0x1002847; /* U+2847 BRAILLE PATTERN DOTS-1237 */
enum XK_braille_dots_47 = 0x1002848; /* U+2848 BRAILLE PATTERN DOTS-47 */
enum XK_braille_dots_147 = 0x1002849; /* U+2849 BRAILLE PATTERN DOTS-147 */
enum XK_braille_dots_247 = 0x100284a; /* U+284A BRAILLE PATTERN DOTS-247 */
enum XK_braille_dots_1247 = 0x100284b; /* U+284B BRAILLE PATTERN DOTS-1247 */
enum XK_braille_dots_347 = 0x100284c; /* U+284C BRAILLE PATTERN DOTS-347 */
enum XK_braille_dots_1347 = 0x100284d; /* U+284D BRAILLE PATTERN DOTS-1347 */
enum XK_braille_dots_2347 = 0x100284e; /* U+284E BRAILLE PATTERN DOTS-2347 */
enum XK_braille_dots_12347 = 0x100284f; /* U+284F BRAILLE PATTERN DOTS-12347 */
enum XK_braille_dots_57 = 0x1002850; /* U+2850 BRAILLE PATTERN DOTS-57 */
enum XK_braille_dots_157 = 0x1002851; /* U+2851 BRAILLE PATTERN DOTS-157 */
enum XK_braille_dots_257 = 0x1002852; /* U+2852 BRAILLE PATTERN DOTS-257 */
enum XK_braille_dots_1257 = 0x1002853; /* U+2853 BRAILLE PATTERN DOTS-1257 */
enum XK_braille_dots_357 = 0x1002854; /* U+2854 BRAILLE PATTERN DOTS-357 */
enum XK_braille_dots_1357 = 0x1002855; /* U+2855 BRAILLE PATTERN DOTS-1357 */
enum XK_braille_dots_2357 = 0x1002856; /* U+2856 BRAILLE PATTERN DOTS-2357 */
enum XK_braille_dots_12357 = 0x1002857; /* U+2857 BRAILLE PATTERN DOTS-12357 */
enum XK_braille_dots_457 = 0x1002858; /* U+2858 BRAILLE PATTERN DOTS-457 */
enum XK_braille_dots_1457 = 0x1002859; /* U+2859 BRAILLE PATTERN DOTS-1457 */
enum XK_braille_dots_2457 = 0x100285a; /* U+285A BRAILLE PATTERN DOTS-2457 */
enum XK_braille_dots_12457 = 0x100285b; /* U+285B BRAILLE PATTERN DOTS-12457 */
enum XK_braille_dots_3457 = 0x100285c; /* U+285C BRAILLE PATTERN DOTS-3457 */
enum XK_braille_dots_13457 = 0x100285d; /* U+285D BRAILLE PATTERN DOTS-13457 */
enum XK_braille_dots_23457 = 0x100285e; /* U+285E BRAILLE PATTERN DOTS-23457 */
enum XK_braille_dots_123457 = 0x100285f; /* U+285F BRAILLE PATTERN DOTS-123457 */
enum XK_braille_dots_67 = 0x1002860; /* U+2860 BRAILLE PATTERN DOTS-67 */
enum XK_braille_dots_167 = 0x1002861; /* U+2861 BRAILLE PATTERN DOTS-167 */
enum XK_braille_dots_267 = 0x1002862; /* U+2862 BRAILLE PATTERN DOTS-267 */
enum XK_braille_dots_1267 = 0x1002863; /* U+2863 BRAILLE PATTERN DOTS-1267 */
enum XK_braille_dots_367 = 0x1002864; /* U+2864 BRAILLE PATTERN DOTS-367 */
enum XK_braille_dots_1367 = 0x1002865; /* U+2865 BRAILLE PATTERN DOTS-1367 */
enum XK_braille_dots_2367 = 0x1002866; /* U+2866 BRAILLE PATTERN DOTS-2367 */
enum XK_braille_dots_12367 = 0x1002867; /* U+2867 BRAILLE PATTERN DOTS-12367 */
enum XK_braille_dots_467 = 0x1002868; /* U+2868 BRAILLE PATTERN DOTS-467 */
enum XK_braille_dots_1467 = 0x1002869; /* U+2869 BRAILLE PATTERN DOTS-1467 */
enum XK_braille_dots_2467 = 0x100286a; /* U+286A BRAILLE PATTERN DOTS-2467 */
enum XK_braille_dots_12467 = 0x100286b; /* U+286B BRAILLE PATTERN DOTS-12467 */
enum XK_braille_dots_3467 = 0x100286c; /* U+286C BRAILLE PATTERN DOTS-3467 */
enum XK_braille_dots_13467 = 0x100286d; /* U+286D BRAILLE PATTERN DOTS-13467 */
enum XK_braille_dots_23467 = 0x100286e; /* U+286E BRAILLE PATTERN DOTS-23467 */
enum XK_braille_dots_123467 = 0x100286f; /* U+286F BRAILLE PATTERN DOTS-123467 */
enum XK_braille_dots_567 = 0x1002870; /* U+2870 BRAILLE PATTERN DOTS-567 */
enum XK_braille_dots_1567 = 0x1002871; /* U+2871 BRAILLE PATTERN DOTS-1567 */
enum XK_braille_dots_2567 = 0x1002872; /* U+2872 BRAILLE PATTERN DOTS-2567 */
enum XK_braille_dots_12567 = 0x1002873; /* U+2873 BRAILLE PATTERN DOTS-12567 */
enum XK_braille_dots_3567 = 0x1002874; /* U+2874 BRAILLE PATTERN DOTS-3567 */
enum XK_braille_dots_13567 = 0x1002875; /* U+2875 BRAILLE PATTERN DOTS-13567 */
enum XK_braille_dots_23567 = 0x1002876; /* U+2876 BRAILLE PATTERN DOTS-23567 */
enum XK_braille_dots_123567 = 0x1002877; /* U+2877 BRAILLE PATTERN DOTS-123567 */
enum XK_braille_dots_4567 = 0x1002878; /* U+2878 BRAILLE PATTERN DOTS-4567 */
enum XK_braille_dots_14567 = 0x1002879; /* U+2879 BRAILLE PATTERN DOTS-14567 */
enum XK_braille_dots_24567 = 0x100287a; /* U+287A BRAILLE PATTERN DOTS-24567 */
enum XK_braille_dots_124567 = 0x100287b; /* U+287B BRAILLE PATTERN DOTS-124567 */
enum XK_braille_dots_34567 = 0x100287c; /* U+287C BRAILLE PATTERN DOTS-34567 */
enum XK_braille_dots_134567 = 0x100287d; /* U+287D BRAILLE PATTERN DOTS-134567 */
enum XK_braille_dots_234567 = 0x100287e; /* U+287E BRAILLE PATTERN DOTS-234567 */
enum XK_braille_dots_1234567 = 0x100287f; /* U+287F BRAILLE PATTERN DOTS-1234567 */
enum XK_braille_dots_8 = 0x1002880; /* U+2880 BRAILLE PATTERN DOTS-8 */
enum XK_braille_dots_18 = 0x1002881; /* U+2881 BRAILLE PATTERN DOTS-18 */
enum XK_braille_dots_28 = 0x1002882; /* U+2882 BRAILLE PATTERN DOTS-28 */
enum XK_braille_dots_128 = 0x1002883; /* U+2883 BRAILLE PATTERN DOTS-128 */
enum XK_braille_dots_38 = 0x1002884; /* U+2884 BRAILLE PATTERN DOTS-38 */
enum XK_braille_dots_138 = 0x1002885; /* U+2885 BRAILLE PATTERN DOTS-138 */
enum XK_braille_dots_238 = 0x1002886; /* U+2886 BRAILLE PATTERN DOTS-238 */
enum XK_braille_dots_1238 = 0x1002887; /* U+2887 BRAILLE PATTERN DOTS-1238 */
enum XK_braille_dots_48 = 0x1002888; /* U+2888 BRAILLE PATTERN DOTS-48 */
enum XK_braille_dots_148 = 0x1002889; /* U+2889 BRAILLE PATTERN DOTS-148 */
enum XK_braille_dots_248 = 0x100288a; /* U+288A BRAILLE PATTERN DOTS-248 */
enum XK_braille_dots_1248 = 0x100288b; /* U+288B BRAILLE PATTERN DOTS-1248 */
enum XK_braille_dots_348 = 0x100288c; /* U+288C BRAILLE PATTERN DOTS-348 */
enum XK_braille_dots_1348 = 0x100288d; /* U+288D BRAILLE PATTERN DOTS-1348 */
enum XK_braille_dots_2348 = 0x100288e; /* U+288E BRAILLE PATTERN DOTS-2348 */
enum XK_braille_dots_12348 = 0x100288f; /* U+288F BRAILLE PATTERN DOTS-12348 */
enum XK_braille_dots_58 = 0x1002890; /* U+2890 BRAILLE PATTERN DOTS-58 */
enum XK_braille_dots_158 = 0x1002891; /* U+2891 BRAILLE PATTERN DOTS-158 */
enum XK_braille_dots_258 = 0x1002892; /* U+2892 BRAILLE PATTERN DOTS-258 */
enum XK_braille_dots_1258 = 0x1002893; /* U+2893 BRAILLE PATTERN DOTS-1258 */
enum XK_braille_dots_358 = 0x1002894; /* U+2894 BRAILLE PATTERN DOTS-358 */
enum XK_braille_dots_1358 = 0x1002895; /* U+2895 BRAILLE PATTERN DOTS-1358 */
enum XK_braille_dots_2358 = 0x1002896; /* U+2896 BRAILLE PATTERN DOTS-2358 */
enum XK_braille_dots_12358 = 0x1002897; /* U+2897 BRAILLE PATTERN DOTS-12358 */
enum XK_braille_dots_458 = 0x1002898; /* U+2898 BRAILLE PATTERN DOTS-458 */
enum XK_braille_dots_1458 = 0x1002899; /* U+2899 BRAILLE PATTERN DOTS-1458 */
enum XK_braille_dots_2458 = 0x100289a; /* U+289A BRAILLE PATTERN DOTS-2458 */
enum XK_braille_dots_12458 = 0x100289b; /* U+289B BRAILLE PATTERN DOTS-12458 */
enum XK_braille_dots_3458 = 0x100289c; /* U+289C BRAILLE PATTERN DOTS-3458 */
enum XK_braille_dots_13458 = 0x100289d; /* U+289D BRAILLE PATTERN DOTS-13458 */
enum XK_braille_dots_23458 = 0x100289e; /* U+289E BRAILLE PATTERN DOTS-23458 */
enum XK_braille_dots_123458 = 0x100289f; /* U+289F BRAILLE PATTERN DOTS-123458 */
enum XK_braille_dots_68 = 0x10028a0; /* U+28A0 BRAILLE PATTERN DOTS-68 */
enum XK_braille_dots_168 = 0x10028a1; /* U+28A1 BRAILLE PATTERN DOTS-168 */
enum XK_braille_dots_268 = 0x10028a2; /* U+28A2 BRAILLE PATTERN DOTS-268 */
enum XK_braille_dots_1268 = 0x10028a3; /* U+28A3 BRAILLE PATTERN DOTS-1268 */
enum XK_braille_dots_368 = 0x10028a4; /* U+28A4 BRAILLE PATTERN DOTS-368 */
enum XK_braille_dots_1368 = 0x10028a5; /* U+28A5 BRAILLE PATTERN DOTS-1368 */
enum XK_braille_dots_2368 = 0x10028a6; /* U+28A6 BRAILLE PATTERN DOTS-2368 */
enum XK_braille_dots_12368 = 0x10028a7; /* U+28A7 BRAILLE PATTERN DOTS-12368 */
enum XK_braille_dots_468 = 0x10028a8; /* U+28A8 BRAILLE PATTERN DOTS-468 */
enum XK_braille_dots_1468 = 0x10028a9; /* U+28A9 BRAILLE PATTERN DOTS-1468 */
enum XK_braille_dots_2468 = 0x10028aa; /* U+28AA BRAILLE PATTERN DOTS-2468 */
enum XK_braille_dots_12468 = 0x10028ab; /* U+28AB BRAILLE PATTERN DOTS-12468 */
enum XK_braille_dots_3468 = 0x10028ac; /* U+28AC BRAILLE PATTERN DOTS-3468 */
enum XK_braille_dots_13468 = 0x10028ad; /* U+28AD BRAILLE PATTERN DOTS-13468 */
enum XK_braille_dots_23468 = 0x10028ae; /* U+28AE BRAILLE PATTERN DOTS-23468 */
enum XK_braille_dots_123468 = 0x10028af; /* U+28AF BRAILLE PATTERN DOTS-123468 */
enum XK_braille_dots_568 = 0x10028b0; /* U+28B0 BRAILLE PATTERN DOTS-568 */
enum XK_braille_dots_1568 = 0x10028b1; /* U+28B1 BRAILLE PATTERN DOTS-1568 */
enum XK_braille_dots_2568 = 0x10028b2; /* U+28B2 BRAILLE PATTERN DOTS-2568 */
enum XK_braille_dots_12568 = 0x10028b3; /* U+28B3 BRAILLE PATTERN DOTS-12568 */
enum XK_braille_dots_3568 = 0x10028b4; /* U+28B4 BRAILLE PATTERN DOTS-3568 */
enum XK_braille_dots_13568 = 0x10028b5; /* U+28B5 BRAILLE PATTERN DOTS-13568 */
enum XK_braille_dots_23568 = 0x10028b6; /* U+28B6 BRAILLE PATTERN DOTS-23568 */
enum XK_braille_dots_123568 = 0x10028b7; /* U+28B7 BRAILLE PATTERN DOTS-123568 */
enum XK_braille_dots_4568 = 0x10028b8; /* U+28B8 BRAILLE PATTERN DOTS-4568 */
enum XK_braille_dots_14568 = 0x10028b9; /* U+28B9 BRAILLE PATTERN DOTS-14568 */
enum XK_braille_dots_24568 = 0x10028ba; /* U+28BA BRAILLE PATTERN DOTS-24568 */
enum XK_braille_dots_124568 = 0x10028bb; /* U+28BB BRAILLE PATTERN DOTS-124568 */
enum XK_braille_dots_34568 = 0x10028bc; /* U+28BC BRAILLE PATTERN DOTS-34568 */
enum XK_braille_dots_134568 = 0x10028bd; /* U+28BD BRAILLE PATTERN DOTS-134568 */
enum XK_braille_dots_234568 = 0x10028be; /* U+28BE BRAILLE PATTERN DOTS-234568 */
enum XK_braille_dots_1234568 = 0x10028bf; /* U+28BF BRAILLE PATTERN DOTS-1234568 */
enum XK_braille_dots_78 = 0x10028c0; /* U+28C0 BRAILLE PATTERN DOTS-78 */
enum XK_braille_dots_178 = 0x10028c1; /* U+28C1 BRAILLE PATTERN DOTS-178 */
enum XK_braille_dots_278 = 0x10028c2; /* U+28C2 BRAILLE PATTERN DOTS-278 */
enum XK_braille_dots_1278 = 0x10028c3; /* U+28C3 BRAILLE PATTERN DOTS-1278 */
enum XK_braille_dots_378 = 0x10028c4; /* U+28C4 BRAILLE PATTERN DOTS-378 */
enum XK_braille_dots_1378 = 0x10028c5; /* U+28C5 BRAILLE PATTERN DOTS-1378 */
enum XK_braille_dots_2378 = 0x10028c6; /* U+28C6 BRAILLE PATTERN DOTS-2378 */
enum XK_braille_dots_12378 = 0x10028c7; /* U+28C7 BRAILLE PATTERN DOTS-12378 */
enum XK_braille_dots_478 = 0x10028c8; /* U+28C8 BRAILLE PATTERN DOTS-478 */
enum XK_braille_dots_1478 = 0x10028c9; /* U+28C9 BRAILLE PATTERN DOTS-1478 */
enum XK_braille_dots_2478 = 0x10028ca; /* U+28CA BRAILLE PATTERN DOTS-2478 */
enum XK_braille_dots_12478 = 0x10028cb; /* U+28CB BRAILLE PATTERN DOTS-12478 */
enum XK_braille_dots_3478 = 0x10028cc; /* U+28CC BRAILLE PATTERN DOTS-3478 */
enum XK_braille_dots_13478 = 0x10028cd; /* U+28CD BRAILLE PATTERN DOTS-13478 */
enum XK_braille_dots_23478 = 0x10028ce; /* U+28CE BRAILLE PATTERN DOTS-23478 */
enum XK_braille_dots_123478 = 0x10028cf; /* U+28CF BRAILLE PATTERN DOTS-123478 */
enum XK_braille_dots_578 = 0x10028d0; /* U+28D0 BRAILLE PATTERN DOTS-578 */
enum XK_braille_dots_1578 = 0x10028d1; /* U+28D1 BRAILLE PATTERN DOTS-1578 */
enum XK_braille_dots_2578 = 0x10028d2; /* U+28D2 BRAILLE PATTERN DOTS-2578 */
enum XK_braille_dots_12578 = 0x10028d3; /* U+28D3 BRAILLE PATTERN DOTS-12578 */
enum XK_braille_dots_3578 = 0x10028d4; /* U+28D4 BRAILLE PATTERN DOTS-3578 */
enum XK_braille_dots_13578 = 0x10028d5; /* U+28D5 BRAILLE PATTERN DOTS-13578 */
enum XK_braille_dots_23578 = 0x10028d6; /* U+28D6 BRAILLE PATTERN DOTS-23578 */
enum XK_braille_dots_123578 = 0x10028d7; /* U+28D7 BRAILLE PATTERN DOTS-123578 */
enum XK_braille_dots_4578 = 0x10028d8; /* U+28D8 BRAILLE PATTERN DOTS-4578 */
enum XK_braille_dots_14578 = 0x10028d9; /* U+28D9 BRAILLE PATTERN DOTS-14578 */
enum XK_braille_dots_24578 = 0x10028da; /* U+28DA BRAILLE PATTERN DOTS-24578 */
enum XK_braille_dots_124578 = 0x10028db; /* U+28DB BRAILLE PATTERN DOTS-124578 */
enum XK_braille_dots_34578 = 0x10028dc; /* U+28DC BRAILLE PATTERN DOTS-34578 */
enum XK_braille_dots_134578 = 0x10028dd; /* U+28DD BRAILLE PATTERN DOTS-134578 */
enum XK_braille_dots_234578 = 0x10028de; /* U+28DE BRAILLE PATTERN DOTS-234578 */
enum XK_braille_dots_1234578 = 0x10028df; /* U+28DF BRAILLE PATTERN DOTS-1234578 */
enum XK_braille_dots_678 = 0x10028e0; /* U+28E0 BRAILLE PATTERN DOTS-678 */
enum XK_braille_dots_1678 = 0x10028e1; /* U+28E1 BRAILLE PATTERN DOTS-1678 */
enum XK_braille_dots_2678 = 0x10028e2; /* U+28E2 BRAILLE PATTERN DOTS-2678 */
enum XK_braille_dots_12678 = 0x10028e3; /* U+28E3 BRAILLE PATTERN DOTS-12678 */
enum XK_braille_dots_3678 = 0x10028e4; /* U+28E4 BRAILLE PATTERN DOTS-3678 */
enum XK_braille_dots_13678 = 0x10028e5; /* U+28E5 BRAILLE PATTERN DOTS-13678 */
enum XK_braille_dots_23678 = 0x10028e6; /* U+28E6 BRAILLE PATTERN DOTS-23678 */
enum XK_braille_dots_123678 = 0x10028e7; /* U+28E7 BRAILLE PATTERN DOTS-123678 */
enum XK_braille_dots_4678 = 0x10028e8; /* U+28E8 BRAILLE PATTERN DOTS-4678 */
enum XK_braille_dots_14678 = 0x10028e9; /* U+28E9 BRAILLE PATTERN DOTS-14678 */
enum XK_braille_dots_24678 = 0x10028ea; /* U+28EA BRAILLE PATTERN DOTS-24678 */
enum XK_braille_dots_124678 = 0x10028eb; /* U+28EB BRAILLE PATTERN DOTS-124678 */
enum XK_braille_dots_34678 = 0x10028ec; /* U+28EC BRAILLE PATTERN DOTS-34678 */
enum XK_braille_dots_134678 = 0x10028ed; /* U+28ED BRAILLE PATTERN DOTS-134678 */
enum XK_braille_dots_234678 = 0x10028ee; /* U+28EE BRAILLE PATTERN DOTS-234678 */
enum XK_braille_dots_1234678 = 0x10028ef; /* U+28EF BRAILLE PATTERN DOTS-1234678 */
enum XK_braille_dots_5678 = 0x10028f0; /* U+28F0 BRAILLE PATTERN DOTS-5678 */
enum XK_braille_dots_15678 = 0x10028f1; /* U+28F1 BRAILLE PATTERN DOTS-15678 */
enum XK_braille_dots_25678 = 0x10028f2; /* U+28F2 BRAILLE PATTERN DOTS-25678 */
enum XK_braille_dots_125678 = 0x10028f3; /* U+28F3 BRAILLE PATTERN DOTS-125678 */
enum XK_braille_dots_35678 = 0x10028f4; /* U+28F4 BRAILLE PATTERN DOTS-35678 */
enum XK_braille_dots_135678 = 0x10028f5; /* U+28F5 BRAILLE PATTERN DOTS-135678 */
enum XK_braille_dots_235678 = 0x10028f6; /* U+28F6 BRAILLE PATTERN DOTS-235678 */
enum XK_braille_dots_1235678 = 0x10028f7; /* U+28F7 BRAILLE PATTERN DOTS-1235678 */
enum XK_braille_dots_45678 = 0x10028f8; /* U+28F8 BRAILLE PATTERN DOTS-45678 */
enum XK_braille_dots_145678 = 0x10028f9; /* U+28F9 BRAILLE PATTERN DOTS-145678 */
enum XK_braille_dots_245678 = 0x10028fa; /* U+28FA BRAILLE PATTERN DOTS-245678 */
enum XK_braille_dots_1245678 = 0x10028fb; /* U+28FB BRAILLE PATTERN DOTS-1245678 */
enum XK_braille_dots_345678 = 0x10028fc; /* U+28FC BRAILLE PATTERN DOTS-345678 */
enum XK_braille_dots_1345678 = 0x10028fd; /* U+28FD BRAILLE PATTERN DOTS-1345678 */
enum XK_braille_dots_2345678 = 0x10028fe; /* U+28FE BRAILLE PATTERN DOTS-2345678 */
enum XK_braille_dots_12345678 = 0x10028ff; /* U+28FF BRAILLE PATTERN DOTS-12345678 */
/* XK_BRAILLE */

/*
 * Sinhala (http://unicode.org/charts/PDF/U0D80.pdf)
 * http://www.nongnu.org/sinhala/doc/transliteration/sinhala-transliteration_6.html
 */

enum XK_Sinh_ng = 0x1000d82; /* U+0D82 SINHALA SIGN ANUSVARAYA */
enum XK_Sinh_h2 = 0x1000d83; /* U+0D83 SINHALA SIGN VISARGAYA */
enum XK_Sinh_a = 0x1000d85; /* U+0D85 SINHALA LETTER AYANNA */
enum XK_Sinh_aa = 0x1000d86; /* U+0D86 SINHALA LETTER AAYANNA */
enum XK_Sinh_ae = 0x1000d87; /* U+0D87 SINHALA LETTER AEYANNA */
enum XK_Sinh_aee = 0x1000d88; /* U+0D88 SINHALA LETTER AEEYANNA */
enum XK_Sinh_i = 0x1000d89; /* U+0D89 SINHALA LETTER IYANNA */
enum XK_Sinh_ii = 0x1000d8a; /* U+0D8A SINHALA LETTER IIYANNA */
enum XK_Sinh_u = 0x1000d8b; /* U+0D8B SINHALA LETTER UYANNA */
enum XK_Sinh_uu = 0x1000d8c; /* U+0D8C SINHALA LETTER UUYANNA */
enum XK_Sinh_ri = 0x1000d8d; /* U+0D8D SINHALA LETTER IRUYANNA */
enum XK_Sinh_rii = 0x1000d8e; /* U+0D8E SINHALA LETTER IRUUYANNA */
enum XK_Sinh_lu = 0x1000d8f; /* U+0D8F SINHALA LETTER ILUYANNA */
enum XK_Sinh_luu = 0x1000d90; /* U+0D90 SINHALA LETTER ILUUYANNA */
enum XK_Sinh_e = 0x1000d91; /* U+0D91 SINHALA LETTER EYANNA */
enum XK_Sinh_ee = 0x1000d92; /* U+0D92 SINHALA LETTER EEYANNA */
enum XK_Sinh_ai = 0x1000d93; /* U+0D93 SINHALA LETTER AIYANNA */
enum XK_Sinh_o = 0x1000d94; /* U+0D94 SINHALA LETTER OYANNA */
enum XK_Sinh_oo = 0x1000d95; /* U+0D95 SINHALA LETTER OOYANNA */
enum XK_Sinh_au = 0x1000d96; /* U+0D96 SINHALA LETTER AUYANNA */
enum XK_Sinh_ka = 0x1000d9a; /* U+0D9A SINHALA LETTER ALPAPRAANA KAYANNA */
enum XK_Sinh_kha = 0x1000d9b; /* U+0D9B SINHALA LETTER MAHAAPRAANA KAYANNA */
enum XK_Sinh_ga = 0x1000d9c; /* U+0D9C SINHALA LETTER ALPAPRAANA GAYANNA */
enum XK_Sinh_gha = 0x1000d9d; /* U+0D9D SINHALA LETTER MAHAAPRAANA GAYANNA */
enum XK_Sinh_ng2 = 0x1000d9e; /* U+0D9E SINHALA LETTER KANTAJA NAASIKYAYA */
enum XK_Sinh_nga = 0x1000d9f; /* U+0D9F SINHALA LETTER SANYAKA GAYANNA */
enum XK_Sinh_ca = 0x1000da0; /* U+0DA0 SINHALA LETTER ALPAPRAANA CAYANNA */
enum XK_Sinh_cha = 0x1000da1; /* U+0DA1 SINHALA LETTER MAHAAPRAANA CAYANNA */
enum XK_Sinh_ja = 0x1000da2; /* U+0DA2 SINHALA LETTER ALPAPRAANA JAYANNA */
enum XK_Sinh_jha = 0x1000da3; /* U+0DA3 SINHALA LETTER MAHAAPRAANA JAYANNA */
enum XK_Sinh_nya = 0x1000da4; /* U+0DA4 SINHALA LETTER TAALUJA NAASIKYAYA */
enum XK_Sinh_jnya = 0x1000da5; /* U+0DA5 SINHALA LETTER TAALUJA SANYOOGA NAAKSIKYAYA */
enum XK_Sinh_nja = 0x1000da6; /* U+0DA6 SINHALA LETTER SANYAKA JAYANNA */
enum XK_Sinh_tta = 0x1000da7; /* U+0DA7 SINHALA LETTER ALPAPRAANA TTAYANNA */
enum XK_Sinh_ttha = 0x1000da8; /* U+0DA8 SINHALA LETTER MAHAAPRAANA TTAYANNA */
enum XK_Sinh_dda = 0x1000da9; /* U+0DA9 SINHALA LETTER ALPAPRAANA DDAYANNA */
enum XK_Sinh_ddha = 0x1000daa; /* U+0DAA SINHALA LETTER MAHAAPRAANA DDAYANNA */
enum XK_Sinh_nna = 0x1000dab; /* U+0DAB SINHALA LETTER MUURDHAJA NAYANNA */
enum XK_Sinh_ndda = 0x1000dac; /* U+0DAC SINHALA LETTER SANYAKA DDAYANNA */
enum XK_Sinh_tha = 0x1000dad; /* U+0DAD SINHALA LETTER ALPAPRAANA TAYANNA */
enum XK_Sinh_thha = 0x1000dae; /* U+0DAE SINHALA LETTER MAHAAPRAANA TAYANNA */
enum XK_Sinh_dha = 0x1000daf; /* U+0DAF SINHALA LETTER ALPAPRAANA DAYANNA */
enum XK_Sinh_dhha = 0x1000db0; /* U+0DB0 SINHALA LETTER MAHAAPRAANA DAYANNA */
enum XK_Sinh_na = 0x1000db1; /* U+0DB1 SINHALA LETTER DANTAJA NAYANNA */
enum XK_Sinh_ndha = 0x1000db3; /* U+0DB3 SINHALA LETTER SANYAKA DAYANNA */
enum XK_Sinh_pa = 0x1000db4; /* U+0DB4 SINHALA LETTER ALPAPRAANA PAYANNA */
enum XK_Sinh_pha = 0x1000db5; /* U+0DB5 SINHALA LETTER MAHAAPRAANA PAYANNA */
enum XK_Sinh_ba = 0x1000db6; /* U+0DB6 SINHALA LETTER ALPAPRAANA BAYANNA */
enum XK_Sinh_bha = 0x1000db7; /* U+0DB7 SINHALA LETTER MAHAAPRAANA BAYANNA */
enum XK_Sinh_ma = 0x1000db8; /* U+0DB8 SINHALA LETTER MAYANNA */
enum XK_Sinh_mba = 0x1000db9; /* U+0DB9 SINHALA LETTER AMBA BAYANNA */
enum XK_Sinh_ya = 0x1000dba; /* U+0DBA SINHALA LETTER YAYANNA */
enum XK_Sinh_ra = 0x1000dbb; /* U+0DBB SINHALA LETTER RAYANNA */
enum XK_Sinh_la = 0x1000dbd; /* U+0DBD SINHALA LETTER DANTAJA LAYANNA */
enum XK_Sinh_va = 0x1000dc0; /* U+0DC0 SINHALA LETTER VAYANNA */
enum XK_Sinh_sha = 0x1000dc1; /* U+0DC1 SINHALA LETTER TAALUJA SAYANNA */
enum XK_Sinh_ssha = 0x1000dc2; /* U+0DC2 SINHALA LETTER MUURDHAJA SAYANNA */
enum XK_Sinh_sa = 0x1000dc3; /* U+0DC3 SINHALA LETTER DANTAJA SAYANNA */
enum XK_Sinh_ha = 0x1000dc4; /* U+0DC4 SINHALA LETTER HAYANNA */
enum XK_Sinh_lla = 0x1000dc5; /* U+0DC5 SINHALA LETTER MUURDHAJA LAYANNA */
enum XK_Sinh_fa = 0x1000dc6; /* U+0DC6 SINHALA LETTER FAYANNA */
enum XK_Sinh_al = 0x1000dca; /* U+0DCA SINHALA SIGN AL-LAKUNA */
enum XK_Sinh_aa2 = 0x1000dcf; /* U+0DCF SINHALA VOWEL SIGN AELA-PILLA */
enum XK_Sinh_ae2 = 0x1000dd0; /* U+0DD0 SINHALA VOWEL SIGN KETTI AEDA-PILLA */
enum XK_Sinh_aee2 = 0x1000dd1; /* U+0DD1 SINHALA VOWEL SIGN DIGA AEDA-PILLA */
enum XK_Sinh_i2 = 0x1000dd2; /* U+0DD2 SINHALA VOWEL SIGN KETTI IS-PILLA */
enum XK_Sinh_ii2 = 0x1000dd3; /* U+0DD3 SINHALA VOWEL SIGN DIGA IS-PILLA */
enum XK_Sinh_u2 = 0x1000dd4; /* U+0DD4 SINHALA VOWEL SIGN KETTI PAA-PILLA */
enum XK_Sinh_uu2 = 0x1000dd6; /* U+0DD6 SINHALA VOWEL SIGN DIGA PAA-PILLA */
enum XK_Sinh_ru2 = 0x1000dd8; /* U+0DD8 SINHALA VOWEL SIGN GAETTA-PILLA */
enum XK_Sinh_e2 = 0x1000dd9; /* U+0DD9 SINHALA VOWEL SIGN KOMBUVA */
enum XK_Sinh_ee2 = 0x1000dda; /* U+0DDA SINHALA VOWEL SIGN DIGA KOMBUVA */
enum XK_Sinh_ai2 = 0x1000ddb; /* U+0DDB SINHALA VOWEL SIGN KOMBU DEKA */
enum XK_Sinh_o2 = 0x1000ddc; /* U+0DDC SINHALA VOWEL SIGN KOMBUVA HAA AELA-PILLA */
enum XK_Sinh_oo2 = 0x1000ddd; /* U+0DDD SINHALA VOWEL SIGN KOMBUVA HAA DIGA AELA-PILLA */
enum XK_Sinh_au2 = 0x1000dde; /* U+0DDE SINHALA VOWEL SIGN KOMBUVA HAA GAYANUKITTA */
enum XK_Sinh_lu2 = 0x1000ddf; /* U+0DDF SINHALA VOWEL SIGN GAYANUKITTA */
enum XK_Sinh_ruu2 = 0x1000df2; /* U+0DF2 SINHALA VOWEL SIGN DIGA GAETTA-PILLA */
enum XK_Sinh_luu2 = 0x1000df3; /* U+0DF3 SINHALA VOWEL SIGN DIGA GAYANUKITTA */
enum XK_Sinh_kunddaliya = 0x1000df4; /* U+0DF4 SINHALA PUNCTUATION KUNDDALIYA */
/* XK_SINHALA */
