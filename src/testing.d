/*
Authors:   tspike (github.com/tspike2k)
Copyright: Copyright (c) 2025
License:   Boost Software License 1.0 (https://www.boost.org/LICENSE_1_0.txt)
*/

import render;

debug{
    enum Testing = true;
}
else{
    enum Testing = false;
}

__gshared bool  g_debug_mode;
__gshared bool  g_debug_pause;
__gshared bool  g_debug_pause_next;
__gshared ulong g_perf_frequency;
__gshared Render_Pass* g_debug_render_pass;

private __gshared string[] g_timer_block_names;

void debug_pause(bool should_pause){
    g_debug_pause_next = should_pause;
}

long rdtsc(){
    // Adapted from the following:
    // https://wiki.dlang.org/Timing_Code
    asm
    {	naked	;
        rdtsc	;
        ret	;
    }
}

// Timer functions inspired by work done by Casey Muratori on Handmade Hero.
// IMPORTANT! Unlike Handmade Hero, this API is not thread safe! We would need to do something
// much smarter to support that here!

enum Perf_Event : uint{
    Begin_Timer,
    End_Timer,
}

struct Perf_Entry{
    ulong        cycles;
    const(char)* name; // Pointer also serves as a unique ID.
    Perf_Event   event;
}

struct Perf_Frame{
    Perf_Entry[256] entries;
    uint            entries_count;
}

Perf_Entry* add_perf_entry(ulong cycles, const(char)* name, Perf_Event event){
    auto frame = &g_perf_frames[g_perf_frames_cursor];

    auto entry = &frame.entries[frame.entries_count++];
    entry.cycles = cycles;
    entry.name   = name;
    entry.event  = event;
    return entry;
}

__gshared uint           g_perf_frames_cursor;
__gshared Perf_Frame[32] g_perf_frames;

struct Perf_Timer{
    ulong cycles;
    const(char)* name;
    Perf_Entry*  entry;
}

Perf_Timer begin_perf_timer(string name){
    Perf_Timer result = void;
    result.cycles = rdtsc();
    result.name   = name.ptr;
    result.entry = add_perf_entry(0, name.ptr, Perf_Event.Begin_Timer);

    return result;
}

void end_perf_timer(Perf_Timer* timer){
    auto cycles_elapsed = rdtsc() - timer.cycles;
    add_perf_entry(cycles_elapsed, timer.name, Perf_Event.End_Timer);
    timer.entry.cycles = cycles_elapsed;
}

template Perf_Function(){
    enum Perf_Function = q{
        auto perf_func_timer = begin_perf_timer(__FUNCTION__);
        scope(exit) end_perf_timer(&perf_func_timer);
    };
}

void print_and_reset_perf_info(){
    import logging;
    auto frame = &g_perf_frames[0];

    int indent = -1;
    foreach(ref entry; frame.entries[0 .. frame.entries_count]){
        if(entry.event == Perf_Event.Begin_Timer){
            indent++;

            foreach(i; 0 .. indent){
                log(" "); // This is just for testing. It's grossly inneficient!
            }
            log("{0}: cycles: {1}\n", entry.name, entry.cycles);
        }
        else if(entry.event == Perf_Event.End_Timer){
            indent--;
        }
    }

    frame.entries_count = 0;
}

/+
float cycles_to_ms(ulong cycles){
    auto perf_freq =
}+/

////
//
version(linux):
//
////

void debug_init(){
    // HACK! Linux has doesn't seem to have a function like QueryPerformanceFrequency
    g_perf_frequency = 1000000000;
}
