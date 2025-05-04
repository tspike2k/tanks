/*
Copyright (c) 2025 tspike2k@github.com
Distributed under the Boost Software License, Version 1.0.
See accompanying file LICENSE_BOOST.txt or copy at http://www.boost.org/LICENSE_1_0.txt
*/

/+
    This GUI library is primarily intended for the editor, but it would be nice if we could
    make it work for game menus.
+/

import app;
import render;
import math;
import memory;

alias Gui_ID = uint;

struct Gui_State{
    List!Window windows;

    Shader* rect_shader;
    Shader* text_shader;
}

struct Window{
    Window* next;
    Window* prev;

    Gui_ID     id;
    Gui_State* gui;
    void[]     buffer;
    size_t     buffer_used;
    Rect       bounds;
}

void init_gui(Gui_State* gs){
    gs.windows.make();
}

Window* add_window(Gui_State* gui, String window_name, Gui_ID id, Rect bounds, void[] buffer){
    auto result = cast(Window*)buffer;
    clear_to_zero(*result);
    result.id     = id;
    result.bounds = bounds;
    result.gui    = gui;
    result.buffer = buffer;

    gui.windows.insert(gui.windows.top, result);
    return result;
}

void remove_window(Window* window){
    auto gui = window.gui;
    gui.windows.remove(window);
}

void render_gui(Gui_State* gui, Render_Pass* pass){
    foreach(window; gui.windows.iterate()){
        set_shader(pass, gui.rect_shader);
        render_rect(pass, window.bounds, Vec4(0, 0.15f, 0.25f, 1.0f));
    }
}
