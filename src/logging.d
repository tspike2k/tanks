/*
Authors:   tspike (github.com/tspike2k)
Copyright: Copyright (c) 2025
License:   Boost Software License 1.0 (https://www.boost.org/LICENSE_1_0.txt)
*/

// TODO: Should we have seperate streams for error and standard out streams?
// TODO: How should we handle mulit-threaded logging? Seperate streams per thread? Can we used the *shared* keyword for this?

// TODO: We also want to handle formatted output.

void log(const(char)[] msg){
    import core.stdc.stdio;
    fprintf(stderr, "%.*s", cast(int)msg.length, msg.ptr);
}

void log_error(const(char)[] msg){
    import core.stdc.stdio;
    fprintf(stderr, "ERROR: %.*s", cast(int)msg.length, msg.ptr);
}
