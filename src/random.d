/*
Authors:   tspike (github.com/tspike2k)
Copyright: Copyright (c) 2025
License:   Boost Software License 1.0 (https://www.boost.org/LICENSE_1_0.txt)
*/

// TODO: Make a generic RNG interface? We could use a strategy similar to our IsAllocator interface. The idea is, anything that implements randomU32 could work for
// an IsRNG template. Then any functions that need to generate random numbers could be templatized and to accept any RNG. Then, all the functions (randomBool,
// randomU32Between, ect) that are built on top of randomU32 could be templatized as well, allowing any random number generator to work off those.

module random;

private{
    import math : lerp;
}

struct Xorshift32{
    private:
    uint s;
}

void seed(Xorshift32* state, uint seed){
    assert(seed != 0);
    state.s = seed;
}

uint random_u32(Xorshift32* state){
    uint num = state.s;
    num ^= num << 13;
    num ^= num >> 17;
    num ^= num << 5;
    state.s = num;

    return num;
}

// TODO: Better distribution?
bool random_bool(Xorshift32* state){
    bool result = cast(bool)random_u32_between(state, 0, 2);
    return result;
}

// Returns [0, max)
/+ TODO: Do we need this one? It can be a bit confusing...
uint randomU32Between(Xorshift32* state, uint max){
    assert(max < uint.max);
    return randomU32(state) % max;
}+/

// Returns [min, max)
uint random_u32_between(Xorshift32* state, uint min, uint max){
    assert(min < max);
    assert(max < uint.max);
    // NOTE: For inclusive max, use the following:
    //randomU32(state) % (max - min + 1) + min;
    return (random_u32(state) % (max - min)) + min;
}

// Returns [0.0, 1.0]
float random_percent(Xorshift32* state){
    return (1.0f/ cast(float)uint.max) * cast(float)random_u32(state);
}

// Returns [-1.0, 1.0]
float random_normal(Xorshift32* state){
    return 2.0f * random_percent(state) - 1.0f;
}

// NOTE: in radians
float random_angle(Xorshift32* state){
    import math : PI;
    return random_percent(state)*2.0f*PI;
}

float random_sign(Xorshift32* state){
    // TODO: Determine if this is the best way to generate a sign value!
    enum delim = uint.max / 2;
    return random_u32(state) >= delim ? 1.0f : -1.0f;
}

// Returns [min, max]
float random_f32_between(Xorshift32* state, float min, float max){
    assert(min < max);

    // NOTE: The idea of lerping between min/max thanks to Handmade Hero.
    return lerp(min, max, random_percent(state));
}

version(none) void shuffle(T)(auto ref T[] items, Xorshift32* rng)
{
    // NOTE: The "modern method" of the Fisher–Yates shuffle algorithm
    foreach_reverse(i, ref item; items)
    {
        auto swapIndex = randomU32Between(rng, 0, cast(uint)i+1);
        auto temp = items[i];
        items[i] = items[swapIndex];
        items[swapIndex] = temp;
    }
}
