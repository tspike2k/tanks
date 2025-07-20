/*
Authors:   tspike (github.com/tspike2k)
Copyright: Copyright (c) 2025
License:   Boost Software License 1.0 (https://www.boost.org/LICENSE_1_0.txt)
*/

/+
Credits:
    BigKitty1011 for the very helpful "Wii Tanks AI Parameter Sheet"
    TheGoldfishKing for the equally helpful "Tanks_Documentation"

TODO:
    - Particles (Explosions, smoke, etc)
    - High score tracking
    - Better scoring
    - Multiplayer
    - Temp saves
    - More editor features (tank params, level size, etc)
    - Debug collision volume display?
    - Bullet can get lodged between two blocks, destroying it before the player sees it reflected.

Sound effects:
    - Firing missile
    - Dropping mine
    - Mine activating
    - Mine exploding
    - Block being destroyed
    - Blowing up tank
    - Bullets colliding with each other
    - Bullets colliding with wall
    - Tanks moving

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
import gui;
import audio;
import menu;
import random;

enum Main_Memory_Size    =  4*1024*1024;
enum Frame_Memory_Size   =  8*1024*1024;
enum Editor_Memory_Size  =  4*1024*1024;
enum Scratch_Memory_Size = 16*1024*1024;
enum Total_Memory_Size   = Main_Memory_Size + Frame_Memory_Size + Editor_Memory_Size + Scratch_Memory_Size;

enum Audio_Frames_Per_Sec = 44100;

enum Campaign_File_Name = "./build/main.camp"; // TODO: Use a specific folder for campaigns?

enum Max_Mines_Per_Tank   = 3;

enum Mine_Detonation_Time    = 8.0f;
enum Mine_Explosion_End_Time = Mine_Detonation_Time + 1.0f;

enum Mission_Intro_Max_Time = 3.0f;
enum Mission_Start_Max_Time = 3.0f;
enum Mission_End_Max_Time   = 3.0f;

enum Text_White = Vec4(1, 1, 1, 1);

// NOTE: Enemies are limited by the number of bytes that encode a map cell.
enum Max_Enemies = 16;
enum Max_Players = 4;

enum Meters_Per_Treadmark = 0.25f;

enum Skip_Level_Intros = true; // TODO: We should make this based on if we're in the debug mode.

enum Game_Mode : uint{
    None,
    Menu,
    Editor,
    Campaign,
}

bool load_campaign_from_file(Campaign* campaign, String file_name, Allocator* allocator){
    auto scratch = allocator.scratch;
    push_frame(scratch);
    scope(exit) pop_frame(scratch);

    bool success = false;
    auto memory = read_file_into_memory(file_name, scratch);
    if(memory.length){
        auto reader = Serializer(memory, allocator);

        auto header = eat_type!Asset_Header(&reader);
        if(verify_asset_header!Campaign_Meta(file_name, header)){
            read(&reader, *campaign);
            success = !reader.errors && campaign.variants.length > 0;
        }
    }

    if(!success){
        log_error("Unable to load campaign from file {0}\n", file_name);
    }

    return success;
}

bool is_player(Entity* e){
    bool result = (e.cell_info & Map_Cell_Is_Player) != 0;
    return result;
}

bool ray_vs_obstacles(World* world, Vec2 ray_start, Vec2 ray_delta){
    float t_min = 1.0f;
    Vec2 collision_normal = void;
    bool result = false;
    foreach(ref e; iterate_entities(world)){
        if(e.type == Entity_Type.Block){
            auto bounds = Rect(e.pos, e.extents);
            if(ray_vs_rect(ray_start, ray_delta, bounds, &t_min, &collision_normal)){
                result = true;
                break;
            }
        }
    }

    if(ray_vs_world_bounds(ray_start, ray_delta, world.bounds, &t_min, &collision_normal)){
        result = true;
    }

    return result;
}

Entity* spawn_tank(App_State* s, Vec2 pos, Vec2 map_center, ubyte cell_info, uint tank_type_min, uint tank_type_max){
    auto e = add_entity(&s.world, pos, Entity_Type.Tank);

    auto is_player = (cell_info & Map_Cell_Is_Player);
    if(!is_player){
        if(tank_type_min != tank_type_max)
            e.tank_type_index = random_u32_between(&s.rng, tank_type_min, tank_type_max);
        else
            e.tank_type_index = tank_type_min;

        auto tank_info = get_tank_info(&s.campaign, e);

        e.fire_timer.min_delay = tank_info.fire_delay_min;
        e.fire_timer.max_delay = tank_info.fire_delay_min + tank_info.fire_delay_time;
        e.fire_timer.window    = tank_info.fire_window;
        timer_reset(&e.fire_timer, 0, &s.rng);
    }

    // All tanks face towards the center of the map when level begins.
    auto dir = normalize(map_center - e.pos);
    Vec2 facing = void;
    if(abs(dir.x) > abs(dir.y))
        facing = Vec2(sign(dir.x), 0);
    else
        facing = Vec2(0, sign(dir.y));

    auto facing_angle  = atan2(facing.y, facing.x);
    e.turret_angle     = facing_angle;
    e.angle            = facing_angle;
    e.target_aim_angle = facing_angle;
    e.cell_info        = cell_info;

    return e;
}

void load_campaign_level(App_State* s, Campaign* campaign, uint mission_index){
    auto world = &s.world;
    world.entities_count = 0;

    s.session.mission_index = mission_index;
    auto variant = &campaign.variants[s.session.variant_index];
    auto mission = &variant.missions[s.session.mission_index];

    uint next_map_index = mission.map_index_min;
    if(mission.map_index_min != mission.map_index_max){
        // TODO: Support random maps. But pick a map that wasn't chosen last time!
        assert(0);
    }
    s.session.prev_map_index = s.session.map_index;
    s.session.map_index = next_map_index; // TODO: Clamp the mission index to variant.maps.length?

    auto map = &campaign.maps[s.session.map_index];
    auto map_center = Vec2(map.width, map.height)*0.5f;
    s.world.bounds = rect_from_min_max(Vec2(0, 0), Vec2(map.width, map.height));

    foreach(y; 0 .. map.height){
        foreach(x; 0 .. map.width){
            auto p = Vec2(x, y) + Vec2(0.5f, 0.5f);
            auto cell_info = map.cells[x + y * map.width];
            if(cell_info & Map_Cell_Is_Tank){
                auto tank_index = cell_info & Map_Cell_Index_Mask;
                bool is_player = (cell_info & Map_Cell_Is_Player) != 0;

                if(is_player){
                    assert(tank_index >= 0 && tank_index <= 4);
                    if(tank_index == 0){
                        auto e = spawn_tank(s, p, map_center, cell_info, 0, 0);
                        // TODO: We should use an array of of entity_ids that maps to player indeces
                        s.player_entity_id = e.id;
                    }
                }
                else{
                    foreach(ref spawner; mission.enemies){
                        if(spawner.spawn_index == tank_index){
                            spawn_tank(s, p, map_center, cell_info, spawner.type_min, spawner.type_max);
                            break;
                        }
                    }
                }
            }
            else if(cell_info){
                auto e = add_entity(world, p, Entity_Type.Block);
                e.cell_info = cell_info;
            }
        }
    }
}

struct Render_Passes{
    Render_Pass* holes;
    Render_Pass* hole_cutouts;
    Render_Pass* world;
    Render_Pass* hud_rects;
    Render_Pass* hud_text;
}

enum Session_State : uint{
    Inactive,
    Mission_Intro,
    Mission_Start,
    Mission_End,
    Playing_Mission,
    Game_Over,
}

struct Session{
    Session_State state;
    uint  lives;
    uint  variant_index;
    uint  mission_index;
    uint  map_index;
    uint  prev_map_index;
    float timer;

    uint[Max_Players] enemies_defeated;
    uint[Max_Players] total_enemies_defeated;
}

struct Tread_Particle{
    Vec2  pos;
    float angle;
}

struct App_State{
    Allocator main_memory;
    Allocator frame_memory;
    Allocator editor_memory;
    //Allocator campaign_memory; // TODO: Implement this?

    bool      running;
    float     t;
    Entity_ID player_entity_id;

    uint test_index;

    World world;
    Vec2 mouse_pixel;
    Vec2 mouse_world;

    // TODO: These could be moved to the editor now.
    Entity_ID highlight_entity_id;

    Game_Mode mode;
    Campaign  campaign;
    Session   session;

    Menu      menu;
    Menu_ID   next_menu_id;
    Gui_State gui;
    Font font_main;
    Font font_editor_small;

    Xorshift32 rng;

    Sound sfx_fire_bullet;

    Shader shader;
    Shader text_shader;
    Shader rect_shader;

    Mesh cube_mesh;
    Mesh tank_base_mesh;
    Mesh tank_top_mesh;
    Mesh bullet_mesh;
    Mesh ground_mesh;
    Mesh hole_mesh;
    Mesh half_sphere_mesh;

    Tank_Materials[] materials_enemy_tank;
    Material[2] material_player_tank;
    Material material_block;
    Material material_ground;
    Material material_eraser;
    Material material_mine;
    Material material_breakable_block;

    Texture img_blank_mesh;
    Texture img_blank_rect;
    Texture img_x_mark;
    Texture img_tread_marks;
    Texture img_wood;

    bool tread_particles_full;
    uint tread_particles_cursor;
    Tread_Particle[2048] tread_particles;
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

/+
In the original Wii Play minigame "Tanks!", AI controlled tanks make decisions based on timers.
These timers give a limited window of opportunity for the AI to make some sort of decision
(take aim, fire bullet, etc.). The length of the window is always fixed, but the amount of time
between opportunities is randomly selected between a minimum and maximum value.
+/
struct AI_Timer{
    float start;
    float window;
    float min_delay;
    float max_delay;
}

void timer_reset(AI_Timer* timer, float ai_time, Xorshift32* rng){
    timer.start = ai_time + random_f32_between(rng, timer.min_delay, timer.max_delay);
}

void timer_update(AI_Timer* timer, float ai_time, Xorshift32* rng){
    if(ai_time > timer.start + timer.window){
        timer_reset(timer, ai_time, rng);
    }
}

bool has_opportunity(AI_Timer* timer, float ai_time){
    bool result = ai_time > timer.start && ai_time < timer.start + timer.window;
    return result;
}

struct Entity{
    Entity_ID   id;
    Entity_ID   parent_id;
    Entity_Type type;
    uint        tank_type_index;

    Vec2     pos;
    Vec2     extents;
    Vec2     vel;
    float    angle;
    float    turret_angle;
    uint     health;
    Map_Cell cell_info;
    float    mine_timer;
    float    total_meters_moved;

    // AI related data:
    float     ai_time;
    AI_Timer  fire_timer;
    float     aim_timer;

    Vec2      aim_target_pos;
    float     target_angle;
    float     target_aim_angle;
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
    Rect        bounds;
}

enum Enemy_Tank_Main_Color = Vec3(0.6f, 0.5f, 0.3f);

struct Tank_Materials{
    Material[2] materials;
}

// TODO: These are debug values. Final values should be stored in the mission file itself.
Tank_Type[] g_tank_types = [
    {
        // Player
        invisible: false,
        speed: 1.8f,

        bullet_limit:     5,
        bullet_ricochets: 1,
        bullet_speed:     3.0f,
    },
    {
        // Brown
        invisible: false,
        speed: 0,
        main_color: Enemy_Tank_Main_Color,
        alt_color: Vec3(0.45f, 0.22f, 0.13f),

        bullet_limit:     1,
        bullet_ricochets: 1,
        bullet_speed:     3.0f,

        fire_delay_min:  (300.0f)/60.0f,
        fire_delay_time: (30.0f)/60.0f,
        fire_window:     (15.0f)/60.0f,

        aim_timer: 60.0f/60.0f,
        aim_max_angle: deg_to_rad(170),
    },
    {
        // Ash
        invisible: false,
        speed: 1.2f,
        main_color: Enemy_Tank_Main_Color,
        alt_color: Vec3(0.38f, 0.35f, 0.35f),

        bullet_limit:     1,
        bullet_ricochets: 1,
        bullet_speed:     3.0f,

        fire_delay_min:  (180.0f)/60.0f,
        fire_delay_time: (30.0f)/60.0f,
        fire_window:     (15.0f)/60.0f,

        aim_timer: 45.0f/60.0f,
        aim_max_angle: deg_to_rad(40),
    },
    {
        // Teal
        invisible: false,
        speed: 1.0f,
        main_color: Enemy_Tank_Main_Color,
        alt_color: Vec3(0.10f, 0.45f, 0.43f),

        bullet_limit:     1,
        bullet_ricochets: 0,
        bullet_speed:     6.0f,

        fire_delay_min:  (180.0f)/60.0f,
        fire_delay_time: (5.0f)/60.0f,
        fire_window:     (5.0f)/60.0f,

        aim_timer: 8.0f/60.0f,
        aim_max_angle: 0,
    },
    {
        // Pink
        invisible: false,
        speed: 1.2f,
        main_color: Enemy_Tank_Main_Color,
        alt_color: Vec3(0.72f, 0.26f, 0.54f),

        bullet_limit:     3,
        bullet_ricochets: 1,
        bullet_speed:     3.0f,

        fire_delay_min:  (30.0f)/60.0f,
        fire_delay_time: (5.0f)/60.0f,
        fire_window:     (5.0f)/60.0f,

        aim_timer: 20.0f/60.0f,
        aim_max_angle: deg_to_rad(40),
    },
    {
        // Yellow
        invisible: false,
        speed: 1.8f,
        main_color: Enemy_Tank_Main_Color,
        alt_color: Vec3(0.73f, 0.60f, 0.15f),

        bullet_limit:     1,
        bullet_ricochets: 1,
        bullet_speed:     3.0f,

        fire_delay_min:  (180.0f)/60.0f,
        fire_delay_time: (30.0f)/60.0f,
        fire_window:     (15.0f)/60.0f,

        aim_timer: 30.0f/60.0f,
        aim_max_angle: deg_to_rad(40),
    },
    {
        // Purple
        invisible: false,
        speed: 1.8f,
        main_color: Enemy_Tank_Main_Color,
        alt_color: Vec3(0.42f, 0.16f, 0.82f),

        bullet_limit:     5,
        bullet_ricochets: 1,
        bullet_speed:     3.0f,

        fire_delay_min:  (30.0f)/60.0f,
        fire_delay_time: (5.0f)/60.0f,
        fire_window:     (5.0f)/60.0f,

        aim_timer: 20.0f/60.0f,
        aim_max_angle: deg_to_rad(40),
    },
    {
        // Green
        invisible: false,
        speed: 0,
        main_color: Enemy_Tank_Main_Color,
        alt_color: Vec3(0.21f, 0.36f, 0.06f),

        bullet_limit:     2,
        bullet_ricochets: 2,
        bullet_speed:     6.0f,

        fire_delay_min:  (60.0f)/60.0f,
        fire_delay_time: (5.0f)/60.0f,
        fire_window:     (5.0f)/60.0f,

        aim_timer: 30.0f/60.0f,
        aim_max_angle: deg_to_rad(80),
    },
    {
        // White
        invisible: true,
        speed: 1.2f,
        main_color: Enemy_Tank_Main_Color,
        alt_color: Vec3(0.68f, 0.70f, 0.73f),

        bullet_limit:     5,
        bullet_ricochets: 1,
        bullet_speed:     3.0f,

        fire_delay_min:  (30.0f)/60.0f,
        fire_delay_time: (5.0f)/60.0f,
        fire_window:     (5.0f)/60.0f,

        aim_timer: 30.0f/60.0f,
        aim_max_angle: deg_to_rad(40),
    },
    {
        // Black
        invisible: false,
        speed: 2.4f,
        main_color: Enemy_Tank_Main_Color,
        alt_color: Vec3(0.15f, 0.18f, 0.20f),

        bullet_limit:     3,
        bullet_ricochets: 0,
        bullet_speed:     6.0f,

        fire_delay_min:  (60.0f)/60.0f,
        fire_delay_time: (5.0f)/60.0f,
        fire_window:     (5.0f)/60.0f,

        aim_timer: 20.0f/60.0f,
        aim_max_angle: deg_to_rad(5),
    },
];

bool is_valid_block(Entity* e){
    assert(e.type == Entity_Type.Block);
    ubyte index = e.cell_info & Map_Cell_Index_Mask;
    bool result = index >= 0 && index <= 7;
    return result;
}

void make_entity(Entity* e, Entity_ID id, Vec2 pos, Entity_Type type){
    clear_to_zero(*e);
    e.health = 1;
    e.parent_id = Null_Entity_ID;
    e.id   = id;
    e.type = type;
    e.pos  = pos;

    final switch(type){
        case Entity_Type.None:
            assert(0);

        case Entity_Type.Tank:
            e.extents = Vec2(0.55f, 0.324f); break;

        case Entity_Type.Block:
            e.extents = Vec2(0.5f, 0.5f);
            break;

        case Entity_Type.Bullet:
            e.extents = Vec2(0.25f, 0.25f)*0.5f; break;

        case Entity_Type.Mine:
            e.extents = Vec2(0.25f, 0.25f); break;
    }
}

Entity* add_entity(World* world, Vec2 pos, Entity_Type type){
    Entity* e = &world.entities[world.entities_count++];
    make_entity(e, world.next_entity_id++, pos, type);
    return e;
}

Mesh obj_to_mesh(Obj_Data* obj_data, Allocator* allocator){
    push_frame(allocator.scratch);
    scope(exit) pop_frame(allocator.scratch);

    Mesh result;
    result.parts = alloc_array!Mesh_Part(allocator, obj_data.models_count);
    auto model = obj_data.model_first;
    foreach(part_index, ref part; result.parts){
        part.vertices = alloc_array!Vertex(allocator, model.faces.length*3);

        part.material_index = model.material_index;

        foreach(face_index, ref face; model.faces){
            auto v0 = &part.vertices[0 + face_index*3];
            auto v1 = &part.vertices[1 + face_index*3];
            auto v2 = &part.vertices[2 + face_index*3];

            v0.pos = obj_data.vertices[face.points[0].v-1];
            v1.pos = obj_data.vertices[face.points[1].v-1];
            v2.pos = obj_data.vertices[face.points[2].v-1];

            if(obj_data.normals.length){
                v0.normal = obj_data.normals[face.points[0].n-1];
                v1.normal = obj_data.normals[face.points[1].n-1];
                v2.normal = obj_data.normals[face.points[2].n-1];
            }

            if(obj_data.uvs.length){
                v0.uv = obj_data.uvs[face.points[0].uv-1];
                v1.uv = obj_data.uvs[face.points[1].uv-1];
                v2.uv = obj_data.uvs[face.points[2].uv-1];
            }
        }

        if(obj_data.normals.length == 0){
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
            auto normals = alloc_array!Normal_Entry(allocator.scratch, model.faces.length*3);

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

            foreach(ref face; model.faces){
                // Thanks to Inigo Quilez for the suggestion to use the cross product directly
                // without normalizing the result. We only need to normalize when we're finished
                // accumulating all the normals.
                // https://iquilezles.org/articles/normals/

                Vec3[3] p = void;
                p[0] = obj_data.vertices[face.points[0].v-1];
                p[1] = obj_data.vertices[face.points[1].v-1];
                p[2] = obj_data.vertices[face.points[2].v-1];

                auto n = cross(p[1] - p[0], p[2] - p[0]);

                auto n0 = find_or_add_normal(p[0]);
                auto n1 = find_or_add_normal(p[1]);
                auto n2 = find_or_add_normal(p[1]);

                *n0 += n;
                *n1 += n;
                *n2 += n;
            }

            foreach(ref v; part.vertices){
                auto n = *find_normal(v.pos);
                v.normal = normalize(n);
            }
        }

        model = model.next;
    }

    return result;
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

void spawn_mine(World* world, Vec2 p, Entity_ID id){
    auto e = add_entity(world, p, Entity_Type.Mine);
    e.parent_id = id;
}

Entity* spawn_bullet(World* world, Entity_ID parent_id, Vec2 p, float angle, Tank_Type* tank_info){
    auto dir    = vec2_from_angle(angle);
    auto e      = add_entity(world, p + dir*1.01f, Entity_Type.Bullet);
    e.angle     = angle;
    e.parent_id = parent_id;
    e.health    = tank_info.bullet_ricochets+1;
    e.vel       = dir*tank_info.bullet_speed;
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

Campaign_Map* get_current_map(App_State* s){
    auto map = &s.campaign.maps[s.session.map_index];
    return map;
}

void entity_vs_world_bounds(App_State* s, Entity* e){
    Rect aabb = void;
    if(e.type == Entity_Type.Tank){
        aabb = aabb_from_obb(e.pos, e.extents, e.angle);
    }
    else{
        aabb = Rect(e.pos, e.extents);
    }

    auto world_bounds = shrink(s.world.bounds, aabb.extents);
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

bool is_destroyed(Entity* e){
    bool result = e.health == 0;
    return result;
}

void remove_destroyed_entities(World* world){
    uint entity_index;
    while(entity_index < world.entities_count){
        auto e = &world.entities[entity_index];
        if(is_destroyed(e) && e.type != Entity_Type.Tank){
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

bool ray_vs_world_bounds(Vec2 ray_start, Vec2 ray_delta, Rect bounds, float* t_min, Vec2* hit_normal){
    auto delta_sign = Vec2(signf(ray_delta.x), signf(ray_delta.y));

    auto edge_x = bounds.extents.x * delta_sign.x + bounds.center.x;
    auto edge_y = bounds.extents.y * delta_sign.y + bounds.center.y;
    auto x_normal = Vec2(-delta_sign.x, 0);
    auto y_normal = Vec2(0, -delta_sign.y);

    bool result = false;
    if(ray_vs_segment(ray_start, ray_delta, Vec2(edge_x, bounds.center.y), x_normal, t_min)){
        *hit_normal = x_normal;
        result = true;
    }

    if(ray_vs_segment(ray_start, ray_delta, Vec2(bounds.center.x, edge_y), y_normal, t_min)){
        *hit_normal = y_normal;
        result = true;
    }

    return result;
}

bool ray_vs_plane(Vec3 ray_start, Vec3 ray_dir, Vec3 plane_p, Vec3 plane_n, Vec3* hit_p){
    // Ray vs plane formula thanks to:
    // https://lousodrome.net/blog/light/2020/07/03/intersection-of-a-ray-and-a-plane/
    auto denom = dot(ray_dir, plane_n);
    bool result = false;
    if(denom != 0.0f){
        auto t = dot(plane_p - ray_start, plane_n) / denom;
        *hit_p = ray_start + ray_dir*t;
        result = true;
    }
    return result;
}

void setup_basic_material(Material* m, Texture diffuse_texture, Vec3 tint = Vec3(0, 0, 0), float shininess = 2.0f){
    m.diffuse_texture = diffuse_texture;
    m.specular        = Vec3(1, 1, 1); // TODO: Use a specular texture?
    m.shininess       = shininess;
    m.tint            = tint;
}

ubyte get_player_index(Entity* e){
    assert(e.type == Entity_Type.Tank);
    assert(e.cell_info & Map_Cell_Is_Player);
    ubyte result = e.cell_info & Map_Cell_Index_Mask;
    return result;
}

bool is_breakable(Entity* e){
    assert(e.type == Entity_Type.Block);
    bool result = (e.cell_info & Map_Cell_Is_Breakable) != 0;
    return result;
}

void generate_test_level(App_State* s){
    {
        auto player = add_entity(&s.world, Vec2(2, 2), Entity_Type.Tank);
        s.player_entity_id = player.id;
        player.cell_info |= Map_Cell_Is_Player;
    }
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
            result = is_exploding(b) && !is_hole(a) && is_breakable(a);
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
    bool result = (e.cell_info & Map_Cell_Is_Player) != 0;
    return result;
}

void add_to_score_if_killed_by_player(App_State* s, Entity* tank, Entity_ID attacker_id){
    assert(tank.type == Entity_Type.Tank);
    if(!is_tank_player(tank)){
        // TODO: Loop through each player to find who controlled the
        // the attacker that shot or placed the mine that defeated the
        // tank
        if(attacker_id == s.player_entity_id){
            auto player_index = 0;
            s.session.enemies_defeated[player_index]++;
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
    bool result = e.type == Entity_Type.Block && (e.cell_info & Map_Cell_Index_Mask) == 0;
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
            font.kerning_pairs   = dup_array(source.kerning_pairs, allocator);
            font.kerning_advance = dup_array(source.kerning_advance, allocator);
        }

        font.texture_id = create_texture(pixels.data, pixels.width, pixels.height);
    }
    else{
        log_error("Unable to load font from file {0}\n", file_name);
    }
    return result;
}

Mat4_Pair make_hud_camera(uint window_width, uint window_height){
    auto extents = Vec2(window_width, window_height)*0.5f;
    auto result = orthographic_projection(Rect(extents, extents));
    return result;
}

Material[] choose_materials(App_State* s, Entity* e, bool highlighted){
    Material[] result;
    if(e.id != s.highlight_entity_id && !highlighted){
        switch(e.type){
            default: {
                result = (&s.material_block)[0..1];
            } break;

            case Entity_Type.Mine:{
                if(is_exploding(e)){
                    // TODO: The explosion should spin over time. This would only have any impact
                    // once we add a texture to it.
                    result = (&s.material_eraser)[0..1]; // TODO: Have a dedicated explosion material
                }
                else{
                    result = (&s.material_block)[0..1];
                }
            } break;

            case Entity_Type.Tank: {
                if(is_tank_player(e))
                    result = s.material_player_tank[];
                else{
                    auto entry = &s.materials_enemy_tank[e.tank_type_index];
                    result = entry.materials[];
                }

            } break;

            case Entity_Type.Block: {
                if(is_hole(e)){
                    result = (&s.material_ground)[0..1];
                }
                else{
                    if(!is_breakable(e))
                        result = (&s.material_block)[0..1];
                    else
                        result = (&s.material_breakable_block)[0..1];
                }
            } break;
        }
    }
    else{
        result = (&s.material_eraser)[0..1];
    }
    return result;
}

// TODO: We could change "highlighted" to some form of flag
void render_entity(App_State* s, Entity* e, Render_Passes rp, bool highlighted = false){
    Material[] materials = choose_materials(s, e, highlighted);

    Vec3 p = world_to_render_pos(e.pos);
    switch(e.type){
        default: break;

        case Entity_Type.Block:{
            assert(is_valid_block(e));
            if(!is_hole(e)){
                auto block_height = (e.cell_info & Map_Cell_Index_Mask);
                float height = 1.0f + 0.5f*cast(float)(block_height-1);
                auto scale = Vec3(1, height, 1);
                auto pos = p + Vec3(0, height*0.5f, 0);

                render_mesh(
                    rp.world, &s.cube_mesh, materials,
                    mat4_translate(pos)*mat4_scale(scale)
                );
            }
            else{
                // A hole is modeled using an inside-out cylinder. This way the inner
                // faces will be visible when rendering. In order to see the hole through
                // the ground mesh, we need a way to "cut out" part of the ground. This
                // can be done by using the depth-buffer to mask off portions of the mesh.
                //
                // For each hole, we first draw the hole mesh as we normally would. We
                // then disable culling so the outer faces of the hole mesh will be
                // rendered. We also disable writing to the color buffer and render the
                // mesh again in order to fill the z-buffer with the outer faces of our
                // mesh.
                //
                // Based on information found here:
                // https://gamedev.stackexchange.com/questions/115501/how-to-combine-depth-and-stencil-tests
                // https://www.youtube.com/watch?v=cHhxs12ZfSQ
                // https://www.youtube.com/watch?v=uxXEV91xsSc
                //
                // A similar result can also be achieved by writing to the stencil buffer
                // and discarding the result when drawing the ground. See here:
                // https://community.khronos.org/t/masking-away-an-area-of-a-terrain-surface/104810/4
                // https://www.blog.radiator.debacle.us/2012/08/how-to-dig-holes-in-unity3d-terrains.html
                // https://www.youtube.com/watch?v=y-SEiDTbszk
                auto hole_scale  = Vec3(0.70f, 0.25f, 0.70f);
                auto hole_offset = Vec3(0, -0.5f*hole_scale.y+0.01f, 0);

                auto xform = mat4_translate(p + hole_offset)*mat4_scale(hole_scale);
                render_mesh(rp.holes, &s.hole_mesh, materials, xform);
                render_mesh(rp.hole_cutouts, &s.hole_mesh, materials, xform);
            }
        } break;

        case Entity_Type.Tank:{
            if(e.health > 0){
                auto mat_tran = mat4_translate(p + Vec3(0, 0.18f, 0))*mat4_scale(Vec3(0.5f, 0.5f, 0.5f));
                render_mesh(
                    rp.world, &s.tank_base_mesh, materials,
                    mat_tran*mat4_rot_y(e.angle)
                );
                render_mesh(
                    rp.world, &s.tank_top_mesh, materials,
                    mat_tran*mat4_rot_y(e.turret_angle)
                );
            }
            else{
                auto bounds = Rect(e.pos, Vec2(0.5f, 0.5f));
                set_shader(rp.world, &s.text_shader); // TODO: Have a decal shader?
                render_ground_decal(rp.world, bounds, Vec4(1, 1, 1, 1), 0, s.img_x_mark);
                set_shader(rp.world, &s.shader); // TODO: Use a push/pop shader interface?
            }
        } break;

        case Entity_Type.Bullet:{
            //auto mat_tran = mat4_translate(p);
            auto mat_tran = mat4_translate(p + Vec3(0, 0.5f, 0)); // TODO: Use this offset when we're done testing the camera
            render_mesh(rp.world, &s.bullet_mesh, materials, mat_tran*mat4_rot_y(e.angle));
        } break;

        case Entity_Type.Mine:{
            // TODO: Dynamic material? This thing needs to blink. Perhaps we should have
            // a shader for that?
            if(!is_exploding(e)){
                render_mesh(
                    rp.world, &s.half_sphere_mesh, materials,
                    mat4_translate(p)*mat4_scale(Vec3(0.5f, 0.5f, 0.5f))
                );
            }
            else{
                auto radius = e.extents.x;
                auto scale = Vec3(radius, radius, radius)*2.0f;
                render_mesh(
                    rp.world, &s.half_sphere_mesh, materials,
                    mat4_translate(p)*mat4_scale(scale)
                );
            }
        } break;
    }
}

bool passed_range(float a, float b, float range){
    auto v0 = floor(a / range);
    auto v1 = floor(b / range);
    bool result = v0 < v1;
    return result;
}

void start_play_session(App_State* s, uint variant_index){
    auto variant = &s.campaign.variants[variant_index];

    clear_to_zero(s.session);
    s.session.state = Session_State.Mission_Intro;
    s.session.lives = variant.lives;
    s.session.variant_index = variant_index;

    load_campaign_level(s, &s.campaign, s.session.mission_index);
}

float rotate_tank_part(float target_rot, float speed, float* rot_remaining){
    auto rot_sign = signf(target_rot);
    auto rot_abs  = abs(target_rot);

    float result = void;
    if(speed > rot_abs){
        result         = target_rot;
        *rot_remaining = 0.0f;
    }
    else{
        result         = speed*rot_sign;
        *rot_remaining = target_rot - result;
    }
    return result;
}

float rotate_towards(float angle, float target_angle, float speed){
    // Based on code found here:
    // https://stackoverflow.com/questions/11821013/rotate-an-object-gradually-to-face-a-point

    if(target_angle < 0) target_angle += TAU; // Put target angle in the range 0 .. TAU

    float result = angle;
    auto delta = angle - target_angle;
    if (delta < -PI) delta += TAU;

    if(abs(delta) > speed){
        result -= speed * sign(delta);

        if(result > PI)
            result -= TAU;
        else if(result < -PI)
            result += TAU;
    }
    else{
        result = target_angle;
    }
    return result;
}

void apply_tank_commands(App_State* s, Entity* e, Tank_Commands* input, float dt){
    auto tank_info = get_tank_info(&s.campaign, e);

    if(input.turn_angle != 0.0f){
        float rot_speed = (PI)*dt;
        auto rotation   = rotate_tank_part(input.turn_angle, rot_speed, &e.target_angle);
        e.angle += rotation;

        // Calculate the meters turned by using the Arc Length of the tank's circular bounds
        // to calulate the Sector Area of said circle.
        // https://www.geogebra.org/m/NWWDJdu8
        float radius = e.extents.x;
        e.total_meters_moved += (squared(radius)*abs(rotation))/2.0f;
    }

    if(!is_player(e)){
        auto target_angle = get_angle(e.aim_target_pos - e.pos);
        e.turret_angle = rotate_towards(e.turret_angle, target_angle, (PI*0.50f)*dt);
    }

    e.vel = Vec2(0, 0);
    auto facing = vec2_from_angle(e.angle);
    float speed = tank_info.speed;
    if(input.move_dir != 0){
        e.vel = facing*(speed*cast(float)input.move_dir);
        e.total_meters_moved += speed*dt;
    }

    if(input.place_mine){
        auto count = get_child_entity_count(&s.world, e.id, Entity_Type.Mine);
        if(count < Max_Mines_Per_Tank){
            spawn_mine(&s.world, e.pos, e.id);
        }
    }

    if(input.fire_bullet){
        auto count = get_child_entity_count(&s.world, e.id, Entity_Type.Bullet);
        if(count < tank_info.bullet_limit){
            auto bullet = spawn_bullet(&s.world, e.id, e.pos, e.turret_angle, tank_info);
            auto sfx = &s.sfx_fire_bullet;
            audio_play(sfx.samples, sfx.channels, 0);
        }
    }
}

bool is_point_in_sight(World* world, Entity* e, float sight_angle, float sight_range, Vec2 target_p){
    bool result = false;
    if(dist_sq(e.pos, target_p) <= squared(sight_range)){
        // Line-of-sight algorithm thanks to:
        // https://nic-gamedev.blogspot.com/2011/11/using-vector-mathematics-and-bit-of.html
        auto look_dir = vec2_from_angle(e.turret_angle);
        auto target_dir  = normalize(target_p - e.pos);
        if(dot(target_dir, look_dir) >= cos(sight_angle)){
            result = !ray_vs_obstacles(world, e.pos, target_dir*sight_range);
        }
    }
    return result;
}


/+
    Turret aiming:
    This determines where the tank is currently aiming.

    Inital target is set to the closest player tank.

    Tanks begin by setting a target location? What if they don't see the player?
    Target position is offset by a a random angle, not more than the given max angle
    After picking a target, the turret will rotate to the target. Once there, it will
    stay there until given a new target. A new target is picked after the aim target timer
    ends.

    Turret shooting:
    This determines if the tank should fire.
    Fire an infinite ray from the tank in the direction of the current turret angle.
    Check along this line to see if a player or an ally are inside the range. If an ally
    is inside, the tank will abort the shot. If not, and a player is found in the zoe,
    the tank fires. The tank also checks a small radius around the tank to check for allies
    as well. If the bullet can ricochet, a ray is also fixed from the contact point towards
    it's destination and check for allies and players the same way.
+/

Tank_Type* get_tank_info(Campaign* campaign, Entity* e){
    auto result = &campaign.tank_types[e.tank_type_index];
    return result;
}

void handle_enemy_ai(App_State* s, Entity* e, Tank_Commands* cmd, float dt){
    // TODO: A LOT of work needs to be done here. Here's just a few features we need:
    // - Random turning
    // - Turning in smaller increments
    // - Aiming at player before firing
    //

    auto tank_info = get_tank_info(&s.campaign, e);
    cmd.turn_angle = e.target_angle;

    // If the tank isn't currently making a turn, handle forward movement
    if(e.target_angle == 0.0f){
        float obstacle_sight_range = 2.0f; // TODO: Get this from the tank params
        if(ray_vs_obstacles(&s.world, e.pos, vec2_from_angle(e.angle)*obstacle_sight_range)){
            // If the tank has seen a wall, try to avoid it by looking to the right
            // or left. If the left and right are not obstructed, randomly pick
            // between the two.
            bool left_is_open  = !ray_vs_obstacles(&s.world, e.pos,
                vec2_from_angle(e.angle + deg_to_rad(90)) * obstacle_sight_range
            );
            bool right_is_open = !ray_vs_obstacles(&s.world, e.pos,
                vec2_from_angle(e.angle - deg_to_rad(90)) * obstacle_sight_range
            );

            if(left_is_open && right_is_open){
                if(random_bool(&s.rng))
                    e.target_angle = deg_to_rad(90);
                else
                    e.target_angle = -deg_to_rad(90);
            }
            else if(left_is_open){
                e.target_angle = deg_to_rad(90);
            }
            else if(right_is_open){
                e.target_angle = -deg_to_rad(90);
            }
            else{
                // TODO: Go in reverse
            }
        }
        else{
            cmd.move_dir = 1;
        }
    }

    e.ai_time += dt;
    timer_update(&e.fire_timer, e.ai_time, &s.rng);

    auto sight_range = 8.0f;           // TODO: Get this from tank params
    auto sight_angle = deg_to_rad(65); // TODO: Get this from tank params
    if(has_opportunity(&e.fire_timer, e.ai_time)){
        float min_aim_angle = deg_to_rad(25); // TODO: Get this from the tank params

        // TODO: Rather than fixate on a specific target, we only care if a valid target
        // is within the range of fire and no ally is in the range.
        auto target = get_entity_by_id(&s.world, s.player_entity_id);

        // TODO: Perform raycasts to make sure the player is in the range of fire and
        // allies are not
        log("Has fire opportunity\n");
        if(target){//&& abs(get_angle(target.pos - e.pos)) < min_aim_angle
        //&& is_point_in_sight(&s.world, e, sight_angle, sight_range, target.pos)){
            cmd.fire_bullet = true;
            timer_reset(&e.fire_timer, e.ai_time, &s.rng);
        }
    }

    e.aim_timer -= dt;
    if(e.aim_timer < 0.0f){
        e.aim_timer = tank_info.aim_timer + e.aim_timer;
        auto player = get_closest_player(s, e.pos);
        if(player){
            auto len   = length(e.pos - player.pos);
            auto angle = get_angle(player.pos - e.pos);
            if(tank_info.aim_max_angle > 0.001f){
                auto angle_offset = random_f32_between(&s.rng, -tank_info.aim_max_angle, tank_info.aim_max_angle);
                angle += angle_offset;

                if(angle > PI)
                    angle -= TAU;
                else if(angle < -PI)
                    angle += TAU;
            }

            e.aim_target_pos = e.pos + vec2_from_angle(angle)*len;
        }
    }
}

Entity* get_closest_player(App_State* s, Vec2 pos){
    float min_dist_sq = float.max;

    // TODO: Loop through all the player and pick the closest one
    Entity* result = get_entity_by_id(&s.world, s.player_entity_id);
    return result;
}

void simulate_world(App_State* s, Tank_Commands* input, float dt){
    // Entity simulation
    uint remaining_enemies_count;
    Vec2 hit_normal = void;
    float hit_depth = void;
    // TODO: Store the world bounds in the app_state somewhere? We seem to need it a lot.
    auto map = get_current_map(s);
    auto world_bounds = rect_from_min_max(Vec2(0, 0), Vec2(map.width, map.height));
    foreach(ref e; iterate_entities(&s.world)){
        if(is_dynamic_entity(e.type) && !is_destroyed(&e)){
            float meters_moved_prev = e.total_meters_moved;

            switch(e.type){
                default: break;

                case Entity_Type.Tank:{
                    auto commands = zero_type!Tank_Commands;
                    if(is_player(&e)){
                        assert(e.id == s.player_entity_id);
                        // TODO: Do we really want to do a copy here? For now we do this since
                        // apply_tank_commands modifies things like the turn_angle. That's useful
                        // for enemy AI, but doing that for the player tank would override player
                        // input. As things are, they're perhaps a little too hackey.
                        commands = *input;
                    }
                    else{
                        handle_enemy_ai(s, &e, &commands, dt);
                    }

                    apply_tank_commands(s, &e, &commands, dt);

                    if(e.id == s.player_entity_id){
                        e.turret_angle = get_angle(s.mouse_world - e.pos);
                    }

                    if(!is_player(&e) && !is_destroyed(&e)){
                        remaining_enemies_count++;
                    }

                    if(passed_range(meters_moved_prev, e.total_meters_moved, Meters_Per_Treadmark)){
                        auto p = &s.tread_particles[s.tread_particles_cursor];
                        p.pos = e.pos;
                        p.angle = e.angle + deg_to_rad(90);

                        s.tread_particles_cursor++;
                        if(s.tread_particles_cursor >= s.tread_particles.length){
                            s.tread_particles_cursor = 0;
                            s.tread_particles_full   = true;
                        }
                    }
                } break;

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

            // Since no objects accelerate in this game, we can simplify integration.
            // TODO: This isn't true: tanks do accelerate, though it's barely noticable.
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

    remove_destroyed_entities(&s.world);

    if(remaining_enemies_count == 0){
        // TODO: End the campaign if this is the last mission
        s.session.state = Session_State.Mission_End;
        s.session.timer = 0.0f;
    }
}

struct Tank_Commands{
    float turn_angle;
    float turret_rot;
    int   move_dir;
    bool  fire_bullet;
    bool  place_mine;
}

Vec3 camera_ray_vs_plane(Camera* camera, Vec2 screen_p, float window_w, float window_h){
    auto mouse_picker_p = unproject(camera, screen_p, window_w, window_h);
    auto result = mouse_picker_p;

    Vec3 plane_p;
    if(ray_vs_plane(
        mouse_picker_p, get_camera_facing(camera),
        Vec3(0, 0, 0), Vec3(0, 1, 0), &plane_p
    )){
        result = plane_p;
    }

    return result;
}

void reset_timer(float* timer, float threshold){
    assert(*timer >= threshold);
    *timer = *timer - threshold;
}

Tread_Particle[] get_visible_tread_particles(App_State* s){
    Tread_Particle[] result;

    if(!s.tread_particles_full){
        result = s.tread_particles[0 .. s.tread_particles_cursor];
    }
    else{
        result = s.tread_particles[0 .. $];
    }

    return result;

}

void change_to_menu(App_State* s, Menu* menu, Menu_ID menu_id){
    s.next_menu_id = menu_id;
}

void menu_simulate(App_State* s, float dt){
    auto menu = &s.menu;

    auto menu_id = s.next_menu_id;
    bool menu_changed = menu.current_menu_id != menu_id;

    switch(menu_id){
        default: break;

        case Menu_ID.None: assert(0);

        case Menu_ID.Main_Menu:{
            if(menu_changed){
                begin_menu_def(menu, menu_id);
                begin_block(menu, 0.40f);
                add_title(menu, "Tanks!");
                end_block(menu);
                begin_block(menu, 0.60f);
                add_button(menu, "Campaign", Menu_Action.Change_Menu, Menu_ID.Campaign);
                add_button(menu, "Quit", Menu_Action.Quit_Game, Menu_ID.None);
                end_block(menu);
                end_menu_def(menu);
            }
        } break;

        case Menu_ID.Campaign:{
            enum Variant_Label_Index = 3;

            auto campaign = &s.campaign;
            auto variant  = &campaign.variants[s.session.variant_index];
            if(menu_changed){

                begin_menu_def(menu, menu_id);
                begin_block(menu, 0.2f);
                add_heading(menu, "Campaign");
                end_block(menu);
                begin_block(menu, 0.8f);
                add_button(menu, "Start", Menu_Action.Begin_Campaign, Menu_ID.None);
                immutable row_style = [Style(0.5f, Align.Right), Style(0.5f, Align.Left)]; // We have to use immutable so D doesn't try to use the GC
                set_style(menu, row_style[]);
                //add_label(menu, "Test:");
                add_index_picker(menu, &s.session.variant_index, cast(uint)campaign.variants.length, "Variant");
                auto variant_label_index = add_label(menu, "");
                assert(variant_label_index == Variant_Label_Index);
                // TODO: We want to be able to select the campaign and the variant from here. This
                // will require a way to select an index. Should be interesting!
                //add_index_picker(menu, "Variant", )
                set_default_style(menu);
                add_button(menu, "Back", Menu_Action.Change_Menu, Menu_ID.Main_Menu);
                end_block(menu);
                end_menu_def(menu);
            }

            set_text(menu, &menu.items[Variant_Label_Index], variant.name);
        } break;
    }
}

void campaign_simulate(App_State* s, Tank_Commands* player_input, float dt){
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
        if(!handle_event(&s.gui, &evt)){
            switch(evt.type){
                default: break;

                case Event_Type.Window_Close:{
                    // TODO: Save state before exit in a temp/suspend file. Only in single player?
                    s.running = false;
                } break;

                case Event_Type.Button:{
                    auto btn = &evt.button;
                    if(btn.pressed){
                        switch(btn.id){
                            default: break;

                            // TODO: Buffer player inputs (other than movement)?
                            case Button_ID.Mouse_Right:{
                                player_input.place_mine = true;
                            } break;

                            case Button_ID.Mouse_Left:{
                                player_input.fire_bullet = true;
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
                    void handle_dir_key(bool key_pressed, int* dir, int target_dir){
                        if(key.pressed){
                            *dir = target_dir;
                        }
                        else if(*dir == target_dir){
                            *dir = 0;
                        }
                    }

                    switch(key.id){
                        default: break;

                        case Key_ID_A:{
                            if(key.pressed)
                                player_input.turn_angle = deg_to_rad(90);
                            else if(player_input.turn_angle > 0.0f)
                                player_input.turn_angle = 0.0f;
                        } break;

                        case Key_ID_D:{
                            if(key.pressed)
                                player_input.turn_angle = -deg_to_rad(90);
                            else if(player_input.turn_angle < 0.0f)
                                player_input.turn_angle = 0.0f;
                        } break;

                        case Key_ID_W:{
                            handle_dir_key(key.pressed, &player_input.move_dir, 1);
                        } break;

                        case Key_ID_S:{
                            handle_dir_key(key.pressed, &player_input.move_dir, -1);
                        } break;

                        case Key_ID_F2:
                            if(!key.is_repeat && key.pressed){
                                editor_toggle(s);
                                s.mode = Game_Mode.Editor;
                            }
                            break;
                    }
                } break;
            }
        }
    }
    update_gui(&s.gui, dt);

    s.session.timer += dt;
    final switch(s.session.state){
        case Session_State.Game_Over:
        case Session_State.Inactive:
            break;

        case Session_State.Playing_Mission:{
            simulate_world(s, player_input, dt);
        } break;

        case Session_State.Mission_Intro:{
            if(s.session.timer >= Mission_Intro_Max_Time){
                reset_timer(&s.session.timer, Mission_Intro_Max_Time);
                s.session.state = Session_State.Mission_Start;
            }

            static if(Skip_Level_Intros){
                s.session.state = Session_State.Playing_Mission;
            }
        } break;

        case Session_State.Mission_Start:{
            if(s.session.timer >= Mission_Start_Max_Time){
                reset_timer(&s.session.timer, Mission_Start_Max_Time);
                s.session.state = Session_State.Playing_Mission;
            }
        } break;

        case Session_State.Mission_End:{
            if(s.session.timer >= Mission_End_Max_Time){
                reset_timer(&s.session.timer, Mission_End_Max_Time);
                s.session.state = Session_State.Mission_Intro;
                s.session.mission_index++;

                s.tread_particles_cursor = 0;
                s.tread_particles_full   = false;

                foreach(i; 0 .. Max_Players){
                    s.session.total_enemies_defeated[i] += s.session.enemies_defeated[i];
                }
                clear_to_zero(s.session.enemies_defeated);

                load_campaign_level(s, &s.campaign, s.session.mission_index);
            }
        } break;
    }

    player_input.fire_bullet = false;
    player_input.place_mine  = false;
}

Texture load_texture_from_file(String file_name, uint flags, Allocator* allocator){
    push_frame(allocator);
    scope(exit) pop_frame(allocator);

    auto pixels = load_tga_file(file_name, allocator);
    premultiply_alpha(pixels.data);
    auto result = create_texture(pixels.data, pixels.width, pixels.height, flags);
    return result;
}

Texture generate_solid_texture(uint color, uint flags){
    uint[4] pixels = color;
    auto result = create_texture(pixels[], 2, 2, flags);
    return result;
}

extern(C) int main(int args_count, char** args){
    auto app_memory = os_alloc(Total_Memory_Size, 0);
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
        s.editor_memory     = make_sub_allocator(&memory, Editor_Memory_Size);
        auto scratch_memory = make_sub_allocator(&memory, Scratch_Memory_Size);

        s.main_memory.scratch   = &scratch_memory;
        s.frame_memory.scratch  = &scratch_memory;
        s.editor_memory.scratch = &scratch_memory;
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

    seed(&s.rng, 1247865); // TODO: Seed using time values?

    // TODO: Build the directory using the path to the application
    load_font("./build/test_en.fnt", &s.font_main, &s.main_memory);
    load_font("./build/editor_small_en.fnt", &s.font_editor_small, &s.main_memory);

    //auto teapot_mesh = load_mesh_from_obj("./build/teapot.obj", &s.main_memory);
    s.cube_mesh        = load_mesh_from_obj("./build/cube.obj", &s.main_memory);
    s.tank_base_mesh   = load_mesh_from_obj("./build/tank_base.obj", &s.main_memory);
    s.tank_top_mesh    = load_mesh_from_obj("./build/tank_top.obj", &s.main_memory);
    s.bullet_mesh      = load_mesh_from_obj("./build/bullet.obj", &s.main_memory);
    s.ground_mesh      = load_mesh_from_obj("./build/ground.obj", &s.main_memory);
    s.hole_mesh        = load_mesh_from_obj("./build/hole.obj", &s.main_memory);
    s.half_sphere_mesh = load_mesh_from_obj("./build/half_sphere.obj", &s.main_memory);

    auto shaders_dir = "./build/shaders";
    load_shader(&s.shader, "default", shaders_dir, &s.frame_memory);
    load_shader(&s.text_shader, "text", shaders_dir, &s.frame_memory);
    load_shader(&s.rect_shader, "rect", shaders_dir, &s.frame_memory);

    s.sfx_fire_bullet = load_wave_file("./build/fire_bullet.wav", Audio_Frames_Per_Sec, &s.main_memory);

    s.img_blank_mesh  = generate_solid_texture(0xff000000, 0);
    s.img_blank_rect  = generate_solid_texture(0xffffffff, 0);
    s.img_x_mark      = load_texture_from_file("./build/x_mark.tga", 0, &s.frame_memory);
    s.img_tread_marks = load_texture_from_file("./build/tread_marks.tga", 0, &s.frame_memory);
    s.img_wood        = load_texture_from_file("./build/wood.tga", 0, &s.frame_memory);

    Shader_Light light = void;
    Vec3 light_color = Vec3(1.0f, 1.0f, 1.0f);
    light.ambient  = light_color*0.15f;
    light.diffuse  = light_color;
    light.specular = light_color;

    setup_basic_material(&s.material_ground, s.img_wood);
    setup_basic_material(&s.material_player_tank[0], s.img_blank_mesh, Vec3(0.1f, 0.1f, 0.6f), 256);
    setup_basic_material(&s.material_player_tank[1], s.img_blank_mesh, Vec3(0.2f, 0.2f, 0.8f), 256);
    setup_basic_material(&s.material_block, s.img_blank_mesh, Vec3(0.46f, 0.72f, 0.46f));
    setup_basic_material(&s.material_eraser, s.img_blank_mesh, Vec3(0.8f, 0.2f, 0.2f));
    setup_basic_material(&s.material_breakable_block, s.img_blank_mesh, Vec3(0.92f, 0.42f, 0.20f));
    s.running = true;

    auto player_input = zero_type!Tank_Commands;
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
    s.campaign.tank_types = g_tank_types[];
    if(load_campaign_from_file(&s.campaign, Campaign_File_Name, &s.main_memory)){
        // Setup enemy tank colors based on tank params
        auto tank_types = s.campaign.tank_types;
        s.materials_enemy_tank = alloc_array!Tank_Materials(&s.main_memory, tank_types.length);
        foreach(i, ref entry; tank_types){
            auto tank_mats = &s.materials_enemy_tank[i];
            setup_basic_material(&tank_mats.materials[0], s.img_blank_mesh, entry.main_color);
            setup_basic_material(&tank_mats.materials[1], s.img_blank_mesh, entry.alt_color, 256);
        }
    }
    else{
        generate_test_level(s);
    }

    s.mouse_pixel = Vec2(0, 0);

    init_gui(&s.gui);
    s.gui.font = &s.font_editor_small;

    audio_init(Audio_Frames_Per_Sec, 2, &s.main_memory);

    //s.mode = Game_Mode.Campaign;
    s.mode = Game_Mode.Menu;
    s.menu.heading_font = &s.font_main;
    s.menu.title_font   = &s.font_main;
    s.menu.button_font  = &s.font_editor_small;
    change_to_menu(s, &s.menu, Menu_ID.Main_Menu);

    float target_dt = 1.0f/60.0f;
    ulong current_timestamp = ns_timestamp();
    ulong prev_timestamp    = current_timestamp;

    while(s.running){
        begin_frame();

        push_frame(&s.frame_memory);
        scope(exit) pop_frame(&s.frame_memory);

        auto window = get_window_info();
        auto dt = target_dt;

        Camera hud_camera = void;
        set_hud_camera(&hud_camera, window.width, window.height);

        auto map = get_current_map(s);
        auto grid_extents = Vec2(map.width, map.height)*0.5f;
        auto grid_center  = world_to_render_pos(grid_extents);
        auto window_aspect_ratio = (cast(float)window.width)/(cast(float)window.height);

        Camera world_camera = void;
        set_world_projection(&world_camera, map.width+2, map.height+2, window_aspect_ratio);

        float world_camera_angle = 45.0f;
        if(s.mode == Game_Mode.Editor)
            world_camera_angle = g_editor_camera_angle;

        set_world_view(&world_camera, grid_center, world_camera_angle);
        auto mouse_world_3d = camera_ray_vs_plane(&world_camera, s.mouse_pixel, window.width, window.height);
        s.mouse_world = Vec2(mouse_world_3d.x, -mouse_world_3d.z);

        s.t += dt;

        auto next_game_mode = s.mode;
        final switch(s.mode){
            case Game_Mode.None:
                assert(0); break;

            case Game_Mode.Editor:{
                auto close_editor = editor_simulate(s, target_dt);
                if(close_editor){
                    s.mode = Game_Mode.Campaign;
                }
            } break;

            case Game_Mode.Menu:{
                auto window_bounds = rect_from_min_max(Vec2(0, 0), Vec2(window.width, window.height));
                Event evt;
                while(next_event(&evt)){
                    if(evt.type == Event_Type.Window_Close){
                        s.running = false;
                    }
                    else{
                        auto menu_evt = menu_handle_event(&s.menu, &evt);
                        switch(menu_evt.action){
                            default: break;

                            case Menu_Action.Change_Menu:{
                                change_to_menu(s, &s.menu, menu_evt.target_menu);
                            } break;

                            case Menu_Action.Begin_Campaign:{
                                next_game_mode = Game_Mode.Campaign;
                            } break;

                            case Menu_Action.Quit_Game:{
                                s.running = false;
                            } break;
                        }
                    }
                }
                menu_simulate(s, dt);
                menu_do_layout(&s.menu, window_bounds);
            } break;

            case Game_Mode.Campaign:{
                campaign_simulate(s, &player_input, target_dt);
            } break;
        }

        if(next_game_mode != s.mode){
            switch(next_game_mode){
                default: assert(0);

                case Game_Mode.Campaign:{
                    start_play_session(s, s.session.variant_index);
                } break;
            }
            s.mode = next_game_mode;
        }

        audio_update();

        // TODO: Sometimes the game becomes a stuttering mess, and the only way to fix it is
        // to minimize the window and restore it. Figure out what's causing this.
        current_timestamp = ns_timestamp();
        ulong frame_time = cast(ulong)(dt*1000000000.0f);
        ulong elapsed_time = current_timestamp - prev_timestamp;
        if(elapsed_time < frame_time){
            ns_sleep(frame_time - elapsed_time); // TODO: Better sleep time.
        }
        prev_timestamp = current_timestamp;

        render_begin_frame(window.width, window.height, Vec4(0, 0.05f, 0.12f, 1), &s.frame_memory);

        Render_Passes render_passes;
        render_passes.holes = add_render_pass(&world_camera);
        set_shader(render_passes.holes, &s.shader);

        render_passes.hole_cutouts = add_render_pass(&world_camera);
        set_shader(render_passes.hole_cutouts, &s.shader); // TODO: We should use a more stripped-down shader for this. We don't need lighting!
        render_passes.hole_cutouts.flags = Render_Flag_Disable_Culling|Render_Flag_Disable_Color;

        render_passes.world = add_render_pass(&world_camera);
        set_shader(render_passes.world, &s.shader);
        set_light(render_passes.world, &light);

        render_passes.hud_rects = add_render_pass(&hud_camera);
        set_shader(render_passes.hud_rects, &s.text_shader);
        set_texture(render_passes.hud_rects, s.img_blank_rect);
        render_passes.hud_rects.flags = Render_Flag_Disable_Depth_Test;

        render_passes.hud_text  = add_render_pass(&hud_camera);
        set_shader(render_passes.hud_text, &s.text_shader);
        render_passes.hud_text.flags = Render_Flag_Disable_Depth_Test;

        final switch(s.mode){
            case Game_Mode.None: assert(0);

            case Game_Mode.Editor:{
                editor_render(s, render_passes);
            } break;

            case Game_Mode.Menu:{
                menu_render(&render_passes, &s.menu, s.t);
            } break;

            case Game_Mode.Campaign:{
                if(s.session.state != Session_State.Mission_Intro){
                    auto ground_xform = mat4_translate(grid_center)*mat4_scale(Vec3(grid_extents.x, 1.0f, grid_extents.y));
                    render_mesh(render_passes.world, &s.ground_mesh, (&s.material_ground)[0..1], ground_xform);

                    foreach(ref e; iterate_entities(&s.world)){
                        render_entity(s, &e, render_passes);
                    }
                }

                switch(s.session.state){
                    default: break;

                    case Session_State.Mission_Intro:{
                        auto variant = &s.campaign.variants[s.session.variant_index];
                        auto mission = &variant.missions[s.session.mission_index];

                        auto font_large = &s.font_main; // TODO: Actually have a large font
                        auto font_small = &s.font_editor_small; // TODO: Actually have a small font
                        auto p_text = render_passes.hud_text;

                        auto pen = Vec2(window.width, window.height)*0.5f;
                        render_text(
                            p_text, font_large, pen,
                            gen_string("Mission {0}", s.session.mission_index+1, &s.frame_memory),
                            Text_White, Text_Align.Center_X
                        );

                        pen.y -= cast(float)font_small.metrics.line_gap;
                        render_text(
                            p_text, font_small, pen,
                            gen_string("Enemy tanks: {0}", mission.enemies.length, &s.frame_memory),
                            Text_White, Text_Align.Center_X
                        );
                    } break;

                    case Session_State.Mission_Start:{
                        // TODO: Do this for all players in the game
                        auto player = get_entity_by_id(&s.world, s.player_entity_id);

                        float offset_y = 1.2f; // TODO: Beter offset value.
                        auto screen_p = project(&world_camera, Vec3(player.pos.x, 0, -player.pos.y - offset_y), window.width, window.height);
                        render_text(
                            render_passes.hud_text, &s.font_editor_small, screen_p, "P1",
                            Text_White, Text_Align.Center_X
                        );
                    } break;

                    case Session_State.Playing_Mission:{
                        if(s.session.timer < 2.0f){
                            // TODO: Fade the text in/out over time
                            auto pen = Vec2(window.width, window.height)*0.5f;
                            render_text(
                                render_passes.hud_text, &s.font_main, pen,
                                "Start!", Text_White, Text_Align.Center_X
                            );
                        }
                    } break;

                    case Session_State.Mission_End:{
                        auto font_large = &s.font_main; // TODO: Actually have a large font
                        auto font_small = &s.font_editor_small; // TODO: Actually have a small font
                        auto p_text = render_passes.hud_text;

                        auto pen = Vec2(window.width, window.height)*0.5f;
                        render_text(
                            p_text, font_large, pen,
                            "Mission Cleared!",
                            Text_White, Text_Align.Center_X
                        );

                        pen.y -= cast(float)font_large.metrics.line_gap;
                        render_text(
                            p_text, font_large, pen,
                            "Destroyed",
                            Text_White, Text_Align.Center_X
                        );

                        // TODO: Show who destroyed how many tanks
                        pen.y -= cast(float)font_small.metrics.line_gap;
                        render_text(
                            p_text, font_small, pen,
                            gen_string("P1 {0}", s.session.enemies_defeated[0], &s.frame_memory),
                            Text_White, Text_Align.Center_X
                        );
                    } break;
                }

                set_shader(render_passes.world, &s.text_shader);
                foreach(ref p; get_visible_tread_particles(s)){
                    render_ground_decal(
                        render_passes.world, Rect(p.pos, Vec2(0.25f, 0.10f)), Vec4(1, 1, 1, 1),
                        p.angle, s.img_tread_marks
                    );
                }
            } break;
        }

        render_gui(&s.gui, &hud_camera, &s.rect_shader, &s.text_shader);

        render_end_frame();
        end_frame();
    }

    return 0;
}
