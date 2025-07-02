/*
Authors:   tspike (github.com/tspike2k)
Copyright: Copyright (c) 2025
License:   Boost Software License 1.0 (https://www.boost.org/LICENSE_1_0.txt)
*/

/+
As of now, the code in gui.d isn't sufficiently flexible enough to use for in-game menus. That's
where this code comes in. This also isn't aiming to be a general approach, just offer enough
flexibility that we can write menus without having to manually place every item.

The basic idea is there are menu items (text, buttons, sliders, etc) and there are containers.
A container is a vertical slice of the screen region and can hold one or more menu items.
Containers are not displayed, they're only used to place menu items.

TODO: Explain the rest after we finilize things!
+/

import memory;
import assets;
import display;
import math;
import app : Render_Passes;
import render;

enum Menu_Item_Type : uint{
    None,
    Title,
    Label,
    Heading,
    Button,
}

enum Menu_Action : uint{
    None,
    Change_Menu,
    Quit_Game,
}

enum Menu_ID : uint{
    None,
    Main_Menu,
    Campaign,
}

enum Align : uint{
    Front,
    Center,
    Back,

    Left  = Front,
    Right = Back,
}

enum Null_Menu_Index = uint.max;

struct Menu_Item{
    Menu_Item_Type type;
    String         text;
    Rect           bounds; // Set by the layout algorithm
    uint           flags;

    // Data for interactive menu items
    Menu_Action action;
    Menu_ID     target_menu;
}

/+
struct Row{
    uint     aligns_count;
    Align[4] aligns;
    uint     items_end;
}+/

struct Block{
    // TODO: Add vertical alignment? We probably won't ever use that.
    float height;
    uint  items_end;

    // For debugging
    float start_y;
    float end_y;
}

struct Menu{
    Font*         button_font;
    Font*         heading_font;
    Font*         title_font;

    Menu_ID current_menu_id;

    uint          hover_item_index;
    uint          items_count;
    Menu_Item[32] items;
    uint          blocks_count;
    Block[8]      blocks;
    //uint          row_layouts_count;
    //Row[16]       row_layouts;
}

void begin_menu_def(Menu* menu, Menu_ID menu_id){
    menu.blocks_count = 0;
    menu.items_count  = 0;
    menu.hover_item_index = Null_Menu_Index;
    menu.hover_item_index = get_next_hover_index(menu);
    menu.current_menu_id = menu_id;

    //auto row = push_row(menu);
    //row.aligns[row.aligns_count++] = Layout(Align.Center, 0);
}

void end_menu_def(Menu* menu){
    // Find the first interactive item and set the hover_item_index to it's slot.
    /+
    foreach(item_index, ref item; menu.items[0 .. menu.items_count]){
        if(item.type == Menu_Item_Type.Button){
            menu.hover_item_index = cast(uint)item_index;
            break;
        }
    }+/
}

enum Menu_Command_Type : uint{
    None,
    Menu_Item,
    Block_Begin,
    Block_End,
    Horizontal_Layout_Begin,
    Horizontal_Layout_End,
}

struct Menu_Command{
    Menu_Command_Type type;
    uint              value;
}

void begin_block(Menu* menu, float block_height){
    auto block = &menu.blocks[menu.blocks_count++];
    block.height = block_height;
}

void end_block(Menu* menu){
    auto block = &menu.blocks[menu.blocks_count-1];
    block.items_end = menu.items_count;
}

/+
void begin_horizontal_layout(Menu* menu, Layout layout){
    auto array = (&layout)[0 .. 1];
    push_layout_command(menu, Menu_Command_Type.Horizontal_Layout_Begin, array);
}

void end_horizontal_layout(Menu* menu){
    push_command(menu, Menu_Command_Type.Horizontal_Layout_End, 0);
}
+/
Menu_Item* add_menu_item(Menu* menu, Menu_Item_Type type){
    auto result = &menu.items[menu.items_count++];
    clear_to_zero(*result);
    result.type = type;
    return result;
}

void add_title(Menu* menu, String text){
    auto entry = add_menu_item(menu, Menu_Item_Type.Title);
    entry.text = text;
}

void add_heading(Menu* menu, String text){
    auto entry = add_menu_item(menu, Menu_Item_Type.Heading);
    entry.text = text;
}

void add_button(Menu* menu, String text, Menu_Action action, Menu_ID target_menu){
    auto entry = add_menu_item(menu, Menu_Item_Type.Button);
    entry.text = text;
    entry.action = action;
    entry.target_menu = target_menu;
}

uint get_prev_hover_index(Menu* menu){
    auto result = menu.hover_item_index;
    auto start = result == Null_Menu_Index ? 0 : result;
    foreach(i; 0 .. menu.items_count){
        auto index = (start - i - 1 + menu.items_count) % menu.items_count;
        auto entry = &menu.items[index];
        if(entry.type == Menu_Item_Type.Button){
            result = index;
            break;
        }
    }
    return result;
}

uint get_next_hover_index(Menu* menu){
    auto result = menu.hover_item_index;
    auto start = result == Null_Menu_Index ? 0 : result;
    foreach(i; 0 .. menu.items_count){
        auto index = (start + i + 1) % menu.items_count;
        auto entry = &menu.items[index];
        if(entry.type == Menu_Item_Type.Button){
            result = index;
            break;
        }
    }
    return result;
}

struct Menu_Event{
    Menu_Action action;
    Menu_ID     target_menu;
}

Menu_Event menu_handle_event(Menu* menu, Event* event){
    Menu_Event result;

    switch(event.type){
        default: break;

        case Event_Type.Key:{
            auto key = &event.key;
            if(key.pressed){
                switch(key.id){
                    default: break;

                    case Key_ID_Arrow_Down:{
                        menu.hover_item_index = get_next_hover_index(menu);
                    } break;

                    case Key_ID_Arrow_Up:{
                        menu.hover_item_index = get_prev_hover_index(menu);
                    } break;

                    case Key_ID_Enter:{
                        auto item = menu.items[menu.hover_item_index];
                        result.action = item.action;
                        result.target_menu = item.target_menu;
                    } break;
                }
            }
        } break;
    }
    return result;
}

void update_menu(Menu* menu, Rect canvas){
    // TODO: Only run the layout algorithm if the canvas position or size has changed
    // since the last update.
    do_layout(menu, canvas);

    /+
    for(auto iter = iterate(menu); iterate_next(&iter);){
        auto entry = &iter.entry;
    }+/
}

void render_menu(Render_Passes* rp, Menu* menu, float time){
    Vec4[2] block_colors = [Vec4(0.25f, 0.25f, 0.25f, 1), Vec4(0, 0, 0, 1)];
    foreach(block_index, ref block; menu.blocks[0 .. menu.blocks_count]){
        auto color = block_colors[block_index % block_colors.length];

        auto bounds = rect_from_min_max(Vec2(0, block.end_y), Vec2(1920, block.start_y));
        render_rect(rp.hud_rects, bounds, color);
    }

    foreach(entry_index, ref entry; menu.items[0 .. menu.items_count]){
        auto font = get_font(menu, entry.type);
        auto p = center_text(font, entry.text, entry.bounds);

        auto color = Vec4(1, 1, 1, 1);
        if(entry_index == menu.hover_item_index){
            float t = fabs(0.8f*cos(0.5f*time*TAU));
            color = lerp(Vec4(1, 0, 0, 1), Vec4(1, 1, 1, 1), t);
        }

        render_rect(rp.hud_rects, entry.bounds, Vec4(0, 1, 0, 1));
        render_text(rp.hud_text, font, p, entry.text, color);
    }
}

////
//
private:
//
////

/+
void[] push_command_bytes(Menu* menu, size_t bytes){
    auto result = menu.command_memory[menu.command_memory_used .. menu.command_memory_used + bytes];
    menu.command_memory_used += bytes;
    return result;
}

void push_command(Menu* menu, Menu_Command_Type type, uint value){
    auto cmd  = cast(Menu_Command*)push_command_bytes(menu, Menu_Command.sizeof);
    cmd.type  = type;
    cmd.value = value;
}+/

/+
void push_layout_command(Menu* menu, Menu_Command_Type type, Layout[] layout){
    push_command(menu, type, cast(uint)layout.length);
    auto dest = cast(Layout[])push_command_bytes(menu, layout.length*Layout.sizeof);
    copy(layout, dest);
}+/

Font* get_font(Menu* menu, Menu_Item_Type type){
    Font* font;
    switch(type){
        default: assert(0);
        case Menu_Item_Type.Title:   font = menu.title_font; break;
        case Menu_Item_Type.Heading: font = menu.heading_font; break;
        case Menu_Item_Type.Button:  font = menu.button_font; break;
    }
    return font;
}

/+
Row* push_row(Menu* menu){
    Row* result = &menu.row_layouts[menu.row_layouts_count++];
    clear_to_zero(*result);
    return result;
}+/

float get_item_height(Menu* menu, Menu_Item* item){
    auto font = get_font(menu, item.type);
    auto result = font.metrics.height; // TODO: Add padding?
    return result;
}

void do_layout(Menu* menu, Rect canvas){
    enum Margin = 4.0f;
    auto canvas_width  = width(canvas);
    auto canvas_height = height(canvas);

    uint item_index = 0;
    float pen_y = top(canvas);

    foreach(ref block; menu.blocks[0 .. menu.blocks_count]){
        auto items   = menu.items[item_index .. block.items_end];

        float total_height = 0.0f;
        foreach(ref item; items){
            auto height = get_item_height(menu, &item);
            item.bounds.extents.y = 0.5f*height; // TODO: Include padding
            item.bounds.extents.x = 0.5f*canvas_width; // TODO: Base this on text width or, in the case of buttons, target width
            total_height += height;
        }

        assert(block.height > 0 && block.height <= 1);
        auto block_height = canvas_height*block.height;
        auto block_end = pen_y - block_height;

        block.start_y = pen_y;
        block.end_y = block.start_y - block_height;
        pen_y = floor(pen_y - (block_height - total_height)*0.5f);
        foreach(ref item; items){
            item.bounds.center.x = canvas.center.x;
            item.bounds.center.y = pen_y - item.bounds.extents.y; // TODO: Add margins?
            pen_y = floor(pen_y - height(item.bounds));
        }
        pen_y = block_end;

        item_index = block.items_end;
    }

    /+
    auto pen = Vec2(canvas.center.x, top(canvas));
    auto canvas_width  = width(canvas);
    auto canvas_height = height(canvas);
    foreach(ref container; menu.containers[0 .. menu.containers_count]){
        float items_height = 0;
        foreach(ref item; container.items){
            // TODO: Include item margins.
            items_height += get_item_height(menu, &item);
        }

        assert(container.target_h > 0.0f && container.target_h <= 1.0f);
        float height = floor(canvas_height*container.target_h);
        auto spacer_y = 0.5f*(height - items_height);
        pen.y -= spacer_y;

        foreach(ref item; container.items){
            auto item_h = get_item_height(menu, &item);
            item.bounds = Rect(
                Vec2(pen.x, pen.y - item_h*0.5f),
                Vec2(canvas.extents.x, item_h*0.5f)
            );
            pen.y -= item_h;
        }

        pen.y -= spacer_y;
    }+/
}

