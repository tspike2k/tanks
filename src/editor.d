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
    - Our use of Edit_Layers complicates things more than it needs to. We should figure
    out a better way of doing this.

    There are two reasons we're breaking entities between maps and levels.
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

enum Window_ID_Main           = 1;
enum Label_Map_ID             = gui_id(Window_ID_Main);
enum Button_Prev_Map          = gui_id(Window_ID_Main);
enum Button_Next_Map          = gui_id(Window_ID_Main);
enum Button_New_Map           = gui_id(Window_ID_Main);

bool editor_is_open;

private:

enum Place_Type : uint{
    Block,
    Tank,
}

enum Cursor_Mode : uint{
    Select,
    Place,
    Erase,
}

struct Map_Entry{
    Map_Entry* next;
    Map_Entry* prev;

    Campaign_Map map;
}

Allocator*     g_allocator;
char[256]      g_dest_file_name;
uint           g_dest_file_name_used;
bool           g_mouse_left_is_down;
bool           g_mouse_right_is_down;
Place_Type     g_place_type;
Cursor_Mode    g_cursor_mode;
Map_Cell*      g_selected_cell;
bool           g_dragging_selected;
Vec2           g_drag_offset;

Map_Entry*     g_current_map;
List!Map_Entry g_maps;

void save_campaign_file(App_State* s, String file_name){
    auto scratch = s.frame_memory.scratch;
    push_frame(scratch);
    scope(exit) pop_frame(scratch);


    auto dest_buffer = begin_reserve_all(scratch);
    auto serializer = Serializer(dest_buffer);

    auto header = eat_type!Asset_Header(&serializer);
    clear_to_zero(*header);
    header.magic        = Campaign_Meta.magic;
    header.file_version = Campaign_Meta.file_version;
    header.asset_type   = Campaign_Meta.type;

    auto info_section = begin_writing_section(&serializer, Campaign_Section_Type.Info);
    auto info = zero_type!Campaign_Info;
    // TODO: Get info strings from editor state
    info.name   = "WII Play Tanks";
    info.author = "tspike";
    //info.next_map_id = 0;
    // TODO: Put date
    //info.levels_count = cast(uint)g_levels.count;
    info.maps_count   = cast(uint)g_maps.count;
    write_campaign_info(&serializer, &info);
    end_writing_section(&serializer, info_section);

    foreach(ref entry; g_maps.iterate()){
        auto section = begin_writing_section(&serializer, Campaign_Section_Type.Map);
        uint map_id = 0; // TODO: Placeholder in case we want to add this later.
        write(&serializer, to_void(&map_id));
        write(&serializer, entry.map.cells[]);
        end_writing_section(&serializer, section);
    }

    /+
    foreach(ref level; g_levels.iterate()){
        auto section = begin_writing_section(&serializer, Campaign_Section_Type.Level);
        write(&serializer, to_void(&level.map_id));
        uint entities_count = cast(uint)level.entities.count;
        write(&serializer, to_void(&entities_count));
        foreach(ref entry; level.entities.iterate()){
            auto e = &entry.entity;
            assert(e.type == Entity_Type.Tank);
            auto cmd = eat_type!Cmd_Make_Tank(&serializer);
            encode(cmd, e);
        }
        end_writing_section(&serializer, section);
    }

    +/
    end_reserve_all(scratch, serializer.buffer, serializer.buffer_used);
    write_file_from_memory(file_name, serializer.buffer[0 .. serializer.buffer_used]);
}

bool is_cell_occupied(Campaign_Map* map, Vec2 cell){
    auto x = cast(int)cell.x;
    auto y = cast(int)cell.y;
    assert(x >= 0 && x <= Grid_Width);
    assert(y >= 0 && y <= Grid_Height);

    bool result = map.cells[x + y * Grid_Width] != 0;
    return result;
}

void set_cell(Campaign_Map* map, Vec2 cell, Map_Cell value){
    auto x = cast(int)cell.x;
    auto y = cast(int)cell.y;
    assert(x >= 0 && x <= Grid_Width);
    assert(y >= 0 && y <= Grid_Width);

    map.cells[x + y * Grid_Width] = value;
}

bool editor_load_campaign(String name){
    push_frame(g_allocator.scratch);
    scope(exit) pop_frame(g_allocator.scratch);
    bool success = false;

    Campaign campaign;
    if(load_campaign_from_file(&campaign, name, g_allocator.scratch)){
        success = true;
        prepare_campaign();

        foreach(ref source; campaign.maps){
            auto entry   = editor_add_map();
            copy(to_void(&source), to_void(&entry.map));
        }
    }
    else{
        // TODO: Have a GUI-facing error log for the editor?
        log_error("Unable to edit campaign file {0}. Failed to load file.", name);
    }

    return success;
}

public void editor_simulate(App_State* s, float dt){
    assert(editor_is_open);

    bool should_close = false;

    bool arrow_up_pressed    = false;
    bool arrow_down_pressed  = false;
    bool mouse_left_pressed  = false;
    bool mouse_right_pressed = false;

    Event evt;
    bool text_buffer_updated = false;
    while(next_event(&evt)){
        if(!handle_event(&s.gui, &evt)){
            switch(evt.type){
                default: break;

                case Event_Type.Window_Close:{
                    // TODO: Save state before exit in a temp/suspend file.
                    s.running = false;
                } break;

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

                case Event_Type.Mouse_Motion:{
                    auto motion = &evt.mouse_motion;
                    s.mouse_pixel = Vec2(motion.pixel_x, motion.pixel_y);
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

                            case Key_ID_U:{
                                if(g_cursor_mode == Cursor_Mode.Select && g_selected_cell){
                                    (*g_selected_cell) ^= Map_Cell_Special; // Toggle the special bit
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
                                        if(entity_type & Map_Cell_Block){
                                            entity_type &= ~Map_Cell_Index_Mask;
                                            entity_type |= (index & Map_Cell_Index_Mask);
                                        }
                                        *g_selected_cell = entity_type;
                                    }
                                }
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
                                if(g_cursor_mode == Cursor_Mode.Select){
                                    if(g_selected_cell){
                                        *g_selected_cell = 0;
                                        g_selected_cell = null;
                                    }
                                }
                            } break;

                            case Key_ID_S:{
                                if(!key.is_repeat){
                                    if(key.modifier & Key_Modifier_Ctrl){
                                        save_campaign_file(s, "./build/test.camp");
                                    }
                                    else{
                                        g_cursor_mode = Cursor_Mode.Select;
                                    }
                                }
                            } break;

                            case Key_ID_L:{
                                if(!key.is_repeat && key.modifier & Key_Modifier_Ctrl){
                                    editor_load_campaign(Campaign_File_Name);
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

    //label(&s.gui, Label_Map_ID, gen_string("map_id: {0}", g_current_map.map_id, &s.frame_memory));
    update_gui(&s.gui, dt);

    if(s.gui.message_id != Null_Gui_ID){
        switch(s.gui.message_id){
            default: break;

            case Button_New_Map:{
                editor_add_map();
            } break;

            case Button_Next_Map:{
                auto next_map = g_current_map.next;
                if(g_maps.is_sentinel(next_map)){
                    next_map = next_map.next;
                }
                g_current_map = next_map;
            } break;

            case Button_Prev_Map:{
                auto next_map = g_current_map.prev;
                if(g_maps.is_sentinel(next_map)){
                    next_map = next_map.prev;
                }
                g_current_map = next_map;
            } break;
        }
    }

    switch(g_cursor_mode){
        default: break;

        case Cursor_Mode.Place:{
            auto map = &g_current_map.map;
            if(inside_grid(s.mouse_world) && !is_cell_occupied(map, s.mouse_world)){
                bool is_tank = g_place_type == Place_Type.Tank;
                if((is_tank && mouse_left_pressed) || (!is_tank && g_mouse_left_is_down)){
                    auto entry = encode_map_cell(is_tank, false, 1);
                    set_cell(map, s.mouse_world, entry);
                }
            }
        } break;

        case Cursor_Mode.Select:{
            auto map = &g_current_map.map;
            if(mouse_left_pressed){
                if(inside_grid(s.mouse_world) && is_cell_occupied(map, s.mouse_world)){
                    auto x = cast(int)s.mouse_world.x;
                    auto y = cast(int)s.mouse_world.y;
                    g_selected_cell = &map.cells[x + y * Grid_Width];
                }
                else{
                    g_selected_cell = null;
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
}

Entity make_entity_from_cell(Map_Cell cell, Vec2 pos){
    assert(cell != 0);
    auto result = zero_type!Entity;
    result.id = 1;
    result.pos = pos;

    if(cell & Map_Cell_Tank){
        result.type = Entity_Type.Tank;
        if(cell & Map_Cell_Special){
            result.player_index = 1; // TODO: Fix this.
        }
    }
    else{
        result.type = Entity_Type.Block;
        if(cell & Map_Cell_Special){
            result.breakable = true;
        }
        result.block_height = (cell & Map_Cell_Index_Mask);
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

    auto map = &g_current_map.map;
    foreach(y; 0 .. Grid_Height){
        foreach(x; 0 .. Grid_Width){
            auto cell = &map.cells[x + y * Grid_Width];
            auto entity_type = *cell;
            if(entity_type){
                auto p = Vec2(x, y) + Vec2(0.5f, 0.5f); // Center on the tile
                auto e = make_entity_from_cell(entity_type, p);

                Material* material = null;
                if(cell == g_selected_cell){
                    material = &s.material_eraser;
                }

                render_entity(s, &e, rp, material);
            }
        }
    }

    if(g_cursor_mode == Cursor_Mode.Place && inside_grid(s.mouse_world)){
        bool is_tank = g_place_type == Place_Type.Tank;
        auto entity_type = encode_map_cell(is_tank, false, 1);
        auto tile_center = floor(s.mouse_world) + Vec2(0.5f, 0.5f);
        auto e = make_entity_from_cell(entity_type, tile_center);
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

    foreach(ref entry; g_current_map.entities.iterate()){
        render_entity(s, &entry.entity, rp);
    }

    foreach(ref entry; g_current_level.entities.iterate()){
        render_entity(s, &entry.entity, rp);
    }+/
}

Map_Entry* editor_add_map(){
    auto map = alloc_type!Map_Entry(g_allocator);
    g_maps.insert(g_maps.top, map);
    g_current_map = map;

    return map;
}

void prepare_campaign(){
    reset(g_allocator); // IMPORTANT: This frees all the memory used by the editor.
    //g_next_entity_id = Null_Entity_ID+1;
    //g_levels.make();
    g_maps.make();
}

void editor_new_campaign(){
    prepare_campaign();
    editor_add_map();
    //editor_add_level();
}

public void editor_toggle(App_State* s){
    // TODO: Don't use malloc and free. Have a free list of window memory.
    import core.stdc.stdlib : malloc, free;

    auto gui = &s.gui;
    if(!editor_is_open){
        g_allocator = &s.editor_memory;

        g_mouse_left_is_down  = false;
        g_mouse_right_is_down = false;

        if(!editor_load_campaign(Campaign_File_Name)){
            editor_new_campaign();
        }

        auto memory = (malloc(4086)[0 .. 4086]);
        begin_window(gui, Window_ID_Main, "Test Window", rect_from_min_wh(Vec2(20, 20), 200, 80), memory);
            button(gui, Button_Prev_Map, "<");
            label(gui, Label_Map_ID, "map_id");
            button(gui, Button_Next_Map, ">");
            button(gui, Button_New_Map, "+");
            next_row(gui);
        end_window(gui);

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

    editor_is_open = !editor_is_open;
}

