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
import assets : Font;

alias Gui_ID = uint;

struct Gui_State{
    List!Window windows;

    Shader* rect_shader;
    Shader* text_shader;
    Font*   font;
}

struct Window{
    Window* next;
    Window* prev;

    String     name;
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
    result.name   = window_name;
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

bool window_has_focus(Gui_State* gui, Window* window){
    bool result = window == gui.windows.top;
    return result;
}

Rect get_work_area(Window* window){
    auto gui  = window.gui;
    auto r    = window.bounds;
    auto font = gui.font;

    auto border = Vec2(4, 4);
    auto title_bar_height = font.metrics.height + border.y*2;

    auto min_p = Vec2(left(r), bottom(r)) + border;
    auto max_p = min_p + Vec2(width(r), height(r)) - Vec2(0, title_bar_height) - border*2.0f;
    auto result = rect_from_min_max(min_p, max_p);

    return result;
}

void render_gui(Gui_State* gui, Render_Pass* pass){
    foreach(window; gui.windows.iterate()){
        set_shader(pass, gui.rect_shader);

        Vec4 seperator_color = Vec4(0.22f, 0.23f, 0.24f, 1.0f);

        Vec4 internal_color = Vec4(0.86f, 0.90f, 0.97f, 1.0f);
        Vec4 border_color = Vec4(0.4f, 0.4f, 0.45f, 1.0f);
        if(window_has_focus(gui, window)){
            border_color = Vec4(0.2f, 0.42f, 0.66f, 1.0f);
        }
        render_rect(pass, window.bounds, border_color);
        //render_rect_outline(pass, window.bounds, seperator_color);

        auto work_area = get_work_area(window);
        render_rect(pass, work_area, internal_color);

        auto title_baseline = Vec2(left(window.bounds), top(window.bounds)) - Vec2(0, 4 + gui.font.metrics.height);
        set_shader(pass, gui.text_shader);
        render_text(pass, gui.font, title_baseline, window.name);
    }
}
