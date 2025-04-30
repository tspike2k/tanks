/*
Copyright (c) 2025 tspike2k@github.com
Distributed under the Boost Software License, Version 1.0.
See accompanying file LICENSE_BOOST.txt or copy at http://www.boost.org/LICENSE_1_0.txt
*/

/+
TODO:
    - Add destory texture function


    Make a single shader constants block that is sensibly divided into chunks that can be block
    copied by the appropriate shader pass.

    We need to have data for the following:
        - Per frame data
        - Per pass data
        - Per model data

+/

import memory;
import assets;
private{
    import display;
    import logging;
    import math;

    Allocator* g_allocator;
    Texture    g_current_texture;
}

enum Z_Far  =  1000.0f;
enum Z_Near = -Z_Far;

alias Texture = ulong;

enum{
    Render_Flag_Disable_Culling = (1 << 0),
    Render_Flag_Disable_Color   = (1 << 1),
}

struct Camera{
    Vec3 pos;
    Vec3 target;
    Vec3 up;
}

struct Vertex{
    Vec3 pos;
    Vec2 uv;
    Vec3 normal;
}

struct Mesh{
    Vertex[] vertices;
}

struct Command_Buffer{
    Command_Buffer * next;
    void[] buffer;
    uint   used;
}

struct Render_Pass{
    Render_Pass* next;

    Mat4 camera;
    Vec3 camera_pos;
    ulong flags;

    // TODO: Have buffer blocks, where we allocate more when we run out of space for more commands.
    void[] buffer;
    uint   buffer_used;
}

enum Max_Quads_Per_Batch = 2048; // TODO: Isn't this a bit high? 512 would be a lot.

// TODO: Ensure members are correctly aligned with both HLSL and GLSL requirements
struct Shader_Constants{
    float time;
}

struct Material{
    Vec3  ambient;
    float pad0;
    Vec3  diffuse;
    float pad1;
    Vec3  specular;
    float shininess;
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
        2.0f / (r-l), 0,            0,            -(r+l)/(r-l),
        0,            2.0f / (t-b), 0,            -(t+b)/(t-b),
        0,            0,            -2.0f / (f-n), -(f+n)/(f-n),
        0,            0,            0,            1,
    ]);

    proj.inv = Mat4([
        (r-l) / 2.0f, 0,            0,              (l+r)/2.0f,
        0,            (t-b) / 2.0f, 0,              (t+b)/2.0f,
        0,            0,            (f-n) / -2.0f, -(f+n)/2.0f,
        0,            0,            0,             1,
    ]);
    return proj;
}

Mat4 invert_view_matrix(Mat4 view){
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

Mat4 mat4_orthographic(Rect camera_bounds){
    // Orthographic adapted from here:
    // https://songho.ca/opengl/gl_projectionmatrix.html#ortho
    auto left   = left(camera_bounds);
    auto right  = right(camera_bounds);
    auto top    = top(camera_bounds);
    auto bottom = bottom(camera_bounds);
    auto near   = Z_Near;
    auto far    = Z_Far;

    float a = 2.0f / (right - left);
    float b = 2.0f / (top - bottom);
    float c = -2.0f / (far - near);
    float d = -(right+left) / (right-left);
    float e = -(top+bottom) / (top-bottom);
    float f = -(far+near) / (far - near);

    auto result = Mat4([
        a, 0, 0, d,
        0, b, 0, e,
        0, 0, c, f,
        0, 0, 0, 1,
    ]);
    return result;
}

Mat4 mat4_perspective(float fov_in_degrees, float aspect_ratio){
    float n        = 0.25;
    float f        = Z_Far;

    // TODO: Where did we get this matrix from? Was this from Learning Modern Graphics Programming?
    // Aspect ration correction taken from:
    // https://gamedev.stackexchange.com/questions/120338/what-does-a-perspective-projection-matrix-look-like-in-opengl
    version(all){
        float e = tanf((fov_in_degrees * (PI/180.0f)) / 2.0f);
        auto result = Mat4([
            1.0f / (aspect_ratio*e), 0.0f, 0.0f, 0.0f,
            0.0f, 1.0f / e, 0.0f, 0.0f,
            0.0f, 0.0f, -((n + f) / (f - n)), -((2.0f*f*n) / (f-n)),
            0.0f, 0.0f, -1.0f, 0.0f
        ]);
    }
    else{
        // Adapted from here:
        // https://perry.cz/articles/ProjectionMatrix.xhtml
        //
        // We are appearently using a right-handed coordinate system. This means z-grows positively
        // as it approaches the camera. I'm sure this is fine, but I wonder what the pros have to
        // say about this.
        float fov = fov_in_degrees * (PI/180.0f);
        float x = tanf(fov*0.5f);
        float a = aspect_ratio * (1.0f / x);
        float b = 1.0f / x;
        float c = -(f+n)/(f-n);
        float d = -1;
        float e = -(2.0f*f*n)/(f-n);

        auto result = Mat4([
            a, 0, 0, 0,
            0, b, 0, 0,
            0, 0, c, e,
            0, 0, d, 0
        ]);
        return result;
    }
    return result;
}

Mat4 make_2d_camera_matrix(Rect camera_bounds){
    float l = left(camera_bounds);
    float r = right(camera_bounds);
    float t = top(camera_bounds);
    float b = bottom(camera_bounds);

    // Odd near-far values taken from Allegro-5.
    // TODO: Are there better values to use?
    float n = -1.0f;
    float f =  1.0f;

    // Orhtographic projection matrix calculation code retrieved from Wikipedia:
    // https://en.wikipedia.org/wiki/Orthographic_projection
    auto result = Mat4([
        2.0f / (r - l),  0, 0, 0,
        0, 2.0f / (t-b),    0, 0,
        0, 0, -2.0f/(f-n), 0,
        -((r+l)/(r-l)), -((t+b)/(t-b)), -((f+n)/(f-n)), 1.0f
    ]);

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

void draw_quad(Vertex[] v, Rect r, Rect uvs){
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

void clear_target_to_color(Render_Pass* pass, Vec4 color){
    auto cmd = push_command!Clear_Target(pass);
    cmd.color = color;
}

void set_shader(Render_Pass* pass, Shader* shader){
    auto cmd   = push_command!Set_Shader(pass);
    cmd.shader = shader;
}

void render_mesh(Render_Pass* pass, Mesh* mesh, Material* material, Mat4 transform){
    auto cmd   = push_command!Render_Mesh(pass);
    cmd.mesh      = mesh;
    cmd.material  = material;
    cmd.transform = transform;
}

void render_text(Render_Pass* pass, Font* font, String text, Vec2 pos){
    auto cmd   = push_command!Render_Text(pass);
    cmd.text = text;
    cmd.font = font;
    cmd.pos  = pos;
}

void set_light(Render_Pass* pass, Shader_Light* light){
    auto cmd   = push_command!Set_Light(pass);
    cmd.light = light;
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
}

struct Clear_Target{
    enum Type = Command.Clear_Target;

    Command type;
    Vec4    color;
}

struct Set_Shader{
    enum Type = Command.Set_Shader;
    Command type;
    Shader* shader;
}

struct Render_Mesh{
    enum Type = Command.Render_Mesh;
    Command   type;
    Mesh*     mesh;
    Material* material;
    Mat4      transform;
}

struct Render_Text{
    enum Type = Command.Render_Text;
    Command type;
    Font*   font;
    String  text;
    Vec2    pos;
}

struct Set_Light{
    enum Type = Command.Set_Light;
    Command type;
    Shader_Light* light;
}

void[] push_bytes(Render_Pass* pass, size_t count){
    auto result = pass.buffer[pass.buffer_used .. pass.buffer_used + count];
    pass.buffer_used += count;
    return result;
}

T* push_command(T)(Render_Pass* pass){
    auto result = cast(T*)push_bytes(pass, T.sizeof);
    result.type = T.Type;
    return result;
}

version(linux){
    version = opengl;
}

version(opengl){
    import math;
    import bind.opengl;

    enum Constants_Uniform_Binding = 0;
    enum Material_Uniform_Binding  = 1;
    enum Light_Uniform_Binding     = 2;

    enum{
        Vertex_Attribute_ID_Pos,
        Vertex_Attribute_ID_Normal,
        Vertex_Attribute_ID_UV,
        Vertex_Attribute_ID_Color,
    }

    alias Quad_Index_Type = GLuint;
    enum Vertex_Indeces_Per_Quad = 6;
    enum Default_Texture_Filter = GL_LINEAR;

    __gshared GLuint        g_shader_constants_buffer;
    __gshared GLuint        g_shader_material_buffer;
    __gshared GLuint        g_shader_light_buffer;
    __gshared GLuint        g_quad_vbo;
    __gshared GLuint        g_quad_index_buffer;
    __gshared Texture       g_default_texture;
    __gshared Render_Pass*  g_render_pass_first;
    __gshared Render_Pass*  g_render_pass_last;
    __gshared Rect          g_base_viewport;

    public:

    struct Shader{
        private:

        GLuint handle;
        GLint  uniform_loc_model;
        GLint  uniform_loc_camera;
        GLint  uniform_loc_camera_pos;
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

        glEnableVertexAttribArray(Vertex_Attribute_ID_Normal);
        glVertexAttribPointer(Vertex_Attribute_ID_Normal, 3, GL_FLOAT, GL_FALSE, Vertex.sizeof, cast(GLvoid*)Vertex.normal.offsetof);

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
        init_uniform_buffer(&g_shader_material_buffer, Material_Uniform_Binding, Material.sizeof);
        init_uniform_buffer(&g_shader_light_buffer, Light_Uniform_Binding, Shader_Light.sizeof);

        /*
        if(!compile_shader("default", 0, Default_Vertex_Shader_Source, Default_Fragment_Shader_Source)){
            log("Error: Unable to create default shader. Aborting.\n");
        }*/

        return true;
    }

    void render_close(){

    }

    void render_begin_frame(uint viewport_width, uint viewport_height, Allocator* memory){
        // TODO: Set viewport and the like?
        g_allocator = memory;
        g_render_pass_first = null;
        g_render_pass_last  = null;
        g_base_viewport     = rect_from_min_max(Vec2(0, 0), Vec2(viewport_width, viewport_height));
    }

    void render_end_frame(){
        auto pass = g_render_pass_first;

        while(pass){
            set_viewport(g_base_viewport);

            Shader* shader;
            Shader_Light* light;

            auto reader = Serializer(pass.buffer[0 .. pass.buffer_used]);
            while(bytes_left(&reader) > uint.sizeof){
                auto cmd_type = *cast(Command*)&reader.buffer[reader.buffer_used];
                switch(cmd_type){
                    default:
                        end_stream(&reader);
                        break;

                    case Command.Clear_Target:{
                        auto cmd = eat_type!Clear_Target(&reader);

                        auto color = cmd.color;
                        glClearColor(color.r, color.g, color.b, color.a);
                        glClearDepth(Z_Far);
                        // TODO: Only clear depth if the depth testing is enabled
                        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
                    } break;

                    case Command.Set_Shader:{
                        auto cmd = eat_type!Set_Shader(&reader);
                        if(shader != cmd.shader){
                            shader = cmd.shader;
                            glUseProgram(shader.handle);

                            set_uniform(shader.uniform_loc_camera, &pass.camera);
                            set_uniform(shader.uniform_loc_camera_pos, &pass.camera_pos);
                        }
                    } break;

                    case Command.Render_Mesh:{
                        assert(shader);
                        auto cmd = eat_type!Render_Mesh(&reader);
                        assert(shader.uniform_loc_model != -1);
                        set_uniform(shader.uniform_loc_model, &cmd.transform);
                        set_material(cmd.material);

                        auto mesh = cmd.mesh;

                        glBindBuffer(GL_ARRAY_BUFFER, g_quad_vbo);
                        glBufferData(GL_ARRAY_BUFFER, cast(GLsizeiptr)(mesh.vertices.length * Vertex.sizeof), &mesh.vertices[0], GL_DYNAMIC_DRAW);
                        glDrawArrays(GL_TRIANGLES, 0, cast(uint)mesh.vertices.length);
                    } break;

                    case Command.Render_Text:{
                        auto cmd = eat_type!Render_Text(&reader);
                        render_text(cmd.font, cmd.text, cmd.pos);
                    } break;

                    case Command.Set_Light:{
                        auto cmd = eat_type!Set_Light(&reader);
                        if(light != cmd.light)
                            shader_light_source(cmd.light);
                    } break;
                }
            }

            pass = pass.next;
        }

        swap_render_backbuffer();
    }

    bool compile_shader(Shader* shader, const(char)[] program_name, const(char)[] vertex_source, const(char)[] fragment_source){
        GLuint program = glCreateProgram();
        if(!program){
            // TODO(tspike): Get error string!
            log("Unable to create shader program.\n");
            return 0;
        }

        glBindAttribLocation(program, Vertex_Attribute_ID_Pos,    "v_pos");
        glBindAttribLocation(program, Vertex_Attribute_ID_Normal, "v_normal");
        glBindAttribLocation(program, Vertex_Attribute_ID_UV,     "v_uv");
        glBindAttribLocation(program, Vertex_Attribute_ID_Color,  "v_color");

        GLuint vertex_shader = compile_shader_pass(GL_VERTEX_SHADER, "Vertex Shader", vertex_source.ptr);
        if(!vertex_shader){
            // TODO: Better logging function
            log("Unable to compile vertex shader for program ");
            log(program_name);
            log(".\n");
            glDeleteProgram(program);
            return 0;
        }

        GLuint fragment_shader = compile_shader_pass(GL_FRAGMENT_SHADER, "Fragment Shader", fragment_source.ptr);
        if (!fragment_shader){
            // TODO: Better logging function
            log("Unable to compile fragment shader for program ");
            log(program_name);
            log(".\n");
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
            log("Unable to link shader:\n");
            //log("Unable to link shader:\n{0}\n", fmt_cstr(buffer));
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
                if(*loc == -1){
                    log_warn("Unable to get uniform \"{0}\" for shader \"{1}\".\n", name, program_name);
                }
            }

            make_uniform_binding(program_name, program, "Constants", Constants_Uniform_Binding);
            make_uniform_binding(program_name, program, "Material", Material_Uniform_Binding);
            make_uniform_binding(program_name, program, "Light", Light_Uniform_Binding);

            get_uniform_loc(&shader.uniform_loc_camera, "mat_camera");
            get_uniform_loc(&shader.uniform_loc_camera_pos, "camera_pos");
            get_uniform_loc(&shader.uniform_loc_model, "mat_model");
        }
        return success;
    }

    void destroy_shader(Shader* shader){
        glDeleteProgram(*cast(GLuint*)shader);
        shader.handle = 0;
    }

    Render_Pass* render_pass(Mat4* camera, Vec3 camera_pos){
        auto result = alloc_type!Render_Pass(g_allocator);
        result.camera     = *camera;
        result.camera_pos = camera_pos;

        if(!g_render_pass_first)
            g_render_pass_first = result;

        if(g_render_pass_last)
            g_render_pass_last.next = result;

        // TODO: Make smaller buffers, but do it in blocks.
        result.buffer = alloc_array!void(g_allocator, 1*1024*1024);

        g_render_pass_last = result;
        return result;
    }

    private:

    void set_material(Material* material){
        glBindBuffer(GL_UNIFORM_BUFFER, g_shader_material_buffer);
        glBufferSubData(GL_UNIFORM_BUFFER, 0, Material.sizeof, material);
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

    void render_text(Font* font, String text, Vec2 baseline){
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
                draw_quad(v, bounds, uvs);

                pen.x += cast(float)glyph.advance;
                prev_codepoint = c;
            }
        }

        auto v = v_buffer[0 .. v_buffer_used];

        set_texture(font.texture_id);
        glBindBuffer(GL_ARRAY_BUFFER, g_quad_vbo);
        glBufferData(GL_ARRAY_BUFFER, cast(GLsizeiptr)(v.length * Vertex.sizeof), v.ptr, GL_DYNAMIC_DRAW);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, g_quad_index_buffer);
        glDrawElements(GL_TRIANGLES, cast(GLsizei)(v.length * Vertex_Indeces_Per_Quad), GL_UNSIGNED_INT, cast(GLvoid*)0);
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
        else{
            log_warn("Unable to set binding for uniform block \"{0}\" in shader \"{1}\".\n", block_name, shader_name);
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
