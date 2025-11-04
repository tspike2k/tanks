/*
Copyright (c) 2025 tspike2k@github.com
Distributed under the Boost Software License, Version 1.0.
See accompanying file LICENSE_BOOST.txt or copy at http://www.boost.org/LICENSE_1_0.txt
*/

/+
TODO:
    - Fix memory leak with calls to load_campaign_from_file. This should load the campaign into
    an allocator specially reserved for campaign memory. When we load, we should reset the
    allocator each time.

    - Undo buffer. This should be an expanding array (so use malloc/realloc?). We should directly
    push the state of removed maps/missions into this buffer so they can be restored easily.
    This way we don't have to ask the user if they're really sure they want to delete a map/mission.
    This means everything in the editor would have to be a command.

    - Input verification. Make sure the user can't add more thanks than a level can contain. Make
    sure multiple tanks cannot exist for a single spawn point, etc.
+/

import app;
import display;
import math;
import logging;
import render;
import memory;
import files;
import assets;
import meta;
import gui;
import menu;

private:

enum Place_Type : uint{
    Block,
    Tank,
}

enum Editor_Tab : uint{
    Selected,
    Map,
    Missions,
    Tanks,
    View,
    Info,
}

enum Cursor_Mode : uint{
    Select,
    Place,
    Erase,
}

enum Map_Width_Max  = 32;
enum Map_Height_Max = 32;

struct Tile{
    bool occupied;
    bool is_tank;
    bool is_special;
    uint index; // This is the spawn index for an enemy tank, the player index for a player tank, and the height for a block.
}

struct Map_Entry{
    Map_Entry* next;
    Map_Entry* prev;

    uint width;
    uint height;
    Tile[Map_Width_Max*Map_Height_Max] cells;
}

struct Mission_Entry{
    Mission_Entry* next;
    Mission_Entry* prev;
}

struct Tank_Entry{
    Tank_Entry* next;
    Tank_Entry* prev;

    Tank_Type params;
}

struct Variant{
    Variant* next;
    Variant* prev;

    uint players;
    uint lives;

    List!Mission_Entry  missions;
}

struct Text_Entry(uint Count){
    char[Count] buffer;
    uint        used;
}

enum Window_ID_Main            = 1;
enum Window_ID_Panel           = 2;
enum Button_Prev_Map           = gui_id();
enum Button_Next_Map           = gui_id();
enum Button_New_Map            = gui_id();
enum Button_Delete_Map         = gui_id();
enum Button_Begin_Save         = gui_id();
enum Button_Begin_Load         = gui_id();
enum Button_Confirm_Load       = gui_id();
enum Button_Confirm_Save       = gui_id();
enum Button_Cancel_File_Op     = gui_id();
enum Button_Prev_Tank_Type     = gui_id();
enum Button_Next_Tank_Type     = gui_id();

enum File_Op : uint{
    None,
    Save,
    Load,
}

__gshared File_Op        g_file_op;
__gshared bool           g_editor_is_open;
__gshared Allocator*     g_allocator;
__gshared Allocator*     g_frame_allocator;
__gshared char[256]      g_dest_file_name;
__gshared uint           g_dest_file_name_used;
__gshared bool           g_mouse_left_is_down;
__gshared bool           g_mouse_right_is_down;
__gshared Place_Type     g_place_type;
__gshared Cursor_Mode    g_cursor_mode;
__gshared Tile*          g_selected_tile;
__gshared bool           g_dragging_selected;
__gshared Vec2           g_drag_offset;
__gshared bool           g_overhead_view;

__gshared List!Variant    g_variants;
__gshared List!Map_Entry  g_maps;
__gshared Tank_Type[Max_Enemies+1] g_tank_types;
__gshared uint                     g_tank_types_count;

__gshared Map_Entry* g_current_map;
__gshared Variant*   g_current_variant;
__gshared uint       g_editor_tab;
__gshared uint       g_current_tank_type;

__gshared Text_Entry!(64)  g_campaign_name;
__gshared Text_Entry!(64)  g_campaign_author;
__gshared Text_Entry!(512) g_campaign_desc;
__gshared Text_Entry!(32)  g_campaign_version_string;

__gshared void[]         g_window_memory;
__gshared void[]         g_panel_memory;

char[] slice_text_entry(T)(T* t){
    auto result = t.buffer[0 .. t.used];
    return result;
}

void set_text_entry(T)(T *t, const(char)[] s){
    uint to_copy = cast(uint)min(t.buffer.length, s.length);
    copy(s[0 .. to_copy], t.buffer[0 .. to_copy]);
    t.used = to_copy;
}

void editor_save_campaign_file(App_State* s){
    auto scratch = s.frame_memory.scratch;
    push_frame(scratch);
    scope(exit) pop_frame(scratch);

    auto file_name = g_dest_file_name[0 .. g_dest_file_name_used];
    auto full_path = concat(trim_path(s.campaigns_path), to_string(Dir_Char), file_name, scratch);

    auto header = zero_type!Asset_Header;
    header.magic        = Campaign_Meta.magic;
    header.file_version = Campaign_Meta.file_version;
    header.asset_type   = Campaign_Meta.type;

    Campaign campaign;
    campaign.name           = slice_text_entry(&g_campaign_name);
    campaign.author         = slice_text_entry(&g_campaign_author);
    campaign.description    = slice_text_entry(&g_campaign_desc);
    campaign.version_string = slice_text_entry(&g_campaign_version_string);
    // TODO: Save date!

    campaign.maps = alloc_array!Campaign_Map(scratch, g_maps.count);
    uint map_index = 0;
    foreach(map; g_maps.iterate()){
        auto dest = &campaign.maps[map_index++];
        auto w = map.width;
        auto h = map.height;

        dest.width  = w;
        dest.height = h;
        dest.cells = alloc_array!Map_Cell(scratch, w*h);

        foreach(y; 0 .. h){
            foreach(x; 0 .. w){
                auto tile = &map.cells[x + y * Map_Width_Max];
                if(tile.occupied){
                    dest.cells[x + y * w] = encode_map_cell(tile.is_tank, tile.is_special, cast(ubyte)tile.index);
                }
            }
        }
    }



    // TODO: Put date
    //info.missions_count = cast(uint)g_missions.count;
    //info.maps_count     = cast(uint)g_maps.count;

    /+
    auto section = begin_writing_section(&serializer, Campaign_Section_Type.Maps);
    auto maps_count = cast(uint)g_maps.count;
    write(&serializer, maps_count);
    foreach(ref entry; g_maps.iterate()){
        write(&serializer, entry.map);
    }
    end_writing_section(&serializer, section);
+/
    /+
    foreach(ref entry; g_missions.iterate()){
        auto section = begin_writing_section(&serializer, Campaign_Section_Type.Mission);
        auto mission = &entry.mission;
        write(&serializer, *mission);
        end_writing_section(&serializer, section);
    }+/

    auto dest_buffer = begin_reserve_all(scratch);
    auto serializer = Serializer(dest_buffer);
    write(&serializer, header);
    write(&serializer, campaign);

    end_reserve_all(scratch, serializer.buffer, serializer.buffer_used);
    write_file_from_memory(full_path, serializer.buffer[0 .. serializer.buffer_used]);
}

bool editor_load_campaign(App_State* s, uint file_flags = 0){
    auto scratch = g_frame_allocator;
    push_frame(scratch);
    scope(exit) pop_frame(scratch);

    auto file_name = g_dest_file_name[0 .. g_dest_file_name_used];

    Campaign campaign;
    auto full_path = concat(trim_path(s.campaigns_path), to_string(Dir_Char), file_name, g_frame_allocator);
    auto memory = read_file_into_memory(full_path, scratch, file_flags);
    bool success = false;
    if(memory.length){
        if(load_campaign_from_memory(&campaign, memory, full_path, scratch)){
            success = true;

            set_text_entry(&g_campaign_name, campaign.name);
            set_text_entry(&g_campaign_author, campaign.author);
            set_text_entry(&g_campaign_desc, campaign.description);
            set_text_entry(&g_campaign_version_string, campaign.version_string);
            //set_text_entry(&g_campaign_date, campaign.date);

            prepare_campaign();

            if(campaign.variants.length){
                foreach(ref source_variant; campaign.variants){
                    auto variant = editor_add_variant();
                }
            }
            else{
                auto variant = editor_add_variant();
            }

            if(campaign.maps.length){
                foreach(ref source; campaign.maps){
                    auto w = source.width;
                    auto h = source.height;
                    auto dest = editor_add_map(w, h);

                    foreach(y; 0 .. h){
                        foreach(x; 0 .. w){
                            auto cell_value = source.cells[x + y * w];
                            auto tile = &dest.cells[x + y * Map_Width_Max];
                            tile.occupied   = cell_value != 0;
                            tile.is_tank    = cast(bool)(cell_value & Map_Cell_Is_Tank);
                            tile.is_special = cast(bool)(cell_value & Map_Cell_Is_Special);
                            tile.index      = cell_value & Map_Cell_Index_Mask;
                        }
                    }
                }
            }
            else{
                editor_add_map(24, 17);
            }

            if(campaign.tank_types.length){
                auto count = min(g_tank_types.length, campaign.tank_types.length);
                copy(campaign.tank_types[0 .. count], g_tank_types[0 .. count]);
                g_tank_types_count = cast(uint)count;
            }
            else{
                g_tank_types_count = 2;
                set_tank_type_to_default(&g_tank_types[0]);
                set_tank_type_to_default(&g_tank_types[1]);
            }
        }
        else{
            // TODO: Have a GUI-facing error log for the editor?
            log_error("Unable to edit campaign file {0}.\n", file_name);
        }
    }

    return success;
}

bool inside_grid(Map_Entry* map, Vec2 p){
    bool result = p.x >= 0.0f && p.x < cast(float)map.width
                  && p.y >= 0.0f && p.y < cast(float)map.height;
    return result;
}

bool is_cell_occupied(Map_Entry* map, Vec2 pos){
    assert(inside_grid(map, pos));
    auto x = cast(int)pos.x;
    auto y = cast(int)pos.y;
    auto result = map.cells[x + y * Map_Width_Max].occupied;
    return result;
}

void clear_cell(Map_Entry* map, Vec2 pos){
    assert(inside_grid(map, pos));
    auto x = cast(int)pos.x;
    auto y = cast(int)pos.y;
    map.cells[x + y * Map_Width_Max].occupied = false;
}

void set_cell(Map_Entry* map, Vec2 pos, bool is_tank, bool is_special, uint index){
    assert(inside_grid(map, pos));
    auto x = cast(int)pos.x;
    auto y = cast(int)pos.y;
    auto tile = &map.cells[x + y * Map_Width_Max];
    tile.occupied   = true;
    tile.is_tank    = is_tank;
    tile.is_special = is_special;
    tile.index      = index;
}

uint get_map_index(Map_Entry* map){
    uint index = 0;
    bool found_entry = false;
    foreach(entry; g_maps.iterate()){
        if(entry == map){
            found_entry = true;
            break;
        }
        index++;
    }

    assert(found_entry);
    return index;
}

void editor_remove_current_map(){
    auto maps = &g_maps;
    if(maps.count > 1){
        auto to_remove = g_current_map;
        auto next = g_current_map.next;
        if(maps.is_sentinel(next)){
            next = g_current_map.prev;
        }
        assert(!maps.is_sentinel(next));
        maps.remove(to_remove);
        g_current_map = next;
    }
}

void set_tank_type_to_default(Tank_Type* type){
    type.main_color = Vec3(0.600000, 0.500000, 0.300000);
    type.alt_color = Vec3(0.450000, 0.220000, 0.130000);
    type.invisible = false;
    type.speed = 0.000000;
    type.bullet_limit = 1;
    type.bullet_ricochets = 1;
    type.bullet_speed = 3.000000;
    type.bullet_min_ally_dist = 2.000000;
    type.mine_limit = 0;
    type.mine_timer_min = 0.000000;
    type.mine_timer_max = 0.000000;
    type.mine_cooldown_time = 0.100000;
    type.mine_stun_time = 0.050000;
    type.mine_placement_chance = 0.000000;
    type.mine_min_ally_dist = 3.000000;
    type.obstacle_sight_dist = float.nan; // TODO: Don't use NaN here!
    type.fire_timer_min = 0.500000;
    type.fire_timer_max = 0.750000;
    type.fire_stun_time = 1.000000;
    type.fire_cooldown_time = 5.000000;
    type.aim_timer = 1.000000;
    type.aim_max_angle = 2.967057;
}

__gshared uint[4] spin_test;

public bool editor_simulate(App_State* s, float dt){
    assert(g_editor_is_open);

    bool should_close = false;

    bool arrow_up_pressed    = false;
    bool arrow_down_pressed  = false;
    bool mouse_left_pressed  = false;
    bool mouse_right_pressed = false;

    auto map = g_current_map;
    auto grid_extents = Vec2(map.width, map.height)*0.5f;
    auto grid_center  = world_to_render_pos(grid_extents);
    s.world_camera_target_pos = world_to_render_pos(Vec2(map.width, map.height)*0.5f);

    auto display_window = get_window_info();
    float display_w = display_window.width;
    float display_h = display_window.height;
    if(g_overhead_view){
        float window_aspect_ratio = display_w/display_h;
        set_world_projection(&s.world_camera, map.width + 2, map.height + 2, window_aspect_ratio, 0);
        set_world_view(&s.world_camera, world_to_render_pos(Vec2(map.width, map.height)*0.5f), 90);

        auto mouse_world_3d = camera_ray_vs_plane(&s.world_camera, s.mouse_pixel, display_w, display_h);
        s.mouse_world = Vec2(mouse_world_3d.x, -mouse_world_3d.z);
    }

    auto font = &s.font_editor_small;
    auto gui = &s.gui;

    float panel_h = 32.0f;
    auto panel_bounds = rect_from_min_wh(Vec2(0, display_h - panel_h), display_w, panel_h);
    begin_window(gui, Window_ID_Panel, "Panel", panel_bounds, g_panel_memory, Window_Flag_Borderless);
    gui.edit_window.bounds = panel_bounds; // TODO: We should probably have a better way to anchor window positions.
    text_field(gui, gui_id(), g_dest_file_name, &g_dest_file_name_used);
    switch(g_file_op){
        default: break;

        case File_Op.None:{
            button(gui, Button_Begin_Save, "Save");
            button(gui, Button_Begin_Load, "Load");
        } break;

        case File_Op.Save:{
            label(gui, gui_id(), "Save?");
            button(gui, Button_Confirm_Save, "Yes");
            button(gui, Button_Cancel_File_Op, "No");
        } break;

        case File_Op.Load:{
            label(gui, gui_id(), "Load?");
            button(gui, Button_Confirm_Load, "Yes");
            button(gui, Button_Cancel_File_Op, "No");
        } break;
    }

    label(gui, gui_id(), gen_string("Mode: {0}", enum_string(g_cursor_mode), &s.frame_memory));
    label(gui, gui_id(), gen_string("Place: {0}", enum_string(g_place_type), &s.frame_memory));

    label(gui, gui_id(), "| Camera:");
    label(gui, gui_id(), "Overhead:");
    checkbox(gui, gui_id(), &g_overhead_view);

    //label(gui, gui_id(Window_ID_Panel));

    end_window(gui);

    // NOTE: We need to regenerate the GUI every frame because we generate strings and wire up
    // pointers for value editors. One solution for this is to only redefine the GUI when a
    // a major event happens (such as changing tabs). Then for every frame we loop over all the
    // widgets and regenerate labels/wire up pointers based on widget IDs. That's how we handle
    // the menu system. There is probably a better way that I'm not thinking of. However, if some
    // frames require a full GUI rebuild, the slow path will need to be executed at some point.
    // Doing it every frame ensures the performance cost is fairly consistent. See this internal
    // email by John Carmack:
    // http://number-none.com/blow/blog/programming/2014/09/26/carmack-on-inlined-code.html
    begin_window(gui, Window_ID_Main, "Editor", rect_from_min_wh(Vec2(20, 400), 400, 200), g_window_memory);
    next_row(gui);

    // NOTE: This is a good reason to have seperate "scroll regions." Ideally the tabs group
    // should remain at the top of the window while the rest of the contents scroll. That's
    // the reason classical GUIs do that. For this project, it's fine, but in the future more
    // control should be given to the client.
    tab(gui, gui_id(), "Selected", &g_editor_tab, Editor_Tab.Selected);
    tab(gui, gui_id(), "Map", &g_editor_tab, Editor_Tab.Map);
    tab(gui, gui_id(), "Mission", &g_editor_tab, Editor_Tab.Missions);
    tab(gui, gui_id(), "Tanks", &g_editor_tab, Editor_Tab.Tanks);
    tab(gui, gui_id(), "Info", &g_editor_tab, Editor_Tab.Info);
    next_row(gui);
    switch(g_editor_tab){
        default: break;

        case Editor_Tab.Map:{
            button(gui, Button_Prev_Map, "<", 0);
            auto map_index = get_map_index(map);
            auto map_msg = gen_string("Map index: {0}", map_index, &s.frame_memory);
            label(gui, gui_id(), map_msg);
            button(gui, Button_Next_Map, ">", 0);
            button(gui, Button_Delete_Map, "-", 0);
            button(gui, Button_New_Map, "+", 0);
            next_row(gui);
            label(gui, gui_id(), "Map width:");
            spin_button(gui, gui_id(), &map.width, 1, 0, Map_Width_Max);
            next_row(gui);
            label(gui, gui_id(), "Map height:");
            spin_button(gui, gui_id(), &map.height, 1, 0, Map_Height_Max);
            next_row(gui);
        } break;

        case Editor_Tab.Selected:{
            // TODO: Allow bulk selecting tiles?
            if(g_selected_tile){
                auto tile = g_selected_tile;
                uint max_index = uint.max;
                if(!tile.is_tank){
                    max_index = 7;
                }
                else if(tile.is_special){
                    max_index = Max_Players-1;
                }

                label(gui, gui_id(), "Special:");
                checkbox(gui, gui_id(), &tile.is_special);
                next_row(gui);
                label(gui, gui_id(), "Index:");
                spin_button(gui, gui_id(), &tile.index, max_index);
                next_row(gui);
            }
            else{
                label(gui, gui_id(), "Press 'S' to enter Select mode and choose a tile to edit.");;
            }
        } break;

        case Editor_Tab.Missions:{
            label(gui, gui_id(), "TODO: Add things!");
        } break;

        case Editor_Tab.Tanks:{
            auto type = &g_tank_types[g_current_tank_type];

            auto index_label = gen_string("Type index: {0}", g_current_tank_type, &s.frame_memory);
            button(gui, Button_Prev_Tank_Type, "<", 0);
            label(gui, gui_id(), index_label);
            button(gui, Button_Next_Tank_Type, ">", 0);
            next_row(gui);

            auto section_header = "-Tank Params (Enemy)-";
            if(g_current_tank_type == 0){
                section_header = "-Tank Params (Player)-";
            }

            label(gui, gui_id(), section_header);
            next_row(gui);

            static foreach(i, member; type.tupleof){
                // TODO: Break colors into RGB fields.
                label(gui, gui_id(), __traits(identifier, member) ~ ":");
                static if(is(typeof(member) == uint) || is(typeof(member) == float)){
                    spin_button(gui, gui_id(i), &type.tupleof[i]);
                }
                else static if(is(typeof(member) == bool)){
                    checkbox(gui, gui_id(i), &type.tupleof[i]);
                }
                next_row(gui);
            }
        } break;

        case Editor_Tab.Info:{
            label(gui, gui_id(), "-Campaign Info-");
            next_row(gui);
            label(gui, gui_id(), "Name:");
            text_field(gui, gui_id(), g_campaign_name.buffer[], &g_campaign_name.used);
            next_row(gui);

            label(gui, gui_id(), "Author:");
            text_field(gui, gui_id(), g_campaign_author.buffer[], &g_campaign_author.used);
            next_row(gui);

            label(gui, gui_id(), "Description:");
            text_field(gui, gui_id(), g_campaign_desc.buffer[], &g_campaign_desc.used);
            next_row(gui);

            label(gui, gui_id(), "Version:");
            text_field(gui, gui_id(), g_campaign_version_string.buffer[], &g_campaign_version_string.used);
            next_row(gui);
        } break;
    }
    end_window(gui);

    Event evt;
    bool text_buffer_updated = false;
    while(next_event(&evt)){
        handle_event_common(s, &evt, dt);
        if(!evt.consumed){
            switch(evt.type){
                default: break;

                case Event_Type.Button:{
                    auto btn = &evt.button;

                    switch(btn.id){
                        default: break;

                        case Button_ID.Mouse_Left:{
                            g_mouse_left_is_down = btn.pressed;
                            mouse_left_pressed   = btn.pressed;
                        } break;

                        case Button_ID.Mouse_Right:{
                            g_mouse_right_is_down = btn.pressed;
                            mouse_right_pressed   = btn.pressed;
                        } break;
                    }
                } break;

                case Event_Type.Key:{
                    auto key = &evt.key;
                    if(key.pressed){
                        switch(key.id){
                            default: break;

                            case Key_ID_Arrow_Up:{
                                arrow_up_pressed = true;
                            } break;

                            case Key_ID_Arrow_Down:{
                                arrow_down_pressed = true;
                            } break;

/+
                            case Key_ID_U:{
                                if(g_cursor_mode == Cursor_Mode.Select && g_selected_cell){
                                    (*g_selected_cell) ^= Map_Cell_Is_Special; // Toggle the special bit
                                }
                            } break;
                            case Key_ID_0:
                            case Key_ID_1:
                            case Key_ID_2:
                            case Key_ID_3:
                            case Key_ID_4:
                            case Key_ID_5:
                            case Key_ID_6:
                            case Key_ID_7:
                            {
                                if(!key.is_repeat){
                                    ubyte index = cast(ubyte)(key.id - Key_ID_0);
                                    if(g_cursor_mode == Cursor_Mode.Select && g_selected_cell){
                                        auto entity_type = *g_selected_cell;
                                        if(!(entity_type & Map_Cell_Is_Tank)){
                                            entity_type &= ~Map_Cell_Index_Mask;
                                            entity_type |= (index & Map_Cell_Index_Mask);
                                        }
                                        *g_selected_cell = entity_type;
                                    }
                                }
                            } break;
+/
                            case Key_ID_T:{
                                g_place_type = Place_Type.Tank;
                            } break;

                            case Key_ID_B:{
                                g_place_type = Place_Type.Block;
                            } break;

                            case Key_ID_P:{
                                g_cursor_mode = Cursor_Mode.Place;
                            } break;

                            case Key_ID_E:{
                                g_cursor_mode = Cursor_Mode.Erase;
                            } break;

                            case Key_ID_Delete:{
                                if(g_cursor_mode == Cursor_Mode.Select && g_selected_tile){
                                        foreach(y; 0 .. map.height){
                                            foreach(x; 0 .. map.width){
                                                auto test_tile = &map.cells[x + y * Map_Width_Max];
                                                if(test_tile == g_selected_tile){
                                                    clear_cell(map, Vec2(x, y));
                                                }
                                            }
                                        }
                                        g_selected_tile = null;
                                }
                            } break;

                            case Key_ID_S:{
                                if(!key.is_repeat){
                                    if(key.modifier & Key_Modifier_Ctrl){
                                        editor_save_campaign_file(s);
                                    }
                                    else{
                                        g_cursor_mode = Cursor_Mode.Select;
                                    }
                                }
                            } break;

                            case Key_ID_L:{
                                if(!key.is_repeat && key.modifier & Key_Modifier_Ctrl){
                                    editor_load_campaign(s);
                                }
                            } break;

                            case Key_ID_F2:
                                if(!key.is_repeat){
                                    should_close = true;
                                }
                            break;
                        }
                    }
                } break;
            }
        }
    }

    update_gui(&s.gui, dt, &s.frame_memory);
    if(s.gui.message_id != Null_Gui_ID){
        switch(s.gui.message_id){
            default: break;

            case Button_New_Map:{
                editor_add_map(map.width, map.height);
            } break;

            case Button_Delete_Map:{
                editor_remove_current_map();
            } break;

            case Button_Next_Map:{
                auto next_map = g_current_map.next;
                auto variant  = g_current_variant;
                if(g_maps.is_sentinel(next_map)){
                    next_map = next_map.next;
                }
                g_current_map = next_map;
            } break;

            case Button_Prev_Map:{
                auto next_map = g_current_map.prev;
                auto variant  = g_current_variant;
                if(g_maps.is_sentinel(next_map)){
                    next_map = next_map.prev;
                }
                g_current_map = next_map;
            } break;

            case Button_Next_Tank_Type:{
                g_current_tank_type++;
                if(g_current_tank_type == g_tank_types_count)
                    g_current_tank_type = 0;
            } break;

            case Button_Prev_Tank_Type:{
                if(g_current_tank_type == 0)
                    g_current_tank_type = g_tank_types_count;
                g_current_tank_type--;
            } break;

            case Button_Begin_Save:{
                g_file_op = File_Op.Save;
            } break;

            case Button_Begin_Load:{
                g_file_op = File_Op.Load;
            } break;

            case Button_Confirm_Save:{
                editor_save_campaign_file(s);
                g_file_op = File_Op.None;
            } break;

            case Button_Confirm_Load:{
                editor_load_campaign(s);
                g_file_op = File_Op.None;
            } break;

            case Button_Cancel_File_Op:{
                g_file_op = File_Op.None;
            } break;
        }
    }

    switch(g_cursor_mode){
        default: break;

        case Cursor_Mode.Place:{
            if(g_mouse_left_is_down){
                if(inside_grid(map, s.mouse_world) && !is_cell_occupied(map, s.mouse_world)){
                    bool is_tank = g_place_type == Place_Type.Tank;
                    set_cell(map, s.mouse_world, is_tank, false, 1);
                }
            }
        } break;

        case Cursor_Mode.Erase:{
            if(g_mouse_left_is_down && inside_grid(map, s.mouse_world)){
                clear_cell(map, s.mouse_world);
            }
        } break;

        case Cursor_Mode.Select:{
            if(mouse_left_pressed){
                if(inside_grid(map, s.mouse_world) && is_cell_occupied(map, s.mouse_world)){
                    auto x = cast(int)s.mouse_world.x;
                    auto y = cast(int)s.mouse_world.y;
                    g_selected_tile = &map.cells[x + y * Map_Width_Max];
                }
                else{
                    g_selected_tile = null;
                }
            }
        } break;
    }

    /+
    switch(g_cursor_mode){
        default: break;

        case Cursor_Mode.Select:{
            if(g_selected_entity){
                s.highlight_entity_id = g_selected_entity.id;
            }
            else{
                s.highlight_entity_id = Null_Entity_ID;
            }
            s.highlight_material = &s.material_eraser;

            if(mouse_left_pressed){
                auto e = editor_get_entity(layer, s.mouse_world);
                g_selected_entity = e;
                if(e){
                    g_drag_offset = e.pos - s.mouse_world;
                }
            }

            if(g_selected_entity){
                auto e = g_selected_entity;
                if(e){
                    if(g_mouse_right_is_down){
                        // TODO: We'd like to be able to use shift+click or ctrl+click to
                        // allow the user to snap rotation to fixed points.
                        auto dir = normalize(s.mouse_world - e.pos);
                        e.angle = atan2(dir.y, dir.x);
                    }

                    if(g_mouse_left_is_down){
                        if(g_dragging_selected){
                            auto dest_p = s.mouse_world + g_drag_offset;
                            if(inside_grid(dest_p)){
                                if(e.type == Entity_Type.Block){
                                    e.pos = floor(dest_p) + Vec2(0.5f, 0.5f);
                                }
                                else{
                                    e.pos = dest_p;
                                }
                            }
                        }
                        else{
                            g_dragging_selected = dist_sq(e.pos, s.mouse_world + g_drag_offset) > squared(0.5f);
                        }
                    }
                    else{
                        g_dragging_selected = false;
                    }

                    if(arrow_up_pressed && e.type == Entity_Type.Block && e.block_height < 7){
                        e.block_height++;
                    }

                    if(arrow_down_pressed && e.type == Entity_Type.Block && e.block_height > 0){
                        e.block_height--;
                    }
                }
                else{
                    g_selected_entity = null;
                }
            }
        } break;

        case Cursor_Mode.Place:{
            if(inside_grid(s.mouse_world)){
                if(g_edit_mode == Edit_Mode.Map && g_mouse_left_is_down){
                    auto tile = floor(s.mouse_world);
                    if(!block_exists_on_tile(tile)){
                        editor_add_entity(g_current_map, tile + Vec2(0.5f, 0.5f), Entity_Type.Block);
                    }
                }
                else if(g_edit_mode == Edit_Mode.Level && mouse_left_pressed){
                    editor_add_entity(g_current_level, s.mouse_world, Entity_Type.Tank);
                }
            }
        } break;

        case Cursor_Mode.Erase:{
            auto hover_e = editor_get_entity(layer, s.mouse_world);
            if(hover_e){
                s.highlight_entity_id = hover_e.id;
                s.highlight_material  = &s.material_eraser;

                if(g_mouse_left_is_down && hover_e){
                    remove_entity(layer, hover_e);
                }
            }
            else{
                s.highlight_entity_id = Null_Entity_ID;
            }
        } break;
    }+/

    if(should_close){
        editor_toggle(s);
    }
    return should_close;
}

Entity make_synthetic_entity(Vec2 pos, Tile* tile, Vec2 map_center){
    auto type = Entity_Type.Block;
    if(tile.is_tank)
        type = Entity_Type.Tank;

    Entity result;
    make_entity(&result, 1, pos, type);

    result.cell_info = encode_map_cell(tile.is_tank, tile.is_special, cast(ubyte)tile.index);
    if(tile.is_tank){
        // TODO: The tank type determines the materials to use. But this is based off the loaded
        // campaign, not the campaign we're editing. How should we rectify this?
        result.tank_type_index = 1;
        set_default_tank_facing(&result, map_center);
    }

    return result;
}

public void editor_render(App_State* s, Render_Passes rp){
    auto window = get_window_info();

    auto font_small = &s.font_editor_small;

    auto padding = 16;
    auto pen = Vec2(padding, window.height - padding - font_small.metrics.height);
    version(none){
        render_text(
            rp.hud_text, font_small, pen,
            gen_string("Mode: {0}", enum_string(g_cursor_mode), &s.frame_memory)
        );
        pen.y -= font_small.metrics.line_gap;
        if(g_cursor_mode == Cursor_Mode.Place){
            render_text(
                rp.hud_text, font_small, pen,
                gen_string("Place Mode: {0}", enum_string(g_place_type), &s.frame_memory)
            );
        }
    }

    auto map = g_current_map;
    auto map_center = Vec2(map.width, map.height)*0.5f;
    render_ground(s, rp.world, rect_from_min_max(Vec2(0, 0), Vec2(map.width, map.height)));

    foreach(y; 0 .. map.height){
        foreach(x; 0 .. map.width){
            auto tile = &map.cells[x + y * Map_Width_Max];
            if(tile.occupied){
                auto e = make_synthetic_entity(Vec2(x, y) + Vec2(0.5f, 0.5f), tile, map_center);
                render_entity(s, &e, rp, tile == g_selected_tile);
            }
        }
    }

    if(g_cursor_mode == Cursor_Mode.Place && inside_grid(map, s.mouse_world)){
        Tile cursor_tile;
        cursor_tile.is_tank = g_place_type == Place_Type.Tank;
        cursor_tile.is_special = false;
        cursor_tile.index = 1;

        auto p = floor(s.mouse_world) + Vec2(0.5f, 0.5f);
        auto e = make_synthetic_entity(p, &cursor_tile, map_center);
        render_entity(s, &e, rp);
    }

    /+
    switch(g_cursor_mode){
        default: break;

        case Cursor_Mode.Select:{
            // Draw cursor
            auto p = world_to_render_pos(s.mouse_world);
            auto material = &s.material_block;
            render_mesh(
                rp.world, &s.cube_mesh, material,
                mat4_translate(p)*mat4_scale(Vec3(0.25f, 0.25f, 0.25f))
            );

            auto e = g_selected_entity;
            if(e){
                pen.y -= font_small.metrics.line_gap;
                pen.x = padding;

                render_text(
                    rp.hud_text, font_small, pen,
                    gen_string("Selected : {0}", enum_string(e.type), &s.frame_memory)
                );
                pen.y -= font_small.metrics.line_gap;

                switch(e.type){
                    default: break;

                    case Entity_Type.Block:{
                        String extra = "";
                        if(e.block_height == 0){
                            extra = "(hole)";
                        }

                        render_text(
                            rp.hud_text, font_small, pen,
                            gen_string("Height: {0} {1}", e.block_height, extra, &s.frame_memory)
                        );
                    } break;

                    case Entity_Type.Tank:{
                        String extra = "";
                        if(e.player_index == 0){
                            extra = "(enemy)";
                        }

                        render_text(
                            rp.hud_text, font_small, pen,
                            gen_string("Player Index: {0} {1}", e.player_index, extra, &s.frame_memory)
                        );
                    } break;
                }
            }
        } break;

        case Cursor_Mode.Place:{
            if(inside_grid(s.mouse_world)){
                if(g_edit_mode == Edit_Mode.Map){
                    Entity e = void;
                    make_entity(&e, Synthetic_Entity_ID, floor(s.mouse_world) + Vec2(0.5f, 0.5f), Entity_Type.Block);
                    render_entity(s, &e, rp);
                }
                else if(g_edit_mode == Edit_Mode.Level){
                    Entity e = void;
                    make_entity(&e, Synthetic_Entity_ID, s.mouse_world, Entity_Type.Tank);
                    render_entity(s, &e, rp);
                }
            }
        } break;
    }
+/

    // Draw cursor
    auto p = world_to_render_pos(s.mouse_world);
    auto material = (&s.material_block)[0..1];
    render_mesh(
        rp.world, &s.cube_mesh, material,
        mat4_translate(p)*mat4_scale(Vec3(0.25f, 0.25f, 0.25f))
    );
}

Variant* editor_add_variant(){
    auto variant = alloc_type!Variant(g_allocator);
    g_variants.insert(g_variants.top, variant);
    g_current_variant = variant;

    variant.players = 1;
    variant.lives   = 4; // TODO: Is this the default of the WII original?

    variant.missions.make();

    return variant;
}

Map_Entry* editor_add_map(uint width, uint height){
    auto variant = g_current_variant;
    auto map = alloc_type!Map_Entry(g_allocator);

    // Default values.
    assert(width <= Map_Width_Max);
    assert(height <= Map_Height_Max);
    map.width  = width;
    map.height = height;

    g_maps.insert(g_maps.top, map);
    g_current_map = map;
    return map;
}

void prepare_campaign(){
    reset(g_allocator); // IMPORTANT: This frees all the memory used by the editor.
    g_variants.make();
    g_maps.make();
}

void editor_new_campaign(){
    prepare_campaign();
    editor_add_variant();
    editor_add_map(22, 17);
    g_tank_types_count = 2;
    set_tank_type_to_default(&g_tank_types[0]);
    set_tank_type_to_default(&g_tank_types[1]);
}

/+
void editor_load_maps_file(String name){
    push_frame(g_allocator.scratch);
    scope(exit) pop_frame(g_allocator.scratch);

    auto memory = read_file_into_memory(name, g_allocator.scratch);
    auto reader = Serializer(memory, g_allocator.scratch);
    auto header = eat_type!Asset_Header(&reader);
    if(verify_asset_header!Maps_Meta(name, header)){
        Campaign_Map[] maps;
        read(&reader, maps);

        foreach(ref source; maps){
            auto map_entry = editor_add_map();
            map_entry.map = source;
            map_entry.map.cells = dup_array(source.cells, g_allocator);
        }
    }
}+/

Vec3 get_map_center(Campaign_Map* map){
    auto grid_extents = Vec2(map.width, map.height)*0.5f;
    auto result = world_to_render_pos(grid_extents);
    return result;
}

public void editor_toggle(App_State* s){
    // TODO: Don't use malloc and free. Have a free list of window memory.
    import core.stdc.stdlib : malloc, free;

    auto gui = &s.gui;
    if(!g_editor_is_open){
        g_allocator       = &s.editor_memory;
        g_frame_allocator = &s.frame_memory;

        set_menu(&s.menu, Menu_ID.None);

        g_mouse_left_is_down  = false;
        g_mouse_right_is_down = false;

        string target_file_name = "sample.camp"; // TODO: This should be loaded from an editor session file.
        auto dest_name = copy_string_to_buffer(target_file_name, g_dest_file_name);
        g_dest_file_name_used = cast(uint)dest_name.length;

        if(!editor_load_campaign(s, File_Flag_No_Open_Errors)){
            editor_new_campaign();
            //editor_load_maps_file("./build/wii_16x9.maps");
        }

        auto map = g_current_map;
        auto map_center = 0.5f*Vec2(map.width, map.height);
        s.world_camera_target_pos = world_to_render_pos(map_center);

        g_overhead_view = true;

        g_window_memory = malloc(4096)[0 .. 4096];
        g_panel_memory  = malloc(2048)[0 .. 2048];

        /+
        memory = (malloc(4086)[0 .. 4086]);
        window = add_window(gui, "Alt Window", Window_ID_Editor_Test_2, rect_from_min_wh(Vec2(20, 20), 200, 80), memory);
        button(window, Button_ID_Editor_Test_2, "Test Button");+/
    }
    else{
        // Close all the windows.
        // TODO: Only close editor windows!
        auto window = gui.windows.bottom;
        while(!gui.windows.is_sentinel(window)){
            auto window_next = window.next;
            gui.windows.remove(window);
            free(window);
            window = window_next;
        }
    }

    g_editor_is_open = !g_editor_is_open;
}

