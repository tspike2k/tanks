/*
Authors:   tspike (github.com/tspike2k)
Copyright: Copyright (c) 2025
License:   Boost Software License 1.0 (https://www.boost.org/LICENSE_1_0.txt)
*/

import display;
import memory;
import logging;
import render;
import math;
import assets;
import files;
import os;
import net;

enum Main_Memory_Size    =  4*1024*1024;
enum Frame_Memory_Size   =  8*1024*1024;
enum Scratch_Memory_Size = 16*1024*1024;

struct App_State{
    Allocator main_memory;
    Allocator frame_memory;

    float t;
    float player_angle;
    Vec3  player_pos;
}

Mesh obj_to_mesh(Obj_Data* obj, Allocator* allocator){
    push_frame(allocator.scratch);
    scope(exit) pop_frame(allocator.scratch);

    Vec3[3] get_points_on_face(Obj_Face* face){
        auto i0 = face.points[0].v-1;
        auto i1 = face.points[1].v-1;
        auto i2 = face.points[2].v-1;

        Vec3[3] result = void;
        result[0] = obj.vertices[i0];
        result[1] = obj.vertices[i1];
        result[2] = obj.vertices[i2];
        return result;
    }

    // TODO: Remove repeat vertices? Doesn't obj do that for us already?
    Mesh mesh;
    mesh.vertices = alloc_array!Vertex(allocator, obj.faces.length*3);
    ulong mesh_vertices_count;

    foreach(i, ref face; obj.faces){
        auto p = get_points_on_face(&face);

        auto v0 = &mesh.vertices[mesh_vertices_count++];
        auto v1 = &mesh.vertices[mesh_vertices_count++];
        auto v2 = &mesh.vertices[mesh_vertices_count++];

        v0.pos = p[0];
        v1.pos = p[1];
        v2.pos = p[2];

        if(obj.normals.length > 0){
            auto i0 = face.points[0].n-1;
            auto i1 = face.points[1].n-1;
            auto i2 = face.points[2].n-1;

            v0.normal = obj.normals[i0];
            v1.normal = obj.normals[i1];
            v2.normal = obj.normals[i2];
        }
    }

    if(obj.normals.length == 0){
        // If the Obj file doesn't supply us with vertex normals, we need to calculate them.
        // We do that by finding the normal of each face on the mesh and adding the result
        // to each connected vertex. Once all the normals are summed, we then normalize
        // the result. Concept found here:
        // https://stackoverflow.com/a/33978584

        struct Normal_Entry{
            Vec3 pos;
            Vec3 normal;
        }

        // TODO: Use a hash table instead? This does work, though.
        uint normals_count;
        auto normals = alloc_array!Normal_Entry(allocator.scratch, obj.faces.length*3);

        Vec3* find_normal(Vec3 pos){
            Vec3* result;
            foreach(ref entry; normals[0 .. normals_count]){
                if(entry.pos.x == pos.x && entry.pos.y == pos.y && entry.pos.z == pos.z){
                    result = &entry.normal;
                    break;
                }
            }
            return result;
        }

        Vec3 *find_or_add_normal(Vec3 pos){
            auto result = find_normal(pos);

            if(!result){
                auto entry = &normals[normals_count++];
                entry.pos = pos;
                result = &entry.normal;
            }
            return result;
        }

        foreach(ref face; obj.faces){
            // Thanks to Inigo Quilez for the suggestion to use the cross product directly
            // without normalizing the result. We only need to normalize when we're finished
            // accumulating all the normals.
            // https://iquilezles.org/articles/normals/

            auto p = get_points_on_face(&face);
            auto n = cross(p[1] - p[0], p[2] - p[0]);

            auto n0 = find_or_add_normal(p[0]);
            auto n1 = find_or_add_normal(p[1]);
            auto n2 = find_or_add_normal(p[1]);

            *n0 += n;
            *n1 += n;
            *n2 += n;
        }

        foreach(ref v; mesh.vertices){
            auto n = *find_normal(v.pos);
            v.normal = normalize(n);
        }
    }

    return mesh;
}

Mesh load_mesh_from_obj(String file_path, Allocator* allocator){
    push_frame(allocator.scratch);
    scope(exit) pop_frame(allocator.scratch);

    auto source = cast(char[])read_file_into_memory(file_path, allocator.scratch);
    auto obj = parse_obj_file(source, allocator.scratch);
    auto result = obj_to_mesh(&obj, allocator);
    return result;
}

bool load_shader(Shader* shader, String name, String path, Allocator* allocator){ // TODO: Take the directory path
    push_frame(allocator.scratch);
    scope(exit) pop_frame(allocator.scratch);

    if(*shader){
        destroy_shader(shader);
    }

    auto scratch = allocator.scratch;
    auto vertex_file_name   = make_file_path(path, concat(name, "_vert.glsl", scratch), scratch);
    auto fragment_file_name = make_file_path(path, concat(name, "_frag.glsl", scratch), scratch);

    auto vertex_source   = cast(char[])read_file_into_memory(vertex_file_name, scratch);
    auto fragment_source = cast(char[])read_file_into_memory(fragment_file_name, scratch);

    // TODO: Error handling?
    auto succeeded = compile_shader(shader, name, vertex_source, fragment_source);

    return succeeded;
}

extern(C) int main(int args_count, char** args){
    auto app_memory = os_alloc(Main_Memory_Size + Scratch_Memory_Size + Frame_Memory_Size, 0);
    scope(exit) os_dealloc(app_memory);

    bool is_host;
    foreach(s; args[0 .. args_count]){
        auto arg = s[0 .. strlen(s)];
        if(arg == "-host"){
            is_host = true;
        }
    }

    App_State* s;
    {
        auto memory = Allocator(app_memory);
        auto main_memory = reserve_memory(&memory, Main_Memory_Size);

        s = alloc_type!App_State(&main_memory);
        s.main_memory = main_memory;
        s.frame_memory   = reserve_memory(&memory, Frame_Memory_Size);
        auto scratch_memory = reserve_memory(&memory, Scratch_Memory_Size);

        s.main_memory.scratch  = &scratch_memory;
        s.frame_memory.scratch = &scratch_memory;
    }

    if(!open_display("Tanks", 1920, 1080, 0)){
        log_error("Unable to open display.\n");
        return 1;
    }
    scope(exit) close_display();

    if(!render_open(&s.main_memory)){
        log_error("Unable to init render subsystem.\n");
        return 2;
    }
    scope(exit) render_close();

    auto teapot_mesh = load_mesh_from_obj("./build/teapot.obj", &s.main_memory);

    auto shaders_dir = "./build/shaders";
    Shader shader;
    load_shader(&shader, "default", shaders_dir, &s.frame_memory);

    float target_dt = 1.0f/60.0f;

    ulong current_timestamp = ns_timestamp();
    ulong prev_timestamp    = current_timestamp;
    auto camera_polar = Vec3(68.0f, -45.0f, 10.0f); // TODO: Make these in radians eventually?

    Shader_Light light = void;
    Vec3 light_color = Vec3(1, 1, 1);
    light.ambient  = light_color*0.25f;
    light.diffuse  = light_color;
    light.specular = light_color;

    Shader_Material material = void;
    Vec3 material_color = Vec3(0.2f, 0.2f, 0.4f);
    material.ambient   = material_color*0.25f;
    material.diffuse   = material_color;
    material.specular  = Vec3(1, 1, 1);
    material.shininess = 256.0f;

    Mesh ground_mesh;
    ground_mesh.vertices = alloc_array!Vertex(&s.main_memory, 6);
    {
        auto n = Vec3(0, 1, 0);
        auto v = ground_mesh.vertices;
        auto bounds = Rect(Vec2(0.5f, 0.5f), Vec2(0.5f, 0.5f));

        v[0].pos = Vec3(left(bounds), 0, bottom(bounds));
        v[1].pos = Vec3(left(bounds), 0, top(bounds));
        v[2].pos = Vec3(right(bounds), 0, top(bounds));

        v[3].pos = Vec3(right(bounds), 0, top(bounds));
        v[4].pos = Vec3(right(bounds), 0, bottom(bounds));
        v[5].pos = Vec3(left(bounds), 0, bottom(bounds));

        static foreach(i; 0 .. 6){
            v[i].normal = n;
        }
    }

    bool running = true;

    bool player_turn_left;
    bool player_turn_right;
    bool player_move_forward;
    bool player_move_backward;
    bool send_broadcast;

    Socket socket;
    Socket broadcast_socket;
    String net_port_number = "1654";

    /+
        When programming a netplay lobby, clients can send broadcast messages to look for hosts on the network.
    +/
    String socket_address = null;
    if(!is_host){
        socket_address = "255.255.255.255";
    }

    open_socket(&socket, socket_address, net_port_number, Socket_Broadcast);
    scope(exit) close_socket(&socket);

    while(running){
        begin_frame();

        auto window = get_window_info();

        sockets_update((&socket)[0 .. 1], &s.frame_memory);

        if(!is_host && send_broadcast){
            log("Sending broadcast now!\n");
            auto msg = "Hello.\n";
            socket_write(&socket, msg.ptr, msg.length);
            send_broadcast = false;
        }

        if(socket.events & Socket_Event_Readable){
            log("We have events to read!\n");
        }

        Event evt;
        while(next_event(&evt)){
            switch(evt.type){
                default: break;

                case Event_Type.Window_Close:{
                    // TODO: Save state before exit in a temp/suspend file.
                    running = false;
                } break;

                case Event_Type.Key:{
                    auto key = &evt.key;
                    switch(key.id){
                        default: break;

                        case Key_ID_A:
                            player_turn_left = key.pressed; break;

                        case Key_ID_D:
                            player_turn_right = key.pressed; break;

                        case Key_ID_W:
                            player_move_forward = key.pressed; break;

                        case Key_ID_S:
                            player_move_backward = key.pressed; break;

                        case Key_ID_Enter:
                            send_broadcast = key.pressed && !key.is_repeat; break;
                    }
                } break;
            }
        }

        // Player movement
        {
            float rot_speed = (1.0f/4.0f)/(2.0f*PI);
            if(player_turn_left){
                s.player_angle += rot_speed;
            }
            if(player_turn_right){
                s.player_angle -= rot_speed;
            }

            auto dir = rotate(Vec2(1, 0), s.player_angle);
            float speed = 1.0f/16.0f;
            if(player_move_forward){
                s.player_pos.x += dir.x*speed;
                s.player_pos.z -= dir.y*speed;
            }
            if(player_move_backward){
                s.player_pos.x -= dir.x*speed;
                s.player_pos.z += dir.y*speed;
            }
        }

        auto dt = target_dt;
        s.t += dt;

        current_timestamp = ns_timestamp();
        ulong frame_time = cast(ulong)(dt*1000000000.0f);
        ulong elapsed_time = current_timestamp - prev_timestamp;
        if(elapsed_time < frame_time){
            ns_sleep(frame_time - elapsed_time); // TODO: Better sleep time.
        }
        prev_timestamp = current_timestamp;

        render_begin_frame(0, 0, &s.frame_memory);

        clear_target_to_color(Vec4(0, 0.05f, 0.12f, 1));

        float aspect_ratio = (cast(float)window.width) / (cast(float)window.height);
        Mat4 mat_proj = make_perspective_matrix(90.0f, aspect_ratio);

        auto camera_target_pos = s.player_pos;
        auto camera_pos = polar_to_world(camera_polar, camera_target_pos);
        auto mat_lookat = make_lookat_matrix(camera_pos, camera_target_pos, Vec3(0, 1, 0));
        auto mat_vp = mat_proj*mat_lookat;

        Shader_Constants constants;
        constants.camera = transpose(mat_vp);
        constants.camera_pos = camera_pos;
        constants.time = s.t;

        light.pos = Vec3(cos(s.t)*18.0f, 2, sin(s.t)*18.0f);

        set_constants(0, &constants, constants.sizeof);
        set_material(&material);
        set_light(&light);
        set_shader(shader);

        auto ground_xform = mat4_translate(Vec3(-8.0f, 0, -8.0f))*mat4_scale(Vec3(16.0f, 1.0f, 16.0f));
        render_mesh(&ground_mesh, ground_xform);

        auto pot1_xform = mat4_translate(s.player_pos) * mat4_rot_y(s.player_angle);
        render_mesh(&teapot_mesh, pot1_xform);

        render_end_frame();

        end_frame();
    }

    return 0;
}
