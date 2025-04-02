/*
Authors:   tspike (github.com/tspike2k)
Copyright: Copyright (c) 2025
License:   Boost Software License 1.0 (https://www.boost.org/LICENSE_1_0.txt)
*/

/+
TODO:
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
    - Level editor

    Interesting article on frequency of packet transmission in multiplayer games
    used in Source games.
    https://developer.valvesoftware.com/wiki/Source_Multiplayer_Networking
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
import editor;

enum Main_Memory_Size    =  4*1024*1024;
enum Frame_Memory_Size   =  8*1024*1024;
enum Scratch_Memory_Size = 16*1024*1024;

enum Max_Bullets_Per_Tank = 5;
enum Max_Mines_Per_Tank   = 3;

enum Grid_Width  = 22;
enum Grid_Height = 16;

enum Difficuly : uint{
    Easy,
    Normal,
    Hard,
    Extreme,
    Impossible,
}

// The main campaign is made up of distinct levels. Levels are constructed and transmitted
// using a command buffer. This simplifies a lot of things.
struct Cmd_Make_Map{
    align(1):
    uint map_id;
    uint blocks_count;
}

struct Cmd_Make_Block{
    align(1):
    ubyte  info;
    ushort pos;
}

struct Cmd_Make_Level{
    align(1):
    uint map_id;
    uint entity_count;
}

struct Cmd_Make_Entity{
    align(1):
    ubyte  info; // Contains both type and player id. Type should usually be Tank
    Vec2  pos;
    float angle;
}

struct Campaign_Info{
    String    name;
    String    author;
    String    date;
    String    description;
    Difficuly difficulty;
    uint      players_count;
    uint      levels_count;
    uint      maps_count;
    uint      next_map_id;
}

struct Map{
    uint map_id;
    Cmd_Make_Block[] blocks;
}

struct Level{
    uint map_id;
    Cmd_Make_Entity[] entities;
}

struct Campaign{
    Campaign_Info info;
    Map[]         maps;
    Level[]       levels;
}

void encode(Cmd_Make_Block* cmd, uint block_height, Vec2 pos){
    ushort x = cast(ushort)pos.x;
    ushort y = cast(ushort)pos.y;

    cmd.info = cast(ubyte)block_height;
    cmd.pos  = cast(ushort)((y << 8) | (x));
}

void decode(Cmd_Make_Block* cmd, uint* block_height, Vec2* pos){
    *block_height= cmd.info;

    ushort x = (cmd.pos)      & 0xff;
    ushort y = (cmd.pos >> 8) & 0xff;
    *pos   = Vec2(x, y);
}

struct App_State{
    Allocator main_memory;
    Allocator frame_memory;
    Allocator campaign_memory;

    bool running;
    float t;
    Entity_ID player_entity_id;
    World world;
    Vec2 mouse_pixel;
    Vec2 mouse_world;

    Campaign campaign;

    Mesh cube_mesh;
    Mesh tank_base_mesh;
    Mesh tank_top_mesh;
    Mesh bullet_mesh;
    Mesh ground_mesh;

    Material material_tank;
    Material material_block;
    Material material_ground;
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
    Entity_ID   parent_id;
    Entity_Type type;

    Vec2  pos;
    Vec2  extents;
    Vec2  vel;
    float angle;
    float turret_angle;
    uint  health;
    uint  block_height;
}

uint get_child_entity_count(World* world, Entity_ID parent_id, Entity_Type type){
    uint result;

    foreach(ref e; iterate_entities(world)){
        if((type == Entity_Type.None || e.type == type) && e.parent_id == parent_id){
            result++;
        }
    }

    return result;
}

struct World{
    Entity_ID   next_entity_id;
    Entity[512] entities;
    uint        entities_count;
}

Entity* add_entity(World* world, Vec2 pos, Entity_Type type){
    Entity* e = &world.entities[world.entities_count++];
    clear_to_zero(*e);
    e.health = 1;
    e.parent_id = Null_Entity_ID;
    e.id   = world.next_entity_id++;
    e.type = type;
    e.pos  = pos;

    final switch(type){
        case Entity_Type.Mine:
        case Entity_Type.None:
            assert(0);

        case Entity_Type.Tank:
            e.extents = Vec2(0.55f, 0.324f); break;

        case Entity_Type.Block:
        case Entity_Type.Hole:
            e.extents = Vec2(0.5f, 0.5f); break;

        case Entity_Type.Bullet:
            e.extents = Vec2(0.25f, 0.25f)*0.5f; break;
    }

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

Entity[] iterate_entities(World* world, size_t starting_index = 0){
    auto result = world.entities[starting_index .. world.entities_count];
    return result;
}

bool inside_grid(Vec2 p){
    bool result = p.x >= 0.0f && p.x < cast(float)Grid_Width
                  && p.y >= 0.0f && p.y < cast(float)Grid_Height;
    return result;
}

Entity* add_block(World* world, Vec2 p, uint block_height){
    // TODO: We should have different types of blocks. We should be able to set height
    // and if the block is breakable.
    assert(inside_grid(p));

    auto e = add_entity(world, p + Vec2(0.5f, 0.5f), Entity_Type.Block);
    e.block_height = block_height;
    return e;
}

Entity* spawn_bullet(World* world, Entity_ID parent_id, Vec2 p, float angle){
    auto e      = add_entity(world, p, Entity_Type.Bullet);
    e.angle     = angle;
    e.parent_id = parent_id;
    e.health    = 2;
    return e;
}

bool is_dynamic_entity(Entity_Type type){
    bool result = type == Entity_Type.Tank || type == Entity_Type.Bullet;
    return result;
}

bool restrict_entity_to_grid(Entity* e, Vec2* hit_normal){
    bool was_hit = false;

    auto aabb = aabb_from_obb(e.pos, e.extents, e.angle);
    auto min_p = Vec2(left(aabb), bottom(aabb));
    auto max_p = Vec2(right(aabb), top(aabb));

    // TODO: This is the world's dumbest collision resolution. Do something smarter here that
    // takes into account the bounds of the entity.
    Rect world_bounds = rect_from_min_max(Vec2(0, 0), Vec2(Grid_Width, Grid_Height));
    if(min_p.x < left(world_bounds)){
        e.pos.x = left(world_bounds) + aabb.extents.x;
        was_hit = true;
        hit_normal.x = 1;
    }
    else if(max_p.x > right(world_bounds)){
        e.pos.x = right(world_bounds) - aabb.extents.x;
        was_hit = true;
        hit_normal.x = -1;
    }

    if(min_p.y < bottom(world_bounds)){
        e.pos.y = bottom(world_bounds) + aabb.extents.y;
        was_hit = true;
        hit_normal.y = 1;
    }
    else if(max_p.y > top(world_bounds)){
        e.pos.y = top(world_bounds) - aabb.extents.y;
        was_hit = true;
        hit_normal.y = -1;
    }

    return was_hit;
}

bool is_destroyed(Entity* e){
    bool result = e.health == 0;
    return result;
}

void remove_destroyed_entities(World* world){
    uint entity_index;
    while(entity_index < world.entities_count){
        auto e = &world.entities[entity_index];
        if(is_destroyed(e)){
            *e = world.entities[world.entities_count-1];
            world.entities_count--;
        }
        else{
            entity_index++;
        }
    }
}

Rect aabb_from_obb(Vec2 p, Vec2 extents, float angle){
    // Adapted from:
    // https://stackoverflow.com/a/71878932
    float c = abs(cos(angle));
    float s = abs(sin(angle));

    auto rotated_extents = Vec2(
        extents.x*c + extents.y*s,
        extents.x*s + extents.y*c
    );
    auto result = Rect(p, rotated_extents);
    return result;
}

ulong make_collision_id(Entity_Type a, Entity_Type b){
    assert(a <= b);
    ulong result = (cast(ulong)b) | ((cast(ulong)a) << 24);
    return result;
}

struct Ray{
    Vec3 pos;
    Vec3 dir;
}

// Based on the following sources:
// https://antongerdelan.net/opengl/raycasting.html
// https://stackoverflow.com/questions/45882951/mouse-picking-miss/45883624#45883624
// https://stackoverflow.com/questions/46749675/opengl-mouse-coordinates-to-space-coordinates/46752492#46752492
//
// Other sources on this topic that were helpful in figuring out how to do this:
// https://guide.handmadehero.org/code/day373/#2978
// https://www.opengl-tutorial.org/miscellaneous/clicking-on-objects/picking-with-a-physics-library/
// https://www.reddit.com/r/gamemaker/comments/c6684w/3d_converting_a_screenspace_mouse_position_into_a/
Ray screen_to_ray(Vec2 screen_p, float screen_w, float screen_h, Mat4_Pair* proj, Mat4_Pair* view){
    auto ndc = Vec2(
        2.0f*(screen_p.x / screen_w) - 1.0f,
        2.0f*(screen_p.y / screen_h) - 1.0f
    );

    // TODO: Account for perspective in case of a perspective view matrix?
    auto eye_p = proj.inv*Vec4(ndc.x, -ndc.y, -1, 0);
    eye_p.z = -1.0f;
    eye_p.w =  0.0f;

    auto origin     = view.inv*Vec4(0, 0, 0, 1);
    auto world_dir  = view.inv*eye_p;
    auto camera_dir = normalize(Vec3(view.mat.m[2][0], view.mat.m[2][1], view.mat.m[2][2]));

    auto result = Ray(world_dir.xyz() + origin.xyz(), camera_dir);
    return result;
}

/+
Vec3 unproject(Vec2 screen_pixel, float screen_width, float screen_height, Mat4_Pair* proj, Mat4_Pair* view){
    auto eye = proj.inv*Vec4(ndc.x, ndc.y, -1.0f, 1.0f);
    eye.z = -1.0f;
    eye.w =  0.0f;
    auto world_p = view.inv * eye;
    auto result = Vec3(world_p.x, world_p.y, world_p.z);
    return result;
}+/

Vec3 project_onto_plane(Vec3 p, Vec3 plane_p, Vec3 plane_n){
    auto result = p - dot(p - plane_p, plane_n)*plane_n;
    return result;
}

bool ray_vs_plane(Ray ray, Vec3 plane_p, Vec3 plane_n, Vec3* hit_p){
    // Ray vs plane formula thanks to:
    // https://lousodrome.net/blog/light/2020/07/03/intersection-of-a-ray-and-a-plane/
    auto denom = dot(ray.dir, plane_n);
    bool result = false;
    if(denom != 0.0f){
        auto t = dot(plane_p - ray.pos, plane_n) / denom;
        *hit_p = ray.pos + ray.dir*t;
        result = true;
    }
    return result;
}

void setup_basic_material(Material* m, Vec3 color, float shininess){
    m.ambient   = color*0.75f;
    m.diffuse   = color;
    m.specular  = color;
    m.shininess = 256.0f;
}

Vec3 world_to_render_pos(Vec2 p){
    auto result = Vec3(p.x, 0, -p.y);
    return result;
}

extern(C) int main(int args_count, char** args){
    auto app_memory = os_alloc(Main_Memory_Size + Scratch_Memory_Size + Frame_Memory_Size, 0);
    scope(exit) os_dealloc(app_memory);

    version(none){
        bool is_host;
        foreach(s; args[0 .. args_count]){
            auto arg = s[0 .. strlen(s)];
            if(arg == "-host"){
                is_host = true;
            }
        }
    }
    else{
        bool is_host = true;
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
    s.cube_mesh      = load_mesh_from_obj("./build/cube.obj", &s.main_memory);
    s.tank_base_mesh = load_mesh_from_obj("./build/tank_base.obj", &s.main_memory);
    s.tank_top_mesh  = load_mesh_from_obj("./build/tank_top.obj", &s.main_memory);
    s.bullet_mesh    = load_mesh_from_obj("./build/bullet.obj", &s.main_memory);
    s.ground_mesh    = load_mesh_from_obj("./build/ground.obj", &s.main_memory);

    auto shaders_dir = "./build/shaders";
    Shader shader;
    load_shader(&shader, "default", shaders_dir, &s.frame_memory);

    float target_dt = 1.0f/60.0f;

    ulong current_timestamp = ns_timestamp();
    ulong prev_timestamp    = current_timestamp;

    Shader_Light light = void;
    Vec3 light_color = Vec3(1, 1, 1);
    light.ambient  = light_color*0.75f;
    light.diffuse  = light_color;
    light.specular = light_color;

    setup_basic_material(&s.material_tank, Vec3(0.2f, 0.2f, 0.4f), 256);
    setup_basic_material(&s.material_ground, Vec3(0.50f, 0.42f, 0.30f), 2);
    setup_basic_material(&s.material_block, Vec3(0.30f, 0.42f, 0.30f), 2);

    s.running = true;

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

    add_entity(&s.world, Vec2(-4, -4), Entity_Type.Tank);

    add_block(&s.world, Vec2(0, 0), 1);
    add_block(&s.world, Vec2(Grid_Width-1, Grid_Height-1), 1);
    add_block(&s.world, Vec2(0, Grid_Height-1), 1);
    add_block(&s.world, Vec2(Grid_Width-1, 0), 1);

    s.mouse_pixel = Vec2(0, 0);

    Vec3 player_center = Vec3(0, 0, 0);

    auto grid_extents = Vec2(Grid_Width, Grid_Height)*0.5f;
    auto grid_center  = Vec3(grid_extents.x, 0, -grid_extents.y);

    while(s.running){
        begin_frame();

        auto window = get_window_info();

        float aspect_ratio = (cast(float)window.width) / (cast(float)window.height);
        auto camera_extents = Vec2((Grid_Width+2), (aspect_ratio*0.5f)*cast(float)(Grid_Height+2))*0.5f;
        auto camera_bounds = Rect(Vec2(0, 0), camera_extents);

        auto mat_proj = orthographic_projection(camera_bounds);

        auto camera_pos = grid_center;
        Mat4_Pair mat_view = void;
        mat_view.mat = mat4_rot_x(45.0f*(PI/180.0f))*mat4_translate(-1.0f*camera_pos);
        mat_view.inv = invert_view_matrix(mat_view.mat);
        auto mat_camera = mat_proj.mat*mat_view.mat;

        auto mouse_picker_ray = screen_to_ray(s.mouse_pixel, window.width, window.height, &mat_proj, &mat_view);
        Vec3 cursor_3d = Vec3(0, 0, 0);
        ray_vs_plane(mouse_picker_ray, Vec3(0, 0, 0), Vec3(0, 1, 0), &cursor_3d);
        s.mouse_world = Vec2(cursor_3d.x, -cursor_3d.z);

        auto dt = target_dt;

        if(editor_is_open){
            editor_simulate(s, target_dt);
        }
        else{
            //import core.stdc.stdio;
            //printf("cursor: %f, %f\n", s.mouse_world.x, s.mouse_world.y);

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
                        s.running = false;
                    } break;

                    case Event_Type.Button:{
                        auto btn = &evt.button;
                        if(btn.pressed){
                            if(btn.id == Button_ID.Mouse_Right){
                                move_camera = evt.button.pressed;
                            }
                            else if(btn.id == Button_ID.Mouse_Left){
                                auto player = get_entity_by_id(&s.world, s.player_entity_id);
                                if(player){
                                    auto count = get_child_entity_count(&s.world, player.id, Entity_Type.Bullet);
                                    if(player && count < Max_Bullets_Per_Tank){
                                        auto angle  = player.turret_angle;
                                        auto dir    = rotate(Vec2(1, 0), angle);
                                        auto p      = player.pos + dir*1.0f;
                                        auto bullet = spawn_bullet(&s.world, player.id, p, angle);
                                        bullet.vel  = dir*4.0f;
                                    }
                                }
                            }
                        }
                    } break;

                    case Event_Type.Mouse_Motion:{
                        auto motion = &evt.mouse_motion;

                        s.mouse_pixel = Vec2(motion.pixel_x, motion.pixel_y);
                        /*float speed = 0.12f;
                        if(should_zoom_camera){
                            auto amount = motion.rel_y*speed;
                            camera_polar.z = max(camera_polar.z + amount, 0.0001f); // TODO: Clamp the y!
                        }
                        else if(move_camera){
                            camera_polar.x += motion.rel_x*speed;

                            auto amount_y = motion.rel_y*speed;
                            camera_polar.y = clamp(camera_polar.y + amount_y, -78.75f, 64.0f); // TODO: Clamp the y!
                        }*/
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

                                case Key_ID_F2:
                                    if(!key.is_repeat && key.pressed)
                                        editor_toggle(s);
                                    break;
                            }
                        }
                        else{
                            if(key.id == Key_ID_Enter)
                                send_broadcast = key.pressed && !key.is_repeat;
                        }
                    } break;
                }
            }

            s.t += dt;

            // Entity simulation
            foreach(ref e; iterate_entities(&s.world)){
                if(is_dynamic_entity(e.type) && !is_destroyed(&e)){
                    // TODO: We should only effect acceleration. Delta would be calculated from this below.
                    Vec2 delta = Vec2(0, 0);
                    Vec2 hit_normal = Vec2(0, 0);
                    if(e.id == s.player_entity_id){
                        player_center = Vec3(e.pos.x, 0, -e.pos.y);

                        float rot_speed = (1.0f/4.0f)/(2.0f*PI);
                        if(player_turn_left){
                            e.angle += rot_speed;
                        }
                        if(player_turn_right){
                            e.angle -= rot_speed;
                        }

                        auto turret_dir = s.mouse_world - e.pos;
                        e.turret_angle = atan2(turret_dir.y, turret_dir.x);

                        auto dir = rotate(Vec2(1, 0), e.angle);
                        float speed = 1.0f/16.0f;
                        if(player_move_forward){
                            delta = dir*speed;
                        }
                        else if(player_move_backward){
                            delta = dir*-speed;
                        }
                    }
                    else{
                        // TODO: Better integration
                        delta = e.vel*dt;
                    }

                    e.pos += delta;

                    if(restrict_entity_to_grid(&e, &hit_normal)){
                        // TODO: This should be designed to work on more than just bullets
                        if(e.type == Entity_Type.Bullet){
                            e.health--;
                            e.vel = reflect(e.vel, hit_normal);
                            e.angle = atan2(e.vel.y, e.vel.x);
                        }
                    }
                }
            }

            // Entity Collisions handling
            // TODO: Should this be part of the simulation loop?
            foreach(ref a; iterate_entities(&s.world, 0)){
                foreach(ref b; iterate_entities(&s.world, 1)){
                    if(a.type > b.type)
                        swap(a, b);

                    auto a_radius = min(a.extents.x, a.extents.y);
                    auto b_radius = min(b.extents.x, b.extents.y);
                    if(circles_overlap(a.pos, a_radius, b.pos, b_radius)){
                        auto collision_id = make_collision_id(a.type, b.type);
                        switch(collision_id){
                            default: break;

                            case make_collision_id(Entity_Type.Tank, Entity_Type.Bullet):{
                                a.health = 0;
                                b.health = 0;
                            } break;
                        }
                    }
                }
            }
        }

        remove_destroyed_entities(&s.world);

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

        Shader_Constants constants;
        constants.camera = transpose(mat_camera); //
        constants.camera_pos = camera_pos;
        constants.time = s.t;

        light.pos = Vec3(cos(s.t)*18.0f, 2, sin(s.t)*18.0f);

        set_constants(0, &constants, constants.sizeof);
        set_light(&light);
        set_shader(shader);

        set_material(&s.material_ground);
        auto ground_xform = mat4_translate(grid_center)*mat4_scale(Vec3(grid_extents.x, 1.0f, grid_extents.y));
        render_mesh(&s.ground_mesh, ground_xform);

        foreach(ref e; iterate_entities(&s.world)){
            Vec3 p = world_to_render_pos(e.pos);
            switch(e.type){
                default: assert(0);

                case Entity_Type.Block:{
                    set_material(&s.material_block);
                    render_mesh(&s.cube_mesh, mat4_translate(p + Vec3(0, 0.5f, 0)));
                } break;

                case Entity_Type.Tank:{
                    set_material(&s.material_tank);
                    auto mat_tran = mat4_translate(p + Vec3(0, 0.18f, 0));
                    render_mesh(&s.tank_base_mesh, mat_tran*mat4_rot_y(e.angle));
                    render_mesh(&s.tank_top_mesh, mat_tran*mat4_rot_y(e.turret_angle));
                } break;

                case Entity_Type.Bullet:{
                    set_material(&s.material_block);
                    auto mat_tran = mat4_translate(p);
                    //auto mat_tran = mat4_translate(p + Vec3(0, 0.5f, 0)); // TODO: Use this offset when we're done testing the camera
                    render_mesh(&s.bullet_mesh, mat_tran*mat4_rot_y(e.angle));
                } break;
            }
        }

        version(all){
            Vec3 p = Vec3(s.mouse_world.x, 0, -s.mouse_world.y);
            set_material(&s.material_block);
            render_mesh(&s.cube_mesh, mat4_translate(p)*mat4_scale(Vec3(0.25f, 0.25f, 0.25f)));
        }

        if(editor_is_open){
            editor_render(s);
        }

        render_end_frame();
        end_frame();
    }

    return 0;
}
