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

__gshared bool g_debug_mode;
__gshared bool g_debug_pause;
__gshared bool g_debug_pause_next;
__gshared Render_Pass* g_debug_render_pass;

void debug_pause(bool should_pause){
    g_debug_pause_next = should_pause;
}
