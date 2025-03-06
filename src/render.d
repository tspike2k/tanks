/*
Authors:   tspike (github.com/tspike2k)
Copyright: Copyright (c) 2025
License:   Boost Software License 1.0 (https://www.boost.org/LICENSE_1_0.txt)
*/

/+
TODO:

Figure out how to make the API easier to use. We're passing shaders and texture to every single draw function.
What is the best way to handle this? Here's some ideas:
    A) We pass the shader to everything that takes it.
    B) We push a command to the command buffer to set the shader.
    C) We have specific shaders for specific render function. If we need to use a different shader, we make a different function. (draw_quad, draw_water_quad)
    D) Each function takes a shader param, but it uses a default.
+/
//

// TODO: Add destory texture function

import memory;
import assets;
private{
    import display;
    import logging;
}

alias Shader_ID = uint;
alias Texture   = ulong;

enum Render_Shaders_Max  = 16;
enum Max_Quads_Per_Batch = 2048; // TODO: Isn't this a bit high? 512 would be a lot.

struct Vertex{
    Vec3 pos;
    Vec3 normal;
    Vec2 uv;
}

struct Mesh{
    Vertex[] vertices;
}

struct Font{
    Font_Metrics metrics;
    Font_Glyph[] glyphs; // TODO: Make this a hash table?
    Texture      texture;

    alias metrics this;
}

// TODO: Ensure memembers are correctly aligned with both HLSL and GLSL requirements
struct Default_Constants{
    align(16):

    Mat4 camera;
    Vec3 camera_pos;
    float time;
}

Mat4 make_perspective_matrix(float fov_in_degrees, float aspect_ratio){
    float near        = 0.25;
    float far         = Z_Far;

    // TODO: Where did we get this matrix from? Was this from Learning Modern Graphics Programming?
    // Aspect ration correction taken from:
    // https://gamedev.stackexchange.com/questions/120338/what-does-a-perspective-projection-matrix-look-like-in-opengl
    float e = tanf((fov_in_degrees * (PI/180.0f)) / 2.0f);
    auto result = Mat4([
        1.0f / (aspect_ratio*e), 0.0f, 0.0f, 0.0f,
        0.0f, 1.0f / e, 0.0f, 0.0f,
        0.0f, 0.0f, -((near + far) / (far - near)), -((2.0f*far*near) / (far-near)),
        0.0f, 0.0f, -1.0f, 0.0f
    ]);
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

private:

enum Z_Far = 1000.0f;

version(linux){
    version = opengl;
}

version(opengl){
    import math;
    import bind.opengl;

    enum Constants_Uniform_Binding_Index = 0;

    struct Shader{
        GLuint handle;
        GLuint constants_uniform_block_index;
    };

    enum{
        Vertex_Attribute_ID_Pos,
        Vertex_Attribute_ID_Normal,
        Vertex_Attribute_ID_UV,
    }

    alias Quad_Index_Type = GLuint;
    enum Vertex_Indeces_Per_Quad = 6;
    enum Default_Texture_Filter = GL_LINEAR;

    __gshared GLuint                     g_shader_constants_buffer;
    __gshared Shader[Render_Shaders_Max] g_shaders;
    __gshared GLuint                     g_quads_vbo;
    __gshared GLuint                     g_quad_index_buffer;
    __gshared Texture                    g_default_texture;

    const(char)[] Default_Vertex_Shader_Source = q{
        #version 330

        in vec3 v_pos;
        in vec3 v_normal;
        in vec2 v_uv;

        out vec4 f_color;
        out vec2 f_uv;
        out vec3 f_normal;
        out vec3 f_world_pos;
        out vec3 f_camera_pos;

        layout(std140) uniform Constants{
            mat4  mat_camera;
            vec3  camera_pos;
            float time;
        };

        void main(){
            gl_Position = mat_camera*vec4(v_pos, 1);

            //vec4 mesh_color = vec4(1, 0, 0, 1);
            vec4 mesh_color = vec4(0.25, 0.25, 1, 1);
            f_color         = mesh_color;
            f_normal        = v_normal;
            f_uv            = v_uv;
            f_camera_pos    = camera_pos;

            // TODO: For now, model-space is the same as world-space. This will need to change in the future.
            // When we do, we're going to need to need a "normal matrix" to correctly scale our normals
            // from model-space to world-space.
            //
            // See here for more information:
            // https://learnopengl.com/Lighting/Basic-Lighting
            f_world_pos = v_pos;
        }
    };

    const(char)[] Default_Fragment_Shader_Source = q{
        #version 330

        in vec4  f_color;
        in vec2  f_uv;
        in vec3  f_normal;
        in vec3  f_world_pos;
        in vec3  f_camera_pos;

        out vec4 out_color;

        void main(){
            vec3 view_dir    = normalize(f_camera_pos - f_world_pos);
            vec3 light_color = vec3(0.5, 1, 0.5);
            vec3 light_dir   = vec3(0, 0, 1);

            // Phong shading adapted from both learnopengl.com and Tom Dalling's blog on Modern OpenGL.
            float ambient_strength = 0.1;
            vec3 ambient = ambient_strength * light_color * f_color.rgb;

            float diffuse_intensity = max(dot(f_normal, light_dir), 0.0);
            vec3 diffuse = diffuse_intensity * light_color * f_color.rgb;

            /*
            float specular_strength = 0.5;
            vec3 reflect_dir = reflect(-light_dir, f_normal);
            float s = pow(max(dot(view_dir, reflect_dir), 0.0), 32);
            vec3 specular = specular_strength * s * light_color;
*/
            // Blin-phong attempt adapted from here:
            // https://en.wikipedia.org/wiki/Blinn%E2%80%93Phong_reflection_model

            float specular_strength = 1;
            vec3 half_vector = normalize(light_dir + view_dir);
            float specular_intensity = pow(dot(f_normal, half_vector), 32);
            vec3 specular = specular_strength * specular_intensity * light_color;

            vec3 linear_color = ambient + diffuse + specular;
            out_color = vec4(linear_color, f_color.a);
        }
    };


    extern(C) void debug_msg_callback(GLenum source, GLenum type, GLuint id, GLenum severity, GLsizei length,
                                      const(GLchar)* message, const(void*) userParam){

        if(severity != GL_DEBUG_SEVERITY_NOTIFICATION){
            log(message[0 .. strlen(message)]);
            log("\n");
        }
    }

    public Texture create_texture(uint[] pixels, uint width, uint height, uint flags = 0){
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

    public bool render_open(Allocator* allocator){
        assert(allocator.scratch);
        push_frame(allocator.scratch);
        scope(exit) pop_frame(allocator.scratch);

        glEnable(GL_BLEND);
        glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA); // Using premultiplied alpha
        //glEnable(GL_SCISSOR_TEST);

        glEnable(GL_CULL_FACE);
        glCullFace(GL_BACK);
        glFrontFace(GL_CCW); // TODO: I think we really want counter-clockwise winding order, since that's the direction of cos/sin

        glEnable(GL_DEPTH_TEST);
        glDepthMask(GL_TRUE);
        glDepthFunc(GL_LESS);
        glDepthRange(0.0f, Z_Far);
        //glEnable(GL_DEPTH_CLAMP); // TODO: Is this a good idea? Probably not

        // TODO: Do we only need one vao? Figure out what a vao is used for, really
        GLuint vao;
        glGenVertexArrays(1, &vao);
        glBindVertexArray(vao);

        glEnable(GL_DEBUG_OUTPUT);
        glEnable(GL_DEBUG_OUTPUT_SYNCHRONOUS);
        glDebugMessageCallback(&debug_msg_callback, null);

        glGenBuffers(1, &g_quads_vbo);
        glGenBuffers(1, &g_shader_constants_buffer);

        version(none){
            /*
            glGenBuffers(1, &g_common_shader_data_buffer);
            if(g_common_shader_data_buffer == -1){
                log(Cyu_Err "Unable to create buffer for common shader.\n");
            }*/

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

        glBindBuffer(GL_UNIFORM_BUFFER, g_shader_constants_buffer);
        glBindBufferRange(GL_UNIFORM_BUFFER, Constants_Uniform_Binding_Index, g_shader_constants_buffer, 0, Default_Constants.sizeof);
        glBufferData(GL_UNIFORM_BUFFER, Default_Constants.sizeof, null, GL_STATIC_DRAW); // TODO: Is static draw correct? We re-upload eery frame.

        if(!render_compile_shader("default", 0, Default_Vertex_Shader_Source, Default_Fragment_Shader_Source)){
            log("Error: Unable to create default shader. Aborting.\n");
        }

        return true;
    }

    public void render_close(){

    }

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

    bool render_compile_shader(const(char)[] program_name, uint shader_id, const(char)[] vertex_source, const(char)[] fragment_source){
        GLuint program = glCreateProgram();
        if(!program){
            // TODO(tspike): Get error string!
            log("Unable to create shader program.\n");
            return 0;
        }

        glBindAttribLocation(program, Vertex_Attribute_ID_Pos,   "v_pos");
        glBindAttribLocation(program, Vertex_Attribute_ID_Normal, "v_normal");
        glBindAttribLocation(program, Vertex_Attribute_ID_UV,    "v_uv");

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
            Shader *shader = &g_shaders[shader_id];
            shader.handle = program;
            shader.constants_uniform_block_index = glGetUniformBlockIndex(shader.handle, "Constants");
            if(shader.constants_uniform_block_index != GL_INVALID_INDEX){
                glUniformBlockBinding(shader.handle, shader.constants_uniform_block_index, Constants_Uniform_Binding_Index);
            }

            glBindBuffer(GL_ARRAY_BUFFER, g_quads_vbo);

            GLsizei stride = Vertex.sizeof;
            glEnableVertexAttribArray(Vertex_Attribute_ID_Pos);
            glVertexAttribPointer(Vertex_Attribute_ID_Pos, 3, GL_FLOAT, GL_FALSE, stride, cast(GLvoid*)Vertex.pos.offsetof);

            glEnableVertexAttribArray(Vertex_Attribute_ID_Normal);
            glVertexAttribPointer(Vertex_Attribute_ID_Normal, 3, GL_FLOAT, GL_FALSE, stride, cast(GLvoid*)Vertex.normal.offsetof);

            glEnableVertexAttribArray(Vertex_Attribute_ID_UV);
            glVertexAttribPointer(Vertex_Attribute_ID_UV, 2, GL_FLOAT, GL_FALSE, stride, cast(GLvoid*)Vertex.uv.offsetof);
        }
        return success;
    }

    public void render_begin_frame(float width, float height){
        // TODO: Set viewport and the like.

    }

    public void clear_target_to_color(Vec4 color){
        glClearColor(color.r, color.g, color.b, color.a);
        glClearDepth(Z_Far);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    }

    public void set_constants(uint offset, void *data, uint size){
        glBindBuffer(GL_UNIFORM_BUFFER, g_shader_constants_buffer);
        glBufferSubData(GL_UNIFORM_BUFFER, offset, size, data);
    }

    public void render_test_triangle(Mat4 translate){
        Vec4 color = Vec4(1, 0, 0, 1);
        Vertex[3] v;
        v[0].pos = Vec3(-0.5f, -0.5f, 0);
        v[0].normal = Vec3(0, 0);
        v[0].uv = Vec2(0, 0);

        v[1].pos = Vec3(0, 0.5f, 0);
        v[1].normal = Vec3(0, 0, 0);
        v[1].uv = Vec2(0, 0);

        v[2].pos = Vec3(0.5, -0.5f, 0);
        v[2].normal = Vec3(0, 0, 0);
        v[2].uv = Vec2(0, 0);

        Shader* shader = &g_shaders[0];
        glUseProgram(shader.handle);

        Mat4 mat_final = transpose(translate);
        set_constants(0, &mat_final, mat_final.sizeof);

        glBindBuffer(GL_ARRAY_BUFFER, g_quads_vbo);
        glBufferData(GL_ARRAY_BUFFER, cast(GLsizeiptr)(v.length * Vertex.sizeof), &v[0], GL_DYNAMIC_DRAW);
        glDrawArrays(GL_TRIANGLES, 0, cast(uint)v.length);
    }

    public void render_mesh(Mesh* mesh, Mat4 transform){
        Shader* shader = &g_shaders[0];
        glUseProgram(shader.handle);

        auto mat_final = transpose(transform);
        set_constants(0, &mat_final, mat_final.sizeof);

        glBindBuffer(GL_ARRAY_BUFFER, g_quads_vbo);
        glBufferData(GL_ARRAY_BUFFER, cast(GLsizeiptr)(mesh.vertices.length * Vertex.sizeof), &mesh.vertices[0], GL_DYNAMIC_DRAW);
        glDrawArrays(GL_TRIANGLES, 0, cast(uint)mesh.vertices.length);
    }

    public void render_end_frame(){
        swap_render_backbuffer();
    }
}
