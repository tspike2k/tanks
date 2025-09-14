/*
Authors:   tspike (github.com/tspike2k)
Copyright: Copyright (c) 2025
License:   Boost Software License 1.0 (https://www.boost.org/LICENSE_1_0.txt)
*/

/+
As of now, the code in gui.d isn't sufficiently flexible enough to use for in-game menus. That's
where this code comes in. This also isn't aiming to be a general approach, just offer enough
flexibility that we can write menus without having to manually place every item.

The broad overview is that each menu can occupy a rectangular region of the window which is
internally called the "canvas." Menu items (such as text labels, buttons, sliders, etc) are
placed onto this convas inside containers called "blocks." A block itself is not rendered, its
purpose is to vertically center menu items to specific sub-regions of the canvas. If there are
more items than can fit inside the canvas, the user is presented with scrollbars with which
to navigate to out of view menu items.

Layout of menu items is done automatically. Conceptually, the layout algorithm works by
placing menu items on rows. The height of a row is determined by the tllest menu item in that
row. Only one item is placed per row by default, though this can be changed by using the
set_style function. This function determines the width and alignment for each column on the row.
This function was inspired by microui (https://github.com/rxi/microui).

TODO:
    - What happens when we don't have any interactive elements? Do we crash if we hit enter?
+/

import memory;
import assets;
import display;
import math;
import app : Render_Passes, Score_Entry, High_Scores_Table_Size, get_total_score, Player_Name;
import render;
import audio;

private{
    enum Padding = 8.0f;
    enum Margin  = 8.0f;
}

enum Menu_Item_Type : uint{
    None,
    Title,
    Label,
    Heading,
    Button,
    Index_Picker,
    High_Score_Row,
    Text_Block,
    High_Score_Table_Head,
    Textfield,
}

enum Menu_Action : uint{
    None,
    Push_Menu,
    Pop_Menu,
    Begin_Campaign,
    Open_Editor,
    Quit_Game,
    Abort_Campaign,
    Show_High_Score_Details,
}

// TODO: Settings menu?
enum Menu_ID : uint{
    None,
    Main_Menu,
    Campaign,
    High_Scores,
    Campaign_Pause,
    High_Score_Details,
    Options,
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
    uint           user_id;
    float          target_width;
    float          target_height;
    Rect           bounds; // Set by the layout algorithm
    String         text;

    // Data for interactive menu items
    Menu_Action action;
    Menu_ID     target_menu;

    union{
        struct{
            uint* index;
            uint  index_max;
        }
        struct{
            Score_Entry* score_entry;
            uint         score_rank;
        }
        char[] text_buffer;
    }
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
    Sound*        sfx_click;

    // TODO: It would be better if these were not inside the menu system itself. It's fine for
    // now because it simplifies how we pass this data around, but this is probably an example
    // of cross-cutting concerns.
    uint         variant_index;
    Score_Entry* newly_added_score;

    bool    text_input_mode;
    bool    changed_menu;
    Rect    canvas;
    bool    mouse_moved;
    Vec2    mouse_p;
    Menu_ID active_menu_id;
    Vec2    scroll_offset;
    float   content_height;
    bool    is_scrolling_y;
    uint    hover_item_stack_count;
    uint[8] hover_item_stack;

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

bool menu_is_closed(Menu* menu){
    auto result = menu.active_menu_id == Menu_ID.None;
    return result;
}

void set_menu(Menu* menu, Menu_ID id){
    menu.active_menu_id = id;
    menu.changed_menu = true;

    // Close the menu
    if(id == Menu_ID.None){
        menu.blocks_count = 0;
        menu.items_count  = 0;
        menu.hover_item_index = 0;
    }
}

void push_menu(Menu* menu, Menu_ID id){
    set_menu(menu, id);
    menu.hover_item_stack[menu.hover_item_stack_count++] = menu.hover_item_index;
    menu.hover_item_index = 0;
}

void pop_menu(Menu* menu){
    auto parent_id = get_parent_menu_id(menu.active_menu_id);
    set_menu(menu, parent_id);

    if(menu.hover_item_stack_count > 0){
        menu.hover_item_stack_count--;
        menu.hover_item_index = menu.hover_item_stack[menu.hover_item_stack_count];
    }
}

Menu_ID get_parent_menu_id(Menu_ID id){
    Menu_ID result = void;

    switch(id){
        default:
            result = Menu_ID.None; break;

        case Menu_ID.None:
            assert(0);

        case Menu_ID.Campaign:
        case Menu_ID.High_Scores:
        case Menu_ID.Options:
            result = Menu_ID.Main_Menu; break;


        case Menu_ID.High_Score_Details:
            result = Menu_ID.High_Scores; break;
    }

    return result;
}

void begin_menu_def(Menu* menu){
    menu.blocks_count = 0;
    menu.items_count  = 0;

    menu.style_groups_count = 1;
    menu.styles_count       = 1;

    auto default_group = &menu.style_groups[0];
    clear_to_zero(*default_group);
    default_group.style_end = 1;
    //menu.styles[0] = Style(0.5f, Align.Right);
    menu.styles[0] = Style(0, Align.Center);
}

void end_menu_def(Menu* menu){
    if(menu.hover_item_index >= menu.items_count
    || !is_interactive(&menu.items[menu.hover_item_index])){
        // Find the first interactive item and set the hover_item_index to it's slot.
        menu.hover_item_index = Null_Menu_Index;
        menu.hover_item_index = get_next_hover_index(menu);
    }

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
    switch(type){
        default:{
            auto font = get_font(menu, result.type);
            result.target_height = (cast(float)font.metrics.height) + Padding*2.0f;
        } break;

        case Menu_Item_Type.Button:{
            result.target_height = Button_Height;
        } break;

        case Menu_Item_Type.Text_Block:
            break;
    }

    return result;
}

void set_text(Menu* menu, Menu_Item* item, String text){
    float width = Button_Width;
    switch(item.type){
        default:{
            auto font = get_font(menu, item.type);
            item.target_width = get_text_width(font, text) + Padding*2.0f;
        } break;

        case Menu_Item_Type.Button:
        case Menu_Item_Type.Text_Block:
            break;
    }

    item.text = text;
}

void add_title(Menu* menu, String text){
    auto entry = add_menu_item(menu, Menu_Item_Type.Title, text);
}

uint add_label(Menu* menu, String text, uint user_id = 0){
    auto index = menu.items_count;
    auto entry = add_menu_item(menu, Menu_Item_Type.Label, text);
    entry.user_id = user_id;
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

enum High_Score_Row_Width = 800;

void add_high_score_table_head(Menu* menu, String name){
    auto entry = add_menu_item(menu, Menu_Item_Type.High_Score_Table_Head, name);

    auto font = get_font(menu, entry.type);
    entry.target_height = font.metrics.height*2.0f + Padding*2.0f;
    entry.target_width  = High_Score_Row_Width;
}

void add_high_score_row(Menu* menu, Score_Entry* score, uint rank, uint user_id){
    auto entry = add_menu_item(menu, Menu_Item_Type.High_Score_Row, "");
    auto font = get_font(menu, entry.type);

    entry.target_height = font.metrics.height + Padding*2.0f;
    entry.target_width  = High_Score_Row_Width;

    entry.action = Menu_Action.Show_High_Score_Details;
    entry.score_rank = rank;
    entry.user_id = user_id;
    entry.score_entry = score;
}

void add_textfield(Menu* menu, String label, char[] buffer){
    auto entry = add_menu_item(menu, Menu_Item_Type.Textfield, label);
    auto font = get_font(menu, entry.type);

    entry.target_height = font.metrics.height + Padding*2.0f;
    entry.target_width  = High_Score_Row_Width;
    entry.text_buffer = buffer;
}

void add_text_block(Menu* menu, String text, uint user_id = 0){
    auto entry = add_menu_item(menu, Menu_Item_Type.Text_Block, text);
    entry.target_width  = 0.45f;
    entry.user_id = user_id;
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
    uint        user_id;
}

char[] get_textfield_used(char[] buffer){
    char[] result;
    foreach(i, c; buffer){
        if(!is_whitespace(c) && c != '\0'){
            result = buffer[0 .. i];
        }
    }

    return result;
}

private Menu_Event do_action(Menu* menu, Menu_Item* item){
    Menu_Event result;

    play_sfx(menu.sfx_click, 0, 1.0f);

    if(item.type == Menu_Item_Type.Index_Picker){
        index_incr(item.index, item.index_max);
    }
    else if(item.type == Menu_Item_Type.Textfield){
        menu.text_input_mode = true;
        auto buffer = item.text_buffer;
        auto used_text = get_textfield_used(buffer);
        enable_text_input_mode(item.text_buffer, cast(uint)used_text.length, 0);
    }
    else{
        result.action  = item.action;
        result.user_id = item.user_id;
        switch(item.action){
            default: break;

            case Menu_Action.Push_Menu:{
                push_menu(menu, item.target_menu);
            } break;

            case Menu_Action.Pop_Menu:{
                pop_menu(menu);
            } break;
        }
    }
    return result;
}

private Menu_Item* get_hover_item(Menu* menu){
    auto result = &menu.items[menu.hover_item_index];
    return result;
}

Menu_Item* get_item_by_user_id(Menu* menu, uint user_id){
    Menu_Item* result;

    foreach(ref item; menu.items[0 .. menu.items_count]){
        if(item.user_id == user_id){
            result = &item;
            break;
        }
    }

    return result;
}

Menu_Event menu_process_event(Menu* menu, Event* event){
    Menu_Event result;
    if(menu_is_closed(menu)) return result;

    if(menu.text_input_mode){
        if(is_text_input_mode_enabled()){
            text_input_handle_event(event);
        }
        else{
            // We lost text input mode. Time to accept the changes to the text in the buffer.
            menu.text_input_mode = false;
        }
    }
    if(event.consumed) return result;

    switch(event.type){
        default: break;

        case Event_Type.Key:{
            auto key = &event.key;
            if(key.pressed){
                switch(key.id){
                    default: break;

                    case Key_ID_Arrow_Down:{
                        menu.hover_item_index = get_next_hover_index(menu);
                        center_on_active_item(menu);
                        event.consumed = true;
                    } break;

                    case Key_ID_Arrow_Up:{
                        menu.hover_item_index = get_prev_hover_index(menu);
                        center_on_active_item(menu);
                        event.consumed = true;
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
                                event.consumed = true;
                            }
                        }
                    } break;

                    case Key_ID_Enter:{
                        auto item = get_hover_item(menu);
                        if(item){
                            result = do_action(menu, item);
                            event.consumed = true;
                        }
                    } break;

                    case Key_ID_Escape:{
                        if(menu.active_menu_id == Menu_ID.Main_Menu)
                            result = Menu_Event(Menu_Action.Quit_Game);
                        else
                            result = Menu_Event(Menu_Action.Pop_Menu);

                        pop_menu(menu);
                        event.consumed = true;
                    } break;
                }
            }
        } break;

        case Event_Type.Button:{
            auto offset = menu.scroll_offset;
            auto button = &event.button;
            switch(button.id){
                default: break;

                case Button_ID.Mouse_Left:{
                    if(should_scroll(menu)){
                        if(button.pressed){
                            auto scroll_region = get_scroll_region_y(menu.canvas);
                            if(is_point_inside_rect(menu.mouse_p, scroll_region)){
                                menu.is_scrolling_y = true;
                                event.consumed = true;
                            }
                        }
                        else{
                            menu.is_scrolling_y = false;
                        }
                    }

                    if(!event.consumed && button.pressed){
                        auto item = get_hover_item(menu);

                        if(item && is_point_inside_rect(menu.mouse_p - offset, item.bounds)){
                            result = do_action(menu, item);
                            event.consumed = true;
                        }
                    }
                } break;
            }
        } break;

        case Event_Type.Mouse_Motion:{
            auto motion = &event.mouse_motion;

            menu.mouse_p = Vec2(motion.pixel_x, height(menu.canvas) - motion.pixel_y);
            menu.mouse_moved = true;
        } break;
    }
    return result;
}

bool should_scroll(Menu* menu){
    auto result = menu.content_height > height(menu.canvas);
    return result;
}

void menu_update(Menu* menu, Rect canvas){
    if(menu.mouse_moved){
        foreach(item_index, ref item; menu.items[0 .. menu.items_count]){
            if(is_interactive(&item) && is_point_inside_rect(menu.mouse_p - menu.scroll_offset, item.bounds)){
                menu.hover_item_index = cast(uint)item_index;
                break;
            }
        }

        menu.mouse_moved = false;
    }

    // TODO: Only run the layout algorithm if the canvas position or size has changed
    // since the last update.

    auto canvas_width  = width(canvas);
    auto canvas_height = height(canvas);
    auto canvas_left   = left(canvas);

    bool canvas_changed = canvas_width != width(menu.canvas)
        || canvas_height != height(menu.canvas)
        || canvas.center.x != menu.canvas.center.x
        || canvas.center.y != menu.canvas.center.y;

    menu.canvas = canvas;

    if(canvas_changed){
        center_on_active_item(menu);
    }

    uint item_index = 0;
    float block_pen_y = top(canvas);

    auto style_group_index = 0;
    auto style_groups = menu.style_groups[0 .. menu.style_groups_count];

    auto style_group = &style_groups[style_group_index++];
    auto styles = menu.styles[style_group.style_offset .. style_group.style_end];

    Menu_Item* last_item;
    float lowest_item_y = 0.0f;
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
                float width, height;
                if(item.target_width == 0.0f){
                    width = Button_Width;
                }
                else if(item.target_width <= 1.0f){
                    width = canvas_width*item.target_width;
                }
                else{
                    width = item.target_width;
                }

                if(item.target_height == 0.0f){
                    height = Button_Height;
                }
                else if(item.target_height <= 1.0f){
                    height = canvas_height*item.target_height;
                }
                else{
                    height = item.target_height;
                }

                if(item.type == Menu_Item_Type.Text_Block){
                    auto text_height = get_text_height(menu.button_font, item.text, width - Padding*2.0f);
                    height = text_height + Padding*2.0f;
                }

                bounds.extents.x = width*0.5f;
                bounds.extents.y = height*0.5f;

                row_height = max(height, row_height);

                if(item_index + i >= style_group.items_end){
                    style_group = &style_groups[style_group_index++];
                    styles = menu.styles[style_group.style_offset .. style_group.style_end];

                    if(column > 0)
                        end_row();
                }
                auto style = &styles[column];

                float target_column_width = (canvas_width - pen_x);
                if(style.size != 0.0f){
                    target_column_width = canvas_width*style.size;
                }

                float center_x = void;
                final switch(style.alignment){
                    case Align.Center:
                        center_x = pen_x + target_column_width*0.5f; break;

                    case Align.Right:
                        center_x = pen_x + target_column_width - width*0.5f - Margin; break;

                    case Align.Left:
                        center_x = pen_x + width*0.5f + Margin; break;
                }

                bounds.center = Vec2(center_x, item_pen_y - bounds.extents.y);
                pen_x += target_column_width;

                column++;
                if(column >= styles.length){
                    end_row();
                }
            }
            total_height += Margin*(cast(float)items.length-1);

            assert(block.height > 0 && block.height <= 1);
            auto block_height = max(canvas_height*block.height, total_height);
            auto block_end = block_pen_y - block_height;

            // Debug values
            block.start_y = block_pen_y;
            block.end_y   = block_end;

            auto block_offset = Vec2(canvas_left, block_pen_y - (block_height - total_height)*0.5f);
            block_pen_y = block_end;
            foreach(ref item; items){
                item.bounds.center = floor(item.bounds.center + block_offset);
                last_item = &item;
            }
        }

        item_index = block.items_end;
    }

    if(menu.changed_menu){
        center_on_active_item(menu); // TODO: This doesn't work with the high score table. It puts it at the bottom of the table!
    }

    menu.content_height = 0.0f;
    if(last_item){
        menu.content_height = top(canvas) - (bottom(last_item.bounds)) + Margin;
    }

    if(!should_scroll(menu)){
        menu.is_scrolling_y = false;
        menu.scroll_offset.y = 0.0f;
    }
    else{
        auto scroll_region = get_scroll_region_y(menu.canvas);
        auto region_height = height(scroll_region);
        if(menu.is_scrolling_y){
            auto click_percent = menu.mouse_p.y / region_height;
            menu.scroll_offset.y = (1.0f-click_percent)*(menu.content_height - region_height);
        }
        assert(menu.content_height >= region_height);
        menu.scroll_offset.y = clamp(menu.scroll_offset.y, 0, menu.content_height - region_height);
    }

    menu.changed_menu = false;
}

char[] make_date_pretty(char[] buffer, char[] date){
    uint count = 0;
    void push(String s){
        copy(s, buffer[count .. count+s.length]);
        count += s.length;
    }

    // The source date is in the following format:
    // YYYY MM DD hh mm pm
    // But we want it in the following format:
    // hh:mm pm YYYY-MM-DD
    push(date[8..10]);
    push(":");
    push(date[10..12]);
    push(" ");
    push(date[12..14]);
    push(" ");
    push(date[0 .. 4]);
    push("-");
    push(date[4..6]);
    push("-");
    push(date[6..8]);

    auto result = buffer[0 .. count];
    return result;
}

void render_button_border(Render_Pass* pass, Rect r){
    auto thickness = 2.0f;

    auto color_top = Vec4(0.8f, 0.9f, 1.0f, 1);
    auto color_bottom = color_top*0.2f;
    color_bottom.a = color_top.a;

    auto b = thickness * 0.5f;
    auto top    = Rect(r.center + Vec2(0, r.extents.y - b), Vec2(r.extents.x, b));
    auto bottom = Rect(r.center - Vec2(0, r.extents.y - b), Vec2(r.extents.x, b));
    auto left   = Rect(r.center - Vec2(r.extents.x - b, 0), Vec2(b, r.extents.y));
    auto right  = Rect(r.center + Vec2(r.extents.x - b, 0), Vec2(b, r.extents.y));

    render_rect(pass, right, color_bottom);
    render_rect(pass, top, color_top);
    render_rect(pass, left, color_top);
    render_rect(pass, bottom, color_bottom);
}

void menu_render(Render_Passes* rp, Menu* menu, float time, Allocator* allocator){
    Vec4[2] block_colors = [Vec4(0.25f, 0.25f, 0.25f, 1), Vec4(0, 0, 0, 1)];
    /+
    foreach(block_index, ref block; menu.blocks[0 .. menu.blocks_count]){
        auto color = block_colors[block_index % block_colors.length];

        auto bounds = rect_from_min_max(Vec2(0, block.end_y), Vec2(1920, block.start_y));
        render_rect(rp.hud_rects, bounds, color);
    }+/

    auto offset = Vec2(0, menu.scroll_offset.y);

    foreach(entry_index, ref entry; menu.items[0 .. menu.items_count]){
        auto bounds = Rect(entry.bounds.center + offset, entry.bounds.extents);

        auto font = get_font(menu, entry.type);
        auto p = center_text(font, entry.text, bounds);

        auto text_color = Vec4(1, 1, 1, 1);
        if(entry_index == menu.hover_item_index){
            float t = fabs(0.8f*cos(0.5f*time*TAU));
            text_color = lerp(Vec4(1, 0, 0, 1), Vec4(1, 1, 1, 1), t);
        }

        switch(entry.type){
            default:{
                render_text(rp.hud_text, font, p, entry.text, text_color);
            } break;

            case Menu_Item_Type.Text_Block:{
                p = Vec2(left(bounds) + Padding, top(bounds) - font.metrics.line_gap);
                render_rect(rp.hud_rects, bounds, Vec4(0, 0, 0, 1));
                render_text_block(rp.hud_text, font, p, entry.text, Vec4(1,1,1,1), width(bounds) - Padding*2.0f);
            } break;

            case Menu_Item_Type.Index_Picker:
            case Menu_Item_Type.Button:{
                render_rect(rp.hud_button, bounds, Button_Color);
                render_button_border(rp.hud_rects_fg, bounds);
                render_text(rp.hud_text, font, p, entry.text, text_color);
            } break;

            case Menu_Item_Type.High_Score_Table_Head:{
                render_rect(rp.hud_rects, bounds, Vec4(0, 0, 0, 1));

                auto bounds_top = Rect(
                    bounds.center + Vec2(0, bounds.extents.y*0.5f),
                    bounds.extents - Vec2(0, bounds.extents.y*0.5f)
                );

                auto bounds_bottom = Rect(
                    bounds.center - Vec2(0, bounds.extents.y*0.5f),
                    bounds.extents - Vec2(0, bounds.extents.y*0.5f)
                );

                render_rect_outline(rp.hud_rects, bounds_top, Vec4(1,1,1,1), 1.0f);
                auto text_p = center_text(font, entry.text, bounds_top);
                render_text(rp.hud_text, font, text_p, entry.text, Vec4(1, 1, 1, 1));

                auto row_bounds = bounds_bottom;
                auto row_width = width(row_bounds);
                foreach(ref cell_def; g_score_cells){
                    auto cell_bounds = eat_row_piece(&row_bounds, row_width, cell_def.width);
                    render_rect_outline(rp.hud_rects, cell_bounds, Vec4(1,1,1,1), 1.0f);
                    text_p = center_text(font, cell_def.text, cell_bounds);
                    render_text(rp.hud_text, font, text_p, cell_def.text, Vec4(1, 1, 1, 1));
                }
            } break;

            case Menu_Item_Type.Textfield:{
                auto tw = get_text_width(font, entry.text);
                float text_baseline_y = bounds.center.y - 0.5f*cast(float)font.metrics.cap_height;
                auto label_pos = Vec2(left(bounds) - tw, text_baseline_y);
                if(menu.text_input_mode && menu.hover_item_index == entry_index){
                    text_color = Vec4(1, 1, 1, 1);
                }

                auto text_pos = Vec2(left(bounds) + Padding, text_baseline_y);

                render_text(rp.hud_text, font, label_pos, entry.text, text_color);

                auto text_buffer = get_textfield_used(entry.text_buffer);
                render_text(rp.hud_text, font, text_pos, text_buffer, text_color);
                render_rect(rp.hud_rects, bounds, Vec4(1, 1, 1, 1));
                render_rect_outline(rp.hud_rects, bounds, Vec4(0, 0, 0, 1), 1);
            } break;

            case Menu_Item_Type.High_Score_Row:{
                auto bg_color = Button_Color;
                if(entry.score_entry == menu.newly_added_score){
                    float t = fabs(0.8f*cos(0.5f*time*TAU));
                    bg_color = lerp(Vec4(1, 1, 0, 1), Button_Color, t);
                }

                render_rect(rp.hud_button, bounds, bg_color);
                render_button_border(rp.hud_rects_fg, bounds);

                auto row_bounds = bounds;
                auto row_width = width(row_bounds);
                auto cell_rank    = eat_row_piece(&row_bounds, row_width, g_score_cells[0].width);
                auto cell_score   = eat_row_piece(&row_bounds, row_width, g_score_cells[1].width);
                auto cell_name    = eat_row_piece(&row_bounds, row_width, g_score_cells[2].width);
                auto cell_players = eat_row_piece(&row_bounds, row_width, g_score_cells[3].width);

                cell_rank.extents.x    -= Padding;
                cell_score.extents.x   -= Padding;
                cell_name.extents.x    -= Padding;
                cell_players.extents.x -= Padding;

                auto score_entry = entry.score_entry;
                p.x = left(bounds) + Padding;
                uint total_score = 0;
                Player_Name* host_player_name;
                if(score_entry){
                    total_score = get_total_score(score_entry);
                    host_player_name = &score_entry.player_scores[0].name;
                }

                void render_cell(String text, Rect bounds){
                    auto text_p = center_text_right(font, text, bounds);
                    render_text(rp.hud_text, font, text_p, text, text_color);
                }

                render_cell(gen_string("{0}", entry.score_rank, allocator), cell_rank);
                if(total_score > 0){
                    render_cell(gen_string("{0}", total_score, allocator), cell_score);
                    auto name = host_player_name.text[0 .. host_player_name.count];
                    render_cell(name, cell_name);
                    auto players = score_entry.players_count;
                    render_cell(gen_string("{0}", players, allocator), cell_players);
                }
            } break;
        }
    }

    if(should_scroll(menu)){
        auto scroll_region = get_scroll_region_y(menu.canvas);
        render_rect(rp.hud_rects, scroll_region, Vec4(0.8f, 0.9f, 1, 1));

        auto scroll_bar = get_scrollbar_y(menu, scroll_region);
        render_rect(rp.hud_button, scroll_bar, Button_Color);
        render_button_border(rp.hud_rects_fg, scroll_bar);
    }
}

////
//
private:
//
////

struct Score_Cell_Def{
    String text;
    float  width;
    int alignment;
}

enum Button_Color = Vec4(0.54, 0.68, 0.82, 1);

immutable Score_Cell_Def[] g_score_cells = [
    {"Rank",    0.10f},
    {"Score",   0.20f},
    {"Name",    0.55f},
    {"Players", 0.15f},
];

enum Button_Width   = 320.0f;
enum Button_Height  = 40.0f;
enum Scrollbar_Size = 18.0f;

private Rect eat_row_piece(Rect* row, float row_width, float percent){
    auto w = row_width*percent;

    auto result = rect_from_min_wh(min(*row), w, height(*row));

    row.center.x += w*0.5f;
    row.extents.x -= w*0.5f;

    return result;
}

void center_on_active_item(Menu* menu){
    if(should_scroll(menu)){
        auto item = &menu.items[menu.hover_item_index];
        menu.scroll_offset.y = -bottom(item.bounds) + Margin;
    }
}

Rect get_scroll_region_y(Rect canvas){
    auto result = rect_from_min_wh(
        Vec2(right(canvas) - Scrollbar_Size, bottom(canvas)),
        Scrollbar_Size, height(canvas)
    );
    return result;
}

Rect get_scrollbar_y(Menu* menu, Rect scroll_region){
    auto region_height  = height(scroll_region);
    auto height_percent = min(0.85f, region_height / menu.content_height);

    //menu.content_height - region_height

    auto bar_height = max(region_height*height_percent, Scrollbar_Size);
    auto bar_bottom = region_height - map_range(menu.scroll_offset.y, 0, menu.content_height - region_height, bar_height, region_height);

    auto result = rect_from_min_wh(
        Vec2(left(scroll_region), bar_bottom),
        Scrollbar_Size, bar_height
    );
    return result;
}

bool is_interactive(Menu_Item* item){
    bool result = false;

    // TODO: For flexibility (and support for custom widgets), a bit flag should be used
    // to state if a menu item is interactive or not. Interactive items are items that can
    // be navigated to using the keyboard or clicked on using the mouse.
    switch(item.type){
        default: break;

        case Menu_Item_Type.Button:
        case Menu_Item_Type.Index_Picker:
        case Menu_Item_Type.High_Score_Row:
        case Menu_Item_Type.Textfield:
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

void end_current_style_group(Menu* menu){
    auto group = &menu.style_groups[menu.style_groups_count-1];
    group.items_end = menu.items_count;
}
