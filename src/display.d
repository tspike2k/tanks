/*
Authors:   tspike (github.com/tspike2k)
Copyright: Copyright (c) 2025
License:   Boost Software License 1.0 (https://www.boost.org/LICENSE_1_0.txt)
*/

enum{
    Key_Modifier_Ctrl = (1 << 1),
};

enum {
    Key_ID_A,
    Key_ID_B,
    Key_ID_C,
    Key_ID_D,
    Key_ID_E,
    Key_ID_F,
    Key_ID_G,
    Key_ID_H,
    Key_ID_I,
    Key_ID_J,
    Key_ID_K,
    Key_ID_L,
    Key_ID_M,
    Key_ID_N,
    Key_ID_O,
    Key_ID_P,
    Key_ID_Q,
    Key_ID_R,
    Key_ID_S,
    Key_ID_T,
    Key_ID_U,
    Key_ID_V,
    Key_ID_W,
    Key_ID_X,
    Key_ID_Y,
    Key_ID_Z,

    Key_ID_F1,
    Key_ID_F2,
    Key_ID_F3,
    Key_ID_F4,
    Key_ID_F5,
    Key_ID_F6,
    Key_ID_F7,
    Key_ID_F8,
    Key_ID_F9,
    Key_ID_F10,
    Key_ID_F11,
    Key_ID_F12,

    Key_ID_Arrow_Up,
    Key_ID_Arrow_Down,
    Key_ID_Arrow_Left,
    Key_ID_Arrow_Right,
    Key_ID_Enter,
    Key_ID_Escape,
    Key_ID_Delete,
};

enum Event_Type : uint{
    None,
    Window_Close,
    Key,
    Mouse_Motion,
    Button,
};

enum Button_ID : uint{
    None,
    Mouse_Left,
    Mouse_Right,
    Mouse_Middle,
};

struct Event_Key{
    Event_Type type;
    uint id;
    uint modifier;
    bool pressed; // TODO: Make these flags?
    bool is_repeat;
};

struct Event_Mouse_Motion{
    Event_Type type;
    // TODO: Have a mouse id?
    int   pixel_x;
    int   pixel_y;
    float rel_x;
    float rel_y;
}

struct Event_Button{
    Event_Type type;
    Button_ID id;
    bool      pressed; // TODO: Button status flag?
}

union Event{
    Event_Type         type;
    Event_Key          key;
    Event_Mouse_Motion mouse_motion;
    Event_Button       button;
}

struct Window{
    uint flags;
    uint width;
    uint height;
}

Window* get_window_info(){
    auto result = &g_window_info;
    return result;
}

private:

__gshared Window g_window_info;

version(linux){
    pragma(lib, "Xext");
    pragma(lib, "Xi"); // TODO: Load XInput dynamically?

    // TODO: Make OpenGL optional.

    import logging;
    import bind.xlib;
    import logging;
    import core.stdc.string : strlen; // TODO: Have a strlen of our own?

    import bind.glx;
    import bind.opengl;

    alias XWindow = bind.xlib.Window;

    enum Target_OpenGL_Version_Major = 3;
    enum Target_OpenGL_Version_Minor = 2;

    T zero_type(T)(){
        import core.stdc.string: memset;
        T result = void;
        memset(&result, 0, T.sizeof);
        return result;
    }

    struct Xlib_Window{
        XWindow handle;

        Visual *visual;
        int     screen;
        int     bit_depth;
        GC      graphics_context;

        // For software rendering
        // TODO: The buffer and the width/height can be accessed directly from the XImage. Use those instead!
        uint* backbuffer_pixels;
        uint  backbuffer_width;
        uint  backbuffer_height;
        XImage *backbuffer;
    }

    __gshared Display* g_x11_display;
    __gshared Atom     g_x11_atom_WMState;
    __gshared Atom     g_x11_atom_WMStateFullscreen;
    __gshared Atom     g_x11_atom_WMDeleteWindow;
    __gshared Atom     g_x11_atom_WMIcon;
    __gshared Atom     g_x11_atom_clipboard;
    __gshared int      g_last_mouse_x;
    __gshared int      g_last_mouse_y;
    __gshared int      g_libXI_extension_opcode;
    __gshared int      g_libXI_master_pointer_device;
    __gshared bool     g_use_XI2_for_mouse;

    __gshared Xlib_Window g_xlib_window;

    // For hardware rendering
    __gshared glXCreateContextAttribsARBFunc glxCreateContextAttribsARB;
    __gshared glXSwapIntervalEXTFunc         glxSwapIntervalEXT;
    __gshared glXSwapIntervalMESAFunc        glxSwapIntervalMESA;
    __gshared glXSwapIntervalSGIFunc         glxSwapIntervalSGI;

    // TODO: These are shared between windows, right?
    __gshared GLXContext  g_glx_context;
    __gshared GLXFBConfig g_fb_config;

    public void swap_render_backbuffer(){
        glXSwapBuffers(g_x11_display, g_xlib_window.handle);
        XFlush(g_x11_display);
    }

    public bool open_display(const(char)* window_title, uint width, uint height, uint window_flags){
        g_x11_display = XOpenDisplay(null);
        if(!g_x11_display){
            log("Unable to open X11 display. Aborting.\n");
            return false;
        }

        g_window_info.width  = width;
        g_window_info.height = height;

        g_x11_atom_WMState           = XInternAtom(g_x11_display, "_NET_WM_STATE", False);
        g_x11_atom_WMStateFullscreen = XInternAtom(g_x11_display, "_NET_WM_STATE_FULLSCREEN", False);
        g_x11_atom_WMDeleteWindow    = XInternAtom(g_x11_display, "WM_DELETE_WINDOW", False);
        g_x11_atom_WMIcon            = XInternAtom(g_x11_display, "_NET_WM_ICON", False);
        g_x11_atom_clipboard         = XInternAtom(g_x11_display, "CLIPBOARD", False);

        g_xlib_window = open_window(window_title, width, height, window_flags);

        int screen = g_xlib_window.screen;
        const char* glx_extension_string = glXQueryExtensionsString(g_x11_display, screen);
        load_glx_extensions(glx_extension_string[0 .. strlen(glx_extension_string)]);

        XextErrorHandler default_xext_error_handler =
            XSetExtensionErrorHandler(&xext_error_handler);

        g_use_XI2_for_mouse = request_XInput2_mouse_events();

        XSync(g_x11_display, False);
        XSetExtensionErrorHandler(default_xext_error_handler);

        if(glxCreateContextAttribsARB){
            // NOTE(tspike): Temporarily stub out the X11 error handler with our own in case context creation fails.
            XErrorHandler defaultX11ErrorHandler = XSetErrorHandler(&stub_x11_error_handler);

            // NOTE(tspike): Setting GLX_CONTEXT_FLAGS_ARB to GLX_CONTEXT_FORWARD_COMPATIBLE_BIT_ARB
            // appears to be bad practice. The official OpenGL wiki states you should NEVER do it:
            // https://www.khronos.org/opengl/wiki/Creating_an_OpenGL_Context_(WGL)
            debug{
                int[9] glxContextAttribs = [
                    GLX_CONTEXT_MAJOR_VERSION_ARB, Target_OpenGL_Version_Major,
                    GLX_CONTEXT_MINOR_VERSION_ARB, Target_OpenGL_Version_Minor,
                    GLX_CONTEXT_PROFILE_MASK_ARB, GLX_CONTEXT_CORE_PROFILE_BIT_ARB,
                    GLX_CONTEXT_FLAGS_ARB, GLX_CONTEXT_DEBUG_BIT_ARB,
                    None
                ];
            }
            else{
                int[7] glxContextAttribs = [
                    GLX_CONTEXT_MAJOR_VERSION_ARB, Target_OpenGL_Version_Major,
                    GLX_CONTEXT_MINOR_VERSION_ARB, Target_OpenGL_Version_Minor,
                    GLX_CONTEXT_PROFILE_MASK_ARB, GLX_CONTEXT_CORE_PROFILE_BIT_ARB,
                    None
                ];
            }

            // TODO: Error checking
            g_glx_context = glxCreateContextAttribsARB(g_x11_display, g_fb_config, null, True, &glxContextAttribs[0]);

            // NOTE(tspike): Call XSync to force X11 to process errors and send them to our error handler
            XSync(g_x11_display, False);
            XSetErrorHandler(defaultX11ErrorHandler);
        }

        // TODO: Fallback to software rendering if we can't get an OpenGL context
        if (!g_glx_context){
            log("Unable to create OpenGL context. Exiting.\n"); // TODO: Better logging
            //log("Unable to create OpenGL {0}.{1} context. Exiting.\n", fmt_u(TARGET_GL_VERSION_MAJOR), fmt_u(TARGET_GL_VERSION_MINOR));
            return false;
        }
        glXMakeCurrent(g_x11_display, g_xlib_window.handle, g_glx_context);

        load_opengl_functions(cast(OpenGL_Load_Sym_Func)&glXGetProcAddressARB);

        //log("OpenGL context: {0}\n", fmt_cstr((const char*)glGetString(GL_VERSION)));
        //log("OpenGL shader version: {0}\n", fmt_cstr((const char*)glGetString(GL_SHADING_LANGUAGE_VERSION)));

        // TODO: Only make this fullscreen if the window_flags requests it.
        // TODO: Make this send_fullscreen_request and take the _NET_WM_STATE as a parameter.
        send_fullscreen_toggle_request();
        XSync(g_x11_display, True);

        return true;
    }

    extern(C) int xext_error_handler(Display* display, const(char)* ext_name, const(char)* msg){
        char[256] buffer ;
        log("Error.\n");
        //log(Cyu_Err "{0}: {1}\n", fmt_cstr(ext_name), fmt_cstr(msg));
        return 0;
    }

    extern(C) int stub_x11_error_handler(Display* display, XErrorEvent* ev){
        char[256] buffer ;
        XGetErrorText(display, ev.error_code, &buffer[0], 256);
        log(buffer[0 .. strlen(buffer.ptr)]);
        return 0;
    }

    bool request_XInput2_mouse_events(){
        // NOTE: Much of this function is based around the ManyMouse library written by Ryan C. Gordon, released under the ZLIB license.
        bool succeeded = false;

        int first_event, first_error;
        if(XQueryExtension(g_x11_display, "XInputExtension", &g_libXI_extension_opcode, &first_event, &first_error)){
            int version_major = 2;
            int version_minor = 0;
            if (XIQueryVersion(g_x11_display, &version_major, &version_minor) == Success){
                XIEventMask evmask;
                ubyte[3] mask = [0, 0, 0];

                XISetMask(&mask[0], XI_RawMotion);
                //XISetMask(mask.ptr, XI_RawButtonPress);
                //XISetMask(mask.ptr, XI_RawButtonRelease);

                // NOTE: We should only need to subscribe to master device events because the master device is supposed to forward
                // events generated by every associated slave device. However, when we do we never receive any XI_RawButtonRelease events.
                // So instead we'll subscribe to all devices and simply ignore events sent by the master pointer device.
                evmask.deviceid = XIAllDevices;
                evmask.mask_len = mask.length;
                evmask.mask = &mask[0];

                XISelectEvents(g_x11_display, DefaultRootWindow(g_x11_display), &evmask, 1);

                int devicesMax;
                XIDeviceInfo* devices = XIQueryDevice(g_x11_display, XIAllDevices, &devicesMax);
                // NOTE: We're assuming there is only one master pointer device. This certainly SHOULD be true, AFAIK.
                for(int i = 0; i < devicesMax; i++){
                    XIDeviceInfo* info = &devices[i];
                    if (info.use == XIMasterPointer){
                        g_libXI_master_pointer_device = info.deviceid;
                        succeeded = true;
                        break;
                    }
                }
                if(!succeeded){
                    log("XInput2 unable to find master pointer device. Unable to get raw mouse input.\n");
                }

                XIFreeDeviceInfo(devices);
            }
            else{
                log("XIQueryVersion failed. Unable to get raw mouse input.\n");
            }
        }
        else{
            log("XQueryExtension failed to query for the XInput extension. Unable to get raw mouse input.\n");
        }

        return succeeded;
    }

    Xlib_Window open_window(const(char)* window_title, uint width, uint height, uint flags){
        // TODO: Find out once and for all what a "visual" and "gc" are and how they relate to software/hardware rendering.
        Xlib_Window result;

        // NOTE: Setting the window attribute "bit_gravity" to StaticGravity helps prevent flickering
        // when resizing the window. See here for more information:
        // https://handmade.network/forums/articles/t/2834-tutorial_a_tour_through_xlib_and_related_technologies
        uint attributes_mask = CWEventMask|CWBackPixel|CWBitGravity|CWBackPixmap;
        XSetWindowAttributes attributes;
        attributes.event_mask = FocusChangeMask| ExposureMask | StructureNotifyMask
            | KeyPressMask | KeyReleaseMask | ButtonPressMask | ButtonReleaseMask
            | PointerMotionMask;
        attributes.background_pixmap = None; // TODO: Background pixmap? Does this mean we can make a framebuffer here?
        attributes.bit_gravity = StaticGravity;

        // The "screen" is a render target. It seems safe to use the default screen for the given display.
        int default_screen = DefaultScreen(g_x11_display);

        XVisualInfo* visual_info = null;
        bool got_hw_rendering = false;

        // NOTE(tspike): This is based on the code found at the openGL tutorial found here:
        // https://www.khronos.org/opengl/wiki/Tutorial:_OpenGL_3.0_Context_Creation_(GLX)
        {
            int[23] targetFramebufferAttribs =
            [
                GLX_X_RENDERABLE    , True,
                GLX_DRAWABLE_TYPE   , GLX_WINDOW_BIT,
                GLX_RENDER_TYPE     , GLX_RGBA_BIT,
                GLX_X_VISUAL_TYPE   , GLX_TRUE_COLOR,
                GLX_RED_SIZE        , 8,
                GLX_GREEN_SIZE      , 8,
                GLX_BLUE_SIZE       , 8,
                GLX_ALPHA_SIZE      , 8,
                GLX_DEPTH_SIZE      , 24,
                GLX_STENCIL_SIZE    , 8,
                GLX_DOUBLEBUFFER    , True,
                //GLX_SAMPLE_BUFFERS  , 1,
                //GLX_SAMPLES         , 4,
                None
            ];

            int fbCount;
            GLXFBConfig* fbList = glXChooseFBConfig(g_x11_display, default_screen, &targetFramebufferAttribs[0], &fbCount);
            if(fbCount > 0){
                // TODO(tspike): Choose and store best visual/fbConfig
                g_fb_config = fbList[0];
                visual_info = glXGetVisualFromFBConfig(g_x11_display, g_fb_config);

                // It seems we *must* create a colormap when using OpenGL. If we don't, we get a BadMatch error.
                attributes_mask |= CWColormap;
                attributes.colormap = XCreateColormap(g_x11_display, RootWindow(g_x11_display, visual_info.screen), visual_info.visual, AllocNone);

                got_hw_rendering = true;

                log("Got framebuffer config for HW rendering.\n");
            }
            else{
                log("Unable to get framebuffer list. Falling back to software rendering.\n");
            }
            XFree(fbList);
        }

        XVisualInfo sw_visual_info; // This gives us storage for the visual info when using software rendering
        if(!got_hw_rendering){
            if(XMatchVisualInfo(g_x11_display, default_screen, 24, TrueColor, &sw_visual_info)){
                visual_info = &sw_visual_info;
            }
            else{
                log("Unable to match visual for window.\n");
            }
        }

        //attributes.background_pixel = WhitePixel(g_x11_display, visual_info.screen);
        attributes.background_pixel = BlackPixel(g_x11_display, visual_info.screen);

        if(visual_info){
            XWindow xwindow = XCreateWindow(
                g_x11_display, RootWindow(g_x11_display, visual_info.screen), 0, 0, width, height, 0,
                visual_info.depth, InputOutput, visual_info.visual, attributes_mask, &attributes
            );
            if(xwindow){
                result.handle           = xwindow;
                result.screen           = visual_info.screen;
                result.bit_depth        = visual_info.depth;
                result.visual           = visual_info.visual;
                result.graphics_context = DefaultGC(g_x11_display, visual_info.screen);

                /+
                // TODO: Set window flags here.
                auto user = &g_x11_window_info;
                user.width  = width;
                user.height = height;
+/
                XSetWMProtocols(g_x11_display, xwindow, &g_x11_atom_WMDeleteWindow, 1);
                XStoreName(g_x11_display, xwindow, window_title);
                XMapWindow(g_x11_display, xwindow);
                XSync(g_x11_display, False);
            }
        }

        if(got_hw_rendering){
            XFree(visual_info);
        }

        return result;
    }

    void close_window(Xlib_Window* w){
        if(w.handle)      XDestroyWindow(g_x11_display, w.handle);
    }

    public void close_display(){
        close_window(&g_xlib_window);
        //if(g_glx_context) glXDestroyContext(g_x11_display, g_glx_context);
        if(g_x11_display) XCloseDisplay(g_x11_display);
    }

    public void begin_frame(){

    }

    public void end_frame(){
        XFlush(g_x11_display);
    }

    void load_glx_extensions(const(char)[] extensions_string){
        auto reader = extensions_string;
        while(reader.length){
            auto name = reader;
            while(reader.length){
                if(reader[0] == ' '){
                    name = name[0 .. reader.ptr - name.ptr];
                    reader = reader[1..$];
                    break;
                }

                reader = reader[1..$];
            }

            if(name == "GLX_EXT_swap_control"){
                glxSwapIntervalEXT = cast(glXSwapIntervalEXTFunc)glXGetProcAddressARB(cast(ubyte*)"glXSwapIntervalEXT".ptr);
            }
            else if(name == "GLX_MESA_swap_control"){
                glxSwapIntervalMESA = cast(glXSwapIntervalMESAFunc)glXGetProcAddressARB(cast(ubyte*)"glXSwapIntervalMESA".ptr);
            }
            else if(name == "GLX_SGI_swap_control"){
                glxSwapIntervalSGI = cast(glXSwapIntervalSGIFunc)glXGetProcAddressARB(cast(ubyte*)"glXSwapIntervalSGI".ptr);
            }
            else if(name == "GLX_ARB_create_context" || name == "GLX_ARB_create_context_profile"){
                if(!glxCreateContextAttribsARB){
                    glxCreateContextAttribsARB = cast(glXCreateContextAttribsARBFunc)glXGetProcAddressARB(cast(ubyte*)"glXCreateContextAttribsARB".ptr);
                }
            }
        }
    }

    void send_fullscreen_toggle_request(){
        // NOTE(tspike): See here for discussions on making an X11 app fullscreen:
        // https://stackoverflow.com/a/10900462
        // https://stackoverflow.com/a/17576405
        XEvent fsEvt = {};
        fsEvt.xclient.type         = ClientMessage;
        fsEvt.xclient.serial       = 0;
        fsEvt.xclient.send_event   = True;
        fsEvt.xclient.window       = g_xlib_window.handle;
        fsEvt.xclient.message_type = g_x11_atom_WMState;
        fsEvt.xclient.format       = 32;
        fsEvt.xclient.data.l[0]    = 2; // NOTE(tspike): 2 == _NET_WM_STATE_TOGGLE
        fsEvt.xclient.data.l[1]    = g_x11_atom_WMStateFullscreen;

        XSendEvent(g_x11_display, DefaultRootWindow(g_x11_display), False, SubstructureRedirectMask | SubstructureNotifyMask, &fsEvt);
    }

    public bool next_event(Event* evt){
        bool event_translated = false;

        while(!event_translated && XEventsQueued(g_x11_display, QueuedAlready)){
            XEvent xevt;
            XNextEvent(g_x11_display, &xevt);
            event_translated = process_event(&xevt, evt);
        }

        return event_translated;
    }

    bool process_event(XEvent *xevt, Event *evt){
        bool event_translated = false;

        switch(xevt.type){
            default: break;

            case ClientMessage:{
                if(g_x11_atom_WMDeleteWindow == cast(Atom)xevt.xclient.data.l[0]){
                    event_translated = true;
                    evt.type = Event_Type.Window_Close;
                }
            } break;

            case GenericEvent:{
                if(xevt.xcookie.extension == g_libXI_extension_opcode && XGetEventData(g_x11_display, &xevt.xcookie)){
                    assert(g_use_XI2_for_mouse);

                    XIRawEvent* raw = cast(XIRawEvent*)xevt.xcookie.data;
                    // Filter out events from the master pointer device because (long ago) we would never get button release from the device.
                    // TODO: Is this really still an issue?
                    if(raw.deviceid != g_libXI_master_pointer_device){
                        switch(xevt.xcookie.evtype){
                            case XI_RawMotion:{
                                if(raw.valuators.mask_len > 0){
                                    auto mouse = &evt.mouse_motion;
                                    *mouse = zero_type!(typeof(*mouse));

                                    mouse.type = Event_Type.Mouse_Motion;
                                    // TODO: Make sure this is correct. Do the valuators always map to the x axis to 0 and the y axis to 1?
                                    if (XIMaskIsSet(raw.valuators.mask, 0)){
                                        mouse.rel_x = raw.raw_values[0];
                                    }

                                    if (XIMaskIsSet(raw.valuators.mask, 1)){
                                        mouse.rel_y = raw.raw_values[1];
                                    }
                                    mouse.pixel_x = g_last_mouse_x;
                                    mouse.pixel_y = g_last_mouse_y;
                                    event_translated = true;
                                }
                            } break;

/+
                            // TODO: Handle mouse button presses.
                            case XI_RawButtonPress:
                            case XI_RawButtonRelease:
                            {
                                bool isDown = evt.xcookie.evtype == XI_RawButtonPress;
                                // TODO: Test to make sure this is standard! Should we allow button mapping for mice?
                                if (raw.detail == 1)
                                {
                                    processButton(&mouse.buttons[MBUTTON_LEFT], isDown, time);
                                }
                                else if (raw.detail == 2)
                                {
                                    processButton(&mouse.buttons[MBUTTON_MIDDLE], isDown, time);
                                }
                                else if (raw.detail == 3)
                                {
                                    processButton(&mouse.buttons[MBUTTON_RIGHT], isDown, time);
                                }
                                else if (raw.detail == 4)
                                {
                                    mouse.wheel = -1.0f;
                                }
                                else if (raw.detail == 5)
                                {
                                    mouse.wheel = 1.0f;
                                }

                                //logInfo("Mouse detail: {0}\n", raw.detail);
                            } break;
+/

                            default:
                            {
                                assert(!"Unknown raw mouse event type!");
                            } break;
                        }
                    }
                }

                XFreeEventData(g_x11_display, &xevt.xcookie);
            } break;

            case ButtonRelease:
            case ButtonPress:{
                event_translated = true;
                evt.type = Event_Type.Button;
                evt.button.pressed = xevt.type == ButtonPress;

                switch(xevt.xbutton.button){
                    default:
                        event_translated = false;
                        break;

                    case Button1: evt.button.id = Button_ID.Mouse_Left;  break;
                    case Button3: evt.button.id = Button_ID.Mouse_Right; break;
                }
            } break;

            case ConfigureNotify:{
                g_window_info.width  = xevt.xconfigure.width;
                g_window_info.height = xevt.xconfigure.height;
            } break;

            case MotionNotify:{
                // TODO: Find out what motion hints are and if we need them.
                // TODO: If we can't use XInput2 for raw mouse, send an event using this instead.
                // Should we use the warp cursor hack for motion in that case? I think we can only do that
                // if we have the mouse grabbed. We should probably just use the delta from the last mouse
                // motion.
                g_last_mouse_x = xevt.xmotion.x;
                g_last_mouse_y = xevt.xmotion.y;
            } break;

            case KeyPress:
            case KeyRelease:{
                KeySym keycode    = XLookupKeysym(&xevt.xkey, 0);
                auto is_repeat    = consume_weird_key_repeat_events(xevt, keycode);
                bool just_pressed = xevt.type == KeyPress;

                // NOTE: Enter fullscreen.
                if (xevt.xkey.state & Mod1Mask && keycode == XK_Return){
                    if(!is_repeat && just_pressed){
                        // NOTE(tspike): Mod1Mask == alt key. See here for more info:
                        // https://stackoverflow.com/a/29001687
                        send_fullscreen_toggle_request();
                        break;
                    }
                }

                event_translated = true;

                if(xevt.xkey.state & ControlMask){
                    evt.key.modifier |= Key_Modifier_Ctrl;
                }

                evt.type          = Event_Type.Key;
                evt.key.pressed   = just_pressed;
                evt.key.is_repeat = is_repeat;

                switch(keycode){
                    default:
                        event_translated = false;
                        break;

                    case XK_A:
                    case XK_a:
                        evt.key.id = Key_ID_A; break;

                    case XK_B:
                    case XK_b:
                        evt.key.id = Key_ID_B; break;

                    case XK_C:
                    case XK_c:
                        evt.key.id = Key_ID_C; break;

                    case XK_D:
                    case XK_d:
                        evt.key.id = Key_ID_D; break;

                    case XK_E:
                    case XK_e:
                        evt.key.id = Key_ID_E; break;

                    case XK_F:
                    case XK_f:
                        evt.key.id = Key_ID_F; break;

                    case XK_G:
                    case XK_g:
                        evt.key.id = Key_ID_G; break;

                    case XK_H:
                    case XK_h:
                        evt.key.id = Key_ID_H; break;

                    case XK_I:
                    case XK_i:
                        evt.key.id = Key_ID_I; break;

                    case XK_J:
                    case XK_j:
                        evt.key.id = Key_ID_J; break;

                    case XK_K:
                    case XK_k:
                        evt.key.id = Key_ID_K; break;

                    case XK_L:
                    case XK_l:
                        evt.key.id = Key_ID_L; break;

                    case XK_M:
                    case XK_m:
                        evt.key.id = Key_ID_M; break;

                    case XK_N:
                    case XK_n:
                        evt.key.id = Key_ID_N; break;

                    case XK_O:
                    case XK_o:
                        evt.key.id = Key_ID_O; break;

                    case XK_P:
                    case XK_p:
                        evt.key.id = Key_ID_P; break;

                    case XK_Q:
                    case XK_q:
                        evt.key.id = Key_ID_Q; break;

                    case XK_R:
                    case XK_r:
                        evt.key.id = Key_ID_R; break;

                    case XK_S:
                    case XK_s:
                        evt.key.id = Key_ID_S; break;

                    case XK_T:
                    case XK_t:
                        evt.key.id = Key_ID_T; break;

                    case XK_U:
                    case XK_u:
                        evt.key.id = Key_ID_U; break;

                    case XK_V:
                    case XK_v:
                        evt.key.id = Key_ID_V; break;

                    case XK_W:
                    case XK_w:
                        evt.key.id = Key_ID_W; break;

                    case XK_X:
                    case XK_x:
                        evt.key.id = Key_ID_X; break;

                    case XK_Y:
                    case XK_y:
                        evt.key.id = Key_ID_Y; break;

                    case XK_Z:
                    case XK_z:
                        evt.key.id = Key_ID_Z; break;

                    case XK_F1:
                        evt.key.id = Key_ID_F1; break;

                    case XK_F2:
                        evt.key.id = Key_ID_F2; break;

                    case XK_F3:
                        evt.key.id = Key_ID_F3; break;

                    case XK_F4:
                        evt.key.id = Key_ID_F4; break;

                    case XK_F5:
                        evt.key.id = Key_ID_F5; break;

                    case XK_F6:
                        evt.key.id = Key_ID_F6; break;

                    case XK_F7:
                        evt.key.id = Key_ID_F7; break;

                    case XK_F8:
                        evt.key.id = Key_ID_F8; break;

                    case XK_F9:
                        evt.key.id = Key_ID_F9; break;

                    case XK_F10:
                        evt.key.id = Key_ID_F10; break;

                    case XK_F11:
                        evt.key.id = Key_ID_F11; break;

                    case XK_F12:
                        evt.key.id = Key_ID_F12; break;

                    case XK_Up:
                        evt.key.id = Key_ID_Arrow_Up; break;

                    case XK_Down:
                        evt.key.id = Key_ID_Arrow_Down; break;

                    case XK_Left:
                        evt.key.id = Key_ID_Arrow_Left; break;

                    case XK_Right:
                        evt.key.id = Key_ID_Arrow_Right; break;

                    case XK_Return:
                        evt.key.id = Key_ID_Enter; break;

                    case XK_Delete:
                        evt.key.id = Key_ID_Delete; break;

                    case XK_Escape:
                        evt.key.id = Key_ID_Escape; break;
                }
            } break;
        }
        return event_translated;
    }

    bool consume_weird_key_repeat_events(XEvent *evt, KeySym keycode){
        // When a keyboard key is first pressed, a Key Press event is generated. If the key is held
        // down, Operating Systems will typically generate additional Key Press events at regular
        // intervals. Xlib does this, as most users would expect. Before each repeat Key Press
        // event, however, a Key Release event is misleadingly generated.
        //
        // Calling this function will check for these events, returning true if one was found. It
        // will then consume the Key Release event, replacing the "evt" parameter with the repeat
        // Key Press event.
        //
        // See here for more info:
        // https://groups.google.com/forum/#!topic/pyglet-users/KaF8RQb-ifc
        // https://stackoverflow.com/questions/2100654/ignore-auto-repeat-in-x11-applications
        // https://github.com/glfw/glfw/blob/master/src/x11_window.c
        assert(evt.type == KeyPress || evt.type == KeyRelease);
        bool result = false;
        if(evt.type == KeyRelease && XEventsQueued(g_x11_display, QueuedAlready)){
            XEvent peek_evt;
            XPeekEvent(g_x11_display, &peek_evt);
            if(peek_evt.type == KeyPress && XLookupKeysym(&peek_evt.xkey, 0) == keycode && (peek_evt.xkey.time - evt.xkey.time) < 20){
                XNextEvent(g_x11_display, evt);
                result = true;
            }
        }
        return result;
    }
}
