/*
Authors:   tspike (github.com/tspike2k)
Copyright: Copyright (c) 2025
License:   Boost Software License 1.0 (https://www.boost.org/LICENSE_1_0.txt)
*/

import logging;
import std.traits;

public import core.stdc.string : memset, memcpy, strlen;

alias String = const(char)[];

void clear_to_zero(T)(ref T t){
    memset(&t, 0, T.sizeof);
}

void[] to_void(T)(T* t){
    auto result = t[0 .. 1];
    return result;
}

void swap(T)(ref T a, ref T b){
    auto temp = b;
    b = a;
    a = temp;
}

T zero_type(T)(){
    T result = void;
    memset(&result, 0, T.sizeof);
    return result;
}

void[] eat_bytes(ref void[] data, size_t size){
    auto result = data[0 .. size];
    data = data[size .. $];
    return result;
}

Unqual!T[] dup_array(T)(T[] src, Allocator* allocator){
    auto result = alloc_array!(Unqual!T)(allocator, src.length);
    result[0 .. $] = src[0 .. $];
    return result;
}

char[] concat(String a, String b, Allocator* allocator){
    auto result = alloc_array!(char)(allocator, a.length+b.length+1);
    copy(a[0 .. $], result[0 .. a.length]);
    copy(b[0 .. $], result[a.length .. a.length + b.length]);
    result[$-1] = '\0';
    return result;
}

bool begins_with(String a, String b){
    bool result = false;
    if(a.length >= b.length){
        result = a[0 .. b.length] == b[0 .. $];
    }
    return result;
}

// TODO: Make sure the source args are String.
char[] make_file_path(Args...)(Args args, Allocator* allocator)
if(Args.length > 0){
    version(Windows){
        String dir = "\\";
    }
    else{
        String dir = "/";
    }

    size_t len;
    static foreach(arg; args){
        len += arg.length;
    }

    len += args.length-1; // Account for directory seperators
    len += 1; // Account for null terminator
    auto dest = alloc_array!char(allocator, len);

    size_t place;
    void append(String s){
        copy(s[0 .. $], dest[place .. place + s.length]);
        place += s.length;
    }

    foreach(arg; args[0 .. $-1]){
        append(arg);
        append(dir);
    }
    append(args[$-1]);
    append("\0");

    return dest[0 .. $-1]; // Ignore the null terminator
}


version(linux){
    import core.sys.linux.sys.mman;

    // TODO: Do mmap/munmap need to be gaurded against EINTR as well?

    void[] os_alloc(size_t size, uint flags){
        void[] result;

        void *memory = mmap(null, size, PROT_READ|PROT_WRITE, MAP_ANONYMOUS|MAP_PRIVATE|MAP_NORESERVE, -1, 0);
        if (memory != cast(void*)-1){
            result = memory[0 .. size];
        }
        else{
            log("Unable to allocate memory.\n");
        }

        return result;
    }

    void os_dealloc(void[] memory){
        assert(memory);
        if(munmap(memory.ptr, memory.length) == -1){
            log("Unable to free memory.\n");
        }
    }
}

bool is_whitespace(char c){
    bool result = (c == ' ')
               || (c == '\t')
               || (c == '\v')
               || (c == '\f')
               || (c == '\n')
               || (c == '\r');
    return result;
}

enum Default_Align = uint.sizeof;

struct Allocator_Frame{
    Allocator_Frame* next;
    size_t           used;
}

//
// Each allocator can point to a scratch buffer. This way we wouldn't have to pass a scratch buffer
// to every single function that uses temporary scratch memory.
//
struct Allocator{
    void[] memory;
    size_t used;
    Allocator_Frame* last_frame;

    Allocator* scratch;
}

Allocator reserve_memory(Allocator* allocator, size_t size, uint flags = 0, uint alignment = Default_Align){
    auto result = Allocator(alloc_array!void(allocator, size, flags, alignment));
    return result;
}

void[] alloc(Allocator* block, size_t size, uint flags = 0, uint alignment = Default_Align){
    assert(block.used <= block.memory.length);
    assert(size <= block.memory.length - block.used);

    size_t memory_loc = cast(size_t)&block.memory[block.used];
    size_t align_push = 0;
    if(alignment != 0)
        align_push = (alignment - memory_loc) & (alignment - 1); // Alignment code thanks to Handmade Hero day 131

    size_t index = block.used + align_push;
    assert(index + size <= block.memory.length);
    void *raw = &block.memory[index];
    memset(raw, 0, size); // TODO: Flag for not clearing memory
    auto result = raw[0 .. size];

    block.used += size + align_push;

    return result;
}

void copy(T)(const(T[]) src, T[] dest){
    version(LDC){
        // NOTE: Workaround for LDC compilation issues.
        assert(dest.length == src.length);
        memcpy(dest.ptr, src.ptr, src.length*src[0].sizeof);
    }
    else{
        dest[0 .. $] = src[0 .. $];
    }
}

T* alloc_type(T)(Allocator* allocator, uint flags = 0, uint alignment = Default_Align){
    auto result = cast(T*)alloc(allocator, T.sizeof, flags, alignment);
    return result;
}

T[] alloc_array(T)(Allocator* allocator, size_t count, uint flags = 0, uint alignment = Default_Align){
    auto raw = cast(T*)alloc(allocator, T.sizeof*count, flags, alignment);
    auto result = raw[0 .. count];
    return result;
}

void reset(Allocator* allocator){
    allocator.used = 0;
    allocator.last_frame = null;
}

void push_frame(Allocator* allocator){
    auto prev_used = allocator.used;
    auto frame = alloc_type!Allocator_Frame(allocator);
    frame.used = prev_used;
    frame.next = allocator.last_frame;
    allocator.last_frame = frame;
}

void pop_frame(Allocator* allocator){
    allocator.used = allocator.last_frame.used;
    allocator.last_frame = allocator.last_frame.next;
}

bool to_int(T)(T* t, String s)
if(isIntegral!T && !isFloatingPoint!T){
    bool succeeded = s.length > 0;

    bool is_negative;
    if(s.length > 0){
        is_negative = s[0] == '-';

        if(s[0] == '-' || s[0] == '+')
            s = s[1..$];
    }

    // TODO: Parse hex literals. What about binary and octal?
    T base = 10;

    T result = 0;
    foreach_reverse(i, c; s){
        if(c >= '0' && c <= '9'){
            T n = (c - '0');
            result += n*(base^^(s.length-1 - i)); // ^^ is the pow expression in D
        }
        else if(c != '_'){
            succeeded = false;
            break;
        }
    }

    if(succeeded){
        *t = result;
    }

    return succeeded;
}

bool to_float(float* f, String s){
    import core.stdc.stdlib : strtod;

    bool result = false;

    // Since we're using strtod, we need to pass in a string that we know is null terminated.
    // Therefore, we copy the string.
    //
    // TODO: Learn how to write a replacement to strtod, so we don't have to do this silly
    // null termination dance.
    char[512] buffer = void;
    if(s.length > 0 && s.length < buffer.length){
        copy(s[0..$], buffer[0 .. s.length]);
        buffer[s.length] = '\0';
        *f = strtod(buffer.ptr, null);
        result = true;
    }

    return result;
}

//
// Strings
//


String eat_line(ref String reader){
    String result = reader;
    foreach(i, c; reader){
        if(c == '\n'){ // Handle Windows style line ends?
            result = reader[0 .. i];
            break;
        }
    }

    reader = reader[result.ptr - reader.ptr+1 .. $];
    return result;
}

String eat_obj_line_command(ref String reader){
    String result;

    foreach(i, c; reader){
        if(is_whitespace(c)){
            result = reader[0 .. i];
            reader = reader[i+1..$];
            break;
        }
    }

    return result;
}

String eat_whitespace(ref String reader){
    auto result = reader;
    foreach(i, c; reader){
        if(!is_whitespace(c)){
            result = result[0 .. i];
            reader = reader[i .. $];
            break;
        }
    }
    return result;
}

String eat_between_whitespace(ref String reader){
    eat_whitespace(reader);
    auto result = reader;
    foreach(i, c; reader){
        if(is_whitespace(c)){
            result = result[0 .. i];
            reader = reader[i .. $];
            break;
        }
    }
    return result;
}

String eat_between_char(ref String reader, char delimiter){
    auto result = reader;
    foreach(i, c; reader){
        if(c == delimiter){
            result = result[0 .. i];
            reader = reader[i+1 .. $];
            break;
        }
    }
    return result;
}


////
//
// Serialization
//
///

alias Serialize = void function(ref void[] stream, void[] data);

void stream_write(ref void[] stream, void[] data){
    copy(data, stream[0 .. data.length]);
    stream = stream[data.length .. $];
}

void stream_read(ref void[] stream, void[] data){
    copy(stream[0 .. data.length], data);
    stream = stream[data.length .. $];
}

void[] stream_next(ref void[] stream, size_t size){
    void[] result;
    if(stream.length >= size){
        result = stream[0 .. size];
        stream = stream[size .. $];
    }
    return result;
}

T* stream_next(T)(ref void[] stream){
    T* result = null;
    auto memory = stream_next(stream, T.sizeof);
    if(memory.length){
        result = cast(T*)memory;
    }

    return result;
}

version(none){
    void serialize_level_element(alias serialize)(Entity* e, ref void[] stream){
        ubyte stored_type = void;
        ubyte stored_p    = void;

        enum is_reading = __traits(isSame, serialize, stream_read);
        static if(!is_reading){
            assert(e.type == Entity_Type.Block || e.type == Entity_Type.Hole);
            assert(e.type != Entity_Type.Hole || e.block_height == 0);
            uint x = cast(uint)e.pos.x;
            uint y = cast(uint)e.pos.y;

            stored_type = cast(ubyte)e.block_height;
            stored_p    = cast(ubyte)((x << 4) | y);
        }

        serialize(stream, to_void(&stored_type));
        serialize(stream, to_void(&stored_p));

        static if(is_reading){
            if(stored_type == 0){
                e.type = Entity_Type.Hole;
            }
            else{
                e.type = Entity_Type.Block;
            }
            e.block_height = stored_type;

            uint x = ((cast(uint)stored_p) >> 4) & 0x0f;
            uint y = ((cast(uint)stored_p))      & 0x0f;
            e.pos = Vec2(x, y) + Vec2(0.5, 0.5f);
        }
    }
}



/+

//
// Slices
//

Slice slice_and_advance(Slice *slice, u64 length){
    assert(slice->length >= length);
    Slice result = {slice->data, length};
    slice_advance(slice, length);
    return result;
}

void slice_advance_char(Slice* slice){
    slice_advance(slice, 1);
}

bool slice_eat_line(Slice* reader, Slice* slice){
    *slice = *reader;
    bool result = reader->length > 0;

    while(reader->length > 0){
        if(reader->data[0] == '\n'){
            slice->length = &reader->data[0] - &slice->data[0];
            slice_advance_char(reader);
            break;
        }
        slice_advance_char(reader);
    }

    return result;
}

bool slice_eat_until_char(Slice* reader, char c){
    bool result = false;
    while(reader->length > 0){
        if(reader->data[0] == c){
            result = true;
            break;
        }
        slice_advance_char(reader);
    }
    return result;
}

void slice_skip_whitespace(Slice *slice){
    while(slice->length > 0){
        if(!is_char_whitespace(slice->data[0]))
            break;
        slice_advance_char(slice);
    }
}

bool slice_eat_next_word(Slice *reader, Slice *word){
    slice_skip_whitespace(reader);

    *word = *reader;
    while(reader->length > 0){
        if(is_char_whitespace(reader->data[0])){
            word->length = reader->data - word->data;
            break;
        }
        slice_advance_char(reader);
    }

    return word->length > 0;
}

// TODO: Make this take two Slices and just expect the user to call make_Slice for the last parameter?
bool slice_matches_cstr(Slice slice, const char* str){
    // TODO: This would be much more efficient if we don't get the length of str and just
    // loop until we hit the null terminator.
    size_t len = strlen(str);
    bool result = false;

    if(len == slice.length){
        result = true;
        for(size_t i = 0; i < len; i++){
            if(slice.data[i] != str[i]){
                result = false;
                break;
            }
        }
    }

    return result;
}

bool slice_begins_with(Slice a, Slice b){
    bool result = false;
    if(a.length >= b.length){
        result = true;
        for(size_t i = 0; i < b.length; i++){
            if(a.data[i] != b.data[i]){
                result = false;
                break;
            }
        }
    }
    return result;
}

void slice_to_cstr(Slice* s, char *buffer, size_t buffer_size){
    size_t to_copy = s->length > buffer_size - 1 ? buffer_size - 1 : s->length;
    memcpy(buffer, s->data, to_copy);
    assert(to_copy+1 < buffer_size);
    buffer[to_copy+1] = '\0';
}

char *slice_get_last_char(Slice s, char c){
    char *result = NULL;

    while(s.length > 0){
        char *p = &s.data[s.length-1];
        if(*p == c){
            result = p;
            break;
        }
        s.length--;
    }

    return result;
}

Cyu_API void slice_write(Slice *writer, const void* data, size_t size){
    assert(size < writer->length);
    memcpy(&writer->data[0], data, size);
    slice_advance(writer, size);
}

Cyu_API void slice_write_str(Slice* writer, char* text, size_t length){
    if (writer->length <= 0) return;

    size_t to_write = length < writer->length ? length : writer->length;
    memcpy(&writer->data[0], text, to_write);

    if(to_write == writer->length){
        writer->data[writer->length-1] = '\0';
    }

    slice_advance(writer, to_write);
}

Cyu_API void slice_terminate_str(Slice* writer){
    if (writer->length <= 0) return;

    writer->data[0] = '\0';
    slice_advance(writer, 1);
}

Cyu_API void slice_advance(Slice* slice, size_t size){
    assert(slice->length >= size);
    slice->length -= size;
    slice->data   += size;
}

//
// Memory Blocks
//

Memory_Block make_memory_block(void* memory, size_t size){
    Memory_Block result = {};

    result.base = (u8*)memory;
    result.size = size;

    return result;
}

void *memory_alloc(Memory_Block *block, size_t size, u32 flags, size_t align){
    assert(block->used <= block->size);
    assert(size < block->size - block->used);

    size_t memory_loc = (size_t)&block->base[block->used];
    size_t align_push = (align - memory_loc) & (align - 1); // Alignment code thanks to Handmade Hero day 131

    size_t index = block->used + align_push;
    assert(index + size < block->size);
    void *result = &block->base[index];
    memset(result, 0, size);

    block->used += size + align_push;

    return result;
}

void memory_drop(Memory_Block *block){
    block->used = 0;
}

void memory_write(Memory_Block *block, void *data, size_t size){
    assert(size < block->size - block->used);
    memcpy(&block->base[block->used], data, size);
    block->used += size;
}

void *memory_read(Memory_Block* block, size_t size){
    assert(block->used <= block->size);

    void *result = NULL;
    if(size <= block->size - block->used){
        result = &block->base[block->used];
        block->used += size;
    }
    else{
        block->used = block->size;
    }

    return result;
}

void combine_strings_raw(Memory_Block *block, Slice* result, Slice *strings, size_t strings_count){
    size_t size = 1;
    for(u32 i = 0; i < strings_count; i++){
        size += strings[i].length;
    }

    char *memory = memory_alloc(block, size, 0, Default_Align);
    memory[size] = '\0';
    *result = slice(memory, size);

    char *cursor = memory;
    for(u32 i = 0; i < strings_count; i++){
        Slice s = strings[i];
        memcpy(cursor, s.data, s.length);
        cursor += s.length;
        assert(cursor <= &memory[size]);
    }
}
+/
