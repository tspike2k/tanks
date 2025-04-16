/*
Authors:   tspike (github.com/tspike2k)
Copyright: Copyright (c) 2025
License:   Boost Software License 1.0 (https://www.boost.org/LICENSE_1_0.txt)
*/

import fmt;

alias log = formatOut;

void log_error(Args...)(const(char)[] msg, Args args){
    log("ERROR: ");
    log(msg, args);
}

void log_warn(Args...)(const(char)[] msg, Args args){
    log("WARN : ");
    log(msg, args);
}
