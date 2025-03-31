/*
Copyright (c) 2025 tspike2k@github.com
Distributed under the Boost Software License, Version 1.0.
See accompanying file LICENSE_BOOST.txt or copy at http://www.boost.org/LICENSE_1_0.txt
*/

import app;
import display;
import math;
import logging;
import render;

bool editor_is_open;

private{

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
                if(btn.pressed){
                    if(btn.id == Button_ID.Mouse_Left){

                    }
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

                        case Key_ID_F2:
                            editor_toggle(s); break;
                    }
                }
            } break;
        }
    }
}

bool inside_grid(Vec2 p){
    bool result = p.x >= 0.0f && p.x <= Grid_Width && p.y > 0.0f && p.y < Grid_Height;
    return result;
}

void editor_render(App_State* s){
    if(inside_grid(s.mouse_world)){
        set_material(&s.material_block);
        Vec2 world_p = floor(s.mouse_world) + Vec2(0.5f, 0.5f);
        auto p = world_to_render_pos(world_p) + Vec3(0, 0.5f, 0);
        render_mesh(&s.cube_mesh, mat4_translate(p));
    }
}

void editor_toggle(App_State* s){
    if(!editor_is_open){
        s.world.entities_count = 0;
    }

    editor_is_open = !editor_is_open;
}

