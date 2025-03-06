/*
Authors:   tspike (github.com/tspike2k)
Copyright: Copyright (c) 2025
License:   Boost Software License 1.0 (https://www.boost.org/LICENSE_1_0.txt)
*/

version(linux){
    import core.sys.linux.time;

    void ns_sleep(ulong nanoseconds){
        // TODO: nanosleep can fail if a signal is raised. In that case, it will return -1. Figure out how to handle this.
        if(nanoseconds != 0){
            timespec ts;
            ts.tv_sec  = nanoseconds / 1000000000;
            ts.tv_nsec = nanoseconds % 1000000000;
            int r = nanosleep(&ts, null);
            assert(r != -1);
        }
    }

    ulong ns_timestamp(){
        // TODO: Should we use CLOCK_MONOTONIC_RAW? It requires a "newer" kernel.
        timespec ts;
        clock_gettime(CLOCK_MONOTONIC, &ts);
        ulong result = ts.tv_sec * 1000000000 + ts.tv_nsec;
        return result;
    }
}
