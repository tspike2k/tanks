/*
Copyright (c) 2020 tspike2k@github.com
Distributed under the Boost Software License, Version 1.0.
See accompanying file LICENSE_BOOST.txt or copy at http://www.boost.org/LICENSE_1_0.txt
*/

module meta;

public import std.traits;
public import std.meta;

alias ArrayTarget(T : T[]) = T;

bool isStructPacked(T)()
if(is(T == struct))
{
    size_t membersSize;
    static foreach(member; __traits(allMembers, T))
    {
        membersSize += mixin("T." ~ member ~ ".sizeof");
    }

    return membersSize == T.sizeof;
}

bool isUnionPacked(T)()
if(is(T == union))
{
    size_t maxMemberSize = 0;
    static foreach(i, member; T.tupleof)
    {
        static if(is(typeof(member) == struct))
            static assert(isStructPacked!(typeof(member)));
        else static if(is(typeof(member) == union))
            static assert(isUnionPacked!(typeof(member)));
        memberSize = memberSize > T.tupleof[i].sizeof ? memberSize : T.tupleof[i].sizeof;
    }

    return memberSize == T.sizeof;
}

version(none)
{
    bool testFunc(int a, int b);

    // NOTE: Incomplete function signature extractor. This is as far as I got.
    // See here for explination on how this template works:
    // https://forum.dlang.org/post/qdasbrihugkvpjpywhhg@forum.dlang.org
    template getFuncSig(alias f, string name)
    {
        import std.traits;
        enum getFuncSig = (ReturnType!f).stringof ~ " " ~ name ~ (Parameters!f).stringof;
    }
}

string enum_string(T)(T t)
if(is(T == enum))
{
    // NOTE: There is a way to do this for enums known at compile-time:
    // https://forum.dlang.org/thread/rjmp61$o70$1@digitalmars.com
    // We probably won't use this, though, as we want to be able to get the name at runtime.
    import std.traits : EnumMembers;

    alias members = EnumMembers!T;
    outer: final switch(t)
    {
        static foreach (i, member; members)
        {
            case member:
            {
                return __traits(identifier, members[i]);
            } break outer;
        }
    }

    // NOTE: It shouldn't be possible to ever reach this point.
    assert(0, "ERR: Unable to find enum member for type " ~ T.stringof ~ ".");
    return "";
}
