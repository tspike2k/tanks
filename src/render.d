/*
Copyright (c) 2025 tspike2k@github.com
Distributed under the Boost Software License, Version 1.0.
See accompanying file LICENSE_BOOST.txt or copy at http://www.boost.org/LICENSE_1_0.txt
*/

/+
TODO:
    - Add destory texture function
    - Have a shaders/common.glsl file and append it to the top of all the shaders we load in?
    - Use list nodes rather than a 1m block for each render pass.

    Make a single shader constants block that is sensibly divided into chunks that can be block
    copied by the appropriate shader pass.

    We need to have data for the following:
        - Per frame data
        - Per pass data
        - Per model data

    We should also rename "pass" to layer. That would be more indicative of what we're trying to
    do.

    We should also change the prefix render_ to be draw_. This would be faster to type.

    Each call to add_draw_layer() should take a pointer to Draw_Layer_Data, which is all the
    state that needs to be set up for every draw layer. The draw layer holds a pointer to
    the data, and when we go to draw we can to a pointer comparison to see if we need to
    resubmit the layer data.
+/

import memory;
import assets;
private{
    import display;
    import logging;
    import math;

    Allocator* g_allocator;
    Texture    g_current_texture;

    enum Max_Materials = 2;
}

enum Vec3_Up = Vec3(0, 1, 0); // TODO: Is this correct? If it is, in the future we would prefer it if z positive was up instead.

enum Z_Far  =  1000.0f;
enum Z_Near = -Z_Far;

alias Texture = ulong;

enum{
    Render_Flag_Disable_Culling    = (1 << 0),
    Render_Flag_Disable_Color      = (1 << 1),
    Render_Flag_Disable_Depth_Test = (1 << 2),
}

// To keep from having to juggle seperate vertex formats between quads and meshes,
// the first attribute could either hold color or normal information, depending
// on which one the shader needs.
struct Vertex{
    union{
        Vec4 common; // Name used internally by shaders
        Vec4 color;
        Vec3 normal;
    }
    Vec3 pos;
    Vec2 uv;
}

struct Mesh_Part{
    Vertex[] vertices;
    uint     material_index;
}

struct Mesh{
    Mesh_Part[] parts;
}

struct Render_Pass{
    Render_Pass* next;

    Camera* camera;
    ulong flags;

    Render_Cmd* cmd_next;
    Render_Cmd* cmd_last;
}

enum Max_Quads_Per_Batch = 2048; // TODO: Isn't this a bit high? 512 would be a lot.

// TODO: Ensure members are correctly aligned with both HLSL and GLSL requirements
struct Shader_Constants{
    float time;
}

struct Material{
    Texture diffuse_texture;
    Vec3    specular;
    Vec3    tint;
    float   shininess;
}

struct Shader_Light{
    Vec3  pos;
    float pad0;
    Vec3  ambient;
    float pad1;
    Vec3  diffuse;
    float pad2;
    Vec3  specular;
    float pad4;
}

enum Text_Align : uint{
    Left,
    Right,
    Center_X,
}

enum Texture_Index_Diffuse = 0;

Mat4_Pair orthographic_projection(Rect camera_bounds){
    // Orthographic adapted from here:
    // https://songho.ca/opengl/gl_projectionmatrix.html#ortho
    // https://en.wikipedia.org/wiki/Orthographic_projection
    auto l = left(camera_bounds);
    auto r = right(camera_bounds);
    auto t = top(camera_bounds);
    auto b = bottom(camera_bounds);
    auto n = Z_Near;
    auto f = Z_Far;

    Mat4_Pair proj = void;
    proj.mat = Mat4([
        2.0f / (r-l), 0,            0,             -(r+l)/(r-l),
        0,            2.0f / (t-b), 0,             -(t+b)/(t-b),
        0,            0,            -2.0f / (f-n), -(f+n)/(f-n),
        0,            0,            0,             1,
    ]);

    proj.inv = Mat4([
        (r-l) / 2.0f, 0,            0,              (l+r)/2.0f,
        0,            (t-b) / 2.0f, 0,              (t+b)/2.0f,
        0,            0,            (f-n) / -2.0f, -(f+n)/2.0f,
        0,            0,            0,             1,
    ]);
    return proj;
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

Mat4 invert_view_matrix(Mat4 view){
    // IMPORTANT: Inverting a view matrix this way only works if no non-uniform rotation has been
    // applied.

    // Transpose 3x3 rotation portion of the view to invert it.
    auto rot = Mat4([
        view.m[0][0], view.m[1][0], view.m[2][0], 0,
        view.m[0][1], view.m[1][1], view.m[2][1], 0,
        view.m[0][2], view.m[1][2], view.m[2][2], 0,
        0,            0,            0,            1,
    ]);

    // Negate the translation portion of the view to invert it.
    auto x = view.m[0][3];
    auto y = view.m[1][3];
    auto z = view.m[2][3];
    auto result = rot*mat4_translate(Vec3(-x, -y, -z));
    return result;
}

Rect calc_scaling_viewport(float res_x, float res_y, float window_w, float window_h){
    // TODO(tspike) Investigate why there's a vertical stripe of non-rendered pixels on the right side of the screen when
    // in fullcreen mode in X11 (on my laptop). Floating point precision issues? Do we need to clamp?

    // Resolution independent code thanks to this post:
    // http://www.david-amador.com/2013/04/opengl-2d-independent-resolution-rendering/

    float aspect_ratio = res_x/res_y;

    float target_w = window_w;
    float target_h = target_w / aspect_ratio;

    if(target_h > window_h){
        target_h = window_h;
        target_w = target_h*aspect_ratio;
    }

    float min_x = (window_w - target_w)*0.5f;
    float min_y = (window_h - target_h)*0.5f;

    Rect result = rect_from_min_max(Vec2(min_x, min_y), Vec2(min_x + target_w, min_y + target_h));
    return result;
}

struct Camera{
    Mat4_Pair proj;
    Mat4_Pair view;
    Vec3      center;
    Vec3      facing;
}

void set_world_projection(Camera* camera, float target_w, float target_h, float window_aspect_ratio){
    // Aspect ratio correction for orthographic perspective adapted from the following:
    // http://www.david-amador.com/2013/04/opengl-2d-independent-resolution-rendering/
    Vec2 camera_size = void;
    if(window_aspect_ratio >= target_w/target_h){
        camera_size = Vec2(target_h*window_aspect_ratio, target_h);
    }
    else{
        camera_size = Vec2(target_w, target_w/window_aspect_ratio);
    }
    auto camera_bounds = Rect(Vec2(0, 0), camera_size*0.5f);
    camera.proj = orthographic_projection(camera_bounds);
}

void set_world_view(Camera* camera, Vec3 camera_polar, Vec3 camera_target, Vec3 up){
    auto camera_world = polar_to_world(camera_polar, camera_target);
    camera.view.mat = make_lookat_matrix(camera_world, camera_target, up);
    camera.view.inv = invert_view_matrix(camera.view.mat);
    camera.center   = camera_world;
}

void set_world_view(Camera* camera, Vec3 camera_center, float camera_x_rot){
    camera.view.mat = mat4_rot_x(camera_x_rot*(PI/180.0f))*mat4_translate(-1.0f*camera_center);
    camera.view.inv = invert_view_matrix(camera.view.mat);
    camera.center   = camera_center;
}

void set_hud_camera(Camera* camera, float camera_w, float camera_h){
    auto camera_extents = Vec2(camera_w, camera_h)*0.5f;
    auto camera_bounds = Rect(camera_extents, camera_extents);
    camera.proj = orthographic_projection(camera_bounds);
    camera.view.mat = Mat4_Identity;
    camera.view.inv = invert_view_matrix(Mat4_Identity);
    camera.center = Vec3(0, 0, 0); // TODO: Is this the correct center for the HUD?
}

Vec3 get_camera_facing(Camera* camera){
    auto result = Vec3(
        camera.view.mat.m[2][0],
        camera.view.mat.m[2][1],
        camera.view.mat.m[2][2]
    );
    return result;
}

Vec2 project(Camera* camera, Vec3 world_p, float screen_w, float screen_h){
    auto mat = camera.proj.mat*camera.view.mat; // TODO: Precompute this?
    auto p = mat*Vec4(world_p.x, world_p.y, world_p.z, 1);
    auto ndc = Vec2(p.x/p.w, p.y/p.w);
    auto n = Vec2((ndc.x + 1.0f)/2.0f, (ndc.y + 1.0f)/2.0f);
    auto result = Vec2(n.x * screen_w, n.y*screen_h);
    return result;
}

Vec3 unproject(Camera* camera, Vec2 screen_p, float screen_w, float screen_h){
    // Based on the following sources:
    // https://antongerdelan.net/opengl/raycasting.html
    // https://stackoverflow.com/questions/45882951/mouse-picking-miss/45883624#45883624
    // https://stackoverflow.com/questions/46749675/opengl-mouse-coordinates-to-space-coordinates/46752492#46752492
    //
    // Other sources on this topic that were helpful in figuring out how to do this:
    // https://guide.handmadehero.org/code/day373/#2978
    // https://www.opengl-tutorial.org/miscellaneous/clicking-on-objects/picking-with-a-physics-library/
    // https://www.reddit.com/r/gamemaker/comments/c6684w/3d_converting_a_screenspace_mouse_position_into_a/
    auto ndc = Vec2(
        2.0f*(screen_p.x / screen_w) - 1.0f,
        2.0f*(screen_p.y / screen_h) - 1.0f
    );

    // TODO: Account for perspective in case of a perspective view matrix?
    auto eye_p = camera.proj.inv*Vec4(ndc.x, -ndc.y, -1, 0);
    eye_p.z = -1.0f;
    eye_p.w =  0.0f;

    auto origin   = camera.view.inv*Vec4(0, 0, 0, 1);
    auto world_p  = camera.view.inv*eye_p;
    auto result   = world_p.xyz() + origin.xyz();
    return result;
}

Vec3 world_to_render_pos(Vec2 p){
    auto result = Vec3(p.x, 0, -p.y);
    return result;
}

void clear_target_to_color(Render_Pass* pass, Vec4 color){
    auto cmd = push_command!Clear_Target(pass);
    cmd.color = color;
}

void set_shader(Render_Pass* pass, Shader* shader){
    auto cmd   = push_command!Set_Shader(pass);
    cmd.shader = shader;
}

void render_mesh(Render_Pass* pass, Mesh* mesh, Material[] materials, Mat4 transform){
    auto cmd      = push_command!Render_Mesh(pass);
    cmd.mesh      = mesh;
    cmd.materials = materials;
    cmd.transform = transform;
}

void push_scissor(Render_Pass* pass, Rect scissor){
    auto cmd   = push_command!Push_Scissor(pass);
    cmd.scissor = scissor;
}

void pop_scissor(Render_Pass* pass){
    push_command(pass, Command.Pop_Scissor, Render_Cmd.sizeof);
}

Vec2 center_text_left(Font* font, String text, Rect bounds){
    auto h = cast(float)font.metrics.cap_height;
    auto result = floor(Vec2(left(bounds), bounds.center.y - 0.5f*h));
    return result;
}

Vec2 center_text(Font* font, String text, Rect bounds){
    auto text_width = get_text_width(font, text);
    auto result = floor(bounds.center - 0.5f*Vec2(text_width, font.metrics.cap_height));
    return result;
}

void render_text(Render_Pass* pass, Font* font, Vec2 pos, String text,
Vec4 color = Vec4(1, 1, 1, 1), Text_Align text_align = Text_Align.Left){
    auto cmd       = push_command!Render_Text(pass);
    cmd.text       = text;
    cmd.font       = font;
    cmd.pos        = pos;
    cmd.color      = color;
    cmd.text_align = text_align;
}

void render_rect(Render_Pass* pass, Rect bounds, Vec4 color){
    auto cmd   = push_command!Render_Rect(pass);
    cmd.bounds = bounds;
    cmd.color  = color;
}

void render_particle(Render_Pass* pass, Vec3 pos, Vec2 extents, Vec3 normal, Vec4 color, Texture texture){
    auto cmd    = push_command!Render_Particle(pass);
    cmd.pos     = pos;
    cmd.extents = extents;
    cmd.normal  = normal;
    cmd.texture = texture;
}

void render_ground_decal(Render_Pass* pass, Rect bounds, Vec4 color, float angle, Texture texture){
    auto cmd    = push_command!Render_Ground_Decal(pass);
    cmd.bounds  = bounds;
    cmd.color   = color;
    cmd.texture = texture;
    cmd.angle   = angle;
}

void render_rect_outline(Render_Pass* pass, Rect r, Vec4 color, float thickness){
    auto b = thickness * 0.5f;
    auto top    = Rect(r.center + Vec2(0, r.extents.y - b), Vec2(r.extents.x, b));
    auto bottom = Rect(r.center - Vec2(0, r.extents.y - b), Vec2(r.extents.x, b));
    auto left   = Rect(r.center - Vec2(r.extents.x - b, 0), Vec2(b, r.extents.y));
    auto right  = Rect(r.center + Vec2(r.extents.x - b, 0), Vec2(b, r.extents.y));

    render_rect(pass, top, color);
    render_rect(pass, bottom, color);
    render_rect(pass, left, color);
    render_rect(pass, right, color);
}

void set_light(Render_Pass* pass, Shader_Light* light){
    auto cmd   = push_command!Set_Light(pass);
    cmd.light = light;
}

void set_texture(Render_Pass* pass, Texture texture){
    auto cmd    = push_command!Set_Texture(pass);
    cmd.texture = texture;
}

float get_text_width(Font* font, String text){
    float result = 0;
    uint prev_codepoint = 0;
    // TODO: Take newlines into account.
    foreach(c; text){
        // TODO: Due to kerning, we probably need "space" to be a valid glyph, just not one we render.
        if(c == ' '){
            result += font.metrics.space_width;
        }
        else{
            // When to apply kerning based on sample code from here:
            // https://freetype.org/freetype2/docs/tutorial/step2.html#:~:text=c.%20Kerning
            auto glyph   = get_glyph(font, c);
            auto kerning = get_codepoint_kerning_advance(font, prev_codepoint, glyph.codepoint);
            result += kerning;

            result += cast(float)glyph.advance;
            prev_codepoint = c;
        }
    }
    return result;
}

private:

enum Command : uint{
    None,
    No_Op,
    Clear_Target,
    Set_Shader,
    Render_Mesh,
    Render_Text,
    Set_Light,
    Render_Rect,
    Push_Scissor,
    Pop_Scissor,
    Render_Particle,
    Render_Ground_Decal,
    Set_Texture,
}

struct Render_Cmd{
    Render_Cmd* next;
    Command type;
}

struct Clear_Target{
    enum Type = Command.Clear_Target;
    Render_Cmd header;
    alias header this;

    Vec4    color;
}

struct Set_Shader{
    enum Type = Command.Set_Shader;
    Render_Cmd header;
    alias header this;

    Shader* shader;
}

struct Render_Mesh{
    enum Type = Command.Render_Mesh;
    Render_Cmd header;
    alias header this;

    Mesh*      mesh;
    Material[] materials;
    Mat4       transform;
}

struct Render_Text{
    enum Type = Command.Render_Text;
    Render_Cmd header;
    alias header this;

    Font*      font;
    String     text;
    Vec2       pos;
    Vec4       color;
    Text_Align text_align;
}

struct Set_Light{
    enum Type = Command.Set_Light;
    Render_Cmd header;
    alias header this;

    Shader_Light* light;
}

struct Set_Texture{
    enum Type = Command.Set_Texture;
    Render_Cmd header;
    alias header this;

    Texture texture;
}

struct Push_Scissor{
    enum Type = Command.Push_Scissor;
    Render_Cmd header;
    alias header this;

    Rect scissor;
}

struct Render_Rect{
    enum Type = Command.Render_Rect;
    Render_Cmd header;
    alias header this;

    Rect bounds;
    Vec4 color;
}

struct Render_Particle{
    enum Type = Command.Render_Particle;
    Render_Cmd header;
    alias header this;

    Vec3 pos;
    Vec2 extents;
    Vec3 normal;
    Vec4 color;
    Texture texture;
}

struct Render_Ground_Decal{
    enum Type = Command.Render_Ground_Decal;
    Render_Cmd header;
    alias header this;

    Rect bounds;
    Vec4 color;
    Texture texture;
    float angle;
}

struct Shader_Camera{
    Mat4 mat;
    Vec3 pos;
    float pad_00;
}

Render_Cmd* push_command(Render_Pass* pass, Command type, size_t size){
    auto result = cast(Render_Cmd*)alloc(g_allocator, size);
    result.type = type;
    if(pass.cmd_last){
        pass.cmd_last.next = result;
    }
    if(!pass.cmd_next){
        pass.cmd_next = result;
    }

    pass.cmd_last = result;
    return result;
}

T* push_command(T)(Render_Pass* pass){
    auto result = cast(T*)push_command(pass, T.Type, T.sizeof);
    return result;
}

void set_quad(Vertex[] v, Rect r, Rect uvs){
    auto p0 = Vec2(right(r), top(r));
    auto p1 = Vec2(left(r),  top(r));
    auto p2 = Vec2(left(r),  bottom(r));
    auto p3 = Vec2(right(r), bottom(r));

    v[0].pos = v2_to_v3(p0, 0);
    v[0].uv = Vec2(right(uvs), bottom(uvs));

    v[1].pos = v2_to_v3(p1, 0);
    v[1].uv = Vec2(left(uvs), bottom(uvs));

    v[2].pos = v2_to_v3(p2, 0);
    v[2].uv = Vec2(left(uvs), top(uvs));

    v[3].pos = v2_to_v3(p3, 0);
    v[3].uv = Vec2(right(uvs), top(uvs));
}

void set_quad(Vertex[] v, Rect r, Rect uvs, Vec4 color){
    set_quad(v, r, uvs);
    v[0].color = color;
    v[1].color = color;
    v[2].color = color;
    v[3].color = color;
}

version(linux){
    version = opengl;
}

version(opengl){
    import math;
    import bind.opengl;

    // TODO: Combine all the uniform blocks into one and use a single binding point?
    enum Constants_Uniform_Binding = 0;
    enum Materials_Uniform_Binding  = 1;
    enum Light_Uniform_Binding     = 2;
    enum Camera_Uniform_Binding    = 3;

    enum{
        Vertex_Attribute_ID_Pos,
        Vertex_Attribute_ID_Common,
        Vertex_Attribute_ID_UV,
    }

    alias Quad_Index_Type = GLuint;
    enum Vertex_Indeces_Per_Quad = 6;
    enum Default_Texture_Filter = GL_LINEAR;

    __gshared GLuint        g_shader_constants_buffer;
    __gshared GLuint        g_shader_material_buffer;
    __gshared GLuint        g_shader_light_buffer;
    __gshared GLuint        g_shader_camera_buffer;
    __gshared GLuint        g_quad_vbo;
    __gshared GLuint        g_quad_index_buffer;
    __gshared Texture       g_default_texture;
    __gshared Render_Pass*  g_render_pass_first;
    __gshared Render_Pass*  g_render_pass_last;
    __gshared Rect          g_base_viewport;
    __gshared Vec4          g_clear_color;

    void draw_quads(Vertex[] v){
        assert(v.length % 4 == 0);

        glBindBuffer(GL_ARRAY_BUFFER, g_quad_vbo);
        glBufferData(GL_ARRAY_BUFFER, cast(GLsizeiptr)(v.length * Vertex.sizeof), v.ptr, GL_DYNAMIC_DRAW);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, g_quad_index_buffer);
        glDrawElements(GL_TRIANGLES, cast(GLsizei)(v.length * Vertex_Indeces_Per_Quad), GL_UNSIGNED_INT, cast(GLvoid*)0);
    }

    public:

    struct Shader{
        private:

        GLuint handle;
        GLint  uniform_loc_model;
        GLint  uniform_loc_texture_diffuse;
    }

    Texture create_texture(uint[] pixels, uint width, uint height, uint flags = 0){
        assert(width > 0 && height > 0);
        GLint  internal_format = GL_RGBA8; // TODO: Do we care? Can we tell OpenGL we don't care?
        GLenum source_format   = GL_RGBA;

        GLuint handle;
        glGenTextures(1, &handle);
        glBindTexture(GL_TEXTURE_2D, handle);
        glTexImage2D(GL_TEXTURE_2D, 0, internal_format, width, height, 0, source_format, GL_UNSIGNED_BYTE, pixels.ptr);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, Default_Texture_Filter);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, Default_Texture_Filter);
        //if(!repeat){
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        /+}
        else{
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
        }+/
        Texture result = handle;
        return result;
    }

    bool render_open(Allocator* allocator){
        g_allocator = allocator;

        g_current_texture = -1;

        assert(allocator.scratch);
        push_frame(allocator.scratch);
        scope(exit) pop_frame(allocator.scratch);

        glEnable(GL_DEBUG_OUTPUT);
        glEnable(GL_DEBUG_OUTPUT_SYNCHRONOUS);
        glDebugMessageCallback(&debug_msg_callback, null);

        glEnable(GL_BLEND);
        glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA); // Using premultiplied alpha
        //glEnable(GL_SCISSOR_TEST);

        glEnable(GL_CULL_FACE);
        glCullFace(GL_BACK);
        glFrontFace(GL_CCW);

        glEnable(GL_DEPTH_TEST);
        glDepthMask(GL_TRUE);
        glDepthFunc(GL_LESS);
        glDepthRange(0.0f, Z_Far);
        //glEnable(GL_DEPTH_CLAMP); // TODO: Is this a good idea? Probably not

        // According to Casey Muratori (Handmade Hero ep 372), driver vendors realized that
        // state changes through VAOs is actually quite inefficient.
        GLuint vao;
        glGenVertexArrays(1, &vao);
        glBindVertexArray(vao);

        glGenBuffers(1, &g_quad_vbo);
        glBindBuffer(GL_ARRAY_BUFFER, g_quad_vbo);

        glEnableVertexAttribArray(Vertex_Attribute_ID_Pos);
        glVertexAttribPointer(Vertex_Attribute_ID_Pos, 3, GL_FLOAT, GL_FALSE, Vertex.sizeof, cast(GLvoid*)Vertex.pos.offsetof);

        glEnableVertexAttribArray(Vertex_Attribute_ID_Common);
        glVertexAttribPointer(Vertex_Attribute_ID_Common, 4, GL_FLOAT, GL_FALSE, Vertex.sizeof, cast(GLvoid*)Vertex.common.offsetof);

        glEnableVertexAttribArray(Vertex_Attribute_ID_UV);
        glVertexAttribPointer(Vertex_Attribute_ID_UV, 2, GL_FLOAT, GL_FALSE, Vertex.sizeof, cast(GLvoid*)Vertex.uv.offsetof);

        // TODO: If we use glDrawElementsBaseVertex, we can use an index buffer with smaller precision (say GL_UNSIGNED_BYTE).
        // Then we tell call glDrawElementsBaseVertex rather than glDrawElements and pass the stride. OpenGL will add the
        // correct offset for each element drawn. Handy.
        // Basically, OpenGL would take care of the "+ (quad_index*4)" part internally, and we could remove that.
        {
            auto index_buffer = alloc_array!Quad_Index_Type(allocator.scratch, Max_Quads_Per_Batch*Vertex_Indeces_Per_Quad);

            foreach(quad_index; 0 .. Max_Quads_Per_Batch){
                auto i = quad_index * Vertex_Indeces_Per_Quad;
                index_buffer[i + 0] = 0 + (quad_index*4);
                index_buffer[i + 1] = 1 + (quad_index*4);
                index_buffer[i + 2] = 2 + (quad_index*4);
                index_buffer[i + 3] = 2 + (quad_index*4);
                index_buffer[i + 4] = 3 + (quad_index*4);
                index_buffer[i + 5] = 0 + (quad_index*4);
            }

            glGenBuffers(1, &g_quad_index_buffer);
            glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, g_quad_index_buffer);
            glBufferData(GL_ELEMENT_ARRAY_BUFFER, Max_Quads_Per_Batch*Quad_Index_Type.sizeof, index_buffer.ptr, GL_STATIC_DRAW);
        }


        version(none){
            /*
            glGenBuffers(1, &g_common_shader_data_buffer);
            if(g_common_shader_data_buffer == -1){
                log(Cyu_Err "Unable to create buffer for common shader.\n");
            }*/

            {
                auto fallback_w = 4;
                auto fallback_h = 4;
                auto fallback_pixels = alloc_array!uint(allocator.scratch, fallback_w*fallback_h);
                fallback_pixels[0 .. $] = uint.max;
                g_default_texture = create_texture(fallback_pixels, fallback_w, fallback_h);

                if(g_default_texture == 0){
                    log("Failed to init renderer: Unable to create default texture.\n");
                    return false;
                }
            }
        }

        init_uniform_buffer(&g_shader_constants_buffer, Constants_Uniform_Binding, Shader_Constants.sizeof);
        init_uniform_buffer(&g_shader_material_buffer, Materials_Uniform_Binding, Shader_Material.sizeof*Max_Materials);
        init_uniform_buffer(&g_shader_light_buffer, Light_Uniform_Binding, Shader_Light.sizeof);
        init_uniform_buffer(&g_shader_camera_buffer, Camera_Uniform_Binding, Shader_Camera.sizeof);

        /*
        if(!compile_shader("default", 0, Default_Vertex_Shader_Source, Default_Fragment_Shader_Source)){
            log("Error: Unable to create default shader. Aborting.\n");
        }*/

        return true;
    }

    void render_close(){

    }

    void render_begin_frame(uint viewport_width, uint viewport_height, Vec4 clear_color, Allocator* memory){
        // TODO: Set viewport and the like?
        g_allocator = memory;
        g_render_pass_first = null;
        g_render_pass_last  = null;
        g_base_viewport     = rect_from_min_max(Vec2(0, 0), Vec2(viewport_width, viewport_height));
        g_clear_color       = clear_color;
    }

    void render_end_frame(){
        auto pass = g_render_pass_first;

        {
            auto color = g_clear_color;
            glClearColor(color.r, color.g, color.b, color.a);
            glClearDepth(Z_Far);
            glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        }

        Camera* current_camera = null;
        while(pass){
            set_viewport(g_base_viewport);
            if(pass.camera != current_camera){
                current_camera = pass.camera;
                auto dest = zero_type!Shader_Camera;
                dest.mat = transpose(current_camera.proj.mat*current_camera.view.mat);
                dest.pos = current_camera.center;

                glBindBuffer(GL_UNIFORM_BUFFER, g_shader_camera_buffer);
                glBufferSubData(GL_UNIFORM_BUFFER, 0, Shader_Camera.sizeof, &dest);
            }

            if(pass.flags & Render_Flag_Disable_Color){
                glColorMask(false, false, false, false);
            }

            if(pass.flags & Render_Flag_Disable_Culling){
                glDisable(GL_CULL_FACE);
            }

            if(pass.flags & Render_Flag_Disable_Depth_Test){
                glDisable(GL_DEPTH_TEST);
            }

            Material* material;
            Shader* shader;
            Shader_Light* light;
            bool scissor_enabled = false;

            auto cmd_node = pass.cmd_next;
            while(cmd_node){
                switch(cmd_node.type){
                    default: break;

                    case Command.Clear_Target:{
                        auto cmd = cast(Clear_Target*)cmd_node;

                        auto color = cmd.color;
                        glClearColor(color.r, color.g, color.b, color.a);
                        glClearDepth(Z_Far);
                        // TODO: Only clear depth if the depth testing is enabled
                        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
                    } break;

                    case Command.Set_Shader:{
                        auto cmd = cast(Set_Shader*)cmd_node;

                        if(shader != cmd.shader){
                            shader = cmd.shader;
                            glUseProgram(shader.handle);

                            //set_uniform(shader.uniform_loc_camera, &pass.camera);
                            //set_uniform(shader.uniform_loc_camera_pos, &pass.camera_pos);
                        }
                    } break;

                    case Command.Render_Rect:{
                        auto cmd = cast(Render_Rect*)cmd_node;
                        material = null;

                        // TODO: Push quads into a vertex buffer. Flush on state change.
                        Vertex[4] v = void;
                        auto uvs = rect_from_min_max(Vec2(0, 0), Vec2(1, 1));
                        set_quad(v[], cmd.bounds, uvs, cmd.color);
                        draw_quads(v[]);
                    } break;

                    case Command.Render_Particle:{
                        auto cmd = cast(Render_Particle*)cmd_node;
                        material = null;

                        assert(0);

                        // TODO: Push quads into a vertex buffer. Flush on state change.
                        Vertex[4] v = void;
                        auto uvs = rect_from_min_max(Vec2(0, 0), Vec2(1, 1));
                        /+
                            auto perp = cross(cmd.normal, Vec3(0, -1, 0));
                            auto a = perp*Vec3(2, 2, 2);
                            auto x = normalize(a - cmd.pos);
                            auto y = cross(x, cmd.normal);


                            auto p0 = cmd.pos + x;
                            auto p1 = cmd.pos + y;
                            auto p2 = cmd.pos - x;
                            auto p3 = cmd.pos - y;
+/
                        /+
                            auto p0 = Vec2(right(r), top(r));
                            auto p1 = Vec2(left(r),  top(r));
                            auto p2 = Vec2(left(r),  bottom(r));
                            auto p3 = Vec2(right(r), bottom(r));

                            v[0].pos = v2_to_v3(p0, 0);
                            v[0].uv = Vec2(right(uvs), bottom(uvs));

                            v[1].pos = v2_to_v3(p1, 0);
                            v[1].uv = Vec2(left(uvs), bottom(uvs));

                            v[2].pos = v2_to_v3(p2, 0);
                            v[2].uv = Vec2(left(uvs), top(uvs));

                            v[3].pos = v2_to_v3(p3, 0);
                            v[3].uv = Vec2(right(uvs), top(uvs));

                        +/
                        //set_texture(cmd.texture);
                        //draw_quads(v[]);
                    } break;

                    case Command.Render_Ground_Decal:{
                        material = null;
                        // TODO: Decal rendering that doesn't have z-fighting!
                        auto cmd = cast(Render_Ground_Decal*)cmd_node;

                        // Drawing rotated rects adapted from this answer:
                        // https://gamedev.stackexchange.com/a/121313
                        auto c = cos(cmd.angle);
                        auto s = sin(cmd.angle);

                        auto extents = cmd.bounds.extents;
                        auto p_up    = Vec2(-extents.y*s, extents.y*c);
                        auto p_right = Vec2(extents.x*c, extents.x*s);

                        auto center = cmd.bounds.center;
                        auto p0 = center + p_up + p_right;
                        auto p1 = center + p_up - p_right;
                        auto p2 = center - p_up - p_right;
                        auto p3 = center - p_up + p_right;

                        auto uvs = rect_from_min_max(Vec2(0, 0), Vec2(1, 1));

                        auto offset = Vec3(0, 0.1f, 0);
                        Vertex[4] v = void;
                        v[0].pos = world_to_render_pos(p0) + offset;
                        v[0].uv = Vec2(right(uvs), bottom(uvs));
                        v[0].color = cmd.color;

                        v[1].pos = world_to_render_pos(p1) + offset;
                        v[1].uv = Vec2(left(uvs), bottom(uvs));
                        v[1].color = cmd.color;

                        v[2].pos = world_to_render_pos(p2) + offset;
                        v[2].uv = Vec2(left(uvs), top(uvs));
                        v[2].color = cmd.color;

                        v[3].pos = world_to_render_pos(p3) + offset;
                        v[3].uv = Vec2(right(uvs), top(uvs));
                        v[3].color = cmd.color;

                        set_texture(cmd.texture);
                        draw_quads(v[]);
                    } break;

                    case Command.Render_Mesh:{
                        assert(shader);
                        auto cmd = cast(Render_Mesh*)cmd_node;
                        assert(shader.uniform_loc_model != -1);
                        set_uniform(shader.uniform_loc_model, &cmd.transform);

                        foreach(ref part; cmd.mesh.parts){
                            auto next_material = &cmd.materials[part.material_index];
                            if(material != next_material){
                                set_material(next_material);
                                material = next_material;
                            }

                            glBindBuffer(GL_ARRAY_BUFFER, g_quad_vbo);
                            glBufferData(GL_ARRAY_BUFFER, cast(GLsizeiptr)(part.vertices.length * Vertex.sizeof), &part.vertices[0], GL_DYNAMIC_DRAW);
                            glDrawArrays(GL_TRIANGLES, 0, cast(uint)part.vertices.length);
                        }
                    } break;

                    case Command.Render_Text:{
                        auto cmd = cast(Render_Text*)cmd_node;
                        material = null;

                        auto p = cmd.pos;
                        switch(cmd.text_align){
                            default: break;

                            case Text_Align.Center_X:{
                                auto text_width = get_text_width(cmd.font, cmd.text);
                                p = p - 0.5f*Vec2(text_width, 0);
                            } break;

                            case Text_Align.Right: assert(0);
                        }

                        render_text(cmd.font, cmd.text, floor(p), cmd.color);
                    } break;

                    case Command.Set_Light:{
                        auto cmd = cast(Set_Light*)cmd_node;
                        if(light != cmd.light)
                            shader_light_source(cmd.light);
                    } break;

                    case Command.Push_Scissor:{
                        // TODO: Allow for a scissor stack!
                        auto cmd = cast(Push_Scissor*)cmd_node;
                        glEnable(GL_SCISSOR_TEST);
                        scissor_enabled = true;
                        auto min_p = min(cmd.scissor);
                        glScissor(
                            cast(int)min_p.x, cast(int)min_p.y,
                            cast(int)width(cmd.scissor), cast(int)height(cmd.scissor)
                        );
                    } break;

                    case Command.Set_Texture:{
                        auto cmd = cast(Set_Texture*)cmd_node;
                        set_texture(cmd.texture);
                    } break;
                }

                cmd_node = cmd_node.next;
            }

            if(scissor_enabled){
                glDisable(GL_SCISSOR_TEST);
            }

            if(pass.flags & Render_Flag_Disable_Color){
                glColorMask(true, true, true, true);
            }

            if(pass.flags & Render_Flag_Disable_Culling){
                glEnable(GL_CULL_FACE);
            }

            if(pass.flags & Render_Flag_Disable_Depth_Test){
                glEnable(GL_DEPTH_TEST);
            }

            pass = pass.next;
        }

        swap_render_backbuffer();
    }

    bool compile_shader(Shader* shader, const(char)[] program_name, const(char)[] vertex_source, const(char)[] fragment_source){
        GLuint program = glCreateProgram();
        if(!program){
            log_error("Unable to create shader {0}.\n", program_name);
            return 0;
        }

        glBindAttribLocation(program, Vertex_Attribute_ID_Pos,            "v_pos");
        glBindAttribLocation(program, Vertex_Attribute_ID_Common,         "v_common");
        glBindAttribLocation(program, Vertex_Attribute_ID_UV,             "v_uv");

        GLuint vertex_shader = compile_shader_pass(GL_VERTEX_SHADER, "Vertex Shader", vertex_source.ptr);
        if(!vertex_shader){
            log_error("Unable to compile vertex shader for program {0}.\n", program_name);
            glDeleteProgram(program);
            return 0;
        }

        GLuint fragment_shader = compile_shader_pass(GL_FRAGMENT_SHADER, "Fragment Shader", fragment_source.ptr);
        if (!fragment_shader){
            // TODO: Better logging function
            log_error("Unable to compile fragment shader for program {0}.\n", program_name);
            glDeleteProgram(program);
            return 0;
        }

        glAttachShader(program, vertex_shader);
        glAttachShader(program, fragment_shader);

        glLinkProgram(program);

        GLuint link_status;
        glGetProgramiv(program, GL_LINK_STATUS, cast(GLint*)&link_status);
        if (link_status == GL_FALSE){
            char[512] buffer;
            glGetProgramInfoLog(program, buffer.length, null, buffer.ptr);
            log_error("Unable to link shader:\n  {0}\n", buffer.ptr);
        }

        glDetachShader(program, fragment_shader);
        glDetachShader(program, vertex_shader);
        glDeleteShader(vertex_shader);
        glDeleteShader(fragment_shader);

        bool success = link_status != GL_FALSE;
        if(success){
            shader.handle = program;
            void get_uniform_loc(GLint* loc, String name){
                *loc = glGetUniformLocation(program, name.ptr);
            }

            void set_texture_index(String name, uint index){
                auto loc = glGetUniformLocation(program, name.ptr);
                if(loc != -1){
                    glUniform1i(loc, index);
                }
            }

            make_uniform_binding(program_name, program, "Constants", Constants_Uniform_Binding);
            make_uniform_binding(program_name, program, "Materials", Materials_Uniform_Binding);
            make_uniform_binding(program_name, program, "Light", Light_Uniform_Binding);
            make_uniform_binding(program_name, program, "Camera", Camera_Uniform_Binding);

            get_uniform_loc(&shader.uniform_loc_model, "mat_model");

            glUseProgram(program);
            set_texture_index("texture_diffuse", Texture_Index_Diffuse);
            glUseProgram(0);
        }
        return success;
    }

    void destroy_shader(Shader* shader){
        glDeleteProgram(*cast(GLuint*)shader);
        shader.handle = 0;
    }

    Render_Pass* add_render_pass(Camera* camera){
        auto result = alloc_type!Render_Pass(g_allocator);
        result.camera = camera;

        if(!g_render_pass_first)
            g_render_pass_first = result;

        if(g_render_pass_last)
            g_render_pass_last.next = result;

        g_render_pass_last = result;
        return result;
    }

    private:

    struct Shader_Material{
        Vec3  tint;
        float pad_1;
        Vec3  specular;
        float shininess;
    }

    void set_material(Material* source){
        Shader_Material dest;
        dest.specular  = source.specular;
        dest.shininess = source.shininess;
        dest.tint      = source.tint;

        glActiveTexture(GL_TEXTURE0 + 0);
        set_texture(source.diffuse_texture);

        glBindBuffer(GL_UNIFORM_BUFFER, g_shader_material_buffer);
        glBufferSubData(GL_UNIFORM_BUFFER, 0, Shader_Material.sizeof, &dest);
    }

    void shader_light_source(Shader_Light* light){
        glBindBuffer(GL_UNIFORM_BUFFER, g_shader_light_buffer);
        glBufferSubData(GL_UNIFORM_BUFFER, 0, Shader_Light.sizeof, light);
    }

    extern(C) void debug_msg_callback(GLenum source, GLenum type, GLuint id, GLenum severity, GLsizei length,
                                      const(GLchar)* message, const(void*) userParam){
        if(severity != GL_DEBUG_SEVERITY_NOTIFICATION){
            log(message[0 .. strlen(message)]);
            log("\n");
        }
    }

    void init_uniform_buffer(GLuint* buffer, GLuint binding_id, size_t buffer_size){
        glGenBuffers(1, buffer);
        glBindBuffer(GL_UNIFORM_BUFFER, *buffer);
        glBindBufferRange(GL_UNIFORM_BUFFER, binding_id, *buffer, 0, buffer_size);
        glBufferData(GL_UNIFORM_BUFFER, buffer_size, null, GL_DYNAMIC_DRAW); // TODO: Is static draw correct? We re-upload every frame.
    }

    void set_viewport(Rect r){
        auto min_p = min(r);
        glViewport(cast(int)min_p.x, cast(int)min_p.y, cast(int)width(r), cast(int)height(r));
    }

    void set_uniform(T)(GLint uniform_loc, T* value){
        if(uniform_loc != -1){
            static if(is(T == Mat4)){
                glUniformMatrix4fv(uniform_loc, 1, GL_TRUE, cast(float*)value);
            }
            else static if(is(T == Vec3)){
                glUniform3f(uniform_loc, value.x, value.y, value.z);
            }
            else{
                static assert(0);
            }
        }
    }

    void set_texture(Texture texture){
        if(g_current_texture != texture){
            glBindTexture(GL_TEXTURE_2D, cast(GLuint)texture);
            g_current_texture = texture;
        }
    }

    void render_text(Font* font, String text, Vec2 baseline, Vec4 color){
        if(font.glyphs.length == 0) return;

        push_frame(g_allocator.scratch);
        scope(exit) pop_frame(g_allocator.scratch);

        auto v_buffer = alloc_array!Vertex(g_allocator.scratch, text.length*4);
        uint v_buffer_used = 0;

        Font_Metrics *metrics = &font.metrics;

        auto pen = baseline;
        uint prev_codepoint = 0;
        foreach(c; text){
            // TODO: Due to kerning, we probably need "space" to be a valid glyph, just not one we render.
            if(c == ' '){
                pen.x += metrics.space_width;
            }
            else{
                // When to apply kerning based on sample code from here:
                // https://freetype.org/freetype2/docs/tutorial/step2.html#:~:text=c.%20Kerning
                auto glyph   = get_glyph(font, c);
                auto kerning = get_codepoint_kerning_advance(font, prev_codepoint, glyph.codepoint);
                pen.x += kerning;

                auto v = v_buffer[v_buffer_used .. v_buffer_used+4];
                v_buffer_used += 4;

                auto min_p = pen + glyph.offset;
                auto bounds = rect_from_min_max(min_p, min_p + Vec2(glyph.width, glyph.height));
                auto uvs = rect_from_min_max(glyph.uv_min, glyph.uv_max);
                set_quad(v, bounds, uvs, color);

                pen.x += cast(float)glyph.advance;
                prev_codepoint = c;
            }
        }

        set_texture(font.texture_id);
        draw_quads(v_buffer[0 .. v_buffer_used]);
    }

    /+
    public void render_enable_color(bool enable){
        // For more information on OpenGL Write Masks, see here:
        // https://www.khronos.org/opengl/wiki/Write_Mask
        glColorMask(enable, enable, enable, enable);
    }

    public void enable_depth_testing(bool enable){
        if(enable)
            glEnable(GL_DEPTH_TEST);
        else
            glDisable(GL_DEPTH_TEST);
    }

    public void enable_culling(bool enable){
        if(enable)
            glEnable(GL_CULL_FACE);
        else
            glDisable(GL_CULL_FACE);
    }+/

    GLuint compile_shader_pass(GLenum pass_type, const(char)* shader_type_str, const(char)* source){
        GLuint shader = glCreateShader(pass_type);
        glShaderSource(shader, 1, &source, null);
        glCompileShader(shader);

        GLint compile_status;
        glGetShaderiv(shader, GL_COMPILE_STATUS, &compile_status);
        if (compile_status == GL_FALSE){
            char[512] buffer;
            glGetShaderInfoLog(shader, buffer.length, null, buffer.ptr);
            log("Unable to compile shader:\n");
            log(buffer[0 .. strlen(&buffer[0])]);
            glDeleteShader(shader);
            shader = 0;
        }

        return shader;
    }

    void make_uniform_binding(String shader_name, GLuint shader_handle, const(char)[] block_name, GLuint binding_id){
        auto block_index = glGetUniformBlockIndex(shader_handle, block_name.ptr);
        if(block_index != GL_INVALID_INDEX){
            glUniformBlockBinding(shader_handle, block_index, binding_id);
        }
    }

    /+
    public void set_viewport(float x, float y, float w, float h){
        glViewport(cast(int)x, cast(int)y, cast(int)w, cast(int)h);
    }

    public void set_constants(uint offset, void *data, uint size){
        glBindBuffer(GL_UNIFORM_BUFFER, g_shader_constants_buffer);
        glBufferSubData(GL_UNIFORM_BUFFER, offset, size, data);
    }

    public void set_shader(Shader shader){
        glUseProgram(cast(GLuint)shader);
    }

    version(none) public void render_test_triangle(Mat4 translate){
        Vec4 color = Vec4(1, 0, 0, 1);
        Vertex_Sprite[3] v = void;
        v[0].pos = Vec3(-0.5f, -0.5f, 0);
        v[0].normal = Vec3(0, 0);
        v[0].uv = Vec2(0, 0);

        v[1].pos = Vec3(0, 0.5f, 0);
        v[1].normal = Vec3(0, 0, 0);
        v[1].uv = Vec2(0, 0);

        v[2].pos = Vec3(0.5, -0.5f, 0);
        v[2].normal = Vec3(0, 0, 0);
        v[2].uv = Vec2(0, 0);

        Mat4 mat_final = transpose(translate);
        set_constants(Shader_Constants.model.offsetof, &mat_final, mat_final.sizeof);

        glBindBuffer(GL_ARRAY_BUFFER, g_quad_vbo);
        glBufferData(GL_ARRAY_BUFFER, cast(GLsizeiptr)(v.length * Vertex.sizeof), &v[0], GL_DYNAMIC_DRAW);
        glDrawArrays(GL_TRIANGLES, 0, cast(uint)v.length);
    }

    public void render_mesh(Mesh* mesh, Mat4 transform){
        auto mat_final = transpose(transform);
        //set_constants(Shader_Constants.model.offsetof, &mat_final, mat_final.sizeof);

        glBindBuffer(GL_ARRAY_BUFFER, g_quad_vbo);
        glBufferData(GL_ARRAY_BUFFER, cast(GLsizeiptr)(mesh.vertices.length * Vertex.sizeof), &mesh.vertices[0], GL_DYNAMIC_DRAW);
        glDrawArrays(GL_TRIANGLES, 0, cast(uint)mesh.vertices.length);
    }
+/
}
