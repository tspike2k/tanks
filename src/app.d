/*
Authors:   tspike (github.com/tspike2k)
Copyright: Copyright (c) 2025
License:   Boost Software License 1.0 (https://www.boost.org/LICENSE_1_0.txt)
*/

import display;
import logging;
import memory;
import render;
import math;

enum Main_Memory_Size    =  4*1024*1024;
enum Frame_Memory_Size   =  8*1024*1024;
enum Scratch_Memory_Size = 16*1024*1024;

struct App_State{
    Allocator main_memory;
    Allocator frame_memory;
}

extern(C) int main(){
    auto app_memory = os_alloc(Main_Memory_Size + Scratch_Memory_Size + Frame_Memory_Size, 0);
    scope(exit) os_dealloc(app_memory);

    App_State* s;
    {
        auto memory = Allocator(app_memory);
        auto main_memory = reserve_memory(&memory, Main_Memory_Size);

        s = alloc_type!App_State(&main_memory);
        s.frame_memory   = reserve_memory(&memory, Frame_Memory_Size);
        auto scratch_memory = reserve_memory(&memory, Scratch_Memory_Size);

        s.main_memory.scratch  = &scratch_memory;
        s.frame_memory.scratch = &scratch_memory;
    }

    if(!open_display("Tanks", 1920, 1080, 0)){
        log_error("Unable to open display.\n");
        return 1;
    }
    scope(exit) close_display();

    if(!render_open(&s.main_memory)){
        log_error("Unable to init render subsystem.\n");
        return 2;
    }
    scope(exit) render_close();

    bool running = true;
    while(running){
        begin_frame();

        Event evt;
        while(next_event(&evt)){
            switch(evt.type){
                default: break;

                case Event_Type.Window_Close:{
                    // TODO: Save state before exit in a temp/suspend file.
                    running = false;
                } break;
            }
        }

        render_begin_frame(0, 0, &s.frame_memory);
        clear_target_to_color(Vec4(1, 0, 0, 1));
        render_end_frame();

        end_frame();
    }

    return 0;
}
