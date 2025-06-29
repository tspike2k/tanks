/*
Authors:   tspike (github.com/tspike2k)
Copyright: Copyright (c) 2025
License:   Boost Software License 1.0 (https://www.boost.org/LICENSE_1_0.txt)
*/

import memory;
import assets;
import display;
import math;
import app : Render_Passes;
import render;

enum Menu_Item_Type : uint{
    None,
    Title,
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

struct Menu_Item{
    Menu_Item_Type  type;
    String          text;
    Rect            bounds; // Set by the layout algorithm

    // Data for interactive menu items
    Menu_Action action;
    Menu_ID     target_menu;
}

/+
TODO:
    We want to support simple horizontal layout. The most obvious way to do this is to have
    containers that contain a list of items. Perhaps that would be the best way. This way
    we would be creating a simple tree. Containers can contain containers. Containers also
    have style information attached to them. This could work. But we could invert that and
    make menu items hold a reference to a container instead. We'll see how that goes.
+/

struct Menu_Container{
    float       target_w;
    float       target_h;
    Menu_Item[] items;
    Rect        bounds;
}

struct Menu{
    Font*         button_font;
    Font*         heading_font;
    Font*         title_font;

    // TODO: Allow containers to hold other containers.
    uint              containers_count;
    Menu_Container[8] containers;

    Menu_ID           current_menu_id;
    uint              hover_item_index;
    uint              items_count;
    Menu_Item[16]     items;
}

void begin_menu_def(Menu* menu, Menu_ID menu_id){
    menu.items_count = 0;
    menu.containers_count = 0;
    menu.hover_item_index = Null_Menu_Index;
    menu.current_menu_id = menu_id;
}

void end_menu_def(Menu* menu){
    // Find the first interactive item and set the hover_item_index to it's slot.
    foreach(item_index, ref item; menu.items[0 .. menu.items_count]){
        if(item.type == Menu_Item_Type.Button){
            menu.hover_item_index = cast(uint)item_index;
            break;
        }
    }
}

Menu_Container* add_container(Menu* menu, float target_w, float target_h){
    auto result = &menu.containers[menu.containers_count++];
    clear_to_zero(*result);
    result.target_w = target_w;
    result.target_h = target_h;
    result.items = menu.items[menu.items_count .. menu.items_count];
    return result;
}

private Menu_Item* add_menu_item(Menu* menu, Menu_Item_Type type){
    auto entry = &menu.items[menu.items_count++];
    clear_to_zero(*entry);
    entry.type = type;

    auto container = &menu.containers[menu.containers_count-1];
    auto base_index = cast(size_t)((container.items.ptr - menu.items.ptr));
    container.items = menu.items[base_index .. menu.items_count];
    return entry;
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

private Font* get_font(Menu* menu, Menu_Item_Type type){
    Font* font;
    final switch(type){
        case Menu_Item_Type.None: assert(0);
        case Menu_Item_Type.Title:   font = menu.title_font; break;
        case Menu_Item_Type.Heading: font = menu.heading_font; break;
        case Menu_Item_Type.Button:  font = menu.button_font; break;
    }
    return font;
}

private void do_layout(Menu* menu, Rect canvas){
    enum Margin = 4.0f;
    // TODO: Cache the canvas size. If size is the same, no reason to re-run layout.

    float get_item_height(Menu* menu, Menu_Item* item){
        auto font = get_font(menu, item.type);
        auto result = Margin + font.metrics.height;
        return result;
    }

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
    }
}

void update_menu(Menu* menu, Rect canvas){
    do_layout(menu, canvas);
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
