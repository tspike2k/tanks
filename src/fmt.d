// Authors:   tspike (github.com/tspike2k)
// Copyright: Copyright (c) 2020
// License:   Boost Software License 1.0 (https://www.boost.org/LICENSE_1_0.txt)

/+
TODO:
 - Testing on Windows
 - Get hex values working properly. I have seen issues printing 64-bit hex values at the very least.
 - Figure out if there is a way for the language to easily configure attributes attached to functions and methods in a library.
 - Documentation about toString() support.
 - A new file (tests.d) used to test the library. No more diffing output files!
+/

// NOTE: The order of members returned by __traits(allMembers) is not guaranteed to be in the order they appear in the struct definition.
// However, it SEEMS that the .tupleof property is expected (perhaps even required) to be ordered this way. This behavior appears to be expected by
// some code in Phobos, so we'll rely on this behavior. Should this break in the future, we're going to have to make some changes.
//
// See here for some discussions on this topic:
// https://forum.dlang.org/thread/bug-19036-3@https.issues.dlang.org%2F
// https://forum.dlang.org/thread/odpdhayvxaglheqcntwj@forum.dlang.org
// https://forum.dlang.org/post/stvphdwgugrlcgfkbyxc@forum.dlang.org

public:

//
// Library configuration. Some of these are booleans, others are enums. Thier intended uses are described in comments below.
//

// When set to true, formatting structs and unions will prepend the result with their type name.
enum Output_Struct_And_Union_Names = true;

// When set to true, an assertion will be fired when formatting to a fixed buffer results in truncated text.
enum Assert_On_Truncation          = false;

// When set to true, uses memcpy from the C-runtime instead of the built-in slice copy primitives used by D. This is to solve
// issue #1. This issue was with LDC being unable to use the copy primitives when the D runtime was removed. This is a special
// case, so only enable it if needed.
// See here for details:
// https://github.com/tspike2k/djinnprint/issues/1
enum Use_memcpy                    = true;

enum {
    Terminal_Output_Type_None,
    Terminal_Output_Type_cstdio,
    Terminal_Output_Type_Native,
}

// Determines what API (if any) to use for printing formatted text to a terminal. Can be set to one of the following:
//  - Terminal_Output_Type_None:   No terminal output is used. Terminal output functions don't get compiled in when this flag is used.
//  - Terminal_Output_Type_cstdio: Uses fprintf from the C runtime for terminal output. This is the default.
//  - Terminal_Output_Type_Native: Use the native API provided by the underlying Operating System. If the OS is not supported, a compile error is reported.
enum Terminal_Output_Type          = Terminal_Output_Type_cstdio;

// When set to true, defines aliases for all public facing functions using snake_case naming style.
enum Enable_Snake_Case             = false;

//
// End of library configuration section.
//

private{
    import std.traits;
    import std.range : isInputRange, isInfinite;
    import std.math : abs, sgn;
}

// My original plan was to use a isOutputRange, but that one doesn't play nice when you enable the -betterC flag.
// enum bool canPutStrings(T) = isOutputRange!(T, char) && !isArray!T;
enum bool canPutStrings(T) =
    is(typeof(T.init) == T)
    && __traits(compiles, (T t) => t.put(char[1].init));

enum{
    Fmt_Flag_None       = 0,
    Fmt_Flag_Hex        = 1 << 0,
    Fmt_Flag_HexUp      = 1 << 1,
    Fmt_Flag_Comma      = 1 << 2,
    Fmt_Flag_ENot       = 1 << 3,
    Fmt_Flag_ENotUp     = 1 << 4,
    Fmt_Flag_Sign       = 1 << 5,
}

void format(Dest, Args...)(ref Dest dest, const(char)[] fmt, Args args)
if(canPutStrings!(Dest)){
    auto fmt_remaining = fmt;
    auto reader = fmt_remaining;
    while(reader.length > 0){
        if(reader[0] == '{'){
            dest.put(eat_text(fmt_remaining, reader.ptr - fmt_remaining.ptr));
            // Peek at the next character. If the character is another open-brace, then it's an escape sequence.
            if(reader.length > 1 && reader[1] == '{'){
                advance(reader, 2);
                advance(fmt_remaining);
            }
            else{
                auto fmt_begin = reader.ptr - fmt.ptr;
                auto fmt_end   = fmt_begin;
                while(reader.length > 0){
                    advance(reader);
                    if(reader[0] == '}'){
                        fmt_end = reader.ptr - fmt.ptr;
                        if(reader.length > 0)
                            advance(reader);
                        break;
                    }
                }

                fmt_remaining = fmt[fmt_end+1 .. $];
                auto fmt_command = fmt[fmt_begin+1 .. fmt_end];
                assert(fmt_command.length > 0, "ERR: Unexpected empty format specifier. Format specifier requires at least an integer argument index.");

                auto arg_index = eat_and_return_arg_index(fmt_command);
                assert(arg_index < args.length, "ERR: Format specifier argument index exceeds length of provided arguments.");
                auto format_info = getFormatInfo(fmt_command);

                // This code is to take a runtime value (the argument index) and use it to choose the
                // variadic argument corrosponding to the index.
                // This is based on the indexing strategy used by std.format.getNth(...) from Phobos.
                outer: switch(arg_index){
                    default: assert(0, "ERR: Unable to access variadic argument.");

                    static foreach(i, _; Args){
                        case i:
                            format_arg(dest, format_info, args[i]);
                            break outer;
                    }
                }
            }
        }
        else{
            advance(reader);
        }
    }

    if(fmt_remaining.length > 0){
        dest.put(fmt_remaining);
    }
}

struct BufferWriter{
    char[] buffer;
    size_t buffer_written;

    this(char[] b){
        buffer = b;
        buffer_written = 0;
    }

    void put(const(char)[] text){
        size_t bytes_left = buffer.length - buffer_written;
        static if(Assert_On_Truncation) assert(bytes_left > text.length);
        size_t to_write = text.length > bytes_left ? bytes_left : text.length;

        // Issue #1: Using memcpy rather than the built-in slice copy operator for compatability with LDC when using the -betterC switch.
        // https://github.com/tspike2k/djinnprint/issues/1
        static if(Use_memcpy){
            import core.stdc.string : memcpy;
            memcpy(&buffer[buffer_written], text.ptr, to_write);
        }
        else{
            buffer[buffer_written .. buffer_written + to_write] = text[0 .. to_write];
        }

        buffer_written += to_write;
        buffer[buffer_written >= buffer.length ? $-1 : buffer_written] = '\0';
    }
}

char[] format(Args...)(char[] buffer, const(char)[] fmt, Args args){
    auto writer = BufferWriter(buffer);
    format(writer, fmt, args);
    return writer.buffer[0 .. writer.buffer_written];
}

FormatInfo getFormatInfo(const(char)[] format_info)
{
    FormatInfo result;

    auto reader = format_info;
    while(reader.length > 0){
        switch(reader[0]){
            default:
                // TODO: Log unrecognized format specifiers? Assert on unrecognized
                advance(reader);
                break;

            case 'x':
                result.flags |= Fmt_Flag_Hex;
                advance(reader);
                result.leadingZeroes = cast(ubyte)stringToUint(eat_digits(reader));
                break;

            case 'X':
                result.flags |= Fmt_Flag_HexUp;
                advance(reader);
                result.leadingZeroes = cast(ubyte)stringToUint(eat_digits(reader));
                break;

            case 'e':
                result.flags |= Fmt_Flag_ENot;
                advance(reader);
                break;

            case 'E':
                result.flags |= Fmt_Flag_ENotUp;
                advance(reader);
                break;

            case ',':
                result.flags |= Fmt_Flag_Comma;
                advance(reader);
                break;

            case '+':
                result.flags |= Fmt_Flag_Sign;
                advance(reader);
                break;

            case 'p':
                advance(reader);
                assert(reader.length > 0 && is_digit(reader[0]), "Number expected after precision token (p) in format specifier.");
                result.precision = cast(ubyte)stringToUint(eat_digits(reader));
                break;
        }
    }

    return result;
}

//
// Functions for printing to the terminal
//
static if(Terminal_Output_Type != Terminal_Output_Type_None){
    static if(Terminal_Output_Type == Terminal_Output_Type_cstdio){
        private import core.stdc.stdio : FILE, stdout, stderr, fprintf;
        private alias FileHandle = FILE*;
        private alias std_out_handle = stdout;
        private alias std_err_handle = stderr;

        private void term_write(FileHandle file, const(char)[] text){
            fprintf(file, "%.*s", cast(int)text.length, text.ptr);
        }
    }
    else static if(Terminal_Output_Type == Terminal_Output_Type_Native){
        version(Posix){
            private alias File_Handle = int;
            private enum int std_out_handle = 1;
            private enum int std_err_handle = 2;

            private void term_write(FileHandle file, const(char)[] text){

            }
        }
        else{
            static assert(0, "Unsupported platform for terminal output. Consider using Terminal_Output_Type_cstdio or Terminal_Output_Type_None instead.");
        }
    }

    private struct TermWriter{
        FileHandle file;

        void put(const(char)[] text){
            term_write(file, text);
        }
    }

    void formatOut(Args...)(const(char)[] fmt, Args args){
        auto writer = TermWriter(std_out_handle);
        format(writer, fmt, args);
    }

    void formatErr(Args...)(const(char)[] fmt, Args args){
        auto writer = TermWriter(std_err_handle);
        format(writer, fmt, args);
    }

    void printOut(Args...)(const(char)[] s){
        auto writer = TermWriter(std_out_handle);
        writer.put(s);
    }

    void printErr(Args...)(const(char)[] s){
        auto writer = TermWriter(std_err_handle);
        writer.put(s);
    }
}

////
//
// Utility functions
//
////

uint stringToUint(const(char)[] str){
    uint result = 0;
    uint n = 0;
    foreach_reverse(ref c; str)
    {
        result += (c - '0') * (10 ^^ n);
        n++;
    }
    return result;
}

char[] intToString(T)(ref char[30] buffer, T num, uint flags = 0, uint leadingZeroes = 0)
if(isIntegral!T)
{
    Unqual!T n = num;

    static if (isSigned!T)
    {
        // TODO; Does this play well with displaying negative numbers in hex? Is it NORMAL to display negative numbers using hex?
        import std.math : abs, sgn;
        T sign = cast(T)sgn(n);
        n = abs(n); // NOTE: Strip off the sign to prevent the mod operator from giving us a negative array index.
    }

    ubyte base = (flags & Fmt_Flag_Hex) || (flags & Fmt_Flag_HexUp) ? 16 : 10;
    auto intToCharTable = (flags & Fmt_Flag_HexUp) ? intToCharTableUpper[] : intToCharTableLower[];

    size_t bufferFill = buffer.length;
    size_t place = bufferFill;
    size_t loops = 0;
    while(true)
    {
        if(place == 0) break;
        place--;
        loops++;

        auto c = intToCharTable[cast(size_t)(n % base)];
        buffer[place] = c;
        n /= base;

        /+
        if ((flags & Fmt_Flag_) && base == 10 && loops % 3 == 0 && n != 0)
        {
            buffer[--place] = ',';
        }+/

        if(n == 0)
        {
            {
                auto spaceWritten = buffer.length - place;

                if(leadingZeroes > spaceWritten)
                {
                    auto zeroesToWrite = leadingZeroes - spaceWritten;
                    buffer[place - zeroesToWrite .. place] = '0';
                    place -= zeroesToWrite;
                }
            }


            // TODO: printf doesn't prepend hex values with 0x. Should we actually do this? If the user wants that, they can do it trivially enough.
            // Perhaps this should be it's own flag? Or maybe a library customization option?
            if(base == 16)
            {
                buffer[--place] = 'x';
                buffer[--place] = '0';
            }

            static if (isSigned!T)
            {
                if (sign < 0)
                {
                    buffer[--place] = '-';
                }
                /+
                else if(flags & Fmt_Flag_Sign)
                {
                    buffer[--place] = '+';
                }+/
            }
            else
            {
                if(flags & Fmt_Flag_Sign)
                {
                    buffer[--place] = '+';
                }
            }

            bufferFill = place;
            break;
        }
    }

    return buffer[bufferFill .. $];
}

////
//
// Aliases
//
////

static if(Enable_Snake_Case){
    static if(Terminal_Output_Type != Terminal_Output_Type_None){
        alias print_out  = printOut;
        alias print_err  = printErr;
        alias format_out = formatOut;
        alias format_err = formatErr;
    }
    alias string_to_uint  = stringToUint;
    alias int_to_string   = intToString;
    alias get_format_info = getFormatInfo;
}

////
//
// Internals
//
////

private:

immutable __gshared char[] intToCharTableLower = "0123456789abcdefxp";
immutable __gshared char[] intToCharTableUpper = "0123456789ABCDEFXP";

alias ArrayTarget(T : U[], U) = U;
enum bool isCString(T) = is(Unqual!(PointerTarget!T) == char);
enum bool isCharArray(T) = (isArray!T || isDynamicArray!T) && is(Unqual!(ArrayTarget!T) == char);
enum bool shouldUseQuotes(T) = isCharArray!T || isCString!T;

// TODO: I wish I could think of a better way to test for this, but it does work.
template getHighestOffsetUntil(T, uint index_max){
    enum getHighestOffsetUntil = (){
        size_t result = 0;
        static foreach(i; 0 .. T.tupleof.length){
            if(i < index_max){
                result = result < T.tupleof[i].offsetof ? T.tupleof[i].offsetof : result;
            }
        }
        return result;
    }();
}

template doesMemberOverlap(T, uint i){
    enum doesMemberOverlap = i > 0 && T.tupleof[i].offsetof <= getHighestOffsetUntil!(T, i);
}

struct FormatInfo
{
    uint  flags;
    ubyte precision;
    ubyte leadingZeroes;
}

size_t strlen(const(char)* s){
    size_t result = 0;
    while(s[result] != '\0'){
        result++;
    }
    return result;
}

void advance(ref const(char)[] text, size_t count = 1){
    text = text[count .. $];
}

inout(char)[] eat_text(ref inout(char)[] text, size_t count){
    auto result = text[0 .. count];
    text = text[count .. $];
    return result;
}

uint eat_and_return_arg_index(ref inout(char)[] commandStr)
{
    assert(is_digit(commandStr[0]), "Format specifier must start with numeric argument index.");
    uint argIndex = 0;
    uint end = 0;
    while(end < commandStr.length && is_digit(commandStr[end]))
    {
        end++;
    }
    argIndex = stringToUint(commandStr[0 .. end]);

    commandStr = commandStr[end .. $];
    return argIndex;
}

bool is_digit(char c){
    return (c >= '0') && (c <= '9');
}

inout(char)[] eat_digits(ref inout(char)[] reader){
    auto result = reader;
    foreach(i, c; reader){
        if(!is_digit(c)){
            result = reader[0 .. i];
            reader = reader[i .. $];
            break;
        }
    }
    return result;
}

void format_arg(Type, Dest)(ref Dest dest, in FormatInfo format_info, ref Type t)
if(canPutStrings!(Dest)){
    alias T = Unqual!Type;
    static if(is(T == enum)){
        outer: final switch(t){
            static foreach (i, member; EnumMembers!T){
                case EnumMembers!T[i]:{
                    dest.put(__traits(identifier, EnumMembers!T[i]));
                } break outer;
            }
        }
    }
    else static if(is(T == bool)){
        dest.put(t ? "true" : "false");
    }
    else static if (isIntegral!T){
        char[30] intBuffer;
        auto result = intToString(intBuffer[], t, format_info.flags, format_info.leadingZeroes);
        dest.put(result);
    }
    else static if (is(T == char)){
        char[1] temp = t;
        dest.put(temp);
    }
    else static if(isCharArray!T){
        dest.put(t);
    }
    else static if(isCString!T){
        dest.put(t[0 .. strlen(t)]);
    }
    else static if (is(T == float) || is(T == double)){
        char[512] buffer;
        auto result = doubleToString(buffer, t, format_info.flags, format_info.precision == 0 ? 6 : format_info.precision, format_info.leadingZeroes);
        dest.put(result);
    }
    else static if(isInputRange!T){
        static assert(!isInfinite!T);

        dest.put("[");
        size_t i = 0;
        foreach(ref v; t)
        {
            if(i > 0) dest.put(", ");
            format_arg(dest, format_info, v);
            i++;
        }
        dest.put("]");
    }
    else static if(is(T == struct) || is(T == union)){
        static if(__traits(compiles, t.toString(dest))){
            t.toString(dest);
        }
        else static if(__traits(compiles, t.to_string(dest))){
            t.to_string(dest);
        }
        else{
            static if(Output_Struct_And_Union_Names) dest.put(__traits(identifier, T));
            dest.put("(");

            foreach(i, ref member; t.tupleof){
                static if(!doesMemberOverlap!(T, i)){
                    static if(i > 0) dest.put(", ");
                    enum use_quotes = shouldUseQuotes!(typeof(member));

                    static if(use_quotes) dest.put(`"`);
                    format_arg(dest, format_info, member);
                    static if(use_quotes) dest.put(`"`);
                }
            }
            dest.put(")");
        }
    }
    else static if(isArray!T || isDynamicArray!T){
        dest.put("[");
        foreach(i; 0 .. t.length){
            format_arg(dest, format_info, t[i]);
            if (i < t.length - 1){
                dest.put(", ");
            }
        }
        dest.put("]");
    }
    else static if (isPointer!T){
        char[30] intBuffer;
        auto result = intToString(intBuffer, cast(size_t)t, Fmt_Flag_Hex);
        dest.put(result);
    }
    else static if(is(T == class)){
        static if(__traits(compiles, t.toString(dest))){
            t.toString(dest);
        }
        else static if(__traits(compiles, t.to_string(dest))){
            t.to_string(dest);
        }
        else{
            pragma(msg, "ERR: class " ~ T.stringof ~ " does not supply toString or to_string method. Unable to format.");
        }
    }
    else{
        pragma(msg, "ERR in print.format_arg(...): Unhandled type " ~ T.stringof);
        static assert(0);
    }
}

////
//
// Floating point to string conversion code based on stb_sprintf.
// Original author Jeff Roberts. Further developed by Sean Barrett and many others.
// https://github.com/nothings/stb/
// License: Public domain
//
////
public char[] doubleToString(return ref char[512] buf, double fv, uint flags = 0, ubyte precision = 6, ubyte leadingZeroes = 0)
{
    //char const *h;
    char[512] num = 0;
    stbsp__uint32 l, n, cs; // l == length
    stbsp__uint64 n64;

    stbsp__int32 fw, pr, tz; // pr == precision?
    stbsp__uint32 fl;

    stbsp__int32 dp; // decimal position

    char[8] tail = 0;
    char[8] lead = 0;
    char* s;
    char *sn;
    char* bf = buf.ptr;

    if(flags & Fmt_Flag_Comma) fl |= STBSP__TRIPLET_COMMA;
    if(flags & Fmt_Flag_Sign)  fl |= STBSP__LEADINGPLUS;
    fl |= STBSP__LEADINGZERO;

    pr = precision;
    fw = leadingZeroes;

    void stbsp__cb_buf_clamp(T, U)(ref T cl, ref U v) {
        pragma(inline, true);
         cl = v;
         /*if (callback) {                                \
            int lg = STB_SPRINTF_MIN - (int)(bf - buf); \
            if (cl > lg)                                \
               cl = lg;                                 \
         }*/
    }

    void stbsp__chk_cb_buf(size_t bytes){
        /*if (callback) {               \
           stbsp__chk_cb_bufL(bytes); \
        } */
    }

    if((flags & Fmt_Flag_Hex) || (flags & Fmt_Flag_HexUp)) // NOTE: Hex float formatting
    {
        auto h = (flags & Fmt_Flag_HexUp) ? intToCharTableUpper : intToCharTableLower;

        // read the double into a string
        if (stbsp__real_to_parts(cast(stbsp__int64*)&n64, &dp, fv))
            fl |= STBSP__NEGATIVE;

        s = num.ptr + 64;

        stbsp__lead_sign(fl, lead.ptr);

        if (dp == -1023)
            dp = (n64) ? -1022 : 0;
        else
            n64 |= ((cast(stbsp__uint64)1) << 52);
        n64 <<= (64 - 56);
        if (pr < 15)
            n64 += (((cast(stbsp__uint64)8) << 56) >> (pr * 4));
        // add leading chars

        lead[1 + lead[0]] = '0';
        lead[2 + lead[0]] = 'x';
        lead[0] += 2;

        *s++ = h[(n64 >> 60) & 15];
        n64 <<= 4;
        if (pr)
            *s++ = stbsp__period;
        sn = s;

        // print the bits
        n = pr;
        if (n > 13)
            n = 13;
        if (pr > cast(stbsp__int32)n)
            tz = pr - n;
        pr = 0;
        while (n--) {
            *s++ = h[(n64 >> 60) & 15];
            n64 <<= 4;
        }

        // print the expo
        tail[1] = h[17];
        if (dp < 0) {
            tail[2] = '-';
            dp = -dp;
        } else
            tail[2] = '+';
        n = (dp >= 1000) ? 6 : ((dp >= 100) ? 5 : ((dp >= 10) ? 4 : 3));
        tail[0] = cast(char)n;
        for (;;) {
            tail[n] = '0' + dp % 10;
            if (n <= 3)
               break;
            --n;
            dp /= 10;
        }

        dp = cast(int)(s - sn);
        l = cast(int)(s - (num.ptr + 64));
        s = num.ptr + 64;
        cs = 1 + (3 << 24);
        goto scopy;
    }
    else if((flags & Fmt_Flag_ENot) || (flags & Fmt_Flag_ENotUp)) // NOTE: Scientific notation
    {
        auto h = (flags & Fmt_Flag_ENotUp) ? intToCharTableUpper : intToCharTableLower;
        // read the double into a string
        if (stbsp__real_to_str(&sn, &l, num.ptr, &dp, fv, pr | 0x80000000))
            fl |= STBSP__NEGATIVE;
doexpfromg:
        tail[0] = 0;
        stbsp__lead_sign(fl, lead.ptr);
        if (dp == STBSP__SPECIAL) {
            s = cast(char*)sn;
            cs = 0;
            pr = 0;
            goto scopy;
        }
        s = num.ptr + 64;
        // handle leading chars
        *s++ = sn[0];

        if (pr)
            *s++ = stbsp__period;

        // handle after decimal
        if ((l - 1) > cast(stbsp__uint32)pr)
            l = pr + 1;
        for (n = 1; n < l; n++)
            *s++ = sn[n];
        // trailing zeros
        tz = pr - (l - 1);
        pr = 0;
        // dump expo
        tail[1] = h[0xe];
        dp -= 1;
        if (dp < 0) {
            tail[2] = '-';
            dp = -dp;
        } else
            tail[2] = '+';
        n = (dp >= 100) ? 5 : 4;
        tail[0] = cast(char)n;
        for (;;) {
            tail[n] = '0' + dp % 10;
            if (n <= 3)
               break;
            --n;
            dp /= 10;
        }
        cs = 1 + (3 << 24); // how many tens
        goto flt_lead;
    }
    else // NOTE: Regular float formatting
    {
        // read the double into a string
        if (stbsp__real_to_str(&sn, &l, num.ptr, &dp, fv, pr))
            fl |= STBSP__NEGATIVE;

        stbsp__lead_sign(fl, lead.ptr);

        if (dp == STBSP__SPECIAL) {
            s = cast(char *)sn;
            cs = 0;
            pr = 0;
            goto scopy;
        }

        s = num.ptr + 64;

        // handle the three decimal varieties
        if (dp <= 0) {
            stbsp__int32 i;
            // handle 0.000*000xxxx
            *s++ = '0';
            if (pr)
               *s++ = stbsp__period;
            n = -dp;
            if (cast(stbsp__int32)n > pr)
               n = pr;
            i = n;
            while (i) {
               if (((cast(stbsp__uintptr)s) & 3) == 0)
                  break;
               *s++ = '0';
               --i;
            }
            while (i >= 4) {
               *(cast(stbsp__uint32 *)s) = 0x30303030;
               s += 4;
               i -= 4;
            }
            while (i) {
               *s++ = '0';
               --i;
            }
            if (cast(stbsp__int32)(l + n) > pr)
               l = pr - n;
            i = l;
            while (i) {
               *s++ = *sn++;
               --i;
            }
            tz = pr - (n + l);
            cs = 1 + (3 << 24); // how many tens did we write (for commas below)
        } else {
            cs = (fl & STBSP__TRIPLET_COMMA) ? ((600 - cast(stbsp__uint32)dp) % 3) : 0;
            if (cast(stbsp__uint32)dp >= l) {
               // handle xxxx000*000.0
               n = 0;
               for (;;) {
                  if ((fl & STBSP__TRIPLET_COMMA) && (++cs == 4)) {
                     cs = 0;
                     *s++ = stbsp__comma;
                  } else {
                     *s++ = sn[n];
                     ++n;
                     if (n >= l)
                        break;
                  }
               }
               if (n < cast(stbsp__uint32)dp) {
                  n = dp - n;
                  if ((fl & STBSP__TRIPLET_COMMA) == 0) {
                     while (n) {
                        if (((cast(stbsp__uintptr)s) & 3) == 0)
                           break;
                        *s++ = '0';
                        --n;
                     }
                     while (n >= 4) {
                        *(cast(stbsp__uint32 *)s) = 0x30303030;
                        s += 4;
                        n -= 4;
                     }
                  }
                  while (n) {
                     if ((fl & STBSP__TRIPLET_COMMA) && (++cs == 4)) {
                        cs = 0;
                        *s++ = stbsp__comma;
                     } else {
                        *s++ = '0';
                        --n;
                     }
                  }
               }
               cs = cast(int)(s - (num.ptr + 64)) + (3 << 24); // cs is how many tens
               if (pr) {
                  *s++ = stbsp__period;
                  tz = pr;
               }
            } else {
               // handle xxxxx.xxxx000*000
               n = 0;
               for (;;) {
                  if ((fl & STBSP__TRIPLET_COMMA) && (++cs == 4)) {
                     cs = 0;
                     *s++ = stbsp__comma;
                  } else {
                     *s++ = sn[n];
                     ++n;
                     if (n >= cast(stbsp__uint32)dp)
                        break;
                  }
               }
               cs = cast(int)(s - (num.ptr + 64)) + (3 << 24); // cs is how many tens
               if (pr)
                  *s++ = stbsp__period;
               if ((l - dp) > cast(stbsp__uint32)pr)
                  l = pr + dp;
               while (n < l) {
                  *s++ = sn[n];
                  ++n;
               }
               tz = pr - (l - dp);
            }
        }
        pr = 0;

flt_lead:
        // get the length that we copied
        l = cast(stbsp__uint32)(s - (num.ptr + 64));
        s = num.ptr + 64;
        goto scopy;
    }

scopy:
        // get fw=leading/trailing space, pr=leading zeros
        if (pr < cast(stbsp__int32)l)
            pr = l;
        //n = pr + lead[0] + tail[0] + tz; // Original line
        n = pr + tail[0] + tz; // NOTE: For our lib, we want to ignore the leading when calculating the trailing zeroes
        if (fw < cast(stbsp__int32)n)
            fw = n;
        fw -= n;
        pr -= l;

        // handle right justify and leading zeros
        if ((fl & STBSP__LEFTJUST) == 0) {
            if (fl & STBSP__LEADINGZERO) // if leading zeros, everything is in pr
            {
               pr = (fw > pr) ? fw : pr;
               fw = 0;
            } else {
               fl &= ~STBSP__TRIPLET_COMMA; // if no leading zeros, then no commas
            }
        }

        // copy the spaces and/or zeros
        if (fw + pr) {
            stbsp__int32 i;
            stbsp__uint32 c;

            // copy leading spaces (or when doing %8.4d stuff)
            if ((fl & STBSP__LEFTJUST) == 0)
               while (fw > 0) {
                  stbsp__cb_buf_clamp(i, fw);
                  fw -= i;
                  while (i) {
                     if (((cast(stbsp__uintptr)bf) & 3) == 0)
                        break;
                     *bf++ = ' ';
                     --i;
                  }
                  while (i >= 4) {
                     *(cast(stbsp__uint32 *)bf) = 0x20202020;
                     bf += 4;
                     i -= 4;
                  }
                  while (i) {
                     *bf++ = ' ';
                     --i;
                  }
                  stbsp__chk_cb_buf(1);
               }

            // copy leader
            sn = lead.ptr + 1;
            while (lead[0]) {
               stbsp__cb_buf_clamp(i, lead[0]);
               lead[0] -= cast(char)i;
               while (i) {
                  *bf++ = *sn++;
                  --i;
               }
               stbsp__chk_cb_buf(1);
            }

            // copy leading zeros
            c = cs >> 24;
            cs &= 0xffffff;
            cs = (fl & STBSP__TRIPLET_COMMA) ? (cast(stbsp__uint32)(c - ((pr + cs) % (c + 1)))) : 0;
            while (pr > 0) {
               stbsp__cb_buf_clamp(i, pr);
               pr -= i;
               if ((fl & STBSP__TRIPLET_COMMA) == 0) {
                  while (i) {
                     if (((cast(stbsp__uintptr)bf) & 3) == 0)
                        break;
                     *bf++ = '0';
                     --i;
                  }
                  while (i >= 4) {
                     *(cast(stbsp__uint32 *)bf) = 0x30303030;
                     bf += 4;
                     i -= 4;
                  }
               }
               while (i) {
                  if ((fl & STBSP__TRIPLET_COMMA) && (cs++ == c)) {
                     cs = 0;
                     *bf++ = stbsp__comma;
                  } else
                     *bf++ = '0';
                  --i;
               }
               stbsp__chk_cb_buf(1);
            }
        }

        // copy leader if there is still one
        sn = lead.ptr + 1;
        while (lead[0]) {
            stbsp__int32 i;
            stbsp__cb_buf_clamp(i, lead[0]);
            lead[0] -= cast(char)i;
            while (i) {
               *bf++ = *sn++;
               --i;
            }
            stbsp__chk_cb_buf(1);
        }

        // copy the string
        n = l;
        while (n) {
            stbsp__int32 i;
            stbsp__cb_buf_clamp(i, n);
            n -= i;
    /+
            STBSP__UNALIGNED(while (i >= 4) {
               *(stbsp__uint32 volatile *)bf = *(stbsp__uint32 volatile *)s;
               bf += 4;
               s += 4;
               i -= 4;
            })
            +/
            while (i) {
               *bf++ = *s++;
               --i;
            }
            stbsp__chk_cb_buf(1);
        }

        // copy trailing zeros
        while (tz) {
            stbsp__int32 i;
            stbsp__cb_buf_clamp(i, tz);
            tz -= i;
            while (i) {
               if (((cast(stbsp__uintptr)bf) & 3) == 0)
                  break;
               *bf++ = '0';
               --i;
            }
            while (i >= 4) {
               *(cast(stbsp__uint32 *)bf) = 0x30303030;
               bf += 4;
               i -= 4;
            }
            while (i) {
               *bf++ = '0';
               --i;
            }
            stbsp__chk_cb_buf(1);
        }

        // copy tail if there is one
        sn = tail.ptr + 1;
        while (tail[0]) {
            stbsp__int32 i;
            stbsp__cb_buf_clamp(i, tail[0]);
            tail[0] -= cast(char)i;
            while (i) {
               *bf++ = *sn++;
               --i;
            }
            stbsp__chk_cb_buf(1);
         }

         // handle the left justify
        if (fl & STBSP__LEFTJUST)
            if (fw > 0) {
               while (fw) {
                  stbsp__int32 i;
                  stbsp__cb_buf_clamp(i, fw);
                  fw -= i;
                  while (i) {
                     if (((cast(stbsp__uintptr)bf) & 3) == 0)
                        break;
                     *bf++ = ' ';
                     --i;
                  }
                  while (i >= 4) {
                     *(cast(stbsp__uint32 *)bf) = 0x20202020;
                     bf += 4;
                     i -= 4;
                  }
                  while (i--)
                     *bf++ = ' ';
                  stbsp__chk_cb_buf(1);
               }
            }

    return buf[0 .. bf - buf.ptr];
}

void stbsp__lead_sign(stbsp__uint32 fl, char *sign)
{
   sign[0] = 0;
   if (fl & STBSP__NEGATIVE) {
      sign[0] = 1;
      sign[1] = '-';
   } else if (fl & STBSP__LEADINGSPACE) {
      sign[0] = 1;
      sign[1] = ' ';
   } else if (fl & STBSP__LEADINGPLUS) {
      sign[0] = 1;
      sign[1] = '+';
   }
}

// get float info
stbsp__int32 stbsp__real_to_parts(stbsp__int64 *bits, stbsp__int32 *expo, double value)
{
   double d;
   stbsp__int64 b = 0;

   // load value and round at the frac_digits
   d = value;

   STBSP__COPYFP(b, d);

   *bits = b & (((cast(stbsp__uint64)1) << 52) - 1);
   *expo = cast(stbsp__int32)(((b >> 52) & 2047) - 1023);

   return cast(stbsp__int32)(cast(stbsp__uint64) b >> 63);
}

alias stbsp__uint16 = ushort;
alias stbsp__int32 = int;
alias stbsp__uint32 = uint;
alias stbsp__int64 = long;
alias stbsp__uint64 = ulong;
alias stbsp__uintptr = size_t;

enum STBSP__LEFTJUST = 1;
enum STBSP__LEADINGPLUS = 2;
enum STBSP__LEADINGSPACE = 4;
enum STBSP__LEADING_0X = 8;
enum STBSP__LEADINGZERO = 16;
enum STBSP__INTMAX = 32;
enum STBSP__TRIPLET_COMMA = 64;
enum STBSP__NEGATIVE = 128;
enum STBSP__METRIC_SUFFIX = 256;
enum STBSP__HALFWIDTH = 512;
enum STBSP__METRIC_NOSPACE = 1024;
enum STBSP__METRIC_1024 = 2048;
enum STBSP__METRIC_JEDEC = 4096;
enum STBSP__SPECIAL = 0x7000;

immutable char stbsp__period = '.';
immutable char stbsp__comma = ',';

immutable __gshared double[23] stbsp__bot = [
   1e+000, 1e+001, 1e+002, 1e+003, 1e+004, 1e+005, 1e+006, 1e+007, 1e+008, 1e+009, 1e+010, 1e+011,
   1e+012, 1e+013, 1e+014, 1e+015, 1e+016, 1e+017, 1e+018, 1e+019, 1e+020, 1e+021, 1e+022
];

immutable __gshared double[22] stbsp__negbot = [
   1e-001, 1e-002, 1e-003, 1e-004, 1e-005, 1e-006, 1e-007, 1e-008, 1e-009, 1e-010, 1e-011,
   1e-012, 1e-013, 1e-014, 1e-015, 1e-016, 1e-017, 1e-018, 1e-019, 1e-020, 1e-021, 1e-022
];

immutable __gshared double[22] stbsp__negboterr = [
   -5.551115123125783e-018,  -2.0816681711721684e-019, -2.0816681711721686e-020, -4.7921736023859299e-021, -8.1803053914031305e-022, 4.5251888174113741e-023,
   4.5251888174113739e-024,  -2.0922560830128471e-025, -6.2281591457779853e-026, -3.6432197315497743e-027, 6.0503030718060191e-028,  2.0113352370744385e-029,
   -3.0373745563400371e-030, 1.1806906454401013e-032,  -7.7705399876661076e-032, 2.0902213275965398e-033,  -7.1542424054621921e-034, -7.1542424054621926e-035,
   2.4754073164739869e-036,  5.4846728545790429e-037,  9.2462547772103625e-038,  -4.8596774326570872e-039
];

immutable __gshared double[13] stbsp__top = [
   1e+023, 1e+046, 1e+069, 1e+092, 1e+115, 1e+138, 1e+161, 1e+184, 1e+207, 1e+230, 1e+253, 1e+276, 1e+299
];

immutable __gshared double[13] stbsp__negtop = [
   1e-023, 1e-046, 1e-069, 1e-092, 1e-115, 1e-138, 1e-161, 1e-184, 1e-207, 1e-230, 1e-253, 1e-276, 1e-299
];

immutable __gshared double[13] stbsp__toperr = [
   8388608,
   6.8601809640529717e+028,
   -7.253143638152921e+052,
   -4.3377296974619174e+075,
   -1.5559416129466825e+098,
   -3.2841562489204913e+121,
   -3.7745893248228135e+144,
   -1.7356668416969134e+167,
   -3.8893577551088374e+190,
   -9.9566444326005119e+213,
   6.3641293062232429e+236,
   -5.2069140800249813e+259,
   -5.2504760255204387e+282
];

immutable double[13] stbsp__negtoperr = [
   3.9565301985100693e-040,  -2.299904345391321e-063,  3.6506201437945798e-086,  1.1875228833981544e-109,
   -5.0644902316928607e-132, -6.7156837247865426e-155, -2.812077463003139e-178,  -5.7778912386589953e-201,
   7.4997100559334532e-224,  -4.6439668915134491e-247, -6.3691100762962136e-270, -9.436808465446358e-293,
   8.0970921678014997e-317L
];

immutable __gshared stbsp__uint64[20] stbsp__powten = [
   1,
   10,
   100,
   1000,
   10000,
   100000,
   1000000,
   10000000,
   100000000,
   1000000000,
   10000000000UL,
   100000000000UL,
   1000000000000UL,
   10000000000000UL,
   100000000000000UL,
   1000000000000000UL,
   10000000000000000UL,
   100000000000000000UL,
   1000000000000000000UL,
   10000000000000000000UL
];

enum stbsp__uint64 stbsp__tento19th = 1000000000000000000;

struct stbsp__digitpair_t
{
   short temp; // force next field to be 2-byte aligned
   char[201] pair;
}

const stbsp__digitpair_t stbsp__digitpair =
stbsp__digitpair_t(
  0,
   "00010203040506070809101112131415161718192021222324" ~
   "25262728293031323334353637383940414243444546474849" ~
   "50515253545556575859606162636465666768697071727374" ~
   "75767778798081828384858687888990919293949596979899"
);

void stbsp__raise_to_power10(double *ohi, double *olo, double d, stbsp__int32 power) // power can be -323 to +350
{
   double ph, pl;
   if ((power >= 0) && (power <= 22)) {
      stbsp__ddmulthi(ph, pl, d, stbsp__bot[power]);
   } else {
      stbsp__int32 e, et, eb;
      double p2h, p2l;

      e = power;
      if (power < 0)
         e = -e;
      et = (e * 0x2c9) >> 14; /* %23 */
      if (et > 13)
         et = 13;
      eb = e - (et * 23);

      ph = d;
      pl = 0.0;
      if (power < 0) {
         if (eb) {
            --eb;
            stbsp__ddmulthi(ph, pl, d, stbsp__negbot[eb]);
            stbsp__ddmultlos(ph, pl, d, stbsp__negboterr[eb]);
         }
         if (et) {
            stbsp__ddrenorm(ph, pl);
            --et;
            stbsp__ddmulthi(p2h, p2l, ph, stbsp__negtop[et]);
            stbsp__ddmultlo(p2h, p2l, ph, pl, stbsp__negtop[et], stbsp__negtoperr[et]);
            ph = p2h;
            pl = p2l;
         }
      } else {
         if (eb) {
            e = eb;
            if (eb > 22)
               eb = 22;
            e -= eb;
            stbsp__ddmulthi(ph, pl, d, stbsp__bot[eb]);
            if (e) {
               stbsp__ddrenorm(ph, pl);
               stbsp__ddmulthi(p2h, p2l, ph, stbsp__bot[e]);
               stbsp__ddmultlos(p2h, p2l, stbsp__bot[e], pl);
               ph = p2h;
               pl = p2l;
            }
         }
         if (et) {
            stbsp__ddrenorm(ph, pl);
            --et;
            stbsp__ddmulthi(p2h, p2l, ph, stbsp__top[et]);
            stbsp__ddmultlo(p2h, p2l, ph, pl, stbsp__top[et], stbsp__toperr[et]);
            ph = p2h;
            pl = p2l;
         }
      }
   }
   stbsp__ddrenorm(ph, pl);
   *ohi = ph;
   *olo = pl;
}


void STBSP__COPYFP(T, U)(ref T dest, in U src)
{
    pragma(inline, true);
    int cn = void;
    for(cn = 0; cn < 8; cn++)
        (cast(char*)&dest)[cn] = (cast(char*)&src)[cn];
}

void stbsp__ddmulthi(T)(ref T oh, ref T ol, ref T xh, const ref T yh)
{
    pragma(inline, true);
    double ahi = 0, alo, bhi = 0, blo;
    stbsp__int64 bt;
    oh = xh * yh;
    STBSP__COPYFP(bt, xh);
    bt &= ((~cast(stbsp__uint64)0) << 27);
    STBSP__COPYFP(ahi, bt);
    alo = xh - ahi;
    STBSP__COPYFP(bt, yh);
    bt &= ((~cast(stbsp__uint64)0) << 27);
    STBSP__COPYFP(bhi, bt);
    blo = yh - bhi;
    ol = ((ahi * bhi - oh) + ahi * blo + alo * bhi) + alo * blo;
}

void stbsp__ddmultlo(T)(ref T oh, ref T ol, ref T xh, ref T xl, const ref T yh, const ref T yl)
{
    pragma(inline, true);
    ol = ol + (xh * yl + xl * yh);
}

void stbsp__ddmultlos(T)(ref T oh, ref T ol, const ref T xh, const ref T yl)
{
    pragma(inline, true);
    ol = ol + (xh * yl);
}

void stbsp__ddtoS64(T, U)(ref T ob, const ref U xh, const ref U xl)
{
    pragma(inline, true);
    double ahi = 0, alo, vh, t;
    ob = cast(stbsp__int64)xh;
    vh = cast(double)ob;
    ahi = (xh - vh);
    t = (ahi - xh);
    alo = (xh - (ahi - t)) - (vh + t);
    ob += cast(stbsp__int64)(ahi + alo + xl);
}

void stbsp__ddrenorm(T)(ref T oh, ref T ol)
{
    pragma(inline, true);
    double s;
    s = oh + ol;
    ol = ol - (s - oh);
    oh = s;
}

// given a float value, returns the significant bits in bits, and the position of the
//   decimal point in decimal_pos.  +/-INF and NAN are specified by special values
//   returned in the decimal_pos parameter.
// frac_digits is absolute normally, but if you want from first significant digits (got %g and %e), or in 0x80000000
stbsp__int32 stbsp__real_to_str(char** start, stbsp__uint32* len, char* outp, stbsp__int32* decimal_pos, double value, stbsp__uint32 frac_digits)
{
   double d;
   stbsp__int64 bits = 0;
   stbsp__int32 expo, e, ng, tens;

   d = value;
   STBSP__COPYFP(bits, d);
   expo = cast(stbsp__int32)((bits >> 52) & 2047);
   ng = cast(stbsp__int32)(cast(stbsp__uint64)bits >> 63);
   if (ng)
      d = -d;

   if (expo == 2047) // is nan or inf?
   {
      *start = (bits & (((cast(stbsp__uint64)1) << 52) - 1)) ? cast(char*)"NaN" : cast(char*)"Inf";
      *decimal_pos = STBSP__SPECIAL;
      *len = 3;
      return ng;
   }

   if (expo == 0) // is zero or denormal
   {
      if ((cast(stbsp__uint64) bits << 1) == 0) // do zero
      {
         *decimal_pos = 1;
         *start = outp;
         outp[0] = '0';
         *len = 1;
         return ng;
      }
      // find the right expo for denormals
      {
         stbsp__int64 v = (cast(stbsp__uint64)1) << 51;
         while ((bits & v) == 0) {
            --expo;
            v >>= 1;
         }
      }
   }

   // find the decimal exponent as well as the decimal bits of the value
   {
      double ph, pl;

      // log10 estimate - very specifically tweaked to hit or undershoot by no more than 1 of log10 of all expos 1..2046
      tens = expo - 1023;
      tens = (tens < 0) ? ((tens * 617) / 2048) : (((tens * 1233) / 4096) + 1);

      // move the significant bits into position and stick them into an int
      stbsp__raise_to_power10(&ph, &pl, d, 18 - tens);

      // get full as much precision from double-double as possible
      stbsp__ddtoS64(bits, ph, pl);

      // check if we undershot
      if ((cast(stbsp__uint64)bits) >= stbsp__tento19th)
         ++tens;
   }

   // now do the rounding in integer land
   frac_digits = (frac_digits & 0x80000000) ? ((frac_digits & 0x7ffffff) + 1) : (tens + frac_digits);
   if ((frac_digits < 24)) {
      stbsp__uint32 dg = 1;
      if (cast(stbsp__uint64)bits >= stbsp__powten[9])
         dg = 10;
      while (cast(stbsp__uint64)bits >= stbsp__powten[dg]) {
         ++dg;
         if (dg == 20)
            goto noround;
      }
      if (frac_digits < dg) {
         stbsp__uint64 r;
         // add 0.5 at the right position and round
         e = dg - frac_digits;
         if (cast(stbsp__uint32)e >= 24)
            goto noround;
         r = stbsp__powten[e];
         bits = bits + (r / 2);
         if (cast(stbsp__uint64)bits >= stbsp__powten[dg])
            ++tens;
         bits /= r;
      }
   noround:;
   }

   // kill long trailing runs of zeros
   if (bits) {
      stbsp__uint32 n;
      for (;;) {
         if (bits <= 0xffffffff)
            break;
         if (bits % 1000)
            goto donez;
         bits /= 1000;
      }
      n = cast(stbsp__uint32)bits;
      while ((n % 1000) == 0)
         n /= 1000;
      bits = n;
   donez:;
   }

   // convert to string
   outp += 64;
   e = 0;
   for (;;) {
      stbsp__uint32 n;
      char *o = outp - 8;
      // do the conversion in chunks of U32s (avoid most 64-bit divides, worth it, constant denomiators be damned)
      if (bits >= 100000000) {
         n = cast(stbsp__uint32)(bits % 100000000);
         bits /= 100000000;
      } else {
         n = cast(stbsp__uint32)bits;
         bits = 0;
      }
      while (n) {
         outp -= 2;
         *cast(stbsp__uint16 *)outp = *cast(stbsp__uint16 *)&stbsp__digitpair.pair[(n % 100) * 2];
         n /= 100;
         e += 2;
      }
      if (bits == 0) {
         if ((e) && (outp[0] == '0')) {
            ++outp;
            --e;
         }
         break;
      }
      while (outp != o) {
         *--outp = '0';
         ++e;
      }
   }

   *decimal_pos = tens;
   *start = outp;
   *len = e;
   return ng;
}
