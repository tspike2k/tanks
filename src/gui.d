/*
Copyright (c) 2025 tspike2k@github.com
Distributed under the Boost Software License, Version 1.0.
See accompanying file LICENSE_BOOST.txt or copy at http://www.boost.org/LICENSE_1_0.txt
*/

/+
    This GUI library is primarily intended for the editor, but it would be nice if we could
    make it work for game menus. It is based on a conversation between Casey Muratori and
    Jonathan Blow which was streamed on Twitch approximately on 2021/02/21. Muratori explained
    he had been using a technique of reserving a region of memory for each GUI window. This
    region of memory would act as a command buffer into which layout information and widgets
    would be pushed.
+/

import app;
import render;
import math;
import memory;
import assets : Font;
import display;

enum  Null_Gui_ID = 0;
alias Gui_ID = uint;

enum Button_Padding      = 4;
enum Window_Border_Size  = 4;
enum Window_Min_Width    = 200;
enum Window_Min_Height   = 140;
enum Window_Resize_Slack = 4; // Additional space for grabbing window border for resize operation

struct Gui_State{
    List!Window windows;
    Font*   font;

    Vec2 cursor_pos;

    Gui_ID message_id;
    Gui_ID hover_widget;

    Gui_ID active_id;
    Gui_Action action;
    uint window_resize_flags;
    Vec2 grab_offset;

    Text_Buffer text_buffer;
    Window* edit_window;

    // "Events" that are passed to widgets.
    //
    // TODO: Would it be better to have a "handle_event" function for
    // widgets and pass the event to the widget directly? It would
    // complicate the widget code.
    //
    // TODO: If we do keep with this, we could probably compress down all the gui
    // events into bit flags.
    bool mouse_left_pressed;
    bool mouse_left_released;
}

enum Gui_Action : uint{
    None,
    Dragging_Window,
    Resizing_Window,
}

enum Window_Resize_Flag : uint{
    None     = 0,
    Left     = (1 << 0),
    Right    = (1 << 1),
    Bottom   = (1 << 2),
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
    gs.hover_widget = Null_Gui_ID;
}

void begin_window(Gui_State* gui, Gui_ID id, String window_name, Rect bounds, void[] buffer){
    auto width  = max(width(bounds), Window_Min_Width);
    auto height = max(height(bounds), Window_Min_Height);
    auto bbox   = rect_from_min_wh(Vec2(left(bounds), top(bounds) - height), width, height);

    auto result = cast(Window*)buffer;
    clear_to_zero(*result);
    result.name   = window_name;
    result.id     = id;
    result.bounds = bbox;
    result.gui    = gui;
    result.buffer = buffer[Window.sizeof .. $];
    result.dirty  = true;

    gui.windows.insert(gui.windows.top, result);
    gui.edit_window = result;
}

void end_window(Gui_State* gui){
    gui.edit_window = null;
}

void remove_window(Window* window){
    auto gui = window.gui;
    gui.windows.remove(window);
}

bool window_has_focus(Window* window){
    bool result = window == window.gui.windows.top;
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

    auto slack_extents = Vec2(Window_Resize_Slack, Window_Resize_Slack)*0.5f;
    auto window = gui.windows.top;
    while(window != cast(Window*)&gui.windows){
        if(is_point_inside_rect(gui.cursor_pos, expand(window.bounds, slack_extents))){
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

void render_button_bounds(Render_Pass* pass, Rect r, bool pressed_down){
    auto thickness = 1.0f;
    auto b = thickness * 0.5f;
    auto top    = Rect(r.center + Vec2(0, r.extents.y - b), Vec2(r.extents.x, b));
    auto bottom = Rect(r.center - Vec2(0, r.extents.y - b), Vec2(r.extents.x, b));
    auto left   = Rect(r.center - Vec2(r.extents.x - b, 0), Vec2(b, r.extents.y));
    auto right  = Rect(r.center + Vec2(r.extents.x - b, 0), Vec2(b, r.extents.y));

    auto top_color    = Vec4(1, 1, 1, 1);
    auto bottom_color = Vec4(0, 0, 0, 1);
    if(pressed_down){
        swap(top_color, bottom_color);
    }

    render_rect(pass, top, top_color);
    render_rect(pass, left, top_color);
    render_rect(pass, bottom, bottom_color);
    render_rect(pass, right, bottom_color);
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

//
// Window Commands (Widgets, layout, etc)
//

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
    Text_Field,
    Custom,
}

// TODO: Should each widget have a flags field? This field could be used to determine bahavior
// (does the widget send an event when mouse is released on it like a button, is the widget
// currenly disable, etc). If we did this, the gui wouldn't have to know the type of the widget
// to update it correctly, and would even allow custom widgets to use standard bahavior.
// I rather like this.
struct Widget{
    Gui_ID      id;
    Widget_Type type;
    Rect        rel_bounds; // NOTE: X, Y positions set by the layout routine, width and height requested by the widget
}

struct Button{
    enum Type = Widget_Type.Button;
    Widget widget;
    alias widget this;

    String label;
    bool   disabled;
}

/+
TODO: There's two ways I can think of to design text fields:
    1) Each text field stores the destination buffer and writes to it directly. This is the ideal
    way of doing it, since it would waste very little memory. This does mean the destination
    need to be allocated before the window is created. But perhaps that a better way of handling
    it.

    2) Each field stores an internal buffer allocated using the command buffer for the window.
    This means the memory is freed automatically with the window. The good part is the destination
    buffer can be allocated at any point. The issue is, the destination buffer size would need to
    match the size of the internal buffer. In case they don't match we'd need to truncate the
    result as we copy. Plus, the copy is silly anyway.
+/
struct Text_Field{
    enum Type = Widget_Type.Text_Field;
    Widget widget;
    alias widget this;

    char[] buffer;
    uint*  used;
}

struct Label{
    enum Type = Widget_Type.Label;
    Widget widget;
    alias widget this;

    String text;
}

/+
Serializer begin_window_cmd(Gui_State* gui, Window_Cmd_Type type){

    auto dest = Serializer(window.buffer[window.buffer_used .. $]);
    auto entry = eat_type!Window_Cmd(&dest);
    entry.type = type;
    entry.size = 0;

    return dest;
}

void end_window_cmd(Window* window, Serializer* buffer){
    auto header = cast(Window_Cmd*)buffer.buffer;
    assert(buffer.buffer_used >= Window_Cmd.sizeof);
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
+/

Gui_ID window_id_from_widget_id(Gui_ID widget_id){
    Gui_ID result = (widget_id >> 16) & 0xfffff;
    return result;
}

void[] begin_widget(Gui_State* gui, Gui_ID id, Widget_Type type, uint size){
    void[] result;

    auto window_id = window_id_from_widget_id(id);
    if(gui.edit_window){
        auto window = gui.edit_window;
        assert(window.id == window_id);

        auto cmd = cast(Window_Cmd*)push_to_command_buffer(window, Window_Cmd.sizeof);
        cmd.type = Window_Cmd_Type.Widget;
        cmd.size = size;

        result = push_to_command_buffer(window, size);
        clear_to_zero(result);
        auto widget = cast(Widget*)result;
        widget.id   = id;
        widget.type = type;
    }
    else{
        auto window = get_window_by_id(gui, window_id);
        // TODO: Lookup acceleration structure
        foreach(ref widget; iterate_widgets(window)){
            if(widget.id == id){
                auto raw = cast(void*)widget;
                result = raw[0 .. size];
            }
        }
    }

    return result;
}

void end_widget(Gui_State* gui, Widget* widget, float w, float h){
    widget.rel_bounds.extents = Vec2(w, h)*0.5f;
}

void button(Gui_State* gui, Gui_ID id, String label, bool disabled = false){
    auto font = gui.font;

    auto btn = cast(Button*)begin_widget(gui, id, Widget_Type.Button, Button.sizeof);

    btn.label    = label;
    btn.disabled = disabled;
    float w = get_text_width(font, label) + Button_Padding*2.0f;
    float h = font.metrics.height + Button_Padding*2.0f;

    end_widget(gui, &btn.widget, w, h);
}

void text_field(Gui_State* gui, Gui_ID id, char[] buffer, uint* buffer_used){
/+
    auto font = window.gui.font;

    auto writer = begin_window_cmd(window, Window_Cmd_Type.Widget);
    float w = 200.0f;
    float h = font.metrics.height + Button_Padding*2.0f;
    auto widget = push_widget!Text_Field(&writer, id, w, h);
    widget.buffer = buffer;
    widget.used = buffer_used;

    end_window_cmd(window, &writer);+/
}

void label(Gui_State* gui, Gui_ID id, String text){
/+
    auto font = window.gui.font;

    auto writer = begin_window_cmd(window, Window_Cmd_Type.Widget);

    float w = get_text_width(font, text) + Button_Padding*2.0f;
    float h = font.metrics.height + Button_Padding*2.0f;
    auto widget = push_widget!Label(&writer, id, w, h);
    widget.text = text;

    end_window_cmd(window, &writer);+/
}

void next_row(Gui_State* gui){
    auto cmd = cast(Window_Cmd*)push_to_command_buffer(gui.edit_window, Window_Cmd.sizeof);
    cmd.type = Window_Cmd_Type.Next_Row;
    cmd.size = 0;
}

void raise_window(Window* window){
    auto gui = window.gui;
    gui.windows.remove(window);
    gui.windows.insert(gui.windows.top, window);
}

/+
bool inside_window_resize_bounds(Vec2 cursor, Rect bounds){
    assert(is_point_inside_rect(cursor, bounds));

    float padding = 4;
    auto l = left(bounds);
    bool result = (cursor.x >= l && cursor.x <= l + Window_Border_Size + padding);
    return result;
}+/

uint get_window_resize_flags(Vec2 cursor, Rect bounds){
    auto l = left(bounds);
    auto r = right(bounds);
    auto b = bottom(bounds);
    float slack = Window_Resize_Slack;

    auto result = Window_Resize_Flag.None;
    if(cursor.x >= l - slack && cursor.x <= l + Window_Border_Size){
        result |= Window_Resize_Flag.Left;
    }
    else if(cursor.x <= r + slack && cursor.x >= r - Window_Border_Size){
        result |= Window_Resize_Flag.Right;
    }

    if(cursor.y >= b - slack && cursor.y <= b + Window_Border_Size){
        result |= Window_Resize_Flag.Bottom;
    }

    return result;
}

auto iterate_widgets(Window* window){
    struct Range{
        Serializer buffer;
        Widget* front;

        bool empty(){
            bool result = !front;
            return result;
        }

        void popFront(){
            front = null;
            while(auto cmd = eat_type!Window_Cmd(&buffer)){
                auto cmd_memory = eat_bytes(&buffer, cmd.size);
                if(cmd.type == Window_Cmd_Type.Widget){
                    front = cast(Widget*)cmd_memory;
                    break;
                }
            }
        }
    }

    auto result = Range(Serializer(window.buffer[0 .. window.buffer_used]));
    result.popFront(); // Prime the "pump"
    return result;
}

bool handle_event(Gui_State* gui, Event* evt){
    auto display_window = get_window_info();

    bool consumed = false;
    // Unfortunately, D can't deduce which handle_event function we mean without specifying
    // the module name.
    if(is_text_input_enabled() && display.handle_event(&gui.text_buffer, evt)){
        consumed = true;
    }
    else{
        switch(evt.type){
            default: break;

            // TODO: Should we move most of the Window Action handling code into update_gui?
            // We do need to be able to flag mouse clicks as consumed, but that's about all.
            // We could sum all the mouse motion events, for instance.

            case Event_Type.Mouse_Motion:{
                auto motion = &evt.mouse_motion;
                // TODO: Invert motion.pixel_y in display.d. This way we don't have to flip the coord
                // all the time.
                gui.cursor_pos = Vec2(motion.pixel_x, display_window.height - motion.pixel_y);
                auto cursor = gui.cursor_pos;
                if(gui.action == Gui_Action.Dragging_Window){
                    auto window = get_window_by_id(gui, gui.active_id);
                    if(window){
                        window.bounds.center = gui.cursor_pos + gui.grab_offset;
                    }
                    else{
                        gui.action = Gui_Action.None;
                    }
                }
                else if(gui.action == Gui_Action.Resizing_Window){
                    auto window = get_window_by_id(gui, gui.active_id);
                    if(window){
                        if(gui.window_resize_flags & Window_Resize_Flag.Left){
                            auto delta_x = left(window.bounds) - cursor.x;
                            auto next_w  = max(width(window.bounds) + delta_x, Window_Min_Width);
                            window.bounds = rect_from_min_wh(
                                Vec2(right(window.bounds) - next_w, bottom(window.bounds)),
                                next_w, height(window.bounds)
                            );
                        }
                        else if(gui.window_resize_flags & Window_Resize_Flag.Right){
                            auto delta_x = cursor.x - right(window.bounds);
                            auto next_w  = max(width(window.bounds) + delta_x, Window_Min_Width);
                            window.bounds = rect_from_min_wh(min(window.bounds), next_w, height(window.bounds));
                        }

                        if(gui.window_resize_flags & Window_Resize_Flag.Bottom){
                            auto delta_y = bottom(window.bounds) - cursor.y;
                            auto next_h  = max(height(window.bounds) + delta_y, Window_Min_Height);
                            auto min_p = min(window.bounds);
                            window.bounds = rect_from_min_wh(
                                Vec2(left(window.bounds), top(window.bounds) - next_h),
                                width(window.bounds), next_h
                            );
                        }
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
                            auto cursor = gui.cursor_pos;
                            gui.mouse_left_pressed = true;

                            if(window){
                                consumed = true;
                                if(is_point_inside_rect(cursor, window.bounds)
                                && !window_has_focus(window)){
                                    raise_window(window);
                                }

                                auto titlebar_bounds = get_titlebar_bounds(window);
                                auto resize_flags = get_window_resize_flags(gui.cursor_pos, window.bounds);
                                if(resize_flags != Window_Resize_Flag.None){
                                    gui.action      = Gui_Action.Resizing_Window; // TODO: Rename this Window_Action?
                                    gui.active_id   = window.id;
                                    gui.grab_offset = window.bounds.center - gui.cursor_pos;
                                    gui.window_resize_flags = resize_flags;
                                }
                                else if(is_point_inside_rect(cursor, titlebar_bounds)){
                                    gui.action      = Gui_Action.Dragging_Window;
                                    gui.active_id   = window.id;
                                    gui.grab_offset = window.bounds.center - gui.cursor_pos;
                                }
                            }
                            else{
                                gui.action = Gui_Action.None;
                            }
                        }
                        else{
                            gui.mouse_left_released = true;
                            gui.action = Gui_Action.None;
                        }
                    } break;

                    case Button_ID.Mouse_Right:{
                    } break;
                }
            } break;
        }
    }

    return consumed;
}

void do_layout(Window* window){
    auto gui = window.gui;

    auto work_area = get_work_area(window);
    auto padding = Vec2(Window_Border_Size, Window_Border_Size); // TODO: Should this be called "margin?"
    auto pen = padding; // Pen is from the top-left

    float max_row_height = 0;
    auto buffer = Serializer(window.buffer[0 .. window.buffer_used]);
    while(auto cmd = eat_type!Window_Cmd(&buffer)){
        switch(cmd.type){
            default:
                eat_bytes(&buffer, cmd.size); break;

            case Window_Cmd_Type.Next_Row:{
                pen.y += max_row_height + padding.y;
                max_row_height = 0;
                pen.x = padding.x;
            } break;

            case Window_Cmd_Type.Widget:{
                auto widget = cast(Widget*)eat_bytes(&buffer, cmd.size);

                widget.rel_bounds.center = pen + widget.rel_bounds.extents;
                pen.x += width(widget.rel_bounds) + padding.x;
                max_row_height = max(max_row_height, height(widget.rel_bounds));
            } break;
        }
    }
}

Rect get_widget_bounds(Rect window_work_area, Widget* widget){
    auto top_left = Vec2(left(window_work_area), top(window_work_area));

    // rel_bounds are relative to the top-left of the work area of the window
    // (window bounds excluding border and titlebar). Therefore we need to
    // flip the y coordinate of the widget center.
    auto result = Rect(
        top_left + Vec2(widget.rel_bounds.center.x, -widget.rel_bounds.center.y),
        widget.rel_bounds.extents
    );
    return result;
}

void update_gui(Gui_State* gui, float dt){
    gui.message_id        = Null_Gui_ID;
    Widget* hover_widget  = null;
    Widget* active_widget = null;
    Gui_ID  next_hover_window_id = Null_Gui_ID;

    auto cursor = gui.cursor_pos;
    foreach(window; gui.windows.iterate!(-1)()){
        if(window.dirty){
            do_layout(window);
            window.dirty = false;
        }

        if(is_point_inside_rect(cursor, window.bounds)
        && next_hover_window_id == Null_Gui_ID)
            next_hover_window_id = window.id;

        // Search for the current hover widget
        auto work_area = get_work_area(window);
        foreach(ref widget; iterate_widgets(window)){
            auto bounds = get_widget_bounds(work_area, widget);
            if(next_hover_window_id == window.id
            && is_point_inside_rect(cursor, work_area)
            && is_point_inside_rect(cursor, bounds)){
                hover_widget = widget;
            }

            if(widget.id == gui.active_id){
                active_widget = widget;
            }

            // TODO: Update widgets that need updating even when they're not the
            // active widget here. Also, call the update_custom_widgets function
            // (when we add it) here.
        }
    }

    if(gui.action == Gui_Action.None){
        if(gui.mouse_left_pressed){
            gui.active_id = Null_Gui_ID;
            if(hover_widget){
                // TODO: Deactivate text input mode if we already activated it. This is important if
                // the previously actvie widget it a text field and the next one is as well.
                // TODO: Maybe we souldn't even have a text input mode. Perhaps we should just
                // generate those events and ignore them if we don't care. That might be best.
                if(hover_widget.type == Widget_Type.Text_Field && hover_widget.id != gui.active_id){
                    auto field = cast(Text_Field*)hover_widget;
                    set_text_input_status(true);
                    set_buffer(&gui.text_buffer, field.buffer, (*field.used), 0); // TODO: Set cursor based on click position.
                }
                else{
                    set_text_input_status(false);
                }

                gui.active_id = hover_widget.id;
            }
            else{
                set_text_input_status(false);
            }
        }

        if(gui.mouse_left_released && active_widget){
            if(active_widget.type != Widget_Type.Text_Field){
                gui.active_id = Null_Gui_ID;
                if(hover_widget == active_widget){
                    gui.message_id = active_widget.id;
                }
            }
        }

        gui.hover_widget = Null_Gui_ID;
        if(hover_widget){
            gui.hover_widget = hover_widget.id;
        }

        // Update the active widget.
        if(active_widget){
            if(active_widget.type == Widget_Type.Text_Field){
                auto field = cast(Text_Field*)active_widget;
                (*field.used) = gui.text_buffer.used;
            }
        }
    }

    // Clear event flags
    gui.mouse_left_pressed  = false;
    gui.mouse_left_released = false;
}

void render_gui(Gui_State* gui, Camera_Data* camera_data, Shader* shader_rects, Shader* shader_text){
    foreach(window; gui.windows.iterate()){
        auto rp_rects = add_render_pass(camera_data);
        set_shader(rp_rects, shader_rects);
        rp_rects.flags = Render_Flag_Disable_Depth_Test;

        auto rp_text = add_render_pass(camera_data);
        set_shader(rp_text, shader_text);
        rp_text.flags = Render_Flag_Disable_Depth_Test;

        // TODO: Clamp text to pixel boundaries?
        Vec4 seperator_color = Vec4(0.22f, 0.23f, 0.24f, 1.0f);
        Vec4 internal_color = Vec4(0.86f, 0.90f, 0.97f, 1.0f);
        if(window_has_focus(window)){
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

        auto font = gui.font;
        auto title_baseline = center_text(font, window.name, title_bounds);
        render_text(rp_text, gui.font, title_baseline, window.name, Vec4(1, 1, 1, 1)); // TODO: Center on X

        // Account for work area outline.
        // TODO: Make it so render_rect_outline draws an outline *inside* the given
        // rectangle instead?
        auto scissor_area = shrink(work_area, Vec2(1, 1));
        push_scissor(rp_rects, scissor_area);
        push_scissor(rp_text, scissor_area);

        foreach(ref widget; iterate_widgets(window)){
            auto bounds = get_widget_bounds(work_area, widget);
            switch(widget.type){
                default: assert(0);

                case Widget_Type.Button:{
                    auto btn = cast(Button*)widget;
                    auto bg_color = Vec4(0.75f, 0.75f, 0.75f, 1);
                    if(gui.active_id == widget.id){
                        bg_color *= 0.75f;
                        bg_color.a = 1;
                    }
                    else if(gui.hover_widget == widget.id){
                        bg_color = Vec4(0.9f, 0.9f, 0.9f, 1);
                    }

                    render_rect(rp_rects, bounds, bg_color);
                    render_button_bounds(rp_rects, bounds, gui.active_id == widget.id);
                    auto baseline = center_text(font, btn.label, bounds);
                    render_text(rp_text, font, baseline, btn.label, Vec4(0, 0, 0, 1));
                } break;

                case Widget_Type.Text_Field:{
                    auto field = cast(Text_Field*)widget;
                    auto bg_color = Vec4(0.75f, 0.75f, 0.75f, 1);
                    if(gui.active_id == widget.id){
                        bg_color *= 0.75f;
                        bg_color.a = 1;
                    }
                    else if(gui.hover_widget == widget.id){
                        bg_color = Vec4(0.9f, 0.9f, 0.9f, 1);
                    }

                    auto text = field.buffer[0 .. (*field.used)];

                    render_rect(rp_rects, bounds, bg_color);
                    render_button_bounds(rp_rects, bounds, gui.active_id == widget.id);
                    auto baseline = center_text_left(font, text, bounds) + Vec2(Button_Padding, 0);
                    render_text(rp_text, font, baseline, text, Vec4(0, 0, 0, 1));
                } break;

                case Widget_Type.Label:{
                    auto label = cast(Label*)widget;
                    auto baseline = center_text_left(font, label.text, bounds) + Vec2(Button_Padding, 0);
                    render_text(rp_text, font, baseline, label.text, Vec4(0, 0, 0, 1));
                } break;
            }
        }

        pop_scissor(rp_rects);
        pop_scissor(rp_text);
    }
}

private:

void[] push_to_command_buffer(Window* window, size_t size){
    void[] result = window.buffer[window.buffer_used .. window.buffer_used + size];
    window.buffer_used += size;
    return result;
}
