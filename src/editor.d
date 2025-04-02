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
}

void save_campaign_file(App_State* s){
    auto scratch = s.frame_memory.scratch;
    push_frame(scratch);
    scope(exit) pop_frame(scratch);

    auto file = open_file(Default_File_Name, File_Flag_Write);
    if(is_open(&file)){
        Campaign_Header header;
        header.magic        = Campaign_File_Magic;
        header.file_version = Campaign_File_Version;

        auto buffer = alloc_array!void(scratch, 2*1024*1024);
        auto writer = buffer;
        stream_write(writer, to_void(&header));

        auto world = &s.world;

        stream_write(writer, to_void(&world.entities_count));
        foreach(ref e; world.entities[0 .. world.entities_count]){
            assert(e.type == Entity_Type.Block);
            Cmd_Make_Block cmd;
            encode(&cmd, e.block_height, e.pos);
            stream_write(writer, to_void(&cmd));
        }

        write_file(&file, 0, buffer[0 .. writer.ptr - buffer.ptr]);
        close_file(&file);
    }
}

void load_campaign_file(App_State* s){
    auto scratch = s.frame_memory.scratch;
    push_frame(scratch);
    scope(exit) pop_frame(scratch);

    auto memory = read_file_into_memory(Default_File_Name, scratch);
    auto reader = memory;
    // TODO: More robust reading code
    // TODO: Validate header
    auto header = stream_read!Campaign_Header(reader);
    if(header){
        auto world = &s.world;
        world.entities_count = 0;
        auto count = *stream_read!uint(reader);
        foreach(i; 0 .. count){
            auto cmd = stream_read!Cmd_Make_Block(reader);
            uint block_height;
            Vec2 pos;
            decode(cmd, &block_height, &pos);
            add_block(world, pos, block_height);
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

void editor_simulate(App_State* s, float dt){
    assert(editor_is_open);

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

    switch(g_edit_mode){
        default: break;

        case Edit_Mode.Place:{
            if(g_mouse_left_is_down){
                auto tile = floor(s.mouse_world);
                if(!block_exists_on_tile(&s.world, tile) && inside_grid(tile)){
                    add_block(&s.world, tile, 1);
                }
            }
        } break;

        case Edit_Mode.Erase:{
            auto tile = floor(s.mouse_world);

            s.to_erase_id = Null_Entity_ID;
            Entity* hover_e;
            foreach(ref e; iterate_entities(&s.world)){
                if(floor(e.pos) == tile){
                    hover_e = &e;
                    s.to_erase_id = e.id;
                }
            }

            if(g_mouse_left_is_down && hover_e){
                hover_e.health = 0;
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

