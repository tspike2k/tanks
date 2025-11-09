/*
Copyright (c) 2025 tspike2k@github.com
Distributed under the Boost Software License, Version 1.0.
See accompanying file LICENSE_BOOST.txt or copy at http://www.boost.org/LICENSE_1_0.txt
*/

/+
TODO:
    - Undo buffer. This should be an expanding array (so use malloc/realloc?). We should directly
    push the state of removed maps/missions into this buffer so they can be restored easily.
    This way we don't have to ask the user if they're really sure they want to delete a map/mission.
    This means everything in the editor would have to be a command.

    - Input verification. Make sure the user can't add more thanks than a level can contain. Make
    sure multiple tanks cannot exist for a single spawn point, etc.

    - Better visualization for the effect editing properties will produce and on what.
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
    Variant,
    Missions,
    Tanks,
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

    bool awards_tank_bonus;
    uint map_index_min;
    uint map_index_max;
    Enemy_Tank[32] enemies;
    uint           enemies_count;
}

struct Tank_Entry{
    Tank_Entry* next;
    Tank_Entry* prev;

    Tank_Type params;
}

struct Variant{
    Variant* next;
    Variant* prev;

    char[256] name;
    uint      name_used;
    uint      players;
    uint      lives;
    Campaign_Difficuly difficulty;

    List!Mission_Entry  missions;
}

struct Free_List(T){
    T* next;
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
enum Button_Prev_Difficulty    = gui_id();
enum Button_Next_Difficulty    = gui_id();
enum Button_Prev_Variant       = gui_id();
enum Button_Next_Variant       = gui_id();
enum Button_Delete_Variant     = gui_id();
enum Button_New_Variant        = gui_id();
enum Button_Prev_Mission       = gui_id();
enum Button_Next_Mission       = gui_id();
enum Button_Delete_Mission     = gui_id();
enum Button_New_Mission        = gui_id();

enum Button_Prev_Enemy         = gui_id();
enum Button_Next_Enemy         = gui_id();
enum Button_Delete_Enemy       = gui_id();
enum Button_New_Enemy          = gui_id();

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
__gshared Vec2           g_drag_offset;
__gshared bool           g_overhead_view;
__gshared uint           g_current_enemy_index;

__gshared List!Variant    g_variants;
__gshared List!Map_Entry  g_maps;
__gshared Tank_Type[Max_Enemies+1]      g_tank_types;
__gshared uint                          g_tank_types_count;
__gshared Tank_Materials[Max_Enemies+1] g_tank_materials;

__gshared Mission_Entry* g_current_mission;
__gshared Map_Entry*     g_current_map;
__gshared Variant*       g_current_variant;
__gshared uint           g_editor_tab;
__gshared uint           g_current_tank_type;

__gshared Free_List!Mission_Entry  g_mission_freelist;
__gshared Free_List!Map_Entry      g_maps_freelist;
__gshared Free_List!Variant        g_variant_freelist;

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
    campaign.tank_types     = g_tank_types[0 .. g_tank_types_count];

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

    campaign.variants = alloc_array!Campaign_Variant(scratch, g_variants.count);
    uint variant_index  = 0;
    foreach(variant; g_variants.iterate()){
        auto dest = &campaign.variants[variant_index++];
        dest.name = variant.name[0 .. variant.name_used];
        dest.players = variant.players;
        dest.lives   = variant.lives;
        dest.difficulty = variant.difficulty;

        dest.missions = alloc_array!Campaign_Mission(scratch, variant.missions.count);
        uint mission_index = 0;
        foreach(ref src_mission; variant.missions.iterate()){
            auto mission = &dest.missions[mission_index++];
            mission.awards_tank_bonus = src_mission.awards_tank_bonus;
            mission.map_index_min     = src_mission.map_index_min;
            mission.map_index_max     = src_mission.map_index_max;
            mission.enemies           = src_mission.enemies[0 .. src_mission.enemies_count];
        }
    }

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
                    variant.lives   = source_variant.lives;
                    variant.players = source_variant.players;
                    variant.name_used = cast(uint)copy(source_variant.name, variant.name);
                    variant.difficulty = source_variant.difficulty;

                    foreach(ref src_mission; source_variant.missions){
                        auto mission = editor_add_mission();
                        mission.awards_tank_bonus = src_mission.awards_tank_bonus;
                        mission.map_index_min     = src_mission.map_index_min;
                        mission.map_index_max     = src_mission.map_index_max;
                        copy(src_mission.enemies, mission.enemies);
                        mission.enemies_count = cast(uint)src_mission.enemies.length;
                    }
                    g_current_mission = variant.missions.bottom;
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
                set_tank_type_to_default(&g_tank_types[0], true);
                set_tank_type_to_default(&g_tank_types[1], false);
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

bool is_cell_occupied(Map_Entry* map, int x, int y){
    assert(inside_grid(map, Vec2(x, y)));
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

uint get_variant_index(Variant* variant){
    uint index = 0;
    bool found_entry = false;
    foreach(entry; g_variants.iterate()){
        if(entry == variant){
            found_entry = true;
            break;
        }
        index++;
    }

    assert(found_entry);
    return index;
}

uint get_mission_index(Mission_Entry* mission){
    uint index = 0;
    bool found_entry = false;
    auto variant = g_current_variant;
    foreach(entry; variant.missions.iterate()){
        if(entry == mission){
            found_entry = true;
            break;
        }
        index++;
    }

    assert(found_entry);
    return index;
}

void set_tank_type_to_default(Tank_Type* type, bool is_player){
    type.main_color = Vec3(0.600000, 0.500000, 0.300000);
    type.alt_color = Vec3(0.450000, 0.220000, 0.130000);
    type.invisible = false;
    type.speed = 1.800000;
    type.bullet_speed = 3.000000;
    type.bullet_min_ally_dist = 2.000000;
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

    if(is_player){
        type.bullet_limit = 1;
        type.mine_limit   = 3;
        type.bullet_ricochets = 1;
    }
    else
        type.mine_limit   = 0;
        type.bullet_limit = 1;
        type.bullet_ricochets = 0;
}

T* list_get_prev(List, T)(List* list, T* node){
    auto result = node.prev;
    if(list.is_sentinel(result)){
        result = result.prev;
    }
    return result;
}

T* list_get_next(List, T)(List* list, T* node){
    auto result = node.next;
    if(list.is_sentinel(result)){
        result = result.next;
    }
    return result;
}

T* list_remove_current(List, T, Free_List)(List* list, T* node, Free_List* freelist){
    T* result = node;
    if(list.count > 1){
        auto to_remove = node;
        result = node.next;
        if(list.is_sentinel(result)){
            result = result.next;
        }
        assert(!list.is_sentinel(result));
        assert(result != to_remove);
        list.remove(to_remove);
        to_remove.next = freelist.next;
        freelist.next = to_remove;
    }
    return result;
}

T* alloc_or_freelist(T, Freelist)(Freelist* freelist){
    T* result;
    if(freelist.next){
        result = freelist.next;
        freelist.next = result.next;
        clear_to_zero(*result);
    }
    else{
        result = alloc_type!T(g_allocator);
    }
    return result;
}


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
    tab(gui, gui_id(), "Variant", &g_editor_tab, Editor_Tab.Variant);
    tab(gui, gui_id(), "Mission", &g_editor_tab, Editor_Tab.Missions);
    tab(gui, gui_id(), "Tank", &g_editor_tab, Editor_Tab.Tanks);
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
            spin_button(gui, gui_id(), &map.width, 1, Map_Width_Max);
            next_row(gui);
            label(gui, gui_id(), "Map height:");
            spin_button(gui, gui_id(), &map.height, 1, Map_Height_Max);
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

                auto special_label = "Is breakable:";
                if(tile.is_tank){
                    special_label = "Is player:";
                }

                label(gui, gui_id(), special_label);
                checkbox(gui, gui_id(), &tile.is_special);
                next_row(gui);

                auto index_label = "Block height:";
                if(tile.is_tank){
                    if(tile.is_special)
                        index_label = "Player index:";
                    else
                        index_label = "Enemy spawn index:";
                }

                label(gui, gui_id(), index_label);
                spin_button(gui, gui_id(), &tile.index, 0, max_index);
                next_row(gui);
            }
            else{
                label(gui, gui_id(), "Press 'S' to enter Select mode and choose a tile to edit.");;
            }
        } break;

        case Editor_Tab.Variant:{
            auto variant  = g_current_variant;

            button(gui, Button_Prev_Variant, "<", 0);
            auto variant_index = get_variant_index(variant);
            auto variant_label = gen_string("Variant: {0}", variant_index, &s.frame_memory);
            label(gui, gui_id(), variant_label);
            button(gui, Button_Next_Variant, ">", 0);
            button(gui, Button_Delete_Variant, "-", 0);
            button(gui, Button_New_Variant, "+", 0);
            next_row(gui);

            label(gui, gui_id(), "Name:");
            text_field(gui, gui_id(), variant.name[], &variant.name_used);
            next_row(gui);

            auto difficulty_label = gen_string("Difficulty: {0}", variant.difficulty, &s.frame_memory);
            button(gui, Button_Prev_Difficulty, "<", 0);
            button(gui, Button_Next_Difficulty, ">", 0);
            label(gui, gui_id(), difficulty_label);
            next_row(gui);

            auto missions_label = gen_string("Missions: {0}", variant.missions.count, &s.frame_memory);
            label(gui, gui_id(), missions_label);
            next_row(gui);

            label(gui, gui_id(), "Lives:");
            spin_button(gui, gui_id(), &variant.lives);
            next_row(gui);

            label(gui, gui_id(), "Players:");
            spin_button(gui, gui_id(), &variant.players, 1, 4);
            next_row(gui);
        } break;

        case Editor_Tab.Missions:{
            auto variant = g_current_variant;
            auto mission = g_current_mission;

            auto variant_label = gen_string("Variant: {0}", variant.name[0 .. variant.name_used], &s.frame_memory);
            label(gui, gui_id(), variant_label);
            next_row(gui);

            button(gui, Button_Prev_Mission, "<", 0);
            auto mission_index = get_mission_index(mission);
            auto mission_label = gen_string("Mission: {0}", mission_index, &s.frame_memory);
            label(gui, gui_id(), mission_label);
            button(gui, Button_Next_Mission, ">", 0);
            button(gui, Button_Delete_Mission, "-", 0);
            button(gui, Button_New_Mission, "+", 0);
            next_row(gui);

            label(gui, gui_id(), "Tank bonus:");
            checkbox(gui, gui_id(), &mission.awards_tank_bonus);
            next_row(gui);

            label(gui, gui_id(), "Map Min:");
            spin_button(gui, gui_id(), &mission.map_index_min, 0, mission.map_index_max);
            next_row(gui);

            label(gui, gui_id(), "Map Max:");
            spin_button(gui, gui_id(), &mission.map_index_max, 0, cast(uint)g_maps.count);
            next_row(gui);

            label(gui, gui_id(), "-Enemies-");
            next_row(gui);

            button(gui, Button_Prev_Enemy, "<", 0);
            auto enemy_label= gen_string("Enemy: {0}", g_current_enemy_index, &s.frame_memory);
            label(gui, gui_id(), enemy_label);
            button(gui, Button_Next_Enemy, ">", 0);
            button(gui, Button_Delete_Enemy, "-", 0);
            button(gui, Button_New_Enemy, "+", 0);
            next_row(gui);

            if(mission.enemies_count > 0){
                g_current_enemy_index = min(mission.enemies_count, g_current_enemy_index);
                auto enemy = &mission.enemies[g_current_enemy_index];

                label(gui, gui_id(), "Type Min:");
                spin_button(gui, gui_id(), &enemy.type_min, 1, enemy.type_max);
                next_row(gui);

                label(gui, gui_id(), "Type Max:");
                spin_button(gui, gui_id(), &enemy.type_max, 1, g_tank_types_count);
                next_row(gui);

                label(gui, gui_id(), "Spawn index:");
                spin_button(gui, gui_id(), &enemy.spawn_index);
                next_row(gui);
            }
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

            static foreach(i, member; type.tupleof){{
                alias T = typeof(member);
                label(gui, gui_id(), __traits(identifier, member) ~ ":");
                static if(is(T == uint) || is(T == float)){
                    spin_button(gui, gui_id(i), &type.tupleof[i], 0);
                }
                else static if(is(T == Vec3)){
                    auto v = &type.tupleof[i];
                    next_row(gui);
                    label(gui, gui_id(), "R:");
                    spin_button(gui, gui_id(i), &v.r, 0, 1, 0.1f);
                    next_row(gui);
                    label(gui, gui_id(), "G:");
                    spin_button(gui, gui_id(i), &v.g, 0, 1, 0.1f);
                    next_row(gui);
                    label(gui, gui_id(), "B:");
                    spin_button(gui, gui_id(i), &v.b, 0, 1, 0.1f);
                    next_row(gui);
                }
                else static if(is(T == bool)){
                    checkbox(gui, gui_id(i), &type.tupleof[i]);
                }
                next_row(gui);
            }}
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
                                        if(g_file_op != File_Op.Save){
                                            g_file_op = File_Op.Save;
                                        }
                                        else{
                                            g_file_op = File_Op.None;
                                            editor_save_campaign_file(s);
                                        }
                                    }
                                    else{
                                        g_cursor_mode = Cursor_Mode.Select;
                                    }
                                }
                            } break;

                            case Key_ID_L:{
                                if(!key.is_repeat && key.modifier & Key_Modifier_Ctrl){
                                    if(g_file_op != File_Op.Load){
                                        g_file_op = File_Op.Load;
                                    }
                                    else{
                                        g_file_op = File_Op.None;
                                        editor_load_campaign(s);
                                    }
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
                g_current_map = list_remove_current(&g_maps, g_current_map, &g_maps_freelist);
            } break;

            case Button_Next_Map:{
                g_current_map = list_get_next(&g_maps, g_current_map);
            } break;

            case Button_Prev_Map:{
                g_current_map = list_get_prev(&g_maps, g_current_map);
            } break;

            case Button_Prev_Variant:{
                g_current_variant = list_get_prev(&g_variants, g_current_variant);
                g_current_mission = g_current_variant.missions.bottom;
            } break;

            case Button_Next_Variant:{
                g_current_variant = list_get_next(&g_variants, g_current_variant);
                g_current_mission = g_current_variant.missions.bottom;
            } break;

            case Button_Delete_Variant:{
                g_current_variant = list_remove_current(&g_variants, g_current_variant, &g_variant_freelist);
                g_current_mission = g_current_variant.missions.bottom;
            } break;

            case Button_New_Variant:{
                editor_add_variant();
            } break;

            case Button_Prev_Mission:{
                g_current_mission = list_get_prev(&g_current_variant.missions, g_current_mission);
                g_current_enemy_index = 0;
            } break;

            case Button_Next_Mission:{
                g_current_enemy_index = 0;
                g_current_mission = list_get_next(&g_current_variant.missions, g_current_mission);
            } break;

            case Button_Delete_Mission:{
                g_current_enemy_index = 0;
                g_current_mission = list_remove_current(&g_current_variant.missions, g_current_mission, &g_mission_freelist);
            } break;

            case Button_New_Mission:{
                g_current_enemy_index = 0;
                editor_add_mission();
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

            case Button_Next_Difficulty:{
                auto variant = g_current_variant;
                auto d = cast(uint)variant.difficulty;
                d = clamp(d + 1, 0, Campaign_Difficuly.max);
                variant.difficulty = cast(Campaign_Difficuly)d;
            } break;

            case Button_Prev_Difficulty:{
                auto variant = g_current_variant;
                auto d = cast(uint)variant.difficulty;
                d = clamp(d - 1, 0, Campaign_Difficuly.max);
                variant.difficulty = cast(Campaign_Difficuly)d;
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

            case Button_New_Enemy:{
                auto mission = g_current_mission;
                if(mission.enemies_count < mission.enemies.length){
                    g_current_enemy_index = mission.enemies_count;
                    auto enemy = &mission.enemies[g_current_enemy_index];
                    enemy.type_min = 1;
                    enemy.type_max = 1;
                    mission.enemies_count++;
                }
            } break;
        }
    }

    switch(g_cursor_mode){
        default: break;

        case Cursor_Mode.Place:{
            if(g_mouse_left_is_down){
                auto x = cast(int)s.mouse_world.x;
                auto y = cast(int)s.mouse_world.y;
                if(inside_grid(map, s.mouse_world) && !is_cell_occupied(map, x, y)){
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
                auto x = cast(int)s.mouse_world.x;
                auto y = cast(int)s.mouse_world.y;
                if(inside_grid(map, s.mouse_world) && is_cell_occupied(map, x, y)){
                    g_selected_tile = &map.cells[x + y * Map_Width_Max];
                    g_drag_offset = Vec2(x, y) - s.mouse_world;
                }
                else{
                    g_selected_tile = null;
                }
            }

            if(g_mouse_left_is_down && g_selected_tile){
                auto dest_p = s.mouse_world + g_drag_offset;
                auto x = cast(int)s.mouse_world.x;
                auto y = cast(int)s.mouse_world.y;
                if(inside_grid(map, dest_p) && !is_cell_occupied(map, x, y)){
                    auto tile_value  = *g_selected_tile;
                    g_selected_tile.occupied = false;

                    g_selected_tile = &map.cells[x + y * Map_Width_Max];
                    *g_selected_tile = tile_value;
                }
            }
        } break;
    }

    // Setup tank materials
    foreach(i, ref entry; g_tank_types[0 .. g_tank_types_count]){
        auto tank_mats = &g_tank_materials[i];
        setup_basic_material(&tank_mats.materials[0], s.img_blank_mesh, entry.main_color);
        setup_basic_material(&tank_mats.materials[1], s.img_blank_mesh, entry.alt_color, 256);
    }

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
                auto enemy_materials = g_tank_materials[0 .. g_tank_types_count];
                render_entity(s, &e, rp, enemy_materials, tile == g_selected_tile);
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
        auto enemy_materials = g_tank_materials[0 .. g_tank_types_count];
        render_entity(s, &e, rp, enemy_materials);
    }

    // Draw cursor
    auto p = world_to_render_pos(s.mouse_world);
    auto material = (&s.material_block)[0..1];
    render_mesh(
        rp.world, &s.cube_mesh, material,
        mat4_translate(p)*mat4_scale(Vec3(0.25f, 0.25f, 0.25f))
    );
}

Variant* editor_add_variant(){
    auto variant = alloc_or_freelist!Variant(&g_variant_freelist);
    g_variants.insert(g_variants.top, variant);
    g_current_variant = variant;

    auto default_name = "New Variant";
    copy(default_name, variant.name[0 .. default_name.length]);
    variant.name_used = cast(uint)default_name.length;
    variant.players = 1;
    variant.lives   = 3;
    variant.difficulty = Campaign_Difficuly.Normal;

    variant.missions.make();
    return variant;
}

Map_Entry* editor_add_map(uint width, uint height){
    auto map = alloc_or_freelist!Map_Entry(&g_maps_freelist);

    // Default values.
    assert(width <= Map_Width_Max);
    assert(height <= Map_Height_Max);
    map.width  = width;
    map.height = height;

    g_maps.insert(g_maps.top, map);
    g_current_map = map;
    return map;
}

Mission_Entry* editor_add_mission(){
    auto variant = g_current_variant;

    auto mission = alloc_or_freelist!Mission_Entry(&g_mission_freelist);
    variant.missions.insert(variant.missions.top, mission);
    g_current_mission = mission;
    return mission;
}

void prepare_campaign(){
    reset(g_allocator); // IMPORTANT: This frees all the memory used by the editor.
    g_variants.make();
    g_maps.make();
}

void editor_new_campaign(){
    prepare_campaign();
    editor_add_variant();
    editor_add_mission();
    editor_add_map(22, 17);
    g_tank_types_count = 2;
    set_tank_type_to_default(&g_tank_types[0], true);
    set_tank_type_to_default(&g_tank_types[1], false);
}

Vec3 get_map_center(Campaign_Map* map){
    auto grid_extents = Vec2(map.width, map.height)*0.5f;
    auto result = world_to_render_pos(grid_extents);
    return result;
}

public void editor_toggle(App_State* s){
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
        }

        auto map = g_current_map;
        auto map_center = 0.5f*Vec2(map.width, map.height);
        s.world_camera_target_pos = world_to_render_pos(map_center);

        g_overhead_view = true;

        g_window_memory = malloc(8192)[0 .. 8192];
        g_panel_memory  = malloc(2048)[0 .. 2048];
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

