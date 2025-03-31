/*
Copyright (c) 2025 tspike2k@github.com
Distributed under the Boost Software License, Version 1.0.
See accompanying file LICENSE_BOOST.txt or copy at http://www.boost.org/LICENSE_1_0.txt
*/

import display;
import app;
import logging;

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

                //mouse_pixel = Vec2(motion.pixel_x, motion.pixel_y);
            } break;

            case Event_Type.Key:{
                auto key = &evt.key;
                if(!key.is_repeat && key.pressed){
                    switch(key.id){
                        default: break;

                        case Key_ID_F2:
                            editor_toggle(); break;
                    }
                }
            } break;
        }
    }
}

void editor_render(){

}

void editor_toggle(){
    editor_is_open = !editor_is_open;
}

