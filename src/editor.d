/*
Copyright (c) 2025 tspike2k@github.com
Distributed under the Boost Software License, Version 1.0.
See accompanying file LICENSE_BOOST.txt or copy at http://www.boost.org/LICENSE_1_0.txt
*/

/+
TODO:
    - Make an actual GUI for the editor.
    - Fix memory leak with calls to load_campaign_from_file. This should load the campaign into
    an allocator specially reserved for campaign memory. When we load, we should reset the
    allocator each time.
    - In the future, don't use the "world" as the place for the editor to edit
    entities? Maybe.
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

enum Window_ID_Editor_Test   = 1;
enum Window_ID_Editor_Test_2 = 2;
enum Button_ID_Editor_Test   = gui_id(Window_ID_Editor_Test);
enum Button_ID_Editor_Test_2 = gui_id(Window_ID_Editor_Test_2);

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

    auto dest_buffer = begin_reserve_all(scratch);
    auto serializer = Serializer(dest_buffer);

    Asset_Header header;
    header.magic        = Campaign_Meta.magic;
    header.file_version = Campaign_Meta.file_version;
    header.asset_type   = Campaign_Meta.type;
    write(&serializer, to_void(&header));

    // TODO: Upgrade to using Asset_Sections instead.
    auto section = eat_type!Campaign_Section(&serializer);
    section.type = Campaign_Section_Type.Blocks;
    section.size = 0;

    foreach(ref e; iterate_entities(world)){
        if(e.type == Entity_Type.Block){
            auto cmd = eat_type!Cmd_Make_Block(&serializer);
            encode(cmd, &e);

            section.size += Cmd_Make_Block.sizeof;
        }
    }

    section = eat_type!Campaign_Section(&serializer);
    section.type = Campaign_Section_Type.Tanks;
    section.size = 0;

    foreach(ref e; iterate_entities(world)){
        if(e.type == Entity_Type.Tank){
            auto cmd = eat_type!Cmd_Make_Tank(&serializer);
            encode(cmd, &e);
            section.size += Cmd_Make_Tank.sizeof;
        }
    }

    end_reserve_all(scratch, serializer.buffer, serializer.buffer_used);
    write_file_from_memory(Campaign_File_Name, serializer.buffer[0 .. serializer.buffer_used]);
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

char[4]     g_text_buffer_data;
Text_Buffer g_text_buffer;

void editor_simulate(App_State* s, float dt){
    assert(editor_is_open);

    bool arrow_up_pressed    = false;
    bool arrow_down_pressed  = false;
    bool mouse_left_pressed  = false;
    bool mouse_right_pressed = false;

    Event evt;
    bool text_buffer_updated = false;
    while(next_event(&evt)){
        auto text_buffer_consumed = false;
        if(handle_event(&g_text_buffer, &evt)){
            text_buffer_updated  = true;
            text_buffer_consumed = true;
        }

        if(!text_buffer_consumed && !handle_event(&s.gui, &evt)){
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

                            case Key_ID_K:{
                                if(g_edit_mode == Edit_Mode.Select){
                                    auto e = get_entity_by_id(&s.world, g_selected_entity_id);
                                    if(e && e.type == Entity_Type.Block){
                                        e.breakable = !e.breakable;
                                    }
                                }
                            } break;

                            case Key_ID_0:
                            case Key_ID_1:
                            case Key_ID_2:
                            case Key_ID_3:
                            case Key_ID_4:
                            {
                                if(!key.is_repeat){
                                    auto index = key.id - Key_ID_0;
                                    if(g_edit_mode == Edit_Mode.Select){
                                        auto e = get_entity_by_id(&s.world, g_selected_entity_id);
                                        if(e && e.type == Entity_Type.Tank){
                                            e.player_index = index;
                                        }
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
                                if(!key.is_repeat){
                                    if(key.modifier & Key_Modifier_Ctrl){
                                        save_campaign_file(s);
                                    }
                                }
                            } break;

                            case Key_ID_L:{
                                if(!key.is_repeat){
                                    if(key.modifier & Key_Modifier_Ctrl){
                                        if(load_campaign_from_file(&s.campaign, Campaign_File_Name, &s.main_memory)){
                                            load_campaign_level(s, &s.campaign, 0);
                                        }
                                    }
                                }
                            } break;

                            case Key_ID_F2:
                                if(!key.is_repeat){
                                    editor_toggle(s);
                                }
                            break;
                        }
                    }
                } break;
            }
        }
    }
    update_gui(&s.gui, dt);

    if(s.gui.message_id != Null_Gui_ID){
        switch(s.gui.message_id){
            default: break;

            case Button_ID_Editor_Test:{
                log("Test button pressed!\n");
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

    if(text_buffer_updated){
        foreach(i; 0 .. g_text_buffer.used+1){
            if(i == g_text_buffer.cursor){
                log("c");
            }
            else{
                log(" ");
            }
        }
        log("\n");

        log("{0}\n", g_text_buffer.text[0 .. g_text_buffer.used]);
    }
}

void editor_render(App_State* s, Render_Pass* rp_world, Render_Pass* rp_text){
    auto window = get_window_info();

    auto font_small = &s.font_editor_small;

    auto padding = 16;
    auto pen = Vec2(padding, window.height - padding - font_small.metrics.height);
    render_text(
        rp_text, font_small, pen,
        gen_string("Mode: {0}", enum_string(g_edit_mode), &s.frame_memory)
    );

    switch(g_edit_mode){
        default: break;

        case Edit_Mode.Select:{
            // Draw cursor
            auto p = world_to_render_pos(s.mouse_world);
            auto material = &s.material_block;
            render_mesh(
                rp_world, &s.cube_mesh, material,
                mat4_translate(p)*mat4_scale(Vec3(0.25f, 0.25f, 0.25f))
            );

            auto e = get_entity_by_id(&s.world, g_selected_entity_id);
            if(e){
                pen.y -= font_small.metrics.line_gap;
                pen.x = padding;

                render_text(
                    rp_text, font_small, pen,
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
                            rp_text, font_small, pen,
                            gen_string("Height: {0} {1}", e.block_height, extra, &s.frame_memory)
                        );
                    } break;

                    case Entity_Type.Tank:{
                        String extra = "";
                        if(e.player_index == 0){
                            extra = "(enemy)";
                        }

                        render_text(
                            rp_text, font_small, pen,
                            gen_string("Player Index: {0} {1}", e.player_index, extra, &s.frame_memory)
                        );
                    } break;
                }
            }
        } break;

        case Edit_Mode.Place:{
            if(inside_grid(s.mouse_world)){
                if(g_placement_mode == Place_Mode.Block){
                    auto p = world_to_render_pos(floor(s.mouse_world)) + Vec3(0.5f, 0.5f, -0.5f);
                    render_mesh(rp_world, &s.cube_mesh, &s.material_block, mat4_translate(p));
                }
                else if(g_placement_mode == Place_Mode.Tank){
                    auto p = world_to_render_pos(s.mouse_world) + Vec3(0, 0.18f, 0);
                    render_mesh(rp_world, &s.tank_base_mesh, &s.material_enemy_tank, mat4_translate(p));
                    render_mesh(rp_world, &s.tank_top_mesh, &s.material_enemy_tank, mat4_translate(p));
                }
            }
        } break;
    }
}

void editor_toggle(App_State* s){
    // TODO: Don't use malloc and free. Have a free list of window memory.
    import core.stdc.stdlib : malloc, free;

    auto gui = &s.gui;
    if(!editor_is_open){
        begin_text_input();
        set_buffer(&g_text_buffer, g_text_buffer_data[], 0);

        s.world.entities_count = 0;
        g_mouse_left_is_down  = false;
        g_mouse_right_is_down = false;

        auto memory = (malloc(4086)[0 .. 4086]);
        auto window = add_window(gui, "Test Window", Window_ID_Editor_Test, rect_from_min_wh(Vec2(20, 20), 200, 80), memory);
        button(window, Button_ID_Editor_Test, "Test Button");
        button(window, gui_id(window.id), "Button B");
        next_row(window);
        button(window, gui_id(window.id), "Button C");

        memory = (malloc(4086)[0 .. 4086]);
        window = add_window(gui, "Alt Window", Window_ID_Editor_Test_2, rect_from_min_wh(Vec2(20, 20), 200, 80), memory);
        button(window, Button_ID_Editor_Test_2, "Test Button");
    }
    else{
        end_text_input();
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

