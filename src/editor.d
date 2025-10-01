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
    Map,
    Tile,
    Missions,
    Tanks,
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

    List!Map_Entry      maps;
    List!Mission_Entry  missions;
    List!Tank_Entry     tank_params;
}

enum Window_ID_Main            = 1;
enum Button_Prev_Map           = gui_id(Window_ID_Main);
enum Button_Next_Map           = gui_id(Window_ID_Main);
enum Button_New_Map            = gui_id(Window_ID_Main);
enum Button_Delete_Map         = gui_id(Window_ID_Main);

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

__gshared List!Variant   g_variants;
__gshared Map_Entry*     g_current_map;
__gshared Variant*       g_current_variant;
__gshared uint           g_editor_tab;

__gshared void[]         g_window_memory;

void save_campaign_file(App_State* s, String file_name){
    auto scratch = s.frame_memory.scratch;
    push_frame(scratch);
    scope(exit) pop_frame(scratch);

    auto header = zero_type!Asset_Header;
    header.magic        = Campaign_Meta.magic;
    header.file_version = Campaign_Meta.file_version;
    header.asset_type   = Campaign_Meta.type;

    Campaign campaign;
    // TODO: Get info strings from editor state
    campaign.name   = "WII Play Tanks";
    campaign.author = "tspike";
    //info.next_map_id = 0;
    // TODO: Put date
    //info.missions_count = cast(uint)g_missions.count;
    //info.maps_count     = cast(uint)g_maps.count;

    auto dest_buffer = begin_reserve_all(scratch);
    auto serializer = Serializer(dest_buffer);
    write(&serializer, header);
    write(&serializer, campaign);

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

    end_reserve_all(scratch, serializer.buffer, serializer.buffer_used);
    write_file_from_memory(file_name, serializer.buffer[0 .. serializer.buffer_used]);
}

bool editor_load_campaign(App_State* s, String name){
    push_frame(g_frame_allocator);
    scope(exit) pop_frame(g_frame_allocator);
    bool success = false;

    Campaign campaign;
    if(load_campaign_from_file(s, name)){
        success = true;
        prepare_campaign();

        foreach(ref source_variant; campaign.variants){
            auto variant = editor_add_variant();
        }

        foreach(ref source_map; campaign.maps){
            auto entry   = editor_add_map(22, 17);
            // TODO: Set map width/height
            // TODO: Populate map cells.
            //entry.map = source_map;
            //entry.map.cells = dup_array(source_map.cells, g_allocator);
        }
    }
    else{
        // TODO: Have a GUI-facing error log for the editor?
        log_error("Unable to edit campaign file {0}. Failed to load file.\n", name);
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
    auto variant = g_current_variant;
    uint index = 0;
    bool found_entry = false;
    foreach(entry; variant.maps.iterate()){
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
    auto variant = g_current_variant;
    auto maps = &variant.maps;
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

    if(g_overhead_view){
        auto window = get_window_info();
        float window_aspect_ratio = (cast(float)window.width)/cast(float)window.height;
        set_world_projection(&s.world_camera, map.width + 2, map.height + 2, window_aspect_ratio, 0);
        set_world_view(&s.world_camera, world_to_render_pos(Vec2(map.width, map.height)*0.5f), 90);

        auto mouse_world_3d = camera_ray_vs_plane(&s.world_camera, s.mouse_pixel, window.width, window.height);
        s.mouse_world = Vec2(mouse_world_3d.x, -mouse_world_3d.z);
    }

    // NOTE: We need to regenerate the GUI every frame because we generate strings and wire up
    // pointers for value editors. One solution for this is to only redefine the GUI when a
    // a major event happens (such as changing tabs). Then for every frame we loop over all the
    // widgets and regenerate labels/wire up pointers based on widget IDs. That's how we handle
    // the menu system. There is probably a better way that I'm not thinking of. However, if some
    // frames require a full GUI rebuild, the slow path will need to be executed at some point.
    // Doing it every frame ensures the performance cost is fairly consistent. See this internal
    // email by John Carmack:
    // http://number-none.com/blow/blog/programming/2014/09/26/carmack-on-inlined-code.html
    auto gui = &s.gui;
    begin_window(gui, Window_ID_Main, "Editor", rect_from_min_wh(Vec2(20, 400), 400, 200), g_window_memory);

    tab(gui, gui_id(Window_ID_Main), "Map", &g_editor_tab, Editor_Tab.Map);
    tab(gui, gui_id(Window_ID_Main), "Tile", &g_editor_tab, Editor_Tab.Tile);
    tab(gui, gui_id(Window_ID_Main), "Mission", &g_editor_tab, Editor_Tab.Missions);
    tab(gui, gui_id(Window_ID_Main), "Tanks", &g_editor_tab, Editor_Tab.Tanks);
    next_row(gui);
    switch(g_editor_tab){
        default: break;

        case Editor_Tab.Map:{
            button(gui, Button_Prev_Map, "<");
            auto map_index = get_map_index(map);
            auto map_msg = gen_string("Map index: {0}", map_index, &s.frame_memory);
            label(gui, gui_id(Window_ID_Main), map_msg);
            button(gui, Button_Next_Map, ">");
            button(gui, Button_Delete_Map, "-");
            button(gui, Button_New_Map, "+");
            next_row(gui);
            label(gui, gui_id(Window_ID_Main), "Map width:");
            spin_button(gui, gui_id(Window_ID_Main), &map.width, Map_Width_Max);
            next_row(gui);
            label(gui, gui_id(Window_ID_Main), "Map height:");
            spin_button(gui, gui_id(Window_ID_Main), &map.height, Map_Height_Max);
            next_row(gui);
            label(gui, gui_id(Window_ID_Main), "Overhead:");
            checkbox(gui, gui_id(Window_ID_Main), &g_overhead_view);
        } break;

        case Editor_Tab.Tile:{
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

                label(gui, gui_id(Window_ID_Main), "Special:");
                checkbox(gui, gui_id(Window_ID_Main), &tile.is_special);
                next_row(gui);
                label(gui, gui_id(Window_ID_Main), "Index:");
                spin_button(gui, gui_id(Window_ID_Main), &tile.index, max_index);
                next_row(gui);
            }
            else{
                label(gui, gui_id(Window_ID_Main), "Press 'S' to enter Select mode and choose a tile to edit.");;
            }
        } break;

        case Editor_Tab.Missions:{
            label(gui, gui_id(Window_ID_Main), "TODO: Add things!");
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
                                        //save_campaign_file(s, "./build/main.camp");
                                    }
                                    else{
                                        g_cursor_mode = Cursor_Mode.Select;
                                    }
                                }
                            } break;

                            case Key_ID_L:{
                                if(!key.is_repeat && key.modifier & Key_Modifier_Ctrl){
                                    editor_load_campaign(s, Campaign_File_Name);
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
                if(variant.maps.is_sentinel(next_map)){
                    next_map = next_map.next;
                }
                g_current_map = next_map;
            } break;

            case Button_Prev_Map:{
                auto next_map = g_current_map.prev;
                auto variant  = g_current_variant;
                if(variant.maps.is_sentinel(next_map)){
                    next_map = next_map.prev;
                }
                g_current_map = next_map;
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

    variant.maps.make();
    variant.missions.make();
    variant.tank_params.make();

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

    variant.maps.insert(variant.maps.top, map);
    g_current_map = map;
    return map;
}

void prepare_campaign(){
    reset(g_allocator); // IMPORTANT: This frees all the memory used by the editor.
    g_variants.make();
}

void editor_new_campaign(){
    prepare_campaign();
    editor_add_variant();
    editor_add_map(22, 17);
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

        //if(!editor_load_campaign(s, "./build/main.camp")){
            editor_new_campaign();
            //editor_load_maps_file("./build/wii_16x9.maps");
        //}

        auto map = g_current_map;
        auto map_center = 0.5f*Vec2(map.width, map.height);
        s.world_camera_target_pos = world_to_render_pos(map_center);

        g_overhead_view = true;

        g_window_memory = malloc(2048)[0 .. 2048];

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

