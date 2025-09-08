/*
Authors:   tspike (github.com/tspike2k)
Copyright: Copyright (c) 2025
License:   Boost Software License 1.0 (https://www.boost.org/LICENSE_1_0.txt)
*/

import memory;

version(linux){
    import core.sys.linux.time;

    void ns_sleep(ulong nanoseconds){
        if(nanoseconds > 0){
            timespec ts;
            ts.tv_sec  = nanoseconds / 1000000000;
            ts.tv_nsec = nanoseconds % 1000000000;
            // NOTE: nanosleep can fail when a signal is raised. If this happens it returns -1.
            // In that case we try the function again.
            while(nanosleep(&ts, null) == -1){

            }
        }
    }

    ulong ns_timestamp(){
        timespec ts;
        clock_gettime(CLOCK_MONOTONIC_RAW, &ts);
        ulong result = ts.tv_sec * 1000000000 + ts.tv_nsec;
        return result;
    }
}
