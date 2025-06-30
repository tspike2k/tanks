/*
Authors:   tspike (github.com/tspike2k)
Copyright: Copyright (c) 2025
License:   Boost Software License 1.0 (https://www.boost.org/LICENSE_1_0.txt)
*/

/+
For now, the GUI library isn't sufficiently flexible enough to use for the in-game menus. That's where this comes in. Most menus will feature one item per row, centered along the x-axis. However, we need to support multiple items per row in some cases, and have alignment that matches the rest of the menu. One tricky menu will be the campaign selection menu. Here we need to display the following:
    name
    author
    date
    description
    version_string
    variants

The last of which needs to be selectible. And before we display that, we should be able to choose which campaign to display. Interestingly, a library called "microui" has an API where you can declare the number of columns you want in a row and their sizes. I think we could do the same. We would also want to set the column alignment. So something like the following:

    auto row_style = [Menu_Row(0.5f, Menu_Align.Right), Menu_Row(0.5f, Menu_Align.Left)];
    set_row_style(menu, row_style);
    add_label(menu, "Name:");
    add_label(menu, campaign.name);
    set_row_style(menu, null); // Return to normal row settings.
+/

import memory;
import assets;
import display;
import math;
import app : Render_Passes;
import render;

enum Menu_Entry_Type : uint{
    None,
    Container_Begin,
    Container_End,
    Row_Begin,
    Row_End,
    Item,
}

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

enum Null_Menu_Index = uint.max;

// TODO: Allow menu items to have target_width, target_height values. If the values are less than
// or equal to one, they're a percentage of the container that contains them.

struct Menu_Entry_Header{
    Menu_Entry_Type type;
    uint            size;
}

struct Menu_Item{
    Menu_Item_Type type;
    String         text;
    Rect           bounds; // Set by the layout algorithm

    // Data for interactive menu items
    Menu_Action action;
    Menu_ID     target_menu;
}

struct Menu{
    Font*         button_font;
    Font*         heading_font;
    Font*         title_font;

    Menu_ID current_menu_id;
    uint   memory_used;
    void[] memory;

    uint         hover_item_index;
    uint         items_count;
    Menu_Item*[] items; // List of interactive elements.

    Menu_Entry_Header* last_header;
}

void begin_menu_def(Menu* menu, Menu_ID menu_id){
    menu.memory_used = 0;
    menu.items_count = 0;
    menu.hover_item_index = Null_Menu_Index;
    menu.current_menu_id = menu_id;
}

struct Menu_Entry{
    Menu_Entry_Header header;
    void[]            data;
}

struct Menu_Iterator{
    void[]     memory;
    Menu_Entry entry;
}

Menu_Iterator iterate(Menu* menu){
    Menu_Iterator result;
    result.memory = menu.memory[0 .. menu.memory_used];
    return result;
}

bool iterate_next(Menu_Iterator* iter){
    bool result = false;
    if(iter.memory.length >= Menu_Entry_Header.sizeof){
        auto header = cast(Menu_Entry_Header*)iter.memory;
        iter.memory = iter.memory[Menu_Entry_Header.sizeof .. $];

        auto entry = &iter.entry;
        entry.header = *header;
        if(iter.memory.length >= header.size){
            entry.data  = iter.memory[0 .. header.size];
            iter.memory = iter.memory[header.size .. $];
        }
        result = entry.data.length == header.size;
    }

    return result;
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

void begin_container(Menu* menu, float target_w, float target_h){
    push_header(menu, Menu_Entry_Type.Container_Begin);
    // TODO: Store container info
}

void end_container(Menu* menu){
    push_header(menu, Menu_Entry_Type.Container_End);
}

Menu_Item* add_menu_item(Menu* menu, Menu_Item_Type type){
    push_header(menu, Menu_Entry_Type.Item);
    auto result = cast(Menu_Item*)push_bytes(menu, Menu_Item.sizeof);
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
    /+
    auto start = result == Null_Menu_Index ? 0 : result;
    foreach(i; 0 .. menu.items_count){
        auto index = (start - i - 1 + menu.items_count) % menu.items_count;
        auto entry = &menu.items[index];
        if(entry.type == Menu_Item_Type.Button){
            result = index;
            break;
        }
    }+/
    return result;
}

uint get_next_hover_index(Menu* menu){
    auto result = menu.hover_item_index;
    /+
    auto start = result == Null_Menu_Index ? 0 : result;
    foreach(i; 0 .. menu.items_count){
        auto index = (start + i + 1) % menu.items_count;
        auto entry = &menu.items[index];
        if(entry.type == Menu_Item_Type.Button){
            result = index;
            break;
        }
    }+/
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

private Font* get_font(Menu* menu, Menu_Item_Type type){
    Font* font;
    switch(type){
        default: assert(0);
        case Menu_Item_Type.Title:   font = menu.title_font; break;
        case Menu_Item_Type.Heading: font = menu.heading_font; break;
        case Menu_Item_Type.Button:  font = menu.button_font; break;
    }
    return font;
}

private void do_layout(Menu* menu, Rect canvas){
    enum Margin = 4.0f;

    float get_item_height(Menu* menu, Menu_Item* item){
        auto font = get_font(menu, item.type);
        auto result = Margin + font.metrics.height;
        return result;
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

void update_menu(Menu* menu, Rect canvas){
    // TODO: Only run the layout algorithm if the canvas position or size has changed
    // since the last update.
    //do_layout(menu, canvas);

    for(auto iter = iterate(menu); iterate_next(&iter);){
        auto entry = &iter.entry;
    }
}

void render_menu(Render_Passes* rp, Menu* menu, float time){
    foreach(entry_index, ref entry; menu.items[0 .. menu.items_count]){
        auto font = get_font(menu, entry.type);
        auto p = center_text(font, entry.text, entry.bounds);

        auto color = Vec4(1, 1, 1, 1);
        if(entry_index == menu.hover_item_index){
            float t = fabs(0.8f*cos(0.5f*time*TAU));
            color = lerp(Vec4(1, 0, 0, 1), Vec4(1, 1, 1, 1), t);
        }

        render_text(rp.hud_text, font, p, entry.text, color);
    }
}

void push_header(Menu* menu, Menu_Entry_Type type){
    auto header = cast(Menu_Entry_Header*)menu.memory[menu.memory_used .. $];
    menu.memory_used += Menu_Entry_Header.sizeof;
    header.type = type;
    header.size = 0;
    menu.last_header = header;
}

void[] push_bytes(Menu* menu, size_t bytes){
    assert(menu.last_header);
    void[] result = menu.memory[menu.memory_used .. menu.memory_used + bytes];
    menu.memory_used += bytes;
    menu.last_header.size += bytes;
    return result;
}
