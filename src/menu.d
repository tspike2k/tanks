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
    Index_Picker,
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

    // TODO: This should be part of a union.
    uint* index;
    uint  index_max;
}

struct Style_Group{
    uint items_end;

    uint style_offset;
    uint style_end;
}

struct Style{
    float size;
    Align alignment;
}

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

    uint           hover_item_index;
    uint           items_count;
    Menu_Item[32]  items;
    uint           blocks_count;
    Block[8]       blocks;
    uint           style_groups_count;
    Style_Group[8] style_groups;
    uint           styles_count;
    Style[32]      styles;
}

void begin_menu_def(Menu* menu, Menu_ID menu_id){
    menu.blocks_count = 0;
    menu.items_count  = 0;
    menu.current_menu_id = menu_id;

    menu.style_groups_count = 1;
    menu.styles_count       = 1;

    auto default_group = &menu.style_groups[0];
    clear_to_zero(*default_group);
    default_group.style_end = 1;
    //menu.styles[0] = Style(0.5f, Align.Right);
    menu.styles[0] = Style(0, Align.Center);
}

void end_menu_def(Menu* menu){
    // Find the first interactive item and set the hover_item_index to it's slot.
    menu.hover_item_index = Null_Menu_Index;
    menu.hover_item_index = get_next_hover_index(menu);

    end_current_style_group(menu);
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

Menu_Item* add_menu_item(Menu* menu, Menu_Item_Type type, String text){
    auto result = &menu.items[menu.items_count++];
    clear_to_zero(*result);
    result.type = type;
    set_text(menu, result, text);
    return result;
}

void set_text(Menu* menu, Menu_Item* item, String text){
    enum Padding = 8.0f;
    auto font   = get_font(menu, item.type);
    auto width  = get_text_width(font, text) + Padding*2.0f; // TODO: Base this on text width or, in the case of buttons, target width
    auto height = (cast(float)font.metrics.height) + Padding*2.0f;
    item.bounds.extents = 0.5f*Vec2(width, height);
    item.text = text;
}

void add_title(Menu* menu, String text){
    auto entry = add_menu_item(menu, Menu_Item_Type.Title, text);
}

uint add_label(Menu* menu, String text){
    auto index = menu.items_count;
    auto entry = add_menu_item(menu, Menu_Item_Type.Label, text);
    return index;
}

void add_heading(Menu* menu, String text){
    auto entry = add_menu_item(menu, Menu_Item_Type.Heading, text);
}

void add_button(Menu* menu, String text, Menu_Action action, Menu_ID target_menu){
    auto entry = add_menu_item(menu, Menu_Item_Type.Button, text);
    entry.action = action;
    entry.target_menu = target_menu;
}

void add_index_picker(Menu* menu, uint* index, uint index_max, String text){
    auto entry = add_menu_item(menu, Menu_Item_Type.Index_Picker, text);
    entry.index     = index;
    entry.index_max = index_max;
}

void set_style(Menu* menu, const Style[] style){
    // Mark the end of the previous group
    end_current_style_group(menu);

    // Begin a new group
    auto group = &menu.style_groups[menu.style_groups_count++];
    clear_to_zero(*group);
    group.style_offset = menu.styles_count;
    group.style_end    = group.style_offset + cast(uint)style.length;

    auto dest_style = menu.styles[menu.styles_count .. menu.styles_count + style.length];
    copy(style, dest_style);
}

void set_default_style(Menu* menu){
    // Mark the end of the previous group
    end_current_style_group(menu);

    auto group = &menu.style_groups[menu.style_groups_count++];
    clear_to_zero(*group);
    group.style_end = 1; // Point to the first style element, the default style.
}

uint get_prev_hover_index(Menu* menu){
    auto result = menu.hover_item_index;
    auto start = result == Null_Menu_Index ? 0 : result;
    foreach(i; 0 .. menu.items_count){
        auto index = (start - i - 1 + menu.items_count) % menu.items_count;
        auto entry = &menu.items[index];
        if(is_interactive(entry)){
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
        if(is_interactive(entry)){
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

                    case Key_ID_Arrow_Left:
                    case Key_ID_Arrow_Right:{
                        if(menu.hover_item_index != Null_Menu_Index){
                            auto item = &menu.items[menu.hover_item_index];
                            if(item.type == Menu_Item_Type.Index_Picker){
                                if(key.id == Key_ID_Arrow_Left)
                                    index_decr(item.index, item.index_max);
                                else
                                    index_incr(item.index, item.index_max);
                            }
                        }
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

void menu_do_layout(Menu* menu, Rect canvas){
    // TODO: Only run the layout algorithm if the canvas position or size has changed
    // since the last update.

    enum Margin = 8.0f;
    auto canvas_width  = width(canvas);
    auto canvas_height = height(canvas);
    auto canvas_left   = left(canvas);

    uint item_index = 0;
    float block_pen_y = top(canvas);

    auto style_group_index = 0;
    auto style_groups = menu.style_groups[0 .. menu.style_groups_count];

    auto style_group = &style_groups[style_group_index++];
    auto styles = menu.styles[style_group.style_offset .. style_group.style_end];

    foreach(ref block; menu.blocks[0 .. menu.blocks_count]){
        auto items   = menu.items[item_index .. block.items_end];
        if(items.length > 0){
            float total_height = 0.0f;
            float item_pen_y = 0;

            uint column = 0;
            auto pen_x  = 0;
            float row_height = 0.0f;

            void end_row(){
                total_height += row_height;
                item_pen_y -= (row_height + Margin);

                column = 0;
                pen_x  = 0;
                row_height = 0.0f;
            }

            foreach(i, ref item; items){
                auto bounds = &item.bounds;
                auto width  = width(*bounds);
                auto height = height(*bounds);
                row_height = max(height, row_height);

                if(item_index + i >= style_group.items_end){
                    style_group = &style_groups[style_group_index++];
                    styles = menu.styles[style_group.style_offset .. style_group.style_end];
                    end_row();
                }
                auto style = &styles[column];

                float target_width = (canvas_width - pen_x);
                if(style.size != 0.0f){
                    target_width = canvas_width*style.size;
                }

                float center_x = void;
                final switch(style.alignment){
                    case Align.Center:
                        center_x = pen_x + target_width*0.5f; break;

                    case Align.Right:
                        center_x = pen_x + target_width - width*0.5f - Margin; break;

                    case Align.Left:
                        center_x = pen_x + width*0.5f + Margin; break;
                }

                bounds.center = Vec2(center_x, item_pen_y - bounds.extents.y);
                pen_x += target_width;

                column++;
                if(column >= styles.length){
                    end_row();
                }
            }
            total_height += Margin*(cast(float)items.length-1);

            assert(block.height > 0 && block.height <= 1);
            auto block_height = canvas_height*block.height;
            auto block_end = block_pen_y - block_height;

            // Debug values
            block.start_y = block_pen_y;
            block.end_y   = block_end;

            auto block_offset = Vec2(canvas_left, block_pen_y - (block_height - total_height)*0.5f);
            block_pen_y = block_end;
            foreach(ref item; items){
                item.bounds.center = floor(item.bounds.center + block_offset);
            }
        }

        item_index = block.items_end;
    }
}

void menu_render(Render_Passes* rp, Menu* menu, float time){
    Vec4[2] block_colors = [Vec4(0.25f, 0.25f, 0.25f, 1), Vec4(0, 0, 0, 1)];
    foreach(block_index, ref block; menu.blocks[0 .. menu.blocks_count]){
        auto color = block_colors[block_index % block_colors.length];

        auto bounds = rect_from_min_max(Vec2(0, block.end_y), Vec2(1920, block.start_y));
        render_rect(rp.hud_rects, bounds, color);
    }

    foreach(entry_index, ref entry; menu.items[0 .. menu.items_count]){
        auto font = get_font(menu, entry.type);
        auto p = center_text(font, entry.text, entry.bounds);

        auto text_color = Vec4(1, 1, 1, 1);
        if(entry_index == menu.hover_item_index){
            float t = fabs(0.8f*cos(0.5f*time*TAU));
            text_color = lerp(Vec4(1, 0, 0, 1), Vec4(1, 1, 1, 1), t);
        }

        switch(entry.type){
            default:{
                render_text(rp.hud_text, font, p, entry.text, text_color);
            } break;

            case Menu_Item_Type.Button:{
                render_rect(rp.hud_rects, entry.bounds, Vec4(0, 1, 0, 1));
                render_text(rp.hud_text, font, p, entry.text, text_color);
            } break;

            case Menu_Item_Type.Index_Picker:{
                render_rect(rp.hud_rects, entry.bounds, Vec4(0, 1, 0, 1));
                render_text(rp.hud_text, font, p, entry.text, text_color);
            } break;
        }
    }
}

////
//
private:
//
////

bool is_interactive(Menu_Item* item){
    bool result = false;

    // TODO: For flexibility (and support for custom widgets), a bt flag should be used
    // to state if a menu item is interactive or not. Interactive items are items that can
    // be navigated to using the keyboard or clicked on using the mouse.
    switch(item.type){
        default: break;

        case Menu_Item_Type.Button:
        case Menu_Item_Type.Index_Picker:
            result = true; break;
    }

    return result;
}

Font* get_font(Menu* menu, Menu_Item_Type type){
    Font* font;
    switch(type){
        default: font = menu.button_font; break;
        case Menu_Item_Type.Title:   font = menu.title_font; break;
        case Menu_Item_Type.Heading: font = menu.heading_font; break;
    }
    return font;
}

float get_item_height(Menu* menu, Menu_Item* item){
    auto font = get_font(menu, item.type);
    auto result = font.metrics.height; // TODO: Add padding?
    return result;
}

void end_current_style_group(Menu* menu){
    auto group = &menu.style_groups[menu.style_groups_count-1];
    group.items_end = menu.items_count;
}
