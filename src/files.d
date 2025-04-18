/*
Authors:   tspike (github.com/tspike2k)
Copyright: Copyright (c) 2025
License:   Boost Software License 1.0 (https://www.boost.org/LICENSE_1_0.txt)
*/

import memory;
private{
    import logging;
}

version(Windows){
    enum Dir_Sep = "\\";
}
else{
    enum Dir_Sep = "/";
}

enum{
    File_Flag_Read    = (1 << 1),
    File_Flag_Write   = (1 << 2),
    File_Flag_Trunc   = (1 << 3),
    File_Flag_Is_Open = (1 << 4),
}

struct File{
    uint flags;
    ulong internal;
}

bool is_open(File* file){
    bool result = cast(bool)(file.flags & File_Flag_Is_Open);
    return result;
}

void[] read_file_into_memory(const(char)[] file_name, Allocator* allocator){
    void[] result;

    auto file = open_file(file_name, File_Flag_Read);
    if(is_open(&file)){
        auto file_size = get_file_size(&file);
        if(file_size > 0){
            auto memory = cast(char[])alloc_array!void(allocator, file_size+1);
            read_file(&file, 0, memory);
            memory[$-1] = '\0';
            result = memory[0 .. $-1];
        }

        close_file(&file);
    }

    return result;
}

// TODO: Make sure the source args are Strings.
char[] make_file_path(Args...)(Args args, Allocator* allocator)
if(Args.length > 0){
    auto writer = begin_buffer_writer(allocator);

    foreach(arg; args[0 .. $-1]){
        writer.put(arg);
        writer.put(Dir_Sep);
    }
    writer.put(args[$-1]);

    auto result = writer.buffer[0 .. writer.used];
    end_buffer_writer(allocator, &writer);
    return result;
}

enum Directory_Entry_Type: uint{
    None,
    File,
    Directory,
    Unknown,
}

struct Directory_Entry{
    Directory_Entry_Type type;
    char[]               name;
    void*                internal;
}

auto recurse_directory(String dir_name, Allocator* allocator){
    auto result = Directory_Range(dir_name, allocator);
    return result;
}

version(linux){
    File open_file(const(char)[] file_name, uint flags){
        int permissions = 0;
        int oflags = 0;
        if ((flags & File_Flag_Read) && (flags & File_Flag_Write)){
            oflags = O_RDWR|O_CREAT;
        }
        else if (flags & File_Flag_Read){
            oflags = O_RDONLY;
        }
        else if (flags & File_Flag_Write){
            oflags = O_WRONLY|O_CREAT;
            permissions = Dest_File_Permissions;
        }

        if((flags & File_Flag_Write) && (flags & File_Flag_Trunc)){
            oflags |= O_TRUNC;
        }

        File result;
        int fd = open(file_name.ptr, oflags, permissions);
        if(fd != -1){
            *fd_from_file(&result) = fd;
            result.flags |= flags|File_Flag_Is_Open;
        }
        else{
            // TODO: Better logging
            log("Unable to open ");
            log(file_name);
            log("\n");
            //log(Cyu_Err "Unable to open {0}.\n", fmt_cstr(file_path));
        }
        return result;
    }

    void close_file(File* file){
        assert(is_open(file));
        auto fd = *fd_from_file(file);
        close(fd);
        // TODO: Remove bit flag for file being open
    }

    size_t get_file_size(File* file){
        auto fd = *fd_from_file(file);
        stat_t s;
        size_t result;
        if(fstat(fd, &s) == 0){
            result = s.st_size;
        }
        else{
            log("Unable to get file size.\n");
        }
        return result;
    }

    struct Directory_Range{
        import core.sys.posix.dirent;
        struct Node{
            Node*   next;
            Node*   prev;
            DIR*    dir;
            dirent* entry_stream;
        }

        Allocator* allocator;
        List!Node  nodes;
        Node*      node_first_free;
        String     base_dir_name;

        this(String dir_name, Allocator* al){
            allocator = al;
            push_frame(allocator.scratch);
            nodes.make();
            base_dir_name = dir_name;
            push_directory(dir_name);
            advance_directory_stream();
        }

        bool empty(){
            bool result = nodes.is_sentinel(nodes.bottom);
            return result;
        }

        Directory_Entry front(){
            auto entry = nodes.top.entry_stream;

            Directory_Entry result;
            result.name = to_string(entry.d_name.ptr);
            result.internal = &this;

            switch(entry.d_type){
                default:
                    result.type = Directory_Entry_Type.Unknown; break;

                case DT_REG:
                    result.type = Directory_Entry_Type.File; break;

                case DT_DIR:
                    result.type = Directory_Entry_Type.Directory; break;
            }

            return result;
        }

        void popFront(){
            auto stream = nodes.top.entry_stream;
            if(stream && stream.d_type == DT_DIR){
                push_directory(stream.d_name[]);
            }
            advance_directory_stream();

            // We have no more directories to search, so cleanup memory.
            if(nodes.is_sentinel(nodes.top)){
                pop_frame(allocator.scratch);
            }
        }

        void push_directory(String dir_name){
            auto dir = opendir(dir_name.ptr);
            if(dir){
                Node* node;
                if(node_first_free){
                    node = node_first_free;
                    node_first_free = node.next;
                }
                else{
                    node = alloc_type!Node(allocator);
                }

                nodes.insert(nodes.top, node);
                node.dir = dir;
            }
        }

        void advance_directory_stream(){
            auto node = nodes.top;
            while(!nodes.is_sentinel(node)){
                node.entry_stream = readdir(node.dir);
                if(node.entry_stream){
                    auto name = to_string(node.entry_stream.d_name.ptr);
                    if(is_match(name, ".") || is_match(name, "..")){
                        continue;
                    }
                    else{
                        break;
                    }
                }
                else{
                    closedir(node.dir);
                    auto to_remove = node;
                    node = node.prev;
                    nodes.remove(to_remove);

                    if(node_first_free){
                        to_remove.next = node_first_free;
                    }
                    node_first_free = to_remove;
                }
            }
        }
    }

    char[] get_full_path(Directory_Entry *dir, Allocator* allocator){
        char[] result;
/*
        auto range = cast(Directory_Range*)dir.internal;
        auto writer = begin_buffer_writer(allocator);
        writer.put(base_dir_name);

        end_buffer_writer(allocator, &writer);
*/
        return result;
    }

    /+
    struct Directory_Walker{






        Directory_Entry front(){
            Directory_Entry result;

            auto node = sentinel.get;
            while(node != &sentinel){
                auto dir = node.dir;
                dir_stream = readdir(dir);
                if(entry){
                    auto name = to_string(&entry.d_name[0]);
                    if(!is_match(name, ".") && !is_match(name, "..")){
                        graft_name_onto_path_end(name.ptr);
                        break;
                    }
                }
                else{
                    closedir(dir);
                    ;
                }
            }


            auto entry = readdir()

            return result;
        }

        void popFront(){
            if(dir_stream && dir_stream.d_type == DT_DIR){
                push_dir(dir_stream.d_name[]);
            }
            advance_directory_stream();
        }

        private:

        void push_directory(String dir_name){

        }

        void advance_directory_stream(){

        }
    }+/

    size_t read_file(File *file, size_t offset, void[] dest){
        assert(file.flags & File_Flag_Read);
        assert(file.flags & File_Flag_Is_Open);
        int fd = *fd_from_file(file);

        size_t bytes_read = 0;
        // TODO: Are we supposed to offset the subsequent calls to read by bytes_read?
        // Some example code doesn't do this, which seems suspect.
        while(bytes_read < dest.length){
            ssize_t r = pread(fd, &dest[bytes_read], dest.length - bytes_read, offset + bytes_read);
            if(r < 0){
                // TODO: logging
                //fprintf(stderr, "Failed to read from file: %s\n", strerror(errno));
                break;
            }
            else if(r == 0){
                break;
            }
            bytes_read += cast(size_t)r;
        }
        return bytes_read;
    }

    size_t write_file(File *file, size_t offset, void[] data){
        assert(file.flags & File_Flag_Write);
        assert(file.flags & File_Flag_Is_Open);
        int fd = *fd_from_file(file);

        size_t bytes_written = 0;
        // TODO: Are we supposed to offset the subsequent calls to write by bytes_read?
        // Some example code doesn't do this, which seems suspect.
        while(bytes_written < data.length){
            ssize_t r = pwrite(fd, &data[bytes_written], data.length - bytes_written, offset + bytes_written);
            if(r < 0){
                // TODO: Logging
                //fprintf(stderr, "Failed to write to file: %s\n", strerror(errno));
                break;
            }
            else if(r == 0){
                break;
            }
            bytes_written += cast(size_t)r;
        }
        return bytes_written;
    }

    char[] get_path_to_executable(Allocator* allocator){
        char[] result;

        auto writer = begin_buffer_writer(allocator);
        auto buffer = writer.buffer;
        ssize_t count = readlink("/proc/self/exe", buffer.ptr, buffer.length);
        if(count > 0){
            // Remove the trailing binary name from the result
            char* c = get_last_char(buffer[0 .. count], '/');
            if(c){
                *c = '\0';
                result = buffer[0 .. c - buffer.ptr];
                writer.used += result.length + 1;
                assert(result[$-1] != '\0');
            }
            else{
                // TODO: Handle errors
            }
        }
        else{
            // TODO: Handle errors
        }
        end_buffer_writer(allocator, &writer);
        return result;
    }

    private:

    import core.sys.linux.dlfcn;
    import core.sys.linux.unistd;
    import core.sys.linux.fcntl;
    import core.sys.posix.sys.stat;
    import core.stdc.string;
    import core.stdc.errno;

    // Default file permissions: user:rw- group:r-- other: r--
    enum Dest_File_Permissions = S_IRUSR|S_IWUSR|S_IRGRP|S_IROTH;

    int* fd_from_file(File *file){
        int* result = cast(int*)&file.internal;
        return result;
    }
}

version(linux){
    import logging;
    import core.sys.posix.poll;
    import core.stdc.string : strlen;
    import core.sys.linux.sys.inotify;

    struct File_Watcher{
        int    inotify_fd;
        bool   can_read;
        uint   to_watch_count;
        int[8] to_watch;
        char[] read_buffer;
    }

    enum{
        Watch_Event_None     = 0,
        Watch_Event_Modified = IN_MODIFY,
    }

    alias Watch_Handle = int;

    struct Watch_Event{
        Watch_Handle handle;
        uint event;
        const(char)[] name;
    }

    File_Watcher watch_begin(char[] read_buffer){
        File_Watcher watcher;
        watcher.inotify_fd = inotify_init1(IN_NONBLOCK);
        if(watcher.inotify_fd == -1)
            log_warn("Failed to create Inotify fd.\n");

        watcher.read_buffer = read_buffer;
        return watcher;
    }

    void watch_end(File_Watcher* watcher){
        if(watcher.inotify_fd != -1){
            foreach(i; 0 .. watcher.to_watch_count){
                int fd = watcher.to_watch[i];
                assert(fd != -1);
                inotify_rm_watch(watcher.inotify_fd, fd);
            }

            close(watcher.inotify_fd);
        }
    }

    Watch_Handle watch_add(File_Watcher *watcher, const(char)[] file_path, uint watch_events){
        int result = -1;

        if(watcher.inotify_fd != -1){
            int fd = inotify_add_watch(watcher.inotify_fd, file_path.ptr, watch_events);
            if(fd != -1){
                watcher.to_watch[watcher.to_watch_count++] = fd;
                result = fd;
            }
            else
                log_warn("Failed to add to Inotify fd watch list.\n");
                //log_warn("Failed to add %s to Inotify fd watch list.\n", file_path);
        }

        return result;
    }

    void watch_update(File_Watcher* watcher){
        if(watcher.inotify_fd != -1){
            pollfd pollfds;
            pollfds.fd = watcher.inotify_fd;
            pollfds.events = POLLIN;
            poll(&pollfds, 1, 0);

            watcher.can_read = pollfds.revents & POLLIN;
        }
    }

    bool watch_read_events(File_Watcher* watcher, Watch_Event* event){
        bool read_event = false;
        if(watcher.inotify_fd != -1 && watcher.can_read){
            // For some reason, I could only get reads to work if I used a buffer. Trying to only read a single event
            // from the inotify_fd failed every time, even when an event should have fired.
            //
            // TODO: Handle read failures due to kernel interrupts, etc.
            if(read(watcher.inotify_fd, watcher.read_buffer.ptr, watcher.read_buffer.length) > 0){
                auto i_evt = cast(inotify_event*)&watcher.read_buffer[0];
                auto name_raw = i_evt.name.ptr;
                event.handle = i_evt.wd;
                event.event  = i_evt.mask;
                event.name   = name_raw[0 .. strlen(name_raw)];
                read_event = true;
            }
        }
        return read_event;
    }

}

/+
#ifdef OS_Linux
///////////////////////////////
//       Begin Linux         //
///////////////////////////////

#include <assert.h>
#include <dlfcn.h>
#include <unistd.h>
#include <fcntl.h>
#include <string.h> // strerror;
#include <errno.h>
#include <sys/stat.h> // fstat
#include <stdio.h> // printf. TODO: Logging functions!
#include <linux/limits.h> // PATH_MAX
#include <stdlib.h> // getenv



static

Cyu_API bool open_file(File *file, const char *file_path, uint32_t file_mode){
    bool result = false;

    int permissions = 0;
    int oflags = 0;
    if ((file_mode & File_Flag_Read) && (file_mode & File_Flag_Write)){
        oflags = O_RDWR|O_CREAT;
    }
    else if (file_mode & File_Flag_Read){
        oflags = O_RDONLY;
    }
    else if (file_mode & File_Flag_Write){
        oflags = O_WRONLY|O_CREAT;
        permissions = Dest_File_Permissions;
    }

    if((file_mode & File_Flag_Write) && (file_mode & File_Flag_Trunc)){
        oflags |= O_TRUNC;
    }

    int fd = open(file_path, oflags, permissions);
    if(fd != -1){
        *cyu__fd_from_file(file) = fd;
        result = true;
    }
    else{
        log(Cyu_Err "Unable to open {0}.\n", fmt_cstr(file_path));
    }
    return result;
}

Cyu_API size_t get_file_size(File* file){
    int fd = *cyu__fd_from_file(file);
    struct stat s;
    size_t result = 0;
    if(fstat(fd, &s) == 0){
        result = s.st_size;
    }
    else{
        log(Cyu_Err "Unable to get file size.\n");
    }
    return result;
}

Cyu_API void close_file(File *file){
    int *fd = cyu__fd_from_file(file);
    close(*fd);
    *fd = -1;
}

Cyu_API File get_stdout(void){
    File result = {.handle = 1, .flags = File_Flag_Stream|File_Flag_Write};
    return result;
}

Cyu_API File get_stdin(void){
    File result = {.handle = 0, .flags = File_Flag_Stream|File_Flag_Read};
    return result;
}

Cyu_API File get_stderr(void){
    File result = {.handle = 2, .flags = File_Flag_Stream|File_Flag_Write};
    return result;
}

Cyu_API bool read_stream(File *file, size_t* bytes_read, void *buffer, size_t buffer_size){
    assert(file->flags & (File_Flag_Stream|File_Flag_Read));

    bool has_data = false;

    // TODO: Perform more than one read if we have a short read
    int fd = *cyu__fd_from_file(file);
    int r = read(fd, buffer, buffer_size);
    if(r < 0){

    }
    else if(r > 0){
        *bytes_read = (size_t)r;
        has_data = true;
    }

    return has_data;
}

Cyu_API void write_stream(File *stream, void *buffer, size_t buffer_size){
    // TODO: Perform more than one write if we have a short write

    int fd = *((int*)&stream->handle);
    int r = write(fd, buffer, buffer_size);
}

static Slice slice_copy(Slice dest, void *data, size_t length){
    Slice result = {};

    if(dest.length > 0 && length > 0){
        size_t to_write = dest.length > length ? length : dest.length;
        memcpy(dest.data, data, to_write);
        result = slice(dest.data, to_write);
    }

    return result;
}

#if _GNU_SOURCE
    #define cyu__getenv secure_getenv
#else
    #define cyu__getenv getenv
#endif

static Slice cyu__get_xgd_dir_or_fallback(Memory_Block* block, const char *xgd_env, const char *fallback){
    // This is based on the "XDG Base Directory Specification" Freedesktop which can be read here:
    // https://specifications.freedesktop.org/basedir-spec/latest/
    Slice result = {};

    // TODO: Do better than slice_write to null terminate. If there's no space left, it will fail!
    char *s = cyu__getenv(xgd_env);
    if(s){
        size_t len = strlen(s);
        char *text = memory_alloc(block, len+1, 0, Default_Align);
        memcpy(text, s, len);
        text[len] = '\0';

        result = slice(text, len);
    }
    else{
        // TODO: Append "fallback" to result of $HOME env
        s = cyu__getenv("HOME");
        size_t home_len   = strlen(s);
        size_t append_len = strlen(fallback);

        char *text = memory_alloc(block, home_len+append_len+1, 0, Default_Align);
        memcpy(text, s, home_len);
        memcpy(&text[home_len], fallback, append_len);
        text[home_len+append_len] = '\0';

        result = slice(text, home_len+append_len);
    }

    return result;
}

Cyu_API Slice get_directory_path(Memory_Block* block, uint32_t dir_type){
    Slice result = {};

    switch(dir_type){
        default: break;

        case Dir_Type_Application:{
            char *text = memory_alloc(block, 1, 0, Default_Align); // Make sure we're aligned
            ssize_t count = readlink("/proc/self/exe", text, block->size - block->used);
            if(count > 0){
                result = slice(text, count);

                // Remove the trailing binary name from the result
                char* p = slice_get_last_char(result, '/');
                if(p){
                    *p = '\0';
                    result.length = p - result.data;
                }

                block->used += result.length;
            }
            else{
                // TODO: We can't get the directory, so use a relative path instead: "./"
                // TODO: Handle errors.
                assert(0);
            }
        } break;

        case Dir_Type_Cache:{
            result = cyu__get_xgd_dir_or_fallback(block, "XDG_CACHE_HOME", "/.cache");
        } break;

        case Dir_Type_Data:{
            result = cyu__get_xgd_dir_or_fallback(block, "XDG_DATA_HOME", "/.local/share");
        } break;

        case Dir_Type_Config:{
            result = cyu__get_xgd_dir_or_fallback(block, "XDG_CONFIG_HOME", "/.config");
        } break;
    }

    return result;
}

///////////////////////////////
//        End Linux          //
///////////////////////////////
#else
  #error Unsupported OS for file handling.
#endif

Cyu_API size_t read_file_into_buffer(const char *file_path, void *source, size_t source_size){
    File file;
    size_t result = 0;
    if(open_file(&file, file_path, File_Flag_Read)){
        size_t size = get_file_size(&file);
        assert(size <= source_size);
        if(size <= source_size){
            read_file(&file, 0, source, size);
            result = size;
        }
        else{
            // TODO: Log error that the source buffer is too small for the file.
        }

        close_file(&file);
    }
    return result;
}

Cyu_API Slice read_file_into_memory(const char *file_path, Memory_Block* block){
    File file;
    Slice result = {0};
    if(open_file(&file, file_path, File_Flag_Read)){
        size_t size = get_file_size(&file);
        char *p = (char*)memory_alloc(block, size+1, 0, Default_Align);
        read_file(&file, 0, p, size);
        p[size] = '\0';
        result = slice(p, size);

        close_file(&file);
    }
    return result;
}
+/
