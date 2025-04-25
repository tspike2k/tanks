/*
Authors:   tspike (github.com/tspike2k)
Copyright: Copyright (c) 2025
License:   Boost Software License 1.0 (https://www.boost.org/LICENSE_1_0.txt)
*/

/+
TODO:
    - Particles (Explosions, smoke, etc)
    - Enemy AI
    - Different enemy types (how many are there?)
    - Multiplayer
    - High score tracking
    - Temp saves
    - Levels
    - Tanks should be square (a little less than a meter in size)
    - Debug camera?
    - Debug collision volume display?
    - X mark over defeated enemy position
    - Treadmarks

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

enum Campaign_File_Name = "./build/main.camp"; // TODO: Use a specific folder for campaigns?

enum Max_Bullets_Per_Tank = 5;
enum Max_Mines_Per_Tank   = 3;

enum Mine_Detonation_Time    = 8.0f;
enum Mine_Explosion_End_Time = Mine_Detonation_Time + 1.0f;

enum Grid_Width  = 22;
enum Grid_Height = 16;

enum Difficuly : uint{
    Easy,
    Normal,
    Hard,
    Extreme,
    Impossible,
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

struct Campaign_Map{
    uint id;
    Cmd_Make_Block[] blocks;
}

struct Campaign_Level{
    uint map_id;
    Cmd_Make_Tank[] tanks;
}

struct Campaign{
    Campaign_Info    info;
    Campaign_Map[]   maps;
    Campaign_Level[] levels;
}

bool load_campaign_from_file(Campaign* campaign, String file_name, Allocator* allocator){
    auto scratch = allocator.scratch;
    push_frame(scratch);
    scope(exit) pop_frame(scratch);

    bool success = false;
    auto memory = read_file_into_memory(file_name, scratch);
    if(memory.length){
        auto serializer = Serializer(memory);

        Asset_Header header;
        read(&serializer, to_void(&header));
        //if(verify_asset_header!Campaign_Meta(file_name, &header)){
        if(true){
            // TODO: Get these from Campaign_Info once we start saving that out.
            auto levels_count = 1;
            auto maps_count   = 1;

            campaign.maps   = alloc_array!Campaign_Map(allocator, maps_count);
            campaign.levels = alloc_array!Campaign_Level(allocator, levels_count);

            uint map_index;
            uint level_index;

            // TODO: Switch to using Asset_Section instead
            outer: while(auto section = get_type!Campaign_Section(&serializer)){
                switch(section.type){
                    default: break;

                    case Campaign_Section_Type.Blocks:{
                        auto map = &campaign.maps[map_index++];

                        auto count = section.size / Cmd_Make_Block.sizeof;
                        map.blocks = alloc_array!Cmd_Make_Block(allocator, count);
                        read(&serializer, map.blocks);
                    } break;

                    case Campaign_Section_Type.Tanks:{
                        auto level = &campaign.levels[level_index++];
                        auto count = section.size / Cmd_Make_Tank.sizeof;
                        level.tanks = alloc_array!Cmd_Make_Tank(allocator, count);
                        read(&serializer, level.tanks);
                        break outer; // TODO: Ugly hack! Truncate the campaign file!
                    } break;
                }
            }
            success = !serializer.error;
        }
    }

    if(!success){
        log_error("Unable to load campaign from file {0}\n", file_name);
    }

    return success;
}

// TODO: Gracefully handle the level index being out of bounds. Generate the test level?
// Also handle map_index being invalid.
void load_campaign_level(App_State* s, Campaign* campaign, uint level_index){
    auto world = &s.world;
    world.entities_count = 0;

    auto level = campaign.levels[level_index];
    Campaign_Map* map;
    foreach(ref m; campaign.maps){
        if(m.id == level.map_id){
            map = &m;
        }
    }

    foreach(ref cmd; map.blocks){
        auto e = add_entity(world, Vec2(0, 0), Entity_Type.Block);
        decode(&cmd, e);
    }

    foreach(ref cmd; level.tanks){
        auto e = add_entity(world, Vec2(0, 0), Entity_Type.Tank);
        decode(&cmd, e);

        if(e.player_index == 1){
            s.player_entity_id = e.id;
        }
    }
}

// The main campaign is made up of distinct levels. Levels are constructed and transmitted
// using a command buffer. This simplifies a lot of things.
struct Cmd_Make_Block{
    align(1):
    ubyte  info;
    ushort pos;
}

struct Cmd_Make_Tank{
    align(1):
    ushort info;
    Vec2   pos;
    float  angle;
}

void encode(Cmd_Make_Block* cmd, Entity* e){
    assert(is_valid_block(e));
    ushort x = cast(ushort)e.pos.x;
    ushort y = cast(ushort)e.pos.y;

    cmd.info = ((cast(ubyte)e.block_height) & 0x0f) | (cast(ubyte)e.breakable << 7) & 0xf0;
    cmd.pos  = cast(ushort)((y << 8) | (x));
}

void decode(Cmd_Make_Block* cmd, Entity* e){
    e.block_height = cmd.info & 0x0f;
    e.breakable    = (cmd.info & 0xf0) >> 7;

    ushort x = (cmd.pos)      & 0xff;
    ushort y = (cmd.pos >> 8) & 0xff;
    e.pos    = Vec2(x, y) + Vec2(0.5f, 0.5f);

    assert(is_valid_block(e));
}

void encode(Cmd_Make_Tank* cmd, Entity* e){
    assert(e.type == Entity_Type.Tank);
    if(e.player_index != 0){
        cmd.info = (1 << 15) | cast(ushort)e.player_index;
    }
    else{
        // TODO: Add NPC tank info to the command here
    }

    cmd.pos = e.pos;
    cmd.angle = e.angle;
}

void decode(Cmd_Make_Tank* cmd, Entity* e){
    assert(e.type == Entity_Type.Tank);
    if(cmd.info & (1 << 15)){
        e.player_index = cmd.info & 0xff;
    }
    else{
        // TODO: Add NPC tank info to the command here
    }

    e.pos = cmd.pos;
    e.angle = cmd.angle;
}

struct App_State{
    Allocator main_memory;
    Allocator frame_memory;
    Allocator campaign_memory;

    bool running;
    float t;
    Entity_ID player_entity_id;
    uint      player_destroyed_tanks;

    World world;
    Vec2 mouse_pixel;
    Vec2 mouse_world;

    Entity_ID highlight_entity_id;
    Material* highlight_material;

    Campaign campaign;

    Font font_main;

    Mesh cube_mesh;
    Mesh tank_base_mesh;
    Mesh tank_top_mesh;
    Mesh bullet_mesh;
    Mesh ground_mesh;
    Mesh hole_mesh;
    Mesh half_sphere_mesh;

    Material material_enemy_tank;
    Material material_player_tank;
    Material material_block;
    Material material_ground;
    Material material_eraser;
    Material material_mine;
    Material material_breakable_block;
}

alias Entity_ID = ulong;
enum  Null_Entity_ID = 0;

enum Entity_Type : uint{
    None,
    Block,
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
    uint  player_index;
    uint  block_height; // TODO: Just store the encoded block_info?
    bool  breakable;    // TODO: Just store the encoded block_info?
    float mine_timer;
}

void destroy_entity(Entity* e){
    e.health = 0;
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

bool is_valid_block(Entity* e){
    assert(e.type == Entity_Type.Block);
    bool result = e.block_height >=0 && e.block_height <= 7;
    return result;
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
        case Entity_Type.None:
            assert(0);

        case Entity_Type.Tank:
            e.extents = Vec2(0.55f, 0.324f); break;

        case Entity_Type.Block:
            e.extents = Vec2(0.5f, 0.5f); break;

        case Entity_Type.Bullet:
            e.extents = Vec2(0.25f, 0.25f)*0.5f; break;

        case Entity_Type.Mine:
            e.extents = Vec2(0.25f, 0.25f); break;
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
    assert(inside_grid(p));

    auto e = add_entity(world, p + Vec2(0.5f, 0.5f), Entity_Type.Block);
    e.block_height = block_height;
    return e;
}

void spawn_mine(World* world, Vec2 p, Entity_ID id){
    auto e = add_entity(world, p, Entity_Type.Mine);
    e.parent_id = id;
}

Entity* spawn_bullet(World* world, Entity_ID parent_id, Vec2 p, float angle){
    auto e      = add_entity(world, p, Entity_Type.Bullet);
    e.angle     = angle;
    e.parent_id = parent_id;
    e.health    = 2;
    return e;
}

bool is_dynamic_entity(Entity_Type type){
    bool result = false;
    switch(type){
        default: break;

        case Entity_Type.Tank:
        case Entity_Type.Bullet:
        case Entity_Type.Mine:
            result = true; break;
    }

    return result;
}

void entity_vs_world_bounds(App_State* s, Entity* e){
    Rect aabb = void;
    if(e.type == Entity_Type.Tank){
        aabb = aabb_from_obb(e.pos, e.extents, e.angle);
    }
    else{
        aabb = Rect(e.pos, e.extents);
    }

    Rect world_bounds = rect_from_min_max(Vec2(0, 0), Vec2(Grid_Width, Grid_Height));
    world_bounds = shrink(world_bounds, aabb.extents);
    auto p = aabb.center;

    Entity fake_e; // TODO: This is a hack. Should we break entity seperation and collision event handling into two different functions?
    fake_e.type = Entity_Type.None;

    enum epsilon = 0.01f;
    if(p.x < left(world_bounds)){
        auto hit_dist = left(world_bounds) - p.x;
        resolve_collision(s, e, &fake_e, Vec2(1, 0), hit_dist + epsilon);
    }
    else if(p.x > right(world_bounds)){
        auto hit_dist = p.x - right(world_bounds);
        resolve_collision(s, e, &fake_e, Vec2(-1, 0), hit_dist + epsilon);
    }

    if(p.y < bottom(world_bounds)){
        auto hit_dist = bottom(world_bounds) - p.y;
        resolve_collision(s, e, &fake_e, Vec2(0, 1), hit_dist + epsilon);
    }
    else if(p.y > top(world_bounds)){
        auto hit_dist = p.y - top(world_bounds);
        resolve_collision(s, e, &fake_e, Vec2(0, -1), hit_dist + epsilon);
    }
}

/+
bool obb_vs_world_bounds(Entity* e, Hit_Info* hit){
    bool was_hit = false;

    auto aabb = aabb_from_obb(e.pos, e.extents, e.angle);


    return was_hit;
}+/


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

Material* choose_material(App_State*s, Entity* e){
    Material* result;
    if(e.id == s.highlight_entity_id){
        result = s.highlight_material;
    }
    else{
        switch(e.type){
            default: {
                result = &s.material_block;
            } break;

            case Entity_Type.Tank: {
                if(e.player_index == 0)
                    result = &s.material_enemy_tank;
                else
                    result = &s.material_player_tank;
            } break;

            case Entity_Type.Block: {
                if(is_hole(e)){
                    result = &s.material_ground;
                }
                else{
                    if(!e.breakable)
                        result = &s.material_block;
                    else
                        result = &s.material_breakable_block;
                }
            } break;
        }
    }
    return result;
}

void generate_test_level(App_State* s){
    {
        auto player = add_entity(&s.world, Vec2(2, 2), Entity_Type.Tank);
        s.player_entity_id = player.id;
        player.player_index = 1;
    }

    add_block(&s.world, Vec2(2, 2), 1);

    //add_entity(&s.world, Vec2(-4, -4), Entity_Type.Tank);

    //add_block(&s.world, Vec2(0, 0), 1);
    //add_block(&s.world, Vec2(Grid_Width-1, Grid_Height-1), 1);
    //add_block(&s.world, Vec2(0, Grid_Height-1), 1);
    //add_block(&s.world, Vec2(Grid_Width-1, 0), 1);
}

enum Shape_Type : uint{
    None,
    Circle,
    AABB,
    OBB,
}

struct Shape{
    Shape_Type type;

    Vec2 center;
    union{
        Vec2  extents;
        float radius;
    }
    float angle;
}

Shape get_collision_shape(Entity* e){
    Shape result;
    result.center = e.pos;
    switch(e.type){
        default: assert(0);

        case Entity_Type.Mine:
            result.type    = Shape_Type.Circle;
            result.radius  = e.extents.x;
            break;

        case Entity_Type.Block:{
            result.type    = Shape_Type.AABB;
            result.extents = e.extents;
        } break;

        version(none){
            case Entity_Type.Tank:{
                result.type    = Shape_Type.OBB;
                result.extents = e.extents;
                result.angle   = e.angle;
            } break;
        }

        case Entity_Type.Tank:
        case Entity_Type.Bullet:{
            result.type    = Shape_Type.Circle;
            result.radius  = min(e.extents.x, e.extents.y);
        } break;
    }
    return result;
}

bool is_exploding(Entity* e){
    assert(e.type == Entity_Type.Mine);
    bool result = e.mine_timer > Mine_Detonation_Time;
    return result;
}

void detonate(Entity* e){
    assert(e.type == Entity_Type.Mine);
    if(e.mine_timer < Mine_Detonation_Time)
        e.mine_timer = Mine_Detonation_Time;
}

bool should_handle_overlap(Entity* a, Entity* b){
    if(a.type > b.type)
        swap(a, b);

    bool result = false;
    switch(make_collision_id(a.type, b.type)){
        default: break;

        case make_collision_id(Entity_Type.Block, Entity_Type.Bullet):{
            result = !is_hole(a);
        } break;

        case make_collision_id(Entity_Type.Block, Entity_Type.Tank):{
            result = true;
        } break;

        case make_collision_id(Entity_Type.Bullet, Entity_Type.Bullet):{
            result = true;
        } break;

        case make_collision_id(Entity_Type.Tank, Entity_Type.Bullet):{
            result = true;
        } break;

        // TODO: When the mine overlaps the correct entity, that entity needs to
        // be destroyed. We're abusing the collision resolution system here for that
        // purpose. The resolution system is designed to always seperate colliding pairs
        // and then do any post-processing on them as needed based on their state.
        // Exploding mines shouldn't affect the positions of other entities. For
        // correctness we should cleanly seperate overlap tests, overlap events,
        // entity seperation and related events somehow.
        case make_collision_id(Entity_Type.Bullet, Entity_Type.Mine):{
            result = true;
        } break;

        case make_collision_id(Entity_Type.Tank, Entity_Type.Mine):{
            result = is_exploding(b);
        } break;

        case make_collision_id(Entity_Type.Block, Entity_Type.Mine):{
            result = is_exploding(b) && !is_hole(a) && a.breakable;
        } break;
    }
    return result;
}

bool should_seperate(Entity_Type a, Entity_Type b){
    if(a > b)
        swap(a, b);

    bool result = false;
    switch(make_collision_id(a, b)){
        default: break;

        case make_collision_id(Entity_Type.Block, Entity_Type.Tank):
        case make_collision_id(Entity_Type.Block, Entity_Type.Bullet):
        case make_collision_id(Entity_Type.None, Entity_Type.Tank):
        case make_collision_id(Entity_Type.None, Entity_Type.Bullet):{
            result = true;
        } break;
    }
    return result;
}

bool detect_collision(Entity* a, Entity* b, Vec2* hit_normal, float* hit_depth){
    bool result = false;
    if(should_handle_overlap(a, b)){
        auto sa = get_collision_shape(a);
        auto sb = get_collision_shape(b);

        if(sa.type == Shape_Type.Circle && sb.type == Shape_Type.Circle){
            result = circle_vs_circle(sa.center, sa.radius, sb.center, sb.radius, hit_normal, hit_depth);
        }
        else if(sa.type == Shape_Type.Circle && sb.type == Shape_Type.AABB){
            result = rect_vs_circle(sb.center, sb.extents, sa.center, sa.radius, hit_normal, hit_depth);
        }
        else if(sa.type == Shape_Type.AABB && sb.type == Shape_Type.Circle){
            result = rect_vs_circle(sa.center, sa.extents, sb.center, sb.radius, hit_normal, hit_depth);
        }
    }

    return result;
}

bool is_tank_player(Entity* e){
    assert(e.type == Entity_Type.Tank);
    bool result = e.player_index > 0;
    return result;
}

void add_to_score_if_killed_by_player(App_State* s, Entity* tank, Entity_ID attacker_id){
    assert(tank.type == Entity_Type.Tank);
    if(!is_tank_player(tank)){
        // TODO: Loop through each player to find who controlled the
        // the attacker that shot or placed the mine that defeated the
        // tank
        if(attacker_id == s.player_entity_id){
            s.player_destroyed_tanks++;
        }
    }
}

void resolve_collision(App_State* s, Entity* e, Entity* target, Vec2 normal, float depth){
    if(should_seperate(e.type, target.type) && is_dynamic_entity(e.type)){
        // TODO: Handle energy transfer here somehow
        // Use this as a resource?
        // https://erikonarheim.com/posts/understanding-collision-constraint-solvers/
        e.pos += depth*normal;
        e.vel = reflect(e.vel, normal);
    }

    switch(e.type){
        default: break;

        case Entity_Type.Bullet:{
            if(target.type == Entity_Type.Tank){
                // TODO: Show explosion
                destroy_entity(e);
                destroy_entity(target);
                add_to_score_if_killed_by_player(s, target, e.parent_id);
            }
            else if(target.type == Entity_Type.Bullet){
                // TODO: Show minor explosion
                destroy_entity(e);
            }
            else if(target.type == Entity_Type.Mine){
                destroy_entity(e);
            }
            else{
                if(e.health > 0)
                    e.health--;
                e.angle = atan2(e.vel.y, e.vel.x);
            }
        } break;

        case Entity_Type.Tank:{
            if(target.type == Entity_Type.Mine){
                if(is_exploding(target)){
                    destroy_entity(e);
                    add_to_score_if_killed_by_player(s, e, target.parent_id);
                    // TODO: Show explosion? Or is the mine explosion enough?
                }
            }
        } break;

        case Entity_Type.Mine:{
            if(target.type == Entity_Type.Bullet){
                if(target.type == Entity_Type.Tank || target.type == Entity_Type.Bullet){
                    detonate(e);
                }
            }
            else if(target.type == Entity_Type.Block){
                assert(is_exploding(e));
                destroy_entity(target);
            }
        } break;
    }
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

bool is_hole(Entity* e){
    bool result = e.type == Entity_Type.Block && e.block_height == 0;
    return result;
}

Vec2 integrate(Vec2* vel, Vec2 accel, float dt){
    // Following simi-implicit Euler integration, we update the velocity based on the acceleration
    // before we calculate the entity delta. This is supposed to improve numerical accuracy.
    *vel += accel*dt;
    Vec2 result = accel * 0.5f*(dt*dt) + *vel*dt;
    return result;
}

bool load_font(String file_name, Font* font, Allocator* allocator){
    bool result = false;
    Font source;
    Pixels pixels;
    if(load_font_from_file(file_name, &source, &pixels, allocator)){
        font.metrics = source.metrics;
        font.glyphs  = dup_array(source.glyphs, allocator);
        if(source.kerning_pairs.length && source.kerning_pairs.length == source.kerning_advance.length){
            font.kerning_pairs  = dup_array(source.kerning_pairs, allocator);
            font.kerning_advance = dup_array(source.kerning_advance, allocator);
        }

        font.texture_id = create_texture(pixels.data, pixels.width, pixels.height);
    }
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
        auto main_memory = make_sub_allocator(&memory, Main_Memory_Size);

        s = alloc_type!App_State(&main_memory);
        s.main_memory       = main_memory;
        s.frame_memory      = make_sub_allocator(&memory, Frame_Memory_Size);
        auto scratch_memory = make_sub_allocator(&memory, Scratch_Memory_Size);

        s.main_memory.scratch  = &scratch_memory;
        s.frame_memory.scratch = &scratch_memory;
    }

    /+
    {
        auto allocator = &s.frame_memory;
        foreach(entry; recurse_directory("./build", allocator)){
            push_frame(allocator);
            auto path = get_full_path(&entry, &s.frame_memory);
            log("Name: {0} type: {1}\n", path, entry.type);
            pop_frame(allocator);
        }
    }+/

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

    load_font("./build/test_en.fnt", &s.font_main, &s.main_memory);

    //auto teapot_mesh = load_mesh_from_obj("./build/teapot.obj", &s.main_memory);
    s.cube_mesh        = load_mesh_from_obj("./build/cube.obj", &s.main_memory);
    s.tank_base_mesh   = load_mesh_from_obj("./build/tank_base.obj", &s.main_memory);
    s.tank_top_mesh    = load_mesh_from_obj("./build/tank_top.obj", &s.main_memory);
    s.bullet_mesh      = load_mesh_from_obj("./build/bullet.obj", &s.main_memory);
    s.ground_mesh      = load_mesh_from_obj("./build/ground.obj", &s.main_memory);
    s.hole_mesh        = load_mesh_from_obj("./build/hole.obj", &s.main_memory);
    s.half_sphere_mesh = load_mesh_from_obj("./build/half_sphere.obj", &s.main_memory);

    auto shaders_dir = "./build/shaders";
    Shader shader;
    load_shader(&shader, "default", shaders_dir, &s.frame_memory);

    Shader text_shader;
    load_shader(&text_shader, "text", shaders_dir, &s.frame_memory);

    float target_dt = 1.0f/60.0f;

    ulong current_timestamp = ns_timestamp();
    ulong prev_timestamp    = current_timestamp;

    Shader_Light light = void;
    Vec3 light_color = Vec3(1, 1, 1);
    light.ambient  = light_color*0.75f;
    light.diffuse  = light_color;
    light.specular = light_color;

    setup_basic_material(&s.material_enemy_tank, Vec3(0.2f, 0.2f, 0.4f), 256);
    setup_basic_material(&s.material_player_tank, Vec3(0.2f, 0.2f, 0.8f), 256);
    setup_basic_material(&s.material_ground, Vec3(0.50f, 0.42f, 0.30f), 2);
    setup_basic_material(&s.material_block, Vec3(0.30f, 0.42f, 0.30f), 2);
    setup_basic_material(&s.material_eraser, Vec3(0.8f, 0.2f, 0.2f), 128);
    setup_basic_material(&s.material_breakable_block, Vec3(0.7f, 0.3f, 0.15f), 2);

    s.running = true;

    bool player_turn_left;
    bool player_turn_right;
    bool player_move_forward;
    bool player_move_backward;
    bool send_broadcast;

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

    s.world.next_entity_id = Null_Entity_ID+1;
    version(all){
        if(load_campaign_from_file(&s.campaign, Campaign_File_Name, &s.main_memory)){
            load_campaign_level(s, &s.campaign, 0);
        }
        else{
            generate_test_level(s);
        }
    }
    else{
        generate_test_level(s);
    }

    s.mouse_pixel = Vec2(0, 0);

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
                            switch(btn.id){
                                default: break;

                                case Button_ID.Mouse_Right:{
                                    auto player = get_entity_by_id(&s.world, s.player_entity_id);
                                    if(player){
                                        auto count = get_child_entity_count(&s.world, player.id, Entity_Type.Mine);
                                        if(player && count < Max_Mines_Per_Tank){
                                            spawn_mine(&s.world, player.pos, player.id);
                                        }
                                    }
                                } break;

                                case Button_ID.Mouse_Left:{
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
                                } break;
                            }
                        }
                    } break;

                    case Event_Type.Mouse_Motion:{
                        auto motion = &evt.mouse_motion;
                        s.mouse_pixel = Vec2(motion.pixel_x, motion.pixel_y);
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
            Vec2 hit_normal = void;
            float hit_depth = void;
            foreach(ref e; iterate_entities(&s.world)){
                if(is_dynamic_entity(e.type) && !is_destroyed(&e)){
                    if(e.id == s.player_entity_id){
                        e.vel = Vec2(0, 0);

                        float rot_speed = ((2.0f*PI)*0.5f);
                        if(player_turn_left){
                            e.angle += rot_speed*dt;
                        }
                        if(player_turn_right){
                            e.angle -= rot_speed*dt;
                        }

                        auto turret_dir = s.mouse_world - e.pos;
                        e.turret_angle = atan2(turret_dir.y, turret_dir.x);

                        auto dir = rotate(Vec2(1, 0), e.angle);
                        float speed = 4.0f;
                        if(player_move_forward){
                            e.vel = dir*(speed);
                        }
                        else if(player_move_backward){
                            e.vel = dir*-(speed);
                        }
                    }

                    switch(e.type){
                        default: break;

                        case Entity_Type.Mine:{
                            e.mine_timer += dt;
                            if(e.mine_timer > Mine_Explosion_End_Time){
                                destroy_entity(&e);
                            }
                            else if(e.mine_timer > Mine_Detonation_Time){
                                auto t = normalized_range_clamp(e.mine_timer, Mine_Detonation_Time, Mine_Explosion_End_Time);
                                auto radius = 3.0f * sin(t);
                                e.extents = Vec2(radius, radius);
                            }
                        } break;
                    }

                    // Since no object accelerate in this game, we can simplify integration.
                    e.pos += e.vel*dt;

                    // TODO: Broadphase, Spatial partitioning to limit the number of entitites
                    // we check here.
                    foreach(ref target; iterate_entities(&s.world)){
                        if(is_destroyed(&target) || &target == &e) continue;

                        if(detect_collision(&e, &target, &hit_normal, &hit_depth)){
                            enum epsilon = 0.01f;
                            // TODO: This probably works well enough, but gliding along blocks
                            // at a steep enough angle will cause a tank to noticeably hitch.
                            // What is the best way to solve that using intersection tests?
                            //
                            // Note this also happens with bullets. If a bullet hits two blocks
                            // just right, it'll be regisered as two collisions in one frame.
                            // This will destroy the bullet before it can be reflected properly.
                            // This is a HUGE problem and must be fixed.
                            resolve_collision(s, &e, &target, hit_normal, hit_depth + epsilon);
                            resolve_collision(s, &target, &e, hit_normal*-1.0f, hit_depth + epsilon);
                        }
                    }
                    entity_vs_world_bounds(s, &e);
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
        constants.camera = transpose(mat_camera);
        constants.camera_pos = camera_pos;
        constants.time = s.t;

        light.pos = Vec3(cos(s.t)*18.0f, 2, sin(s.t)*18.0f);

        set_constants(0, &constants, constants.sizeof);
        set_light(&light);
        set_shader(shader);

        // To draw holes in the ground we use a cylinder with inverted normals so the inner faces will be visible
        // when rendering. The mesh for the holes must extend below the surface of the ground mesh, so we need a
        // way to "cut out" a cylindrical shape in the ground through which we can see the hole. This can be
        // achieved by using the dept-buffer to mask off portions of the ground mesh. For this technique
        // to work, holes will need to be rendered before the ground.
        //
        // For each hole, we first draw the hole mesh as we normally would. We then disable culling so the outer
        // faces of the hole mesh will be rendered. We then disable writing to the color buffer and render the mesh
        // again in order to fill the z-buffer with the outer faces of our mesh.
        //
        // Based on information found here:
        // https://gamedev.stackexchange.com/questions/115501/how-to-combine-depth-and-stencil-tests
        // https://www.youtube.com/watch?v=cHhxs12ZfSQ
        // https://www.youtube.com/watch?v=uxXEV91xsSc
        //
        // A similar result can also be achieved by writing to the stencil buffer and discarding
        // the result when drawing the ground. Examples of this are discussed here:
        // https://community.khronos.org/t/masking-away-an-area-of-a-terrain-surface/104810/4
        // https://www.blog.radiator.debacle.us/2012/08/how-to-dig-holes-in-unity3d-terrains.html
        // https://www.youtube.com/watch?v=y-SEiDTbszk
        auto hole_scale  = Vec3(0.70f, 0.25f, 0.70f);
        auto hole_offset = Vec3(0, -0.5f*hole_scale.y+0.01f, 0);
        foreach(ref e; iterate_entities(&s.world)){
            Vec3 p = world_to_render_pos(e.pos);
            if(is_hole(&e)){
                set_material(choose_material(s, &e));
                render_mesh(&s.hole_mesh, mat4_translate(p + hole_offset)*mat4_scale(hole_scale));

                enable_culling(false);
                render_enable_color(false);
                render_mesh(&s.hole_mesh, mat4_translate(p + hole_offset)*mat4_scale(hole_scale));
                render_enable_color(true);
                enable_culling(true);
            }
        }

        set_material(&s.material_ground);
        auto ground_xform = mat4_translate(grid_center)*mat4_scale(Vec3(grid_extents.x, 1.0f, grid_extents.y));
        render_mesh(&s.ground_mesh, ground_xform);

        foreach(ref e; iterate_entities(&s.world)){
            Vec3 p = world_to_render_pos(e.pos);
            switch(e.type){
                default: assert(0);

                case Entity_Type.Block:{
                    assert(is_valid_block(&e));
                    if(!is_hole(&e)){
                        set_material(choose_material(s, &e));

                        float height = 1.0f + 0.5f*cast(float)(e.block_height-1);
                        auto scale = Vec3(1, height, 1);
                        auto pos = p + Vec3(0, height*0.5f, 0);
                        render_mesh(&s.cube_mesh, mat4_translate(pos)*mat4_scale(scale));
                    }
                } break;

                case Entity_Type.Tank:{
                    set_material(choose_material(s, &e));
                    auto mat_tran = mat4_translate(p + Vec3(0, 0.18f, 0));
                    render_mesh(&s.tank_base_mesh, mat_tran*mat4_rot_y(e.angle));
                    render_mesh(&s.tank_top_mesh, mat_tran*mat4_rot_y(e.turret_angle));
                } break;

                case Entity_Type.Bullet:{
                    set_material(choose_material(s, &e));
                    auto mat_tran = mat4_translate(p);
                    //auto mat_tran = mat4_translate(p + Vec3(0, 0.5f, 0)); // TODO: Use this offset when we're done testing the camera
                    render_mesh(&s.bullet_mesh, mat_tran*mat4_rot_y(e.angle));
                } break;

                case Entity_Type.Mine:{
                    // TODO: Dynamic material? This thing needs to blink. Perhaps we should have
                    // a shader for that?
                    if(!is_exploding(&e)){
                        set_material(choose_material(s, &e));
                        render_mesh(&s.half_sphere_mesh, mat4_translate(p)*mat4_scale(Vec3(0.5f, 0.5f, 0.5f)));
                    }
                    else{
                        // TODO: The explosion should spin over time. This would only have any impact
                        // once we add a texture to it.
                        set_material(&s.material_eraser);

                        auto radius = e.extents.x;
                        auto scale = Vec3(radius, radius, radius)*2.0f;
                        render_mesh(&s.half_sphere_mesh, mat4_translate(p)*mat4_scale(scale));
                    }
                } break;
            }
        }

        // TODO: We need to be able to set the camera here. The HUD needs a seperate camera.

        if(editor_is_open){
            editor_render(s);
        }

        camera_extents = Vec2(window.width, window.height)*0.5f;
        camera_pos = Vec3(0, 0, 0);
        mat_proj = orthographic_projection(Rect(Vec2(0, 0), camera_extents));

        constants.camera = transpose(mat_proj.mat);
        constants.camera_pos = camera_pos;
        constants.time = s.t;
        set_constants(0, &constants, constants.sizeof);

        enable_depth_testing(false);
        set_shader(text_shader);
        render_text(&s.font_main, "Testing the text", Vec2(0, 0));
        enable_depth_testing(true);

        render_end_frame();
        end_frame();
    }

    return 0;
}
