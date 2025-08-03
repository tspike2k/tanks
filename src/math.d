/*
Copyright (c) 2019 tspike2k@github.com
Distributed under the Boost Software License, Version 1.0.
See accompanying file LICENSE_BOOST.txt or copy at http://www.boost.org/LICENSE_1_0.txt
*/

module math;

public {
    import core.math : fabs, cos, sin;
    import core.stdc.math : floor, ceil, atan2f, tanf, powf;
    import std.math : abs, sgn, sqrt, signbit;
    import std.math.traits : isNaN;
    import meta : isIntegral, Unqual;
}

private {
    import memory;
}

alias sign  = sgn;
alias signf = sgn;
alias atan2 = atan2f;

enum PI  = 3.14159f;
enum TAU = PI*2.0f;

//
// Types
//

@nogc nothrow:

bool equals(float a, float b, float epsilon){
    bool result = a > b - epsilon && a < b + epsilon;
    return result;
}

union Vec2{
    struct{float x = 0.0f; float y = 0.0f;};
    struct{float s; float t;};
    struct{float u; float v;};
    float[2] c;

    nothrow @nogc this(float px, float py){
        // NOTE: This is just to get past an error when initializing when used with CTFE.
        // It's possible this is a compiler bug. If we stick with the default initializer,
        // the following code can't be compiled when used in a function called under CTFE:
        //      Vec2 extents = (max - min)*0.5f
        // This gives the following error when using ldc:
        //      `this.c[0]` is used before initialized
        // Using this particular explicit initializer fixes the issue.
        c[0] = px;
        c[1] = py;
    }

    mixin Vec_Ops;
}

union Vec3{
    struct{float x = 0.0f; float y = 0.0f; float z = 0.0f;};
    struct{float r; float g; float b;}
    struct{float s; float t;};
    struct{float u; float v;};
    float[3] c;

    mixin Vec_Ops;
}

union Vec4{
    struct{float x = 0.0f; float y = 0.0f; float z = 0.0f; float w = 0.0f;};
    struct{float r; float g; float b; float a;}
    struct{float h; float s; float v;}
    float[4] c;

    Vec3 xyz(){
        auto result = Vec3(x, y, z);
        return result;
    }

    mixin Vec_Ops;
}

Vec3 v2_to_v3(Vec2 v, float z){
    auto result = Vec3(v.x, v.y, z);
    return result;
}

mixin template Vec_Ops(){
    @nogc nothrow:

    alias This = typeof(this);
    inout ref inout(float) opIndex(size_t i){
        return c[i];
    }

    This opBinary(string op)(This rhs)
    if(op == "+" || op == "-" || op == "*"){
        This result = void;
        static foreach(i; 0 .. c.length){
            result.c[i] = mixin("c[i] " ~ op ~ " rhs.c[i]");
        }
        return result;
    }

    void opOpAssign(string op)(This rhs)
    if(op == "+" || op == "-" || op == "*"){
        static foreach(i; 0 .. c.length){
            mixin("c[i] " ~ op ~ "= rhs.c[i];");
        }
    }

    This opBinary(string op)(float rhs)
    if(op == "*"){
        This result = void;
        static foreach(i; 0 .. c.length){
            result.c[i] = mixin("c[i] " ~ op ~ "rhs");
        }
        return result;
    }

    void opOpAssign(string op)(float rhs)
    if(op == "*"){
        static foreach(i; 0 .. c.length){
            mixin("c[i] " ~ op ~ "= rhs;");
        }
    }

    auto opBinaryRight(string op, T)(T inp)
    {
        return this.opBinary!(op)(inp);
    }

    void serialize(SerializerT)(SerializerT* serializer)
    if(isSerializer!SerializerT){
        serializer.next(c[0 .. $]);
    }
}

Vec2 vec2_from_angle(float radians){
    auto c = cos(radians);
    auto s = sin(radians);
    auto result = Vec2(c, s);
    return result;
}

float get_angle(Vec2 v){
    auto result = atan2(v.y, v.x);
    return result;
}

Vec2 rotate(Vec2 v, float radians){
    auto c = cos(radians);
    auto s = sin(radians);
    auto result = Vec2(v.x*c - v.y*s, v.x*s + v.y*c);
    return result;
}

Vec3 polar_to_world(Vec3 polar, Vec3 target_pos){
    float phi   = polar.x * (PI/180.0f);
    float theta = (polar.y + 90.0f) * (PI/180.0f);

    float phi_sin = sin(phi);
    float phi_cos = cos(phi);
    float theta_sin = sin(theta);
    float theta_cos = cos(theta);

    Vec3 dir_to_camera = Vec3(theta_sin * phi_cos, theta_cos, theta_sin*phi_sin);
    Vec3 world_pos = target_pos + dir_to_camera*polar.z;
    return world_pos;
}

union Mat4{
    float[16]   c;
    float[4][4] m;

    Mat4 opBinary(string op)(auto ref Mat4 rhs)
    if(op == "*"){
        Mat4 result = void;

        static foreach(r; 0 .. 4){
            static foreach(c; 0 .. 4){
                result.m[r][c] = m[r][0] * rhs.m[0][c]
                               + m[r][1] * rhs.m[1][c]
                               + m[r][2] * rhs.m[2][c]
                               + m[r][3] * rhs.m[3][c];
            }
        }

        return result;
    }

    Vec4 opBinary(string op)(auto ref Vec4 rhs){
        Vec4 result = void;

        static foreach(r; 0 .. 4){
            static foreach(c; 0 .. 4){
                result.c[r] = m[r][0] * rhs.c[0]
                            + m[r][1] * rhs.c[1]
                            + m[r][2] * rhs.c[2]
                            + m[r][3] * rhs.c[3];
            }
        }

        return result;
    }
}

// Idea of bundling matrix with it's inverse thanks to Casey Muratori and Handmade Hero.
struct Mat4_Pair{
    Mat4 mat;
    Mat4 inv;
}

immutable Mat4 Mat4_Identity = Mat4([
    1.0f, 0.0f, 0.0f, 0.0f,
    0.0f, 1.0f, 0.0f, 0.0f,
    0.0f, 0.0f, 1.0f, 0.0f,
    0.0f, 0.0f, 0.0f, 1.0f]
);

Mat4 mat4_scale(Vec3 s){
    Mat4 result = Mat4([
        s.x,   0,    0,   0,
          0, s.y,    0,   0,
          0,   0,  s.z,   0,
          0,   0,    0,   1,
    ]);
    return result;
}

Mat4 mat4_translate(Vec3 offset){
    Mat4 result = Mat4([
        1.0f, 0.0f, 0.0f, offset.x,
        0.0f, 1.0f, 0.0f, offset.y,
        0.0f, 0.0f, 1.0f, offset.z,
        0.0f, 0.0f, 0.0f, 1.0f,
    ]);
    return result;
}

Mat4 transpose(Mat4 m){
    Mat4 result = void;
    static foreach(r; 0..4){
        static foreach(c; 0 ..4){
            result.m[r][c] = m.m[c][r];
        }
    }
    return result;
}

Mat4 mat4_rot_x(float angle_rad){
    float c = cos(angle_rad);
    float s = sin(angle_rad);

    auto result = Mat4([
        1.0f, 0.0f, 0.0f, 0.0f,
        0.0f, c,    -s,   0.0f,
        0.0f, s,     c,   0.0f,
        0.0f, 0.0f, 0.0f, 1.0f
    ]);
    return result;
}

Mat4 mat4_rot_y(float angle_rad){
    float c = cos(angle_rad);
    float s = sin(angle_rad);

    auto result = Mat4([
        c,    0.0f, s,    0.0f,
        0.0f, 1.0f, 0.0f, 0.0f,
        -s,   0.0f, c,    0.0f,
        0.0f, 0.0f, 0.0f, 1.0f
    ]);
    return result;
}

Mat4 mat4_rot_z(float angle_rad){
    float c = cos(angle_rad);
    float s = sin(angle_rad);

    Mat4 result = Mat4([
        c,   -s,    0.0f, 0.0f,
        s,    c,    0.0f, 0.0f,
        0.0f, 0.0f, 1.0f, 0.0f,
        0.0f, 0.0f, 0.0f, 1.0f
    ]);
    return result;
}

version(none) Mat4 make_inverse_lookat_matrix(Mat4 m){ // TODO: Where did we get this from?
    Mat4 result = void;

    result.c[0 + 0*4] = m.c[0 + 0*4];
    result.c[1 + 0*4] = m.c[0 + 1*4];
    result.c[2 + 0*4] = m.c[0 + 2*4];
    result.c[3 + 0*4] = 0.0f;

    result.c[0 + 1*4] = m.c[1 + 0*4];
    result.c[1 + 1*4] = m.c[1 + 1*4];
    result.c[2 + 1*4] = m.c[1 + 2*4];
    result.c[3 + 1*4] = 0.0f;

    result.c[0 + 2*4] = m.c[2 + 0*4];
    result.c[1 + 2*4] = m.c[2 + 1*4];
    result.c[2 + 2*4] = m.c[2 + 2*4];
    result.c[3 + 2*4] = 0.0f;

    result.c[0 + 3*4] = -(m.c[0 + 3*4] * result.c[0 + 0*4] + m.c[1 + 3*4] * result.c[0 + 1*4] + m.c[2 + 3*4] * result.c[0 + 2*4]);
    result.c[1 + 3*4] = -(m.c[0 + 3*4] * result.c[1 + 0*4] + m.c[1 + 3*4] * result.c[1 + 1*4] + m.c[2 + 3*4] * result.c[1 + 2*4]);
    result.c[2 + 3*4] = -(m.c[0 + 3*4] * result.c[2 + 0*4] + m.c[1 + 3*4] * result.c[2 + 1*4] + m.c[2 + 3*4] * result.c[2 + 2*4]);
    result.c[3 + 3*4] = 1.0f;

    return result;
}

struct Rect{
    Vec2 center;
    Vec2 extents;
}

Vec2 min(Vec2 a, Vec2 b){
    auto result = Vec2(min(a.x, b.x), min(a.y, b.y));
    return result;
}

Vec2 max(Vec2 a, Vec2 b){
    auto result = Vec2(max(a.x, b.x), max(a.y, b.y));
    return result;
}

Vec2 floor(Vec2 v){
    auto result = Vec2(floor(v.x), floor(v.y));
    return result;
}

Vec2 ceil(Vec2 v){
    auto result = Vec2(ceil(v.x), ceil(v.y));
    return result;
}

Vec3 floor(Vec3 v){
    auto result = Vec3(floor(v.x), floor(v.y), floor(v.z));
    return result;
}

Rect rect_from_min_wh(Vec2 min, float w, float h){
    Vec2 extents = Vec2(w, h)*0.5f;
    Rect result  = Rect(min + extents, extents);
    return result;
}

Rect rect_from_min_max(Vec2 min, Vec2 max){
    Vec2 extents = (max - min)*0.5f;
    Rect result = Rect(min + extents, extents);
    return result;
}

float left(Rect r){
    float result = r.center.x - r.extents.x;
    return result;
}

float right(Rect r){
    float result = r.center.x + r.extents.x;
    return result;
}

float top(Rect r){
    float result = r.center.y + r.extents.y;
    return result;
}

float bottom(Rect r){
    float result = r.center.y - r.extents.y;
    return result;
}

float width(Rect r){
    float result = r.extents.x*2.0f;
    return result;
}

float height(Rect r){
    float result = r.extents.y*2.0f;
    return result;
}

Vec2 min(Rect r){
    Vec2 result = Vec2(r.center.x - r.extents.x, r.center.y - r.extents.y);
    return result;
}

Vec2 max(Rect r){
    Vec2 result = Vec2(r.center.x + r.extents.x, r.center.y + r.extents.y);
    return result;
}

Rect expand(Rect r, Vec2 extents){
    Rect result = Rect(r.center, r.extents + extents);
    return result;
}

Rect shrink(Rect r, Vec2 extents){
    Rect result = Rect(r.center, r.extents - extents);
    return result;
}

Vec2 clamp(Vec2 p, Rect r){
    Vec2 result = Vec2(
        clamp(p.x, r.center.x - r.extents.x, r.center.x + r.extents.x),
        clamp(p.y, r.center.y - r.extents.y, r.center.y + r.extents.y),
    );
    return result;
}

Vec2 clamp(Vec2 p, Vec2 min_p, Vec2 max_p){
    Vec2 result = Vec2(
        clamp(p.x, min_p.x, max_p.x),
        clamp(p.y, min_p.y, max_p.y),
    );
    return result;
}

Rect cut_right(Rect r, float size){
    auto w = width(r);
    assert(size <= w);
    auto min_p = min(r);
    auto extents = Vec2((w - size)*0.5f, r.extents.y);
    auto result = Rect(min_p + extents, extents);
    return result;
}

Rect cut_top(Rect* source, float height){
    float extents_y = height*0.5f;
    assert(source.extents.y >= extents_y);

    auto result = Rect(
        Vec2(source.center.x, top(*source) - extents_y),
        Vec2(source.extents.x, extents_y)
    );

    source.center.y  -= extents_y;
    source.extents.y -= extents_y;
    return result;
}

bool rects_overlap(Rect a, Rect b)
{
    bool result = a.center.x - a.extents.x < b.center.x + b.extents.x
        && a.center.x + a.extents.x > b.center.x - b.extents.x
        && a.center.y - a.extents.y < b.center.y + b.extents.y
        && a.center.y + a.extents.y > b.center.y - b.extents.y;
    return result;
}

struct OBB{
    Vec2 center;
    Vec2 extents;
    float angle;
}


bool circle_overlaps_obb(Vec2 circle_center, float circle_radius,
Vec2 obb_center, Vec2 obb_extents, float obb_angle){
    // Based on information hobbled from the following sources:
    // https://yal.cc/rot-rect-vs-circle-intersection/
    // https://2dengine.com/doc/intersections.html
    // https://web.archive.org/web/20190206234842/http://www.migapro.com/circle-and-rotated-rectangle-collision-detection/
    auto c = cos(-obb_angle);
    auto s = sin(-obb_angle);
    auto rel = circle_center - obb_center;
    Vec2 p = Vec2(
        rel.x*c - rel.y*s + obb_center.x,
        rel.x*s + rel.y*c + obb_center.y,
    );

    auto delta = Vec2(abs(obb_center.x - p.x), abs(obb_center.y - p.y));
    delta.x = max(delta.x - obb_extents.x, 0.0f);
    delta.y = max(delta.y - obb_extents.y, 0.0f);

    bool result = squared(delta) <= squared(circle_radius);
    return result;
}

bool circle_vs_circle(Vec2 a_center, float a_radius, Vec2 b_center, float b_radius, Vec2* hit_normal, float* hit_depth){
    bool result = false;
    if(dist_sq(a_center, b_center) < squared(a_radius + b_radius)){
        result      = true;
        *hit_depth  = a_radius + b_radius - length(a_center - b_center);
        *hit_normal = normalize(a_center - b_center);
    }
    return result;
}

bool rect_vs_circle(Vec2 a_center, Vec2 a_extents, Vec2 b_center, float b_radius, Vec2* hit_normal, float* hit_depth){
    auto diff      = b_center - a_center;
    auto closest_p = clamp(diff, -1.0f*a_extents, a_extents);
    auto rel_p     = diff - closest_p;

    bool result = false;
    if(squared(rel_p) < squared(b_radius)){
        *hit_normal = normalize(rel_p);
        *hit_depth  = b_radius - length(rel_p);
        result      = true;
    }
    return result;
}

T round_up_power_of_two(T)(T n)
if(isIntegral!T){
    // NOTE: Adapted from here:
    // https://graphics.stanford.edu/~seander/bithacks.html#RoundUpPowerOf2
    n--;
    static foreach(byteIndex; 0 .. T.sizeof){
        n |= n >> (2 ^^ byteIndex); // ^^ is the pow operator in D
    }
    n++;
    return n;
}

bool is_power_of_two(T)(T n)
if(isIntegral!T){
    // NOTE: Taken from here:
    // https://graphics.stanford.edu/~seander/bithacks.html#DetermineIfPowerOf2
    bool result = (n > 0 && (n & (n - 1)) == 0);
    return result;
}

//
// Utility function
//

pragma(inline, true) T min(T)(T a, T b) {return a < b ? a : b;}
pragma(inline, true) T max(T)(T a, T b) {return a > b ? a : b;}
pragma(inline, true) T clamp(T)(T a, T min, T max)
{
    assert(min <= max);
    return a < min ? min : (a > max ? max : a);
}

void min(T)(T* a, T b){
    *a = *a < b ? *a : b;
}

void max(T)(T* a, T b){
    *a = *a > b ? *a : b;
}

uint premultiply_alpha(uint c){
    ubyte r = (c) & 0xff;
    ubyte g = (c >> 8) & 0xff;
    ubyte b = (c >> 16) & 0xff;
    ubyte a = (c >> 24) & 0xff;

    float fa = (cast(float)a / 255.0f);
    float fr = (cast(float)r / 255.0f) * fa;
    float fg = (cast(float)g / 255.0f) * fa;
    float fb = (cast(float)b / 255.0f) * fa;

    uint result = cast(uint)(a << 24)
                | cast(uint)(fb * 255.0f + 0.5f) << 16
                | cast(uint)(fg * 255.0f + 0.5f) << 8
                | cast(uint)(fr * 255.0f + 0.5f);
    return result;
}

void premultiply_alpha(uint[] rgba_pixels){
    foreach(ref c; rgba_pixels){
        c = premultiply_alpha(c);
    }
}

float deg_to_rad(float degrees){
    float result = degrees*(PI/180.0f);
    return result;
}

uint rgba_to_uint(Vec4 c){
    // NOTE: We have to use x, y, z, w instead of r, g, b, a because D doesn't like the
    // use of "overlapping initializers" in CTFE.
    uint result = cast(uint)(c.x * 255.0f + 0.5f)
                | cast(uint)(c.y * 255.0f + 0.5f) << 8
                | cast(uint)(c.z * 255.0f + 0.5f) << 16
                | cast(uint)(c.w * 255.0f + 0.5f) << 24;
    return result;
}

Vec2 normalize(Vec2 v){
    // TODO(tspike): Make an intrinsics.h file to wrap around this?
    float magnitude = sqrt(v.x * v.x + v.y * v.y);

    Vec2 result = Vec2(0.0f, 0.0f);
    if(magnitude != 0.0f){
        result.x = v.x / magnitude;
        result.y = v.y / magnitude;
    }

    return result;
}

Vec3 normalize(Vec3 a){
    float mag = sqrt(a.x*a.x + a.y*a.y + a.z*a.z);

    Vec3 result = Vec3(0.0f, 0.0f, 0.0f);
    if(mag > 0.00001f){ // TODO: Better epsilon?
        result = Vec3(
            a.x / mag,
            a.y / mag,
            a.z / mag
        );
    }
    return result;
}

float squared(Vec2 v){
    float result = v.x*v.x + v.y*v.y;
    return result;
}

/+
T wrap(T a, T min, T max){
    // Inspired by this thread:
    // https://stackoverflow.com/questions/478721/in-c-how-do-i-implement-modulus-like-google-calc-does
    T result = void;
    T size = max - min;
    if (a < min){
        result = min + (a + size) % size;
    }
    else{
        result = min + (a - min) % size;
    }
    return result;
}+/

private enum TMIN_EPSILON = 0.001f;

bool ray_vs_circle(Vec2 start, Vec2 delta, Vec2 circle_center, float circle_radius, float* t_min, Vec2* collision_normal)
{
    // Adapted from Real-Time Collision detection by Christer Ericson
    auto diff = start - circle_center;
    float b = dot(diff, delta);
    float c = dot(diff, diff) - circle_radius*circle_radius;

    bool result = false;
    if(c <= 0.0f && b <= 0.0f){
        float disc = b*b - c;
        if(disc >= 0.0f){
            float t = -b - sqrt(disc);
            *t_min = max(0.0f, t - TMIN_EPSILON);
            //*t_min = t;
            *collision_normal = normalize(start + delta*t - circle_center);
            result = true;
        }
    }
    return result;
}

bool approx_zero(float a){
    // TODO: Better epsilon?
    bool result = abs(a) < 0.001f;
    return result;
}

bool ray_vs_segment(Vec2 origin, Vec2 delta, Vec2 segment_p, Vec2 segment_normal, float* t_min){
    // Adapted from Real-Time Collision Detection by Christer Erikson, 5.3.1 "Intersecting Segment Against Plane"
    auto d = dot(segment_normal, segment_p);

    bool result = false;
    // TODO: Are we correct in assuming that the dot prodect being zero means there's no way
    // the ray could intersect with the line segment?
    auto denom = dot(segment_normal, delta);
    if(denom != 0.0f){ // TODO: Do approximately not zero?
        auto t = (d - dot(segment_normal, origin)) / denom;
        if(t > 0.0f && t < *t_min){
            *t_min = t;
            result = true;
        }
    }
    return result;
}

bool ray_vs_rect(Vec2 start, Vec2 delta, Rect bounds, float* tMin, Vec2* collisionNormal)
{
    // Adapted from here:
    // https://noonat.github.io/intersect
    //
    // TODO: This algorithm might be busted. We should keep testing things to make sure.
    // Here's other implementations of the slab test:
    // https://tavianator.com/2011/ray_box.html
    // https://www.scratchapixel.com/lessons/3d-basic-rendering/minimal-ray-tracer-rendering-simple-shapes/ray-box-intersection.html
    auto scaleX = 1.0f / delta.x;
    auto scaleY = 1.0f / delta.y;
    auto signX = sign(scaleX);
    auto signY = sign(scaleY);

    auto nearTimeX = (bounds.center.x - signX*bounds.extents.x - start.x) * scaleX;
    auto nearTimeY = (bounds.center.y - signY*bounds.extents.y - start.y) * scaleY;
    auto farTimeX  = (bounds.center.x + signX*bounds.extents.x - start.x) * scaleX;
    auto farTimeY  = (bounds.center.y + signY*bounds.extents.y - start.y) * scaleY;

    if(nearTimeX > farTimeY || nearTimeY > farTimeX){
        return false;
    }

    float nearTime = max(nearTimeX, nearTimeY);
    float farTime  = min(farTimeX, farTimeY);
    if(nearTime >= 1.0f || farTime <= 0.0f){
        return false;
    }

    // If nearTime <= 0.0f, then the origin of the ray is within the rect.
    // Should we signal this somehow and let the collision handling code
    // resolve this?
    if(nearTime > 0.0f && nearTime < *tMin){
        *tMin = max(nearTime - TMIN_EPSILON, 0.0f);
        if(nearTimeX > nearTimeY)
            *collisionNormal = Vec2(-signX, 0);
        else
            *collisionNormal = Vec2(0, -signY);

        return true;
    }

    return false;
}

float length(in Vec2 v)
{
    float result = sqrt(v.x * v.x + v.y * v.y);
    return result;
}

float dot(Vec2 a, Vec2 b)
{
    return a.x * b.x + a.y * b.y;
}

float dot(Vec3 a, Vec3 b)
{
    return a.x * b.x + a.y * b.y + a.z*b.z;
}

float distanceBetween(Vec2 a, Vec2 b)
{
    Vec2 diff;

    diff = a - b;
    // TODO(tspike): Make an intrinsics.h file to wrap around this!
    return sqrt(diff.x * diff.x + diff.y * diff.y);
}

float squared(float n){
    pragma(inline, true);
    auto result = n*n;
    return result;
}

float dist_sq(Vec2 a, Vec2 b){
    auto c = b - a;
    auto result = dot(c, c);
    return result;
}

float dist_sq(Vec3 a, Vec3 b){
    auto c = b - a;
    auto result = dot(c, c);
    return result;
}

Vec4 lerp(Vec4 a, Vec4 b, float t){
    Vec4 result = void;
    static foreach(i; 0 .. 4){
        result.c[i] = lerp(a.c[i], b.c[i], t);
    }
    return result;
}

Vec4 hsv_to_rgb(Vec4 color){
    // Conversion code adapted from here:
    // http://www.easyrgb.com/en/math.php
    float r, g, b;
    if (color.s == 0.0f){
       r = color.v;
       g = color.v;
       b = color.v;
    }
    else{
       auto h = color.h * 6.0f;
       if (h == 6.0f) h = 0.0f;
       auto i = floor(h);
       auto v1 = color.v * (1.0f - color.s);
       auto v2 = color.v * (1.0f - color.s * (h - i));
       auto v3 = color.v * (1.0f - color.s * (1.0f - (h - i)));

       if      (i == 0.0f) {r = color.v; g = v3 ; b = v1;}
       else if (i == 1.0f) {r = v2; g = color.v; b = v1;}
       else if (i == 2.0f) {r = v1; g = color.v; b = v3;}
       else if (i == 3.0f) {r = v1; g = v2; b = color.v;}
       else if (i == 4.0f) {r = v3; g = v1; b = color.v;}
       else                {r = color.v; g = v1 ; b = v2;}
    }

    // TODO: What about alpha?
    auto result = Vec4(r, g, b);
    return result;
}

Vec4 rgb_to_hsv(Vec4 color){
    // Conversion code adapted from here:
    // http://www.easyrgb.com/en/math.php
    auto rgb_min = min(min(color.r, color.g), color.b);
    auto rgb_max = max(max(color.r, color.g), color.b);
    auto rgb_delta = rgb_max - rgb_min;

    float h, s, v;
    v = rgb_max;
    if (rgb_delta == 0.0f){
        h = 0.0f;
        s = 0.0f;
    }
    else{
        s = rgb_delta / rgb_max;

        auto r = ((((rgb_max - color.r) / 6.0f) +  rgb_delta / 2.0f)) / rgb_delta;
        auto g = ((((rgb_max - color.g) / 6.0f) +  rgb_delta / 2.0f)) / rgb_delta;
        auto b = ((((rgb_max - color.b) / 6.0f) +  rgb_delta / 2.0f)) / rgb_delta;

        if      (color.r == rgb_max) h = b - g;
        else if (color.g == rgb_max) h = (1.0f / 3.0f) + r - b;
        else if (color.b == rgb_max) h = (2.0f / 3.0f) + g - r;

        if (h < 0.0f) h += 1.0f;
        if (h > 1.0f) h -= 1.0f;
    }

    // TODO: What about alpha?
    auto result = Vec4(h, s, v);
    return result;
}

float cross2D(Vec2 a, Vec2 b){
    // Adapted from Real-Time Collision Detection by Christer Ericson.
    // This is the 2D version of the cross product. I don't think it
    // has the same properties as the 3D cross product, but it does have
    // it's uses, appearently.
    float result = a.y*b.x - a.x*b.y;
    return result;
}

bool is_point_inside_triangle(Vec2 point, Vec2 p0, Vec2 p1, Vec2 p2)
{
    // Adapted from Real-Time Collision Detection by Christer Ericson.
    // The winding order of the triangle must be counter-clockwise.
    bool result = false;
    if(cross2D(point - p0, p1 - p0) >= 0.0f
        && cross2D(point - p1, p2 - p1) >= 0.0f
        && cross2D(point - p2, p0 - p2) >= 0.0f){
        result = true;
    }

    return result;
}

bool circles_overlap(Vec2 a_center, float a_radius, Vec2 b_center, float b_radius){
    bool result = false;
    if(dist_sq(a_center, b_center) <= squared(a_radius + b_radius)){
        result = true;
    }
    return result;
}

void index_incr(T)(T* index, T index_max)
{
    *index = (*index + 1) % index_max;
}

void index_decr(T)(T* index, T index_max)
{
    *index = (*index - 1 + index_max) % index_max;
}

float lerp(float start, float end, float t){
    float result = (end * t) + (start * (1.0f - t));
    return result;
}

bool is_point_inside_rect(Vec2 p, Rect r){
    auto r_min = min(r);
    auto r_max = max(r);
    bool result = p.x > r_min.x && p.x < r_max.x
               && p.y > r_min.y && p.y < r_max.y;
    return result;
}

// Regarding the coefficient of restitution (cor): Set to 1.0f for full reflection of velocity.
// Set it to less to absorb some of the velocity, set it to more to add some energy to it
// (in the case of hitting something bouncy such as a bumper)
Vec2 reflect(Vec2 v, Vec2 normal, float cor = 1.0f){
    // Calculate the reflection delta using the formula x = v - (1 + c)(v . n)n
    Vec2 result = v - ((1.0f + cor) * dot(v, normal)) * normal;
    return result;
}

Vec3 cross(Vec3 a, Vec3 b){
    auto result = Vec3(
        a.y*b.z - a.z*b.y,
        a.z*b.x - a.x*b.z,
        a.x*b.y - a.y*b.x
    );
    return result;
}

float normalized_range_clamp(float a, float min, float max)
{
    // Handy function thanks to Casey Muratori, Handmade Hero day 107.
    a = clamp(a, min, max);
    float result = (a - min) / (max - min);
    return result;
}
