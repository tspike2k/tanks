/*
Copyright (c) 2019 tspike2k@github.com
Distributed under the Boost Software License, Version 1.0.
See accompanying file LICENSE_BOOST.txt or copy at http://www.boost.org/LICENSE_1_0.txt
*/

module math;

public {
    import core.math : fabs, cos, sin;
    import core.stdc.math : floor, ceil, atan2f, tanf;
    import std.math : abs, sgn, sqrt, signbit, pow;
    import std.math.traits : isNaN;
    import meta : isIntegral, Unqual;
}

private {
    import memory;
}

alias sign  = sgn;
alias signf = sgn;
alias atan2 = atan2f;

enum PI = 3.14159f;

//
// Types
//

@nogc nothrow:

union Vec2{
    struct{float x = 0.0f; float y = 0.0f;};
    struct{float s; float t;};
    struct{float u; float v;};
    float[2] c;

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

Mat4 make_lookat_matrix(Vec3 camera_pos, Vec3 look_pos, Vec3 up_pos){
    Vec3 look_dir = normalize(look_pos - camera_pos);
    Vec3 up_dir   = normalize(up_pos); // TODO: Do we really need to normalize the up direction?

    Vec3 right_dir   = normalize(cross(look_dir, up_dir));
    Vec3 perp_up_dir = cross(right_dir, look_dir);

    auto result = Mat4([
        right_dir.x, perp_up_dir.x, -look_dir.x, 0,
        right_dir.y, perp_up_dir.y, -look_dir.y, 0,
        right_dir.z, perp_up_dir.z, -look_dir.z, 0,
        0,           0,             0,           1,
    ]);

    result = transpose(result)*mat4_translate(camera_pos*-1.0f);
    return result;
}

Mat4 make_inverse_lookat_matrix(Mat4 m){ // TODO: Where did we get this from?
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

T round_up_power_of_two(T)(T n)
if(isIntegral!T){
    // NOTE: Adapted from here:
    // https://graphics.stanford.edu/~seander/bithacks.html#RoundUpPowerOf2
    n--;
    static foreach(byteIndex; 0 .. T.sizeof){
        n |= n >> pow(2, byteIndex);
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

/*
bool ray_vs_rect(Vec2 start, Vec2 delta, Rect bounds, float* t_min, Vec2* collisionNormal){
    enum EPSILON = 0.0001f;

    // Addepted from "Realtime Collision Detection by Christer Ericson"
    float tmin = 0;
    float tmax = float.max;
    auto bmin = min(bounds);
    auto bmax = max(bounds);
    Vec2 tv = void; // tmin for each axis

    // For all three slabs
    for (int i = 0; i < 2; i++) {
        if (abs(delta.c[i]) < EPSILON) {
            // Ray is parallel to slab. No hit if origin not within slab
            if (start.c[i] < bmin.c[i] || start.c[i] > bmax.c[i])
                return false;
        } else {
            // Compute intersection t value of ray with near and far plane of slab
            float ood = 1.0f / delta.c[i];
            float t1 = (bmin.c[i] - start.c[i]) * ood;
            float t2 = (bmax.c[i] - start.c[i]) * ood;
            // Make t1 be intersection with near plane, t2 with far plane
            if (t1 > t2) swap(t1, t2);
            // Compute the intersection of slab intersection intervals
            if (t1 > tmin) tmin = t1;
            if (t2 > tmax) tmax = t2;

            tv.c[i] = tmin;

            // Exit with no collision as soon as slab intersection becomes empty
            if (tmin > tmax)
                return false;
        }
    }

    if(tmin >= 0.0f && tmin < 1.0f){
        *t_min = max(tmin - EPSILON, 0.0f);

        if(tv.x > tv.y)
            *collisionNormal = Vec2(-sign(delta.x), 0);
        else
            *collisionNormal = Vec2(0, -sign(delta.y));

        //q = p + d * tmin;
        return true;
    }

    return false;
}*/

bool ray_vs_segment(Vec2 start, Vec2 delta, Vec2 line_start, Vec2 line_end, Vec2 line_normal, float* t_min, Vec2* collision_normal){
    bool foundContact = false;

    Vec2 startRel = start - line_start;
    Vec2 endRel   = start + delta - line_start;
    float startDist = dot(startRel, line_normal);
    float endDist   = dot(endRel, line_normal);

    if (startDist >= 0.0f && endDist < 0.0f){
        float deltaDist = dot(delta, line_normal);
        deltaDist = fabs(deltaDist);
        float startDistPerc = startDist / deltaDist;

        if (startDistPerc < *t_min){
            Vec2 contactPoint = Vec2(start.x + delta.x * startDistPerc, start.y + delta.y * startDistPerc);

            // NOTE(tspike): Code for checking if a point is on a line segment courtesy of Daniel Fischer on this SO question:
            // https://stackoverflow.com/a/17582526
            // Additional reading can be found here:
            // http://www.sunshine2k.de/coding/java/PointOnLine/PointOnLine.html#step4
            // https://www.lucidar.me/en/mathematics/check-if-a-point-belongs-on-a-line-segment/
            // https://stackoverflow.com/a/328122
            float lineDiffX = line_end.x - line_start.x;
            float lineDiffY = line_end.y - line_start.y;
            float dPoduct = (contactPoint.x - line_start.x) * lineDiffX + (contactPoint.y - line_start.y) * lineDiffY;

            if (dPoduct > 0 && dPoduct < lineDiffX*lineDiffX + lineDiffY*lineDiffY)
            {
                startDistPerc = max(0.0f, startDistPerc - TMIN_EPSILON);
                *t_min = startDistPerc;
                *collision_normal = line_normal;
                foundContact = true;
            }
        }
    }

    return foundContact;
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

// TODO: Should we simplify this? Make it so that it takes templateOf!Vect?
T lerp(T, U)(in T start, in U end, float t)
if((is(T == struct) || is(T == union)) && isArray!(typeof(T.c))){
    T result = void;

    enum minComponents = min(start.c.length, end.c.length);
    static foreach(i; 0 .. minComponents)
    {
        result.c[i] = lerp(start.c[i], end.c[i], t);
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

void index_incr(T)(T* index, T size)
{
    *index = (*index + 1) % size;
}

void index_decr(T)(T* index, T size)
{
    *index = (*index - 1 + size) % size;
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

version(none):

Rect expand(Rect source, Vec2 expand)
{
    auto result = Rect(source.center, source.extents + expand);
    return result;
}

//
// Insersection tests
//

// TODO: Better epsilon. So far, it prevents catching on edges. But this is much larger than I would expect.
//private enum TMIN_EPSILON = 0.01f;

// This epsilon is better than the one we had for snapping to the ground,
// but it causes units to get inside level geometry more (at least with right triangles)
private enum TMIN_EPSILON = 0.001f;

// TODO: An old comment said there are times where this function fails. That certainly seems to be true with our
// ray vs triangle test. But then again, I can't seem to find an algorithm that has any better results.
/+
bool rayVsLineSegment(Vec2 start, Vec2 delta, Vec2 lineStart, Vec2 lineEnd, Vec2 lineNormal, float* tMin, Vec2* collisionNormal)
{
    // Based on the videos "2D Collision Detection", "2D Collision Response", and "2D Collision Response - Position" by
    // Jamie King on YouTube.
    bool result = false;

    float startDist = dot(start - lineStart, lineNormal);
    float endDist   = dot(start + delta - lineStart, lineNormal);

    if (startDist >= 0.0f && endDist <= 0.0f)
    {
        float t = startDist / (startDist + abs(endDist)); // TODO: Is it possible the denom could be zero? Should we test agains that?
        if (t < *tMin)
        {
            // NOTE(tspike): Code for checking if a point is on a line segment courtesy of Daniel Fischer on this SO question:
            // https://stackoverflow.com/a/17582526
            // Additional reading can be found here:
            // http://www.sunshine2k.de/coding/java/PointOnLine/PointOnLine.html#step4
            // https://www.lucidar.me/en/mathematics/check-if-a-point-belongs-on-a-line-segment/
            // https://stackoverflow.com/a/328122
            Vec2 contactPoint = start + delta*t;
            Vec2 lineDiff = lineEnd - lineStart;
            float d = dot(contactPoint - lineStart, lineDiff);

            if (0.0f <= d && d <= dot(lineDiff, lineDiff))
            {
                *tMin = max(0.0f, t - TMIN_EPSILON);
                *collisionNormal = lineNormal;
                result = true;
            }
        }
    }

    return result;
}+/

bool rayVsLineSegment(Vec2 start, Vec2 delta, Vec2 lineStart, Vec2 lineEnd, Vec2 lineNormal, float* tMin, Vec2* collisionNormal)
{
    bool result = false;

    // Adapted from here:
    // https://stackoverflow.com/a/565282
    auto lineDelta = lineEnd - lineStart;
    alias p = start;
    alias r = delta;
    alias q = lineStart;
    alias s = lineDelta;

    float rxs = cross2D(s, r);
    float t = cross2D(s, q - p) / rxs;
    float cross2 = cross2D(r, q - p);
    float u = cross2 / rxs;

    if(rxs == 0.0f && cross2 == 0.0f)
    {
        // TODO: Figure out how to implement this!
        // It's interesting to note that our previous ray vs line segment code, it would have ignored
        // collinear segments. For now at least, I think it's perfectly fine if we ignore that case.

    /+
        // Collinear check adapted from here:
        // https://www.codeproject.com/Tips/862988/Find-the-Intersection-Point-of-Two-Line-Segments
        if((0.0f <= dot(q - p, r) && dot(q - p, r) <= dot(r, r))
            || (0 <= dot(p - q, s) && dot(p - q, s) <= dot(s, s)))
        {
            // Lines are collinear
            *tMin = 0.0f; // TODO: Is this the correct response?
            *collisionNormal = lineNormal;
            result = true;
        }+/
    }
    else if(rxs == 0.0f && cross2 != 0.0f)
    {
        // NOTE: Line are paralell. Do nothing.
    }
    else if(rxs != 0.0f && 0.0f <= t && t <= 1.0f && 0.0f <= u && u <= 1.0f)
    {
        // NOTE: Segments meet at point
        //*tMin = max(0.0f, t - TMIN_EPSILON);
        *tMin = t;
        *collisionNormal = lineNormal;
        result = true;
    }
    return result;
}

void getRightTriangleNormals(Vec2 p0, Vec2 p1, Vec2 p2, Vec2 slopeNormal, ref Vec2[3] normals)
{
    bool xIsMajorAxis = abs(p0.x - p1.x) > abs(p0.y - p1.y);
    normals[0] = Vec2(xIsMajorAxis ? 0 : -sign(slopeNormal.x), xIsMajorAxis ? sign(slopeNormal.x) : 0);

    xIsMajorAxis = abs(p1.x - p2.x) > abs(p1.y - p2.y);
    normals[1] = Vec2(xIsMajorAxis ? 0 : -sign(slopeNormal.x), xIsMajorAxis ? -sign(slopeNormal.x) : 0);

    normals[2] = slopeNormal;
}

void getTrianglePoints(Vec2 center, Vec2 extents, Vec2 slopeNormal, ref Vec2[3] points)
{
    // The winding order of the triangle points is counter-clockwise in order to use the pointInsideTriangle call.
    float normalSignX = sign(slopeNormal.x);
    float normalSignY = sign(slopeNormal.y);

    points[0] = center + Vec2(extents.x * -normalSignY, extents.y*normalSignX);
    points[1] = center + Vec2(extents.x * -normalSignX, extents.y * -normalSignY);
    points[2] = center + Vec2(extents.x * normalSignY, extents.y*-normalSignX);
}

bool rayVsTriangle(Vec2 start, Vec2 delta, Vec2 p0, Vec2 p1, Vec2 p2, Vec2 slopeNormal, float* tMin, Vec2* collisionNormal, bool* originInsideShape)
{
    bool result = false;

    if(pointInsideTriangle(start, p0, p1, p2))
    {
        // Much like the rayVsRect test, we want to say the ray has collided with a rectangle that
        // contains the ray start. This is so we can wait until the end of the collision frame
        // to see if the origin is inside the collision bounds.
        /+result = true;
        *collisionNormal = Vec2(0, 0); // Since we're inside the rectangle, a collision normal doesn't make sense.
        *tMin = 0.0f;+/
        *originInsideShape = true;
    }
    else
    {
        Vec2[3] normals = void;
        getRightTriangleNormals(p0, p1, p2, slopeNormal, normals);

        /+
        void rayVsTriangleEdge(Vec2 start, Vec2 delta, Vec2 p0, Vec2 normal, float* tMin)
        {
            auto d = normalize(p0);
            auto t = (d - dot(normal, start)) / dot(normal, delta);

            if(t >= 0.0f && t < *tMin)
            {
                *tMin = t;
            }
        }

        Vec2[3] triangle = void;
        triangle[0] = p0;
        triangle[1] = p1;
        triangle[2] = p2;

        float t = *tMin;
        foreach(i, p; triangle)
        {
            rayVsTriangleEdge(start, delta, p, normals[i], &t);
            if(t < *tMin)
            {
                auto hitPos = start + delta*t;
                if(pointInsideTriangle(hitPos, p0, p1, p2))
                {
                    *tMin = max(0.0f, t - TMIN_EPSILON);
                    *collisionNormal = normals[i];
                    result = true;
                    break;
                }
            }
        }+/

        // TODO: Better algorithm than this! Things can pass through far too easily.
        if(rayVsLineSegment(start, delta, p0, p1, normals[0], tMin, collisionNormal))
            result = true;

        if(rayVsLineSegment(start, delta, p1, p2, normals[1], tMin, collisionNormal))
            result = true;

        if(rayVsLineSegment(start, delta, p0, p2, normals[2], tMin, collisionNormal))
            result = true;
    }

    return result;
}

void expandRightTriangle(Rect bounds, Vec2 slopeNormal, Vec2 expand, ref Vec2[3] triangle, ref Rect[2] rects)
{
    auto normalSignX = sign(slopeNormal.x);
    auto normalSignY = sign(slopeNormal.y);

    auto offsetCenter = bounds.center + Vec2(expand.x*normalSignX, expand.y*normalSignY);
    getTrianglePoints(offsetCenter, bounds.extents, slopeNormal, triangle);

    // TODO: It seems we should be able to do all this without all the min/max trickery.
    // It's far cleaner than the sort of thing we did in our old projects, but still.
    auto r1 = offsetCenter + Vec2(bounds.extents.x*-normalSignX, bounds.extents.y*-normalSignY);
    auto r2 = r1 + Vec2(2.0f*expand.x*-normalSignX, 2.0f*bounds.extents.y*normalSignY);
    rects[0] = RectFromMinMax(Vec2(min(r1.x, r2.x), min(r1.y, r2.y)), Vec2(max(r1.x, r2.x), max(r1.y, r2.y)));

    r1 = r1 + Vec2(2.0f*bounds.extents.x * normalSignX, 0);;
    r2 = r1 + Vec2(2.0f*(bounds.extents.x + expand.x)*-normalSignX,
        2.0f*(expand.y)*-normalSignY
    );
    rects[1] = RectFromMinMax(Vec2(min(r1.x, r2.x), min(r1.y, r2.y)), Vec2(max(r1.x, r2.x), max(r1.y, r2.y)));
}

Vec2 integrate(Vec2 vel, float dt, Vec2 accel)
{
    Vec2 delta = accel * 0.5f * (dt*dt) + vel * dt;
    return delta;
}

bool isPointOnLineSegment(Vec2 point, Vec2 segmentStart, Vec2 segmentEnd, Vec2 segmentNormal)
{
    // NOTE(tspike): Code for checking if a point is on a line segment courtesy of Daniel Fischer on this SO question:
    // https://stackoverflow.com/a/17582526
    // Additional reading can be found here:
    // http://www.sunshine2k.de/coding/java/PointOnLine/PointOnLine.html#step4
    // https://www.lucidar.me/en/mathematics/check-if-a-point-belongs-on-a-line-segment/
    // https://stackoverflow.com/a/328122
    auto segmentDiff = segmentEnd - segmentStart;
    auto pp = dot(point - segmentStart, segmentDiff);
    return 0.0f < pp && pp < dot(segmentDiff, segmentDiff);
}

// TODO: Add a triangle shape struct and pass that around instead of all this silliness.

// TODO: A) Get this to actually work B) Split this into seperate functions for each shape.
void getSeperationPoint(Vec2 p, Rect bounds, bool hasSlope, Vec2 slopeNormal, Vec2* resultPos, Vec2* resultNormal)
{
    if(!hasSlope)
    {
        //assert(pointInsideRect(p, bounds));

        auto relP = p - bounds.center;
        if(abs(relP.x) > abs(relP.y))
        {
            float x = bounds.center.x + bounds.extents.x*sign(relP.x);
            *resultPos = Vec2(x, p.y);
            *resultNormal = Vec2(sign(relP.x), 0);
        }
        else
        {
            float y = bounds.center.y + bounds.extents.y*sign(relP.y);
            *resultPos = Vec2(p.x, y);
            *resultNormal = Vec2(0, sign(relP.y));
        }
    }
    else
    {
    /+
        Vec2[3] triangle = void;
        Vec2[3] normals = void;
        getTrianglePoints(bounds.center, bounds.extents, slopeNormal, triangle);
        getRightTriangleNormals(triangle[0], triangle[1], triangle[2], slopeNormal, normals);
        assert(pointInsideTriangle(p, triangle[0], triangle[1], triangle[2]));

        float minDistSq = float.infinity;
        foreach(i, p0; triangle)
        {
            // Project p onto an edge of the triangle.
            auto n = Vec2(-normals[i].y, normals[i].x);
            float d = dot(p - p0, n);
            auto projectedP = p0 + d*n;

            // Get the closest point projected onto the triangle
            auto testDistSq = distSq(p, projectedP);
            if(testDistSq < minDistSq)
            {
                *resultPos = projectedP;
                *resultNormal = normals[i];
                minDistSq = testDistSq;
            }
        }+/
    }
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

/*
pragma(inline, true) T abs(T)(T a, T b)
if (!is(T == float) && !is(T == double))
{
    return a * ((a > 0) - (a < 0));
}*/

//
// Misc math operations
//


// NOTE: Useful for preventing underflow of unsigned integers.
T subtractOrZero(T, U)(T a, U b)
{
    pragma(inline, true);
    T result = 0;
    if(a > b)
        result = a - b;
    return result;
}

Vec2 normalizeUnsafe(Vec2 v)
{
    // TODO(tspike): Make an intrinsics.h file to wrap around this?
    float magnitude = sqrt(v.x * v.x + v.y * v.y);
    assert(magnitude != 0.0f);

    Vec2 result = void;
    result.x = v.x / magnitude;
    result.y = v.y / magnitude;

    return result;
}

float lengthSquared(Vec2 a)
{
    return a.x*a.x + a.y*a.y;
}

bool isPointInsideCircle(Vec2 point, Vec2 circleCenter, float radius)
{
    bool result = false;
    if(distanceSquared(point, circleCenter) <= radius*radius)
    {
        result = true;
    }
    return result;
}

bool rectsOverlap(Rect a, Rect b)
{
    return !(
        a.x + a.w <= b.x
        || a.x >= b.x + b.w
        || a.y >= b.y + b.h
        || a.y + a.h <= b.y
    );
}

bool rectsOverlap(in Rect a, in Rect b)
{
    return a.center.x - a.extents.x < b.center.x + b.extents.x
        && a.center.x + a.extents.x > b.center.x - b.extents.x
        && a.center.y - a.extents.y < b.center.y + b.extents.y
        && a.center.y + a.extents.y > b.center.y - b.extents.y;
}

// TODO: Depricate the following?
bool rectsOverlap(Vec2 centerA, Vec2 extentsA, Vec2 centerB, Vec2 extentsB)
{
    return centerA.x - extentsA.x < centerB.x + extentsB.x
        && centerA.x + extentsA.x > centerB.x - extentsB.x
        && centerA.y - extentsA.y < centerB.y + extentsB.y
        && centerA.y + extentsA.y > centerB.y - extentsB.y;
}

Vec2 calcIntersection(Vec2 s1, Vec2 e1, Vec2 s2, Vec2 e2)
{
    // Source:
    // http://rosettacode.org/wiki/Find_the_intersection_of_two_lines#C.23
    float a1 = e1.y - s1.y;
    float b1 = s1.x - e1.x;
    float c1 = a1 * s1.x + b1 * s1.y;

    float a2 = e2.y - s2.y;
    float b2 = s2.x - e2.x;
    float c2 = a2 * s2.x + b2 * s2.y;

    float delta = a1 * b2 - a2 * b1;
    //If lines are parallel, the result will be (NaN, NaN).
    if (delta == 0.0f)
    {
        return Vec2(float.nan, float.nan);
    }

    return Vec2((b2 * c1 - b1 * c2) / delta, (a1 * c2 - a2 * c1) / delta);
}
