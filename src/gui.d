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

enum  Null_Gui_ID = 0;
alias Gui_ID = uint;

enum Window_Border_Size = 4;

struct Gui_State{
    List!Window windows;

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
    bool       dirty; // Do we need to run layout algorithms?
}

pragma(inline) Gui_ID gui_id(uint window_id, uint widget_id = __LINE__){
    assert(widget_id <= 0xffff);
    assert(window_id <= 0xffff);
    Gui_ID result = 0;
    result |= (cast(uint)(window_id & 0xffff) << 16);
    result |= (cast(uint)(widget_id & 0xffff) << 0);
    assert(result != Null_Gui_ID);
    return result;
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
    result.buffer = buffer[Window.sizeof .. $];
    result.dirty  = true;

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

void render_button_bounds(Render_Pass* pass, Rect r, Vec4 top_color, Vec4 bottom_color){
    auto thickness = 1.0f;
    auto b = thickness * 0.5f;
    auto top    = Rect(r.center + Vec2(0, r.extents.y - b), Vec2(r.extents.x, b));
    auto bottom = Rect(r.center - Vec2(0, r.extents.y - b), Vec2(r.extents.x, b));
    auto left   = Rect(r.center - Vec2(r.extents.x - b, 0), Vec2(b, r.extents.y));
    auto right  = Rect(r.center + Vec2(r.extents.x - b, 0), Vec2(b, r.extents.y));

    render_rect(pass, top, top_color);
    render_rect(pass, left, top_color);
    render_rect(pass, bottom, bottom_color);
    render_rect(pass, right, bottom_color);
}

// TODO: Rather than have the GUI state store the shaders, we should send it two render passes:
// Each would be pre-set with the correct shader information. One would be for the rects and the
// other for the text. If we took this approach, we could simplify the render code in general.
void render_gui(Gui_State* gui, Render_Pass* rp_rects, Render_Pass* rp_text){
    foreach(window; gui.windows.iterate()){
        // TODO: Clamp text to pixel boundaries?
        Vec4 seperator_color = Vec4(0.22f, 0.23f, 0.24f, 1.0f);
        Vec4 internal_color = Vec4(0.86f, 0.90f, 0.97f, 1.0f);
        if(window_has_focus(gui, window)){
            render_rect(rp_rects, window.bounds, Vec4(0.2f, 0.42f, 0.66f, 1.0f));
            render_rect_outline(rp_rects, window.bounds, Vec4(1, 1, 1, 1), 1.0f);
        }
        else{
            render_rect(rp_rects, window.bounds, Vec4(0.4f, 0.4f, 0.45f, 1.0f));
            render_rect_outline(rp_rects, window.bounds, seperator_color, 1.0f);
        }

        auto title_bounds = get_titlebar_bounds(window);
        auto work_area    = get_work_area(window);
        render_rect(rp_rects, work_area, internal_color);
        render_rect_outline(rp_rects, work_area, seperator_color, 1.0f);

        // TODO: Begin scissor for the work area

        // TODO: We should have a window command buffer iterator.
        auto font = gui.font;
        auto buffer = Serializer(window.buffer[0 .. window.buffer_used]);
        while(auto cmd = eat_type!Window_Cmd(&buffer)){
            switch(cmd.type){
                default:
                    eat_bytes(&buffer, cmd.size); break;

                case Window_Cmd_Type.Widget:{
                    auto widget_data = eat_bytes(&buffer, cmd.size);
                    auto widget = cast(Widget*)widget_data;

                    auto bounds = Rect(widget.rel_bounds.center + min(work_area), widget.rel_bounds.extents);
                    switch(widget.type){
                        default: assert(0);

                        case Widget_Type.Button:{
                            auto btn = cast(Button*)widget_data;
                            render_rect(rp_rects, bounds, Vec4(0.75f, 0.75f, 0.75f, 1));
                            render_button_bounds(rp_rects, bounds, Vec4(1, 1, 1, 1), Vec4(0, 0, 0, 1));
                            render_text(rp_text, font, bounds.center, btn.label, Text_Align.Center_X);
                        } break;
                    }
                } break;
            }
        }

        // TODO: End scissor for the work area
        auto title_baseline = Vec2(title_bounds.center.x, top(title_bounds)) - Vec2(0, 4 + gui.font.metrics.height);
        render_text(rp_text, gui.font, title_baseline, window.name, Text_Align.Center_X); // TODO: Center on X
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

enum Window_Cmd_Type : uint{
    None,
    Widget,
    Layout,
    Next_Row,
}

struct Window_Cmd{
    Window_Cmd_Type type;
    uint            size;
}

enum Widget_Type : uint{
    None,
    Button,
    Label,
    Custom,
}

struct Widget{
    Gui_ID      id;
    Widget_Type type;
    Rect        rel_bounds; // NOTE: X, Y positions set by the layout routine, width and height requested by the widget
}

struct Button{
    enum Type = Widget_Type.Button;

    Widget widget;
    String label;
    bool   disabled;

    alias widget this;
}

Serializer begin_window_cmd(Window* window, Window_Cmd_Type type){
    auto dest = Serializer(window.buffer[window.buffer_used .. $]);
    auto entry = eat_type!Window_Cmd(&dest);
    entry.type = type;
    entry.size = 0;

    return dest;
}

void end_window_cmd(Window* window, Serializer* buffer){
    auto header = cast(Window_Cmd*)buffer.buffer;
    assert(buffer.buffer_used > Window_Cmd.sizeof);
    header.size = cast(uint)(buffer.buffer_used - Window_Cmd.sizeof);
    window.buffer_used += buffer.buffer_used;
}

T* push_widget(T)(Serializer* dest, Gui_ID id, float w, float h){
    auto widget = eat_type!T(dest);
    clear_to_zero(*widget);
    widget.id         = id;
    widget.type       = T.Type;
    widget.rel_bounds = Rect(Vec2(0, 0), Vec2(w, h)*0.5f);
    return widget;
}

void button(Window* window, Gui_ID id, String label, bool disabled = false){
    auto buffer = begin_window_cmd(window, Window_Cmd_Type.Widget);

    float w = 200;
    float h = 24;
    auto btn = push_widget!Button(&buffer, id, w, h);
    btn.label    = label;
    btn.disabled = disabled;

    end_window_cmd(window, &buffer);
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

void do_layout(Window* window){
    auto gui = window.gui;

    auto work_area = get_work_area(window);
    auto padding = Vec2(Window_Border_Size, -Window_Border_Size); // TODO: Should this be called "margin?"
    auto pen = Vec2(0, height(work_area)) + padding;

    auto buffer = Serializer(window.buffer[0 .. window.buffer_used]);
    while(auto cmd = eat_type!Window_Cmd(&buffer)){
        switch(cmd.type){
            default:
                eat_bytes(&buffer, cmd.size); break;

            case Window_Cmd_Type.Widget:{
                auto widget_data = eat_bytes(&buffer, cmd.size);
                auto widget = cast(Widget*)widget_data;

                auto w = width(widget.rel_bounds);
                auto h = height(widget.rel_bounds);

                widget.rel_bounds.center = pen + Vec2(w, -h)*0.5f;
                pen.x += w + padding.x;
            } break;
        }
    }
}

void update_gui(Gui_State* gui, float dt){
    foreach(window; gui.windows.iterate()){
        if(window.dirty){
            do_layout(window);
            window.dirty = false;
        }
    }
}
