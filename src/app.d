/*
Authors:   tspike (github.com/tspike2k)
Copyright: Copyright (c) 2025
License:   Boost Software License 1.0 (https://www.boost.org/LICENSE_1_0.txt)
*/

/+
    - Static Collisions
    - Dynamic Collisions
    - Enemies
    - Bullets
    - Missiles
    - Mines
    - Particles (Explosions, smoke, etc)
    - Enemy AI
    - Scoring
    - Multiplayer
    - High score tracking
    - Temp saves
    - Levels
    - Tanks should be square (a little less than a meter in size)
+/

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

enum Grid_Width  = 22;
enum Grid_Height = 16;

struct App_State{
    Allocator main_memory;
    Allocator frame_memory;

    float t;
    Entity_ID player_entity_id;
    World world;
}

alias Entity_ID = ulong;
enum  Null_Entity_ID = 0;

enum Entity_Type : uint{
    None,
    Block,
    Hole,
    Tank,
    Bullet,
    Mine,
}

struct Entity{
    Entity_ID   id;
    Entity_Type type;
    Vec2 pos;
    Vec2 vel;
    float angle;
    float turret_angle;
}

struct World{
    Entity_ID   next_entity_id;
    Entity[512] entities;
    uint        entities_count;
}

Entity* add_entity(World* world, Vec2 pos, Entity_Type type){
    Entity* e = &world.entities[world.entities_count++];
    clear_to_zero(*e);
    e.id   = world.next_entity_id++;
    e.type = type;
    e.pos  = pos;
    return e;
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

struct Entity_Message{
    float angle;
    Vec2  pos;
}

Entity* get_entity_by_id(World* world, Entity_ID id){
    Entity* result;

    foreach(ref e; world.entities[0 .. world.entities_count]){
        if(e.id == id){
            result = &e;
            break;
        }
    }

    return result;
}

Entity[] iterate_entities(World* world){
    auto result = world.entities[0 .. world.entities_count];
    return result;
}

Entity* add_block(World* world, uint x, uint y){
    // TODO: We should have different types of blocks. We should be able to set height
    // and if the block is breakable.
    assert(x < Grid_Width);
    assert(y < Grid_Height);


   // Grid cells are relative to the bottom-left of the grid where y grows upwards.
    auto grid_extents = Vec2(Grid_Width, Grid_Height)*0.5f;
    auto p = Vec2(x, y) + Vec2(0.5f, 0.5f) - grid_extents;
    auto e = add_entity(world, p, Entity_Type.Block);
    return e;
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

    //auto teapot_mesh = load_mesh_from_obj("./build/teapot.obj", &s.main_memory);
    auto cube_mesh      = load_mesh_from_obj("./build/cube.obj", &s.main_memory);
    auto tank_base_mesh = load_mesh_from_obj("./build/tank_base.obj", &s.main_memory);
    auto tank_top_mesh  = load_mesh_from_obj("./build/tank_top.obj", &s.main_memory);

    auto shaders_dir = "./build/shaders";
    Shader shader;
    load_shader(&shader, "default", shaders_dir, &s.frame_memory);

    float target_dt = 1.0f/60.0f;

    ulong current_timestamp = ns_timestamp();
    ulong prev_timestamp    = current_timestamp;
    auto camera_polar = Vec3(90.0f, -60.0f, 10.0f); // TODO: Make these in radians eventually?

    Shader_Light light = void;
    Vec3 light_color = Vec3(1, 1, 1);
    light.ambient  = light_color*0.75f;
    light.diffuse  = light_color;
    light.specular = light_color;

    Shader_Material material = void;
    {
        Vec3 material_color = Vec3(0.2f, 0.2f, 0.4f);
        material.ambient   = material_color*0.75f;
        material.diffuse   = material_color;
        material.specular  = material_color;
        material.shininess = 256.0f;
        //material.shininess = 2.0f;
    }

    auto material_ground = zero_type!Shader_Material;
    {
        Vec3 material_color = Vec3(0.50f, 0.42f, 0.30f);
        material_ground.ambient   = material_color*0.75f;
        material_ground.diffuse   = material_color;
        material_ground.specular  = material_color;
        //material.shininess = 256.0f;
        material_ground.shininess = 2.0f;
    }

    auto material_block = zero_type!Shader_Material;
    {
        Vec3 material_color = Vec3(0.30f, 0.42f, 0.30f);
        material_block.ambient   = material_color*0.75f;
        material_block.diffuse   = material_color;
        material_block.specular  = material_color;
        //material.shininess = 256.0f;
        material_block.shininess = 2.0f;
    }

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
    bool move_camera;

    Socket socket;
    String net_port_number = "1654";

    /+
        When programming a netplay lobby, clients can send broadcast messages to look for hosts on the network.
    +/
    Socket_Address client_address;
    auto broadcast_address = make_socket_address("255.255.255.255", net_port_number);
    if(is_host){
        auto host_address = make_socket_address(null, net_port_number);
        if(open_socket(&socket, Socket_Broadcast|Socket_Reause_Address)
        && bind_socket(&socket, &host_address)){
            log("Opened host socket.\n");
        }
    }
    else{
        if(open_socket(&socket, Socket_Broadcast)){
            log("Opened client socket.\n");
        }
    }
    scope(exit) close_socket(&socket);

    {
        auto player = add_entity(&s.world, Vec2(0, 0), Entity_Type.Tank);
        s.player_entity_id = player.id;
    }
    add_block(&s.world, 0, 0);
    add_block(&s.world, Grid_Width-1, Grid_Height-1);

    while(running){
        begin_frame();

        auto window = get_window_info();

version(none){
        sockets_update((&socket)[0 .. 1], &s.frame_memory);

        if(!is_host && send_broadcast){
            log("Sending broadcast now!\n");
            auto msg = "Hello.\n";
            assert(socket.flags & Socket_Broadcast);
            socket_write(&socket, msg.ptr, msg.length, &broadcast_address);
            send_broadcast = false;
        }

        if(socket.events & Socket_Event_Readable){
            char[512] buffer;
            Socket_Address src_address = void;
            // TODO: Limit the number of reads we do on a socket at once. This would help
            // prevent a rogue client from choking out the simulation.
            while(true){
                auto msg = socket_read(&socket, buffer.ptr, buffer.length, &src_address);
                if(msg.length == 0){
                    break;
                }
                else if(is_host){
                    log(cast(char[])msg);
                    client_address = src_address;
                }
                else{
                    auto cmd = cast(Entity_Message*)msg;
                    player.angle = cmd.angle;
                    s.player_pos = Vec3(cmd.pos.x, s.player_pos.y, cmd.pos.y);
                }
            }
        }

        if(socket.events & Socket_Event_Writable){
            if(is_host && is_valid(&client_address)){
                Entity_Message msg = void;
                msg.angle = player.angle;
                msg.pos   = Vec2(s.player_pos.x, s.player_pos.z);
                socket_write(&socket, &msg, msg.sizeof, &client_address);
            }
        }
}

        Event evt;
        while(next_event(&evt)){
            switch(evt.type){
                default: break;

                case Event_Type.Window_Close:{
                    // TODO: Save state before exit in a temp/suspend file.
                    running = false;
                } break;

                case Event_Type.Button:{
                    if(evt.button.id == Button_ID.Mouse_Right){
                        move_camera = evt.button.pressed;
                    }
                } break;

                case Event_Type.Mouse_Motion:{
                    auto motion = &evt.mouse_motion;

                    float speed = 0.12f;
                    /*if(should_zoom_camera){
                        auto amount = motion.rel_y*speed;
                        camera_polar.z = max(camera_polar.z + amount, 0.0001f); // TODO: Clamp the y!
                    }
                    else*/ if(move_camera){
                        camera_polar.x += motion.rel_x*speed;

                        auto amount_y = motion.rel_y*speed;
                        camera_polar.y = clamp(camera_polar.y + amount_y, -78.75f, 64.0f); // TODO: Clamp the y!
                    }
                } break;

                case Event_Type.Key:{
                    auto key = &evt.key;
                    if(is_host){
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
                        }
                    }
                    else{
                        if(key.id == Key_ID_Enter)
                            send_broadcast = key.pressed && !key.is_repeat;
                    }
                } break;
            }
        }

        auto dt = target_dt;
        s.t += dt;

        // Entity simulation
        foreach(ref e; iterate_entities(&s.world)){
            Vec2 delta = Vec2(0, 0);
            if(e.id == s.player_entity_id){
                float rot_speed = (1.0f/4.0f)/(2.0f*PI);
                if(player_turn_left){
                    e.angle += rot_speed;
                }
                if(player_turn_right){
                    e.angle -= rot_speed;
                }

                auto dir = rotate(Vec2(1, 0), e.angle);
                float speed = 1.0f/16.0f;
                if(player_move_forward){
                    delta = dir*speed;
                }
                else if(player_move_backward){
                    delta = dir*-speed;
                }
            }

            e.pos += delta;

            bool is_dynamic_entity = e.type == Entity_Type.Tank || e.type == Entity_Type.Bullet;
            if(is_dynamic_entity){
                 // TODO: This is the world's dumbest collision resolution. Do something smarter here that
                // takes into account the bounds of the entity.
                Rect world_bounds = Rect(Vec2(0, 0), Vec2(Grid_Width, Grid_Height)*0.5f);
                if(e.pos.x < left(world_bounds)){
                    e.pos.x = left(world_bounds);
                }
                else if(e.pos.x > right(world_bounds)){
                    e.pos.x = right(world_bounds);
                }

                if(e.pos.y < bottom(world_bounds)){
                    e.pos.y = bottom(world_bounds);
                }
                else if(e.pos.y > top(world_bounds)){
                    e.pos.y = top(world_bounds);
                }
            }
        }

        current_timestamp = ns_timestamp();
        ulong frame_time = cast(ulong)(dt*1000000000.0f);
        ulong elapsed_time = current_timestamp - prev_timestamp;
        if(elapsed_time < frame_time){
            ns_sleep(frame_time - elapsed_time); // TODO: Better sleep time.
        }
        prev_timestamp = current_timestamp;

        render_begin_frame(&s.frame_memory);

        set_viewport(0, 0, window.width, window.height);
        clear_target_to_color(Vec4(0, 0.05f, 0.12f, 1));

        float aspect_ratio = (cast(float)window.width) / (cast(float)window.height);
        version(none){
            auto camera_pos = Vec3(0, 20, 0.001f); // TODO: For some reason, z can't be zero.
            auto camera_target_pos = Vec3(0, 0, 0);

            auto mat_proj = mat4_perspective(45.0f, aspect_ratio);
            auto mat_view = make_lookat_matrix(camera_pos, camera_target_pos, Vec3(0, 1, 0));
        }
        else{
            auto camera_extents = Vec2((Grid_Width+2), (aspect_ratio*0.5f)*cast(float)(Grid_Height+2))*0.5f;
            auto camera_bounds = Rect(Vec2(0, 0), camera_extents);
            auto mat_proj = mat4_orthographic(camera_bounds);

            auto camera_pos = Vec3(0, 0, 0);
            auto mat_view = mat4_rot_x(45.0f*(PI/180.0f))*mat4_translate(camera_pos);
        }
        auto mat_camera = mat_proj*mat_view;

        Shader_Constants constants;
        constants.camera = transpose(mat_camera);
        constants.camera_pos = camera_pos;
        constants.time = s.t;

        light.pos = Vec3(cos(s.t)*18.0f, 2, sin(s.t)*18.0f);

        set_constants(0, &constants, constants.sizeof);
        set_light(&light);
        set_shader(shader);

        set_material(&material_ground);
        auto ground_xform = mat4_translate(Vec3(Grid_Width, 0, Grid_Height)*-0.5f)*mat4_scale(Vec3(Grid_Width, 1.0f, Grid_Height));
        render_mesh(&ground_mesh, ground_xform);

        foreach(ref e; iterate_entities(&s.world)){
            Vec3 p = Vec3(e.pos.x, 0, -e.pos.y);
            switch(e.type){
                default: assert(0);

                case Entity_Type.Block:{
                    set_material(&material_block);
                    render_mesh(&cube_mesh, mat4_translate(p + Vec3(0, 0.5f, 0)));
                } break;

                case Entity_Type.Tank:{
                    set_material(&material);
                    auto xform = mat4_translate(p + Vec3(0, 0.18f, 0))*mat4_rot_y(e.angle);
                    render_mesh(&tank_base_mesh, xform);
                    render_mesh(&tank_top_mesh, xform);
                } break;
            }
        }

        render_end_frame();

        end_frame();
    }

    return 0;
}
