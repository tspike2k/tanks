/*
Copyright (c) 2025 tspike2k@github.com
Distributed under the Boost Software License, Version 1.0.
See accompanying file LICENSE_BOOST.txt or copy at http://www.boost.org/LICENSE_1_0.txt
*/

/+
TODO:
    - Make an actual GUI for the editor.
    - Fix memory leak with calls to load_campaign_from_file. This should load the campaign into
    an allocator specially reserved for campaign memory. When we load, we should clear the
    allocator each time.
+/

import app;
import display;
import math;
import logging;
import render;
import memory;
import files;
import assets;

bool editor_is_open;

private{
    enum Edit_Mode : uint{
        Select,
        Place,
        Erase,
    }

    enum Place_Mode : uint{
        Block,
        Tank,
    }

    bool       g_initialized;
    bool       g_mouse_left_is_down;
    bool       g_mouse_right_is_down;
    Place_Mode g_placement_mode;
    Edit_Mode  g_edit_mode;
    Entity_ID  g_selected_entity_id;
    bool       g_dragging_selected;
    Vec2       g_drag_offset;
}

void save_campaign_file(App_State* s){
    auto scratch = s.frame_memory.scratch;
    push_frame(scratch);
    scope(exit) pop_frame(scratch);

    auto world = &s.world;

    auto file = open_file(Campaign_File_Name, File_Flag_Write);
    if(is_open(&file)){
        auto buffer = alloc_array!void(scratch, 2*1024*1024);
        auto writer = buffer;

        auto header = stream_next!Campaign_Header(writer);
        header.magic        = Campaign_File_Magic;
        header.file_version = Campaign_File_Version;

        auto section = stream_next!Campaign_Section(writer);
        section.type = Campaign_Section_Type.Blocks;
        section.size = 0;

        // TODO: After the section header, the Block and Tanks sections should state the
        // map_id.

        // TODO: In the future, don't use the "world" as the place for the editor to edit
        // entities? Maybe.
        foreach(ref e; iterate_entities(world)){
            if(e.type == Entity_Type.Block || e.type == Entity_Type.Hole){
                assert(e.type != Entity_Type.Hole || e.block_height == 0);
                auto cmd = stream_next!Cmd_Make_Block(writer);
                encode(cmd, &e);

                section.size += Cmd_Make_Block.sizeof;
            }
        }

        section = stream_next!Campaign_Section(writer);
        section.type = Campaign_Section_Type.Tanks;
        section.size = 0;

        foreach(ref e; iterate_entities(world)){
            if(e.type == Entity_Type.Tank){
                auto cmd = stream_next!Cmd_Make_Tank(writer);
                encode(cmd, &e);
                section.size += Cmd_Make_Tank.sizeof;
            }
        }

        write_file(&file, 0, buffer[0 .. writer.ptr - buffer.ptr]);
        close_file(&file);
    }
}

bool block_exists_on_tile(World* world, Vec2 tile){
    bool result = false;
    assert(floor(tile) == tile);
    foreach(ref e; iterate_entities(world)){
        if(floor(e.pos) == tile){
            result = true;
            break;
        }
    }
    return result;
}

Entity* get_entity_under_cursor(World* world, Vec2 cursor_world){
    Entity* result;

    float closest_dist_sq = float.max;
    foreach(ref e; iterate_entities(world)){
        auto dsq = dist_sq(e.pos, cursor_world);
        if(dsq < closest_dist_sq && dsq < squared(0.5f)){
            closest_dist_sq = dsq;
            result = &e;
        }
    }

    return result;
}

void editor_simulate(App_State* s, float dt){
    assert(editor_is_open);

    bool arrow_up_pressed    = false;
    bool arrow_down_pressed  = false;
    bool mouse_left_pressed  = false;
    bool mouse_right_pressed = false;

    Event evt;
    while(next_event(&evt)){
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
                if(!key.is_repeat && key.pressed){
                    switch(key.id){
                        default: break;

                        case Key_ID_Arrow_Up:{
                            arrow_up_pressed = true;
                        } break;

                        case Key_ID_Arrow_Down:{
                            arrow_down_pressed = true;
                        } break;

                        case Key_ID_0:
                        case Key_ID_1:
                        case Key_ID_2:
                        case Key_ID_3:
                        case Key_ID_4:
                        {
                            auto index = key.id - Key_ID_0;
                            if(g_edit_mode == Edit_Mode.Select){
                                auto e = get_entity_by_id(&s.world, g_selected_entity_id);
                                if(e && e.type == Entity_Type.Tank){
                                    e.player_index = index;
                                }
                            }
                        } break;

                        case Key_ID_T:{
                            g_placement_mode = Place_Mode.Tank;
                        } break;

                        case Key_ID_B:{
                            g_placement_mode = Place_Mode.Block;
                        } break;

                        case Key_ID_C:{
                            g_edit_mode = Edit_Mode.Select;
                        } break;

                        case Key_ID_P:{
                            g_edit_mode = Edit_Mode.Place;
                        } break;

                        case Key_ID_E:{
                            g_edit_mode = Edit_Mode.Erase;
                        } break;

                        case Key_ID_Delete:{
                            if(g_edit_mode == Edit_Mode.Select && g_selected_entity_id != Null_Entity_ID){
                                auto e = get_entity_by_id(&s.world, g_selected_entity_id);
                                assert(e);
                                destroy_entity(e);
                                g_selected_entity_id = Null_Entity_ID;
                            }
                        } break;

                        case Key_ID_S:{
                            if(key.modifier & Key_Modifier_Ctrl){
                                save_campaign_file(s);
                            }
                        } break;

                        case Key_ID_L:{
                            if(key.modifier & Key_Modifier_Ctrl){
                                if(load_campaign_from_file(&s.campaign, Campaign_File_Name, &s.main_memory)){
                                    load_campaign_level(s, &s.campaign, 0);
                                }
                            }
                        } break;

                        case Key_ID_F2:
                            editor_toggle(s); break;
                    }
                }
            } break;
        }
    }

    switch(g_edit_mode){
        default: break;

        case Edit_Mode.Select:{
            s.highlight_entity_id = g_selected_entity_id;
            s.highlight_material = &s.material_eraser;

            if(mouse_left_pressed){
                auto e = get_entity_under_cursor(&s.world, s.mouse_world);
                if(e){
                    g_drag_offset = e.pos - s.mouse_world;
                    g_selected_entity_id = e.id;
                }
                else{
                    g_selected_entity_id = Null_Entity_ID;
                }
            }

            if(g_selected_entity_id != Null_Entity_ID){
                auto e = get_entity_by_id(&s.world, g_selected_entity_id);
                if(e){
                    if(g_mouse_right_is_down){
                        // TODO: We'd like to be able to use shift+click or ctrl+click to
                        // allow the user to snap rotation to fixed points.
                        auto dir = normalize(s.mouse_world - e.pos);
                        e.angle = atan2(dir.y, dir.x);
                    }

                    if(g_mouse_left_is_down){
                        if(g_dragging_selected){
                            if(e.type == Entity_Type.Block || e.type == Entity_Type.Hole){
                                e.pos = floor(s.mouse_world) + Vec2(0.5f, 0.5f);
                            }
                            else{
                                e.pos = s.mouse_world + g_drag_offset;
                            }
                        }
                        else{
                            g_dragging_selected = dist_sq(e.pos, s.mouse_world + g_drag_offset) > squared(0.5f);
                        }
                    }
                    else{
                        g_dragging_selected = false;
                    }

                    if(arrow_up_pressed && e.type == Entity_Type.Block){
                        e.block_height = min(e.block_height + 1, 7);
                    }

                    if(arrow_down_pressed && e.type == Entity_Type.Block){
                        e.block_height = max(e.block_height - 1, 1);
                    }
                }
                else{
                    g_selected_entity_id = Null_Entity_ID;
                }
            }
        } break;

        case Edit_Mode.Place:{
            if(g_placement_mode == Place_Mode.Block && g_mouse_left_is_down){
                auto tile = floor(s.mouse_world);
                if(!block_exists_on_tile(&s.world, tile) && inside_grid(tile)){
                    add_block(&s.world, tile, 1);
                }
            }
            else if(g_placement_mode == Place_Mode.Tank && mouse_left_pressed){
                add_entity(&s.world, s.mouse_world, Entity_Type.Tank);
            }
        } break;

        case Edit_Mode.Erase:{
            auto hover_e = get_entity_under_cursor(&s.world, s.mouse_world);

            if(hover_e){
                s.highlight_entity_id = hover_e.id;
                s.highlight_material  = &s.material_eraser;

                if(g_mouse_left_is_down && hover_e){
                    destroy_entity(hover_e);
                }
            }
            else{
                s.highlight_entity_id = Null_Entity_ID;
            }
        } break;
    }
}

void editor_render(App_State* s){
    switch(g_edit_mode){
        default: break;

        case Edit_Mode.Select:{
            // Draw cursor
            auto p = world_to_render_pos(s.mouse_world);
            set_material(&s.material_block);
            render_mesh(&s.cube_mesh, mat4_translate(p)*mat4_scale(Vec3(0.25f, 0.25f, 0.25f)));
        } break;

        case Edit_Mode.Place:{
            if(inside_grid(s.mouse_world)){
                if(g_placement_mode == Place_Mode.Block){
                    set_material(&s.material_block);
                    auto p = world_to_render_pos(floor(s.mouse_world)) + Vec3(0.5f, 0.5f, -0.5f);
                    render_mesh(&s.cube_mesh, mat4_translate(p));
                }
                else if(g_placement_mode == Place_Mode.Tank){
                    set_material(&s.material_enemy_tank);
                    auto p = world_to_render_pos(s.mouse_world) + Vec3(0, 0.18f, 0);
                    render_mesh(&s.tank_base_mesh, mat4_translate(p));
                    render_mesh(&s.tank_top_mesh, mat4_translate(p));
                }
            }
        } break;
    }
}

void editor_toggle(App_State* s){
    if(!editor_is_open){
        s.world.entities_count = 0;
        g_mouse_left_is_down  = false;
        g_mouse_right_is_down = false;
    }

    editor_is_open = !editor_is_open;
}

