/*
Authors:   tspike (github.com/tspike2k)
Copyright: Copyright (c) 2025
License:   Boost Software License 1.0 (https://www.boost.org/LICENSE_1_0.txt)
*/

import logging;
import meta;

public import core.stdc.string : memset, memcpy, strlen;

alias String = const(char)[];

void clear_to_zero(T)(ref T t){
    static if(isArray!T){
        memset(t.ptr, 0, t.length * T[0].init.sizeof);
    }
    else{
        memset(&t, 0, T.sizeof);
    }
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
    copy(src[0 .. $], result[0 .. $]);
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

template isListNode(T){
    enum isListNode = is(typeof(T.next) == T*)
                   && is(typeof(T.prev) == T*)
                   && T.next.offsetof == 0
                   && T.prev.offsetof == size_t.sizeof;
}

struct List(T)
if(isListNode!T){
    T*     next;
    T*     prev;
    size_t count;

    alias top    = prev;
    alias bottom = next;

    void make(){
        next = cast(T*)&this;
        prev = cast(T*)&this;
    }

    void insert(T* head, T* node){
        head.next.prev = node;
        node.next = head.next;
        node.prev = head;
        head.next = node;
        count++;
    }

    void remove(T* node){
        assert(count > 0);
        node.prev.next = node.next;
        node.next.prev = node.prev;
        count--;
    }

    bool is_sentinel(T* node){
        bool result = node == cast(T*)&this;
        return result;
    }

    auto iterate(int Dir = 1)()
    if(Dir == 1 || Dir == -1){
        struct Range{
            T* sentinel;
            T* node;

            bool empty(){
                bool result = node == sentinel;
                return result;
            }

            T* front(){
                return node;
            }

            void popFront(){
                static if(Dir == 1)
                    node = node.next;
                else
                    node = node.prev;
            }
        }

        static if(Dir == 1)
            auto start_node = bottom;
        else
            auto start_node = top;

        auto result = Range(cast(T*)&this, start_node);
        return result;
    }
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

///
//
// Allocators
//
////

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

size_t calc_alignment_push(void* ptr, size_t alignment){
    // Alignment code thanks to Handmade Hero day 131
    size_t result = 0;
    if(alignment == 0){
        result = (alignment - cast(size_t)ptr) & (alignment - 1);
    }
    return result;
}

void[] alloc(Allocator* block, size_t size, uint flags = 0, uint alignment = Default_Align){
    void[] result = null;
    if(size > 0){
        assert(block.used <= block.memory.length);
        assert(size <= block.memory.length - block.used);

        size_t align_push = calc_alignment_push(&block.memory[block.used], alignment);

        size_t index = block.used + align_push;
        assert(index + size <= block.memory.length);
        void *raw = &block.memory[index];
        memset(raw, 0, size); // TODO: Flag for not clearing memory
        result = raw[0 .. size];

        block.used += size + align_push;
    }

    return result;
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

Allocator make_sub_allocator(Allocator* allocator, size_t size, uint flags = 0, uint alignment = Default_Align){
    auto result = Allocator(alloc_array!void(allocator, size, flags, alignment));
    return result;
}

void[] begin_reserve_all(Allocator* allocator, uint alignment = Default_Align){
    auto push = calc_alignment_push(&allocator.memory[allocator.used], alignment);
    auto result = allocator.memory[allocator.used + push .. $];
    allocator.used = allocator.memory.length;
    return result;
}

void end_reserve_all(Allocator* allocator, void[] buffer, size_t used){
    allocator.used = &buffer[used] - allocator.memory.ptr;
    assert(allocator.used <= allocator.memory.length);
}

////
//
// Strings
//
////

// TODO: This should really be called "String_Writer."
struct Buffer_Writer{
    char[] buffer;
    size_t used;

    // TODO: Are methods almost impossible to debug in gdb? That would be a good reason
    // to prefer not using them. The only reason we're using this method is to make it
    // compatible with D Ranges.
    void put(String text){
        size_t bytes_left = buffer.length - used;
        size_t to_write = text.length > bytes_left ? bytes_left : text.length;
        copy(text[0 .. to_write], buffer[used .. used + to_write]);
        used += to_write;
    }
}

Buffer_Writer begin_buffer_writer(Allocator* allocator, uint alignment = Default_Align){
    auto memory = begin_reserve_all(allocator, alignment);
    auto result = Buffer_Writer(cast(char[])memory);
    return result;
}

char[] end_buffer_writer(Allocator* allocator, Buffer_Writer* writer){
    if(writer.buffer.length > 0 && writer.used > writer.buffer.length-1){
        writer.used = writer.buffer.length-1;
    }

    end_reserve_all(allocator, writer.buffer, writer.used+1);
    writer.buffer[writer.used] = '\0';
    auto result = writer.buffer[0 .. writer.used];
    return result;
}

char[] gen_string(Args...)(String fmt_string, Args args, Allocator* allocator){
    import fmt;

    auto memory = begin_reserve_all(allocator);
    auto result = format(cast(char[])memory, fmt_string, args);
    end_reserve_all(allocator, memory, result.length+1);
    return result;
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

bool is_match(String a, String b){
    if(a.length != b.length)
        return false;

    foreach(i, c; a){
        if(b[i] != c)
            return false;
    }
    return true;
}

inout(char)[] to_string(inout(char)* s){
    auto result = s[0 .. strlen(s)];
    return result;
}

alias Reader_Slice = inout(char)[];

// TODO: Rather than use slices, should we have a buffer with a used value, similar to
// the Serializer?

String eat_line(ref Reader_Slice reader){
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

inout(char)* get_last_char(Reader_Slice s, char target){
    inout(char)* result;

    foreach(ref c; s){
        if(c == target){
            result = &c;
        }
    }

    return result;
}

String eat_whitespace(ref Reader_Slice reader){
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

String eat_between_whitespace(ref Reader_Slice reader){
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

String eat_until_char(ref Reader_Slice reader, char delimiter){
    String result = reader;
    auto end = reader.length;
    foreach(i, c; reader){
        if(c == delimiter){
            result = result[0 .. i];
            end = i+1;
            break;
        }
    }
    reader = reader[end .. $];
    return result;
}

// TODO: This is used by the obj parser. We should switch to using eat_until_char
// once we iron out how it workds.
String eat_between_char(ref Reader_Slice reader, char delimiter){
    String result = reader;
    foreach(i, c; reader){
        if(c == delimiter){
            result = result[0 .. i];
            reader = reader[i+1 .. $];
            break;
        }
    }
    return result;
}

bool to_int(T)(T* result, String s, T base = 10)
if(isIntegral!T && !isFloatingPoint!T){
    bool succeeded = false;
    if(s.length > 0){
        bool is_negative = s[0] == '-';

        // TODO: Override "base" depending on if the string begins with 0x or 0b.
        if(s[0] == '-' || s[0] == '+')
            s = s[1..$];

        succeeded = s.length > 0;
        uint exponent = 0;
        foreach_reverse(c; s){
            T n;
            if(c == '_'){
                continue;
            }
            else if(base >= 10 && c >= '0' && c <= '9'){
                n = (c - '0');
            }
            else if(base == 16 && c >= 'a' && c <= 'f'){
                n = 10 + (c - 'a');
            }
            else if(base == 16 && c >= 'A' && c <= 'F'){
                n = 10 + (c - 'A');
            }
            else{
                succeeded = false;
                break;
            }

            *result += n*(base^^(exponent)); // ^^ is the pow expression in D
            exponent++;
        }

        static if(isSigned!T){
            if(is_negative){
                *result = cast(T)((*result)*-1);
            }
        }
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

////
//
// Serialization
//
///

struct Serializer{
    void[]     buffer;
    Allocator* allocator;
    size_t     buffer_used;
    bool       errors;
}

size_t bytes_left(Serializer* serializer){
    assert(serializer.buffer_used <= serializer.buffer.length);
    size_t result = serializer.buffer.length - serializer.buffer_used;
    return result;
}

void end_stream(Serializer* dest){
    dest.buffer_used = dest.buffer.length;
}

void[] eat_bytes(Serializer* dest, size_t bytes){
    void[] result;
    if(bytes_left(dest) >= bytes){
        result = dest.buffer[dest.buffer_used .. dest.buffer_used + bytes];
        dest.buffer_used += bytes;
    }
    else{
        end_stream(dest);
    }
    return result;
}

T* eat_type(T)(Serializer* dest){
    auto raw    = eat_bytes(dest, T.sizeof);
    auto result = cast(T*)raw.ptr; // Do this to avoid bounds checking on casts. We need to allow for null pointers.
    return result;
}

T[] eat_array(T)(Serializer* dest, size_t count){
    // TODO: Does this work if dest is fully consumed? Will it return an array of length 0?
    auto result = cast(T[])eat_bytes(dest, T.sizeof*count);
    return result;
}

private enum Serialize_Mode{
    Read,
    Write,
}

void write(T)(Serializer* serializer, ref T t){
    serialize!(Serialize_Mode.Write)(serializer, t);
}

void read(T)(Serializer* serializer, ref T t){
    serialize!(Serialize_Mode.Read)(serializer, t);
}

private void serialize(Serialize_Mode Mode, T)(Serializer* serializer, ref T t){
    enum bool is_reading = Mode == Serialize_Mode.Read;

    void copy_data(Serializer* serializer, void[] data){
        auto buffer = eat_bytes(serializer, data.length);
        if(buffer.length){
            static if(is_reading)
                copy(buffer, data);
            else
                copy(data, buffer);
        }
        else{
            serializer.errors = true;
        }
    }

    static if(is(T == struct)){
        foreach(i, ref member; t.tupleof){
            // TODO: Allow flagging members as No_Serialize
            serialize!Mode(serializer, member);
        }
    }
    else static if(isArray!T){
        alias Element = ArrayElementType!T;
        static if(isDynamicArray!T){
            auto count = cast(uint)t.length;
            serialize!Mode(serializer, count);

            // When reading dynamic arrays from a buffer you can choose one of two strategies:
            // 1) Make a deep copy.
            // 2) Make a shallow copy.
            // We support both here. If the allocator on the serializer is not null, space is
            // allocated for the array and the elements are copied to this newly allocated memory.
            // If the allocator is null, the array points to the memory in the source buffer.
            static if(is_reading){
                if(serializer.allocator){
                    t = alloc_array!Element(serializer.allocator, count);
                }
                else{
                    t = eat_array!Element(serializer, count);
                    if(t.length == 0){
                        serializer.errors = true;
                    }
                    return;
                }
            }
        }

        static if(isBuiltinType!Element){
            copy_data(serializer, cast(void[])t);
        }
        else{
            foreach(ref e; t){
                serialize!Mode(serializer, e);
            }
        }
    }
    else static if(isBuiltinType!T){
        copy_data(serializer, to_void(&t));
    }
    else{
        static assert("Unable to serialize type " ~ T.stringof ~ ".\n");
    }
}

// TODO: Remove read_array/write_array. Prefer using memory.read, memory.write.
void read_array(T)(Serializer* reader, ref T[] array){
    uint count = 0;
    read(reader, to_void(&count));
    array = cast(T[])eat_bytes(reader, count*T.sizeof);
}

void write_array(T)(Serializer* reader, T[] array){
    uint count = cast(uint)array.length;
    write(reader, to_void(&count));
    write(reader, cast(void[])array);
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
