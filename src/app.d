/*
Authors:   tspike (github.com/tspike2k)
Copyright: Copyright (c) 2025
License:   Boost Software License 1.0 (https://www.boost.org/LICENSE_1_0.txt)
*/

import display;
import logging;

extern(C) int main(){
    if(!open_display("Tanks", 1920, 1080, 0)){
        log_error("Unable to open display!\n");
    }
    scope(exit) close_display();

    bool running = true;
    while(running){

    }

    return 0;
}
