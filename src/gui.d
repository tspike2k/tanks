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

enum Window_Border_Size = 4;

struct Gui_State{
    List!Window windows;

    Shader* rect_shader;
    Shader* text_shader;
    Font*   font;

    Vec2 cursor_pos;

    Gui_Action action;
    Gui_ID active_id;
    Vec2 grab_offset;
}

enum Gui_Action : uint{
    None,
    Dragging_Window,
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

Rect get_titlebar_bounds(Window* window){
    auto font   = window.gui.font;
    float title_bar_height = font.metrics.height + Window_Border_Size*2;

    auto r      = window.bounds;
    auto min_p  = Vec2(left(r), top(r)) - Vec2(0, title_bar_height);
    auto result = rect_from_min_wh(min_p, width(r), title_bar_height);
    return result;
}

Window* get_window_under_cursor(Gui_State* gui){
    Window* result;

    auto window = gui.windows.top;
    while(window != cast(Window*)&gui.windows){
        if(is_point_inside_rect(gui.cursor_pos, window.bounds)){
            result = window;
            break;
        }

        window = window.prev;
    }

    return result;
}

Rect get_work_area(Window* window){
    auto gui  = window.gui;
    auto r    = window.bounds;
    auto font = gui.font;

    auto title_bar_bounds = get_titlebar_bounds(window);
    auto border = Vec2(Window_Border_Size, Window_Border_Size);
    auto min_p = Vec2(left(r), bottom(r)) + border;
    auto max_p = min_p + Vec2(width(r), height(r)) - Vec2(0, height(title_bar_bounds)) - border*2.0f;
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
        render_text(pass, gui.font, title_baseline, window.name); // TODO: Center on X
    }
}

Window* get_window_by_id(Gui_State* gui, Gui_ID window_id){
    Window* result;
    foreach(window; gui.windows.iterate()){
        if(window.id == window_id){
            result = window;
        }
    }
    return result;
}

import display;

bool handle_event(Gui_State* gui, Event* evt){
    auto display_window = get_window_info();

    bool consumed = false;

    switch(evt.type){
        default: break;

        case Event_Type.Mouse_Motion:{
            auto motion = &evt.mouse_motion;
            // TODO: Invert motion.pixel_y in display.d. This way we don't have to flip the coord
            // all the time.
            gui.cursor_pos = Vec2(motion.pixel_x, display_window.height - motion.pixel_y);
            if(gui.action == Gui_Action.Dragging_Window){
                auto window = get_window_by_id(gui, gui.active_id);
                if(window){
                    window.bounds.center = gui.cursor_pos + gui.grab_offset;
                }
                else{
                    gui.action = Gui_Action.None;
                }
            }
        } break;

        case Event_Type.Button:{
            auto btn = &evt.button;
            switch(btn.id){
                default: break;

                case Button_ID.Mouse_Left:{
                    if(btn.pressed){
                        auto window = get_window_under_cursor(gui);
                        if(window){
                            auto titlebar_bounds = get_titlebar_bounds(window);
                            if(is_point_inside_rect(gui.cursor_pos, titlebar_bounds)){
                                // TODO: Raise window
                                gui.action      = Gui_Action.Dragging_Window;
                                gui.active_id   = window.id;
                                gui.grab_offset = window.bounds.center - gui.cursor_pos;

                                consumed = true;
                            }
                        }
                    }
                    else{
                        gui.action = Gui_Action.None;
                    }
                } break;

                case Button_ID.Mouse_Right:{
                } break;
            }
        } break;
    }

    return consumed;
}


