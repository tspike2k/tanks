/*
Authors:   tspike (github.com/tspike2k)
Copyright: Copyright (c) 2025
License:   Boost Software License 1.0 (https://www.boost.org/LICENSE_1_0.txt)
*/

nothrow @nogc:

import core.stdc.stdio;

// TODO: Better logging API
void log(const(char)[] msg){
    printf("%.*s", cast(int)msg.length, msg.ptr);
}

void log_error(const(char)[] msg){
    printf("ERROR: %.*s", cast(int)msg.length, msg.ptr);
}

void log_warn(const(char)[] msg){
    printf("WARN: %.*s", cast(int)msg.length, msg.ptr);
}
