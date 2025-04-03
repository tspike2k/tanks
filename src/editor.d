/*
Copyright (c) 2025 tspike2k@github.com
Distributed under the Boost Software License, Version 1.0.
See accompanying file LICENSE_BOOST.txt or copy at http://www.boost.org/LICENSE_1_0.txt
*/

/+
    TODO: Use an actual GUI for the editor.
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
    enum Default_File_Name = "./build/main.camp";

    enum Edit_Catagory : uint{
        Map,
        Entity,
    }

    enum Edit_Mode : uint{
        Config,
        Place,
        Erase,
    }

    bool g_initialized;
    bool g_mouse_left_is_down;
    bool g_mouse_right_is_down;
    Material g_eraser_material;
    Edit_Catagory g_edit_catagory;
    Edit_Mode g_edit_mode;
    Entity_ID g_selected_entity_id;
}

void save_campaign_file(App_State* s){
    auto scratch = s.frame_memory.scratch;
    push_frame(scratch);
    scope(exit) pop_frame(scratch);

    auto world = &s.world;

    auto file = open_file(Default_File_Name, File_Flag_Write);
    if(is_open(&file)){
        auto buffer = alloc_array!void(scratch, 2*1024*1024);
        auto writer = buffer;

        auto header = stream_next!Campaign_Header(writer);
        header.magic        = Campaign_File_Magic;
        header.file_version = Campaign_File_Version;

        auto section = stream_next!Campaign_Section(writer);
        section.type = Campaign_Section_Type.Blocks;

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
        section.type = Campaign_Section_Type.Blocks;

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

void load_campaign_file(App_State* s){
    auto scratch = s.frame_memory.scratch;
    push_frame(scratch);
    scope(exit) pop_frame(scratch);

    auto world = &s.world;
    world.entities_count = 0;

    auto memory = read_file_into_memory(Default_File_Name, scratch);
    auto reader = memory;

    // TODO: More robust reading code
    // TODO: Validate header
    auto header = stream_next!Campaign_Header(reader);
    if(header){
        while(auto section = stream_next!Campaign_Section(reader)){
            switch(section.type){
                default: break;

                case Campaign_Section_Type.Blocks:{
                    auto count = section.size / Cmd_Make_Block.sizeof;

                    foreach(i; 0 .. count){
                        auto cmd = stream_next!Cmd_Make_Block(reader);
                        auto e = add_entity(world, Vec2(0, 0), Entity_Type.Block);
                        decode(cmd, e);
                    }
                } break;

                case Campaign_Section_Type.Tanks:{
                    auto count = section.size / Cmd_Make_Tank.sizeof;

                    foreach(i; 0 .. count){
                        auto cmd = stream_next!Cmd_Make_Tank(reader);
                        auto e = add_entity(world, Vec2(0, 0), Entity_Type.Tank);
                        decode(cmd, e);
                    }
                } break;
            }
        }
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

bool config_mode_handle_event(App_State* s, Event* evt){
    bool consumed = false;

    switch(evt.type){
        default: break;

        case Event_Type.Button:{
            auto btn = &evt.button;

            if(btn.pressed){
                switch(btn.id){
                    default: break;

                    case Button_ID.Mouse_Left:{
                        if(g_selected_entity_id == Null_Entity_ID){
                            auto e = get_entity_under_cursor(&s.world, s.mouse_world);
                            if(e)
                                g_selected_entity_id = e.id;
                        }
                    } break;

                    case Button_ID.Mouse_Right:{
                        g_selected_entity_id = Null_Entity_ID;
                    } break;
                }
            }
        } break;

        case Event_Type.Key:{
            auto key = &evt.key;
            if(key.pressed){
                auto e = get_entity_by_id(&s.world, g_selected_entity_id);
                if(e){
                    if(e.type == Entity_Type.Block){
                        if(key.id == Key_ID_Arrow_Up){
                            e.block_height = min(e.block_height + 1, 7);
                        }
                        else if(key.id == Key_ID_Arrow_Down){
                            e.block_height = max(e.block_height - 1, 1);
                        }
                    }
                }
            }
        } break;
    }

    return consumed;
}

void editor_simulate(App_State* s, float dt){
    assert(editor_is_open);

    Event evt;
    while(next_event(&evt)){
        bool event_consumed = false;
        switch(g_edit_mode){
            default: break;

            case Edit_Mode.Config:
                event_consumed = config_mode_handle_event(s, &evt); break;
        }

        if(!event_consumed){
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
                        } break;

                        case Button_ID.Mouse_Right:{
                            g_mouse_right_is_down = btn.pressed;
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

                            case Key_ID_C:{
                                g_edit_mode = Edit_Mode.Config;
                            } break;

                            case Key_ID_P:{
                                g_edit_mode = Edit_Mode.Place;
                            } break;

                            case Key_ID_E:{
                                g_edit_mode = Edit_Mode.Erase;
                            } break;

                            case Key_ID_S:{
                                if(key.modifier & Key_Modifier_Ctrl){
                                    save_campaign_file(s);
                                }
                            } break;

                            case Key_ID_L:{
                                if(key.modifier & Key_Modifier_Ctrl){
                                    load_campaign_file(s);
                                }
                            } break;

                            case Key_ID_F2:
                                editor_toggle(s); break;
                        }
                    }
                } break;
            }
        }

    }

    switch(g_edit_mode){
        default: break;

        case Edit_Mode.Config:{
            s.highlight_entity_id = g_selected_entity_id;
            s.highlight_material = &s.material_eraser;
        } break;

        case Edit_Mode.Place:{
            if(g_mouse_left_is_down){
                auto tile = floor(s.mouse_world);
                if(!block_exists_on_tile(&s.world, tile) && inside_grid(tile)){
                    add_block(&s.world, tile, 1);
                }
            }
        } break;

        case Edit_Mode.Erase:{
            auto hover_e = get_entity_under_cursor(&s.world, s.mouse_world);

            if(hover_e){
                s.highlight_entity_id = hover_e.id;
                s.highlight_material  = &s.material_eraser;

                if(g_mouse_left_is_down && hover_e){
                    hover_e.health = 0;
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

        case Edit_Mode.Config:{
            // Draw cursor
            auto p = world_to_render_pos(s.mouse_world);
            set_material(&s.material_block);
            render_mesh(&s.cube_mesh, mat4_translate(p)*mat4_scale(Vec3(0.25f, 0.25f, 0.25f)));
        } break;

        case Edit_Mode.Place:{
            if(inside_grid(s.mouse_world)){
                set_material(&s.material_block);
                auto p = world_to_render_pos(floor(s.mouse_world)) + Vec3(0.5f, 0.5f, -0.5f);
                render_mesh(&s.cube_mesh, mat4_translate(p));
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

