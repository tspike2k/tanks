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
    - Temp saves
    - More editor features (tank params, level size, etc)
    - Debug collision volume display?
    - Finish porting over tank params
    - Support playing custom campaigns.
    - Add enemy missiles
    - Show HUD during campaign with score, multipliers, and enemies remaining.

Enemy AI:
    - Improved bullet prediction. Right now, even enemies with good aim stats are surprisingly
    off target.
    - Enemies are supposed to enter "survival mode" when they see a bullet (I think) or a mine.
      In this mode, the enemy tries to move as far back as needed.
    - Enemies should make sure they have room to drive away from a mine before placing one.

Sound effects:
    - Firing missile (Can we just up-pitch the normal shot sound?)

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
import testing;
import meta;
import fmt;

enum Main_Memory_Size    =  4*1024*1024;
enum Frame_Memory_Size   =  8*1024*1024;
enum Editor_Memory_Size  =  4*1024*1024;
enum Scratch_Memory_Size = 16*1024*1024;
enum Total_Memory_Size   = Main_Memory_Size + Frame_Memory_Size + Editor_Memory_Size + Scratch_Memory_Size;

enum Audio_Frames_Per_Sec = 44100;

enum Campaign_File_Name = "main.camp";

enum Mine_Detonation_Time    = 10.0f;
enum Mine_Explosion_End_Time = Mine_Detonation_Time + 0.5f;
enum Mine_Explosion_Radius   = 2.0f;
enum Mine_Activation_Dist    = Mine_Explosion_Radius;

enum Mission_Intro_Max_Time = 3.0f;
enum Mission_Start_Max_Time = 3.0f;
enum Mission_End_Max_Time   = 3.0f;

enum Tank_Explosion_Particles_Time = 2.0f;

enum Text_White = Vec4(1, 1, 1, 1);

// NOTE: Enemies are limited by the number of bytes that can be encoded into a map cell.
enum Max_Enemies = 16;
enum Max_Players = 4;

enum Meters_Per_Treadmark = 0.25f;

enum Bullet_Radius = 0.25f*0.5f;
enum Bullet_Smoke_Lifetime = 2.0f;
enum Bullet_Ground_Offset = Vec3(0, 0.5f, 0);
enum Meters_Per_Bullet_Smoke = 0.20f;

enum Default_World_Camera_Polar = Vec3(90, -45, 1); // TODO: Make these in radian eventually

enum Skip_Level_Intros = true; // TODO: We should make this based on if we're in the debug mode.
//enum Skip_Level_Intros = false;
//enum bool Immortal = true; // TODO: Make this toggleable
enum bool Immortal = false;

enum Game_Mode : uint{
    None,
    Menu,
    Editor,
    Campaign,
}

struct Render_Passes{
    Render_Pass* shadow_map;
    Render_Pass* holes;
    Render_Pass* hole_cutouts;
    Render_Pass* ground;
    Render_Pass* ground_decals;
    Render_Pass* world;
    Render_Pass* particles;
    Render_Pass* bg_scroll;
    Render_Pass* hud_rects;
    Render_Pass* hud_button;
    Render_Pass* hud_rects_fg;
    Render_Pass* hud_text;
}

enum Session_State : uint{
    Inactive,
    Mission_Intro,
    Mission_Start,
    Mission_End,
    Playing_Mission,
    Restart_Mission,
    Game_Over,
}

struct Session{
    Session_State state;
    uint                   player_index;
    uint                   players_count;
    Entity_ID[Max_Players] player_entity_ids;
    uint  lives;
    uint  variant_index;
    uint  mission_index;
    uint  map_index;
    uint  prev_map_index;
    float timer;

    Score_Entry score;
    uint mission_enemy_tanks_count;
    uint enemies_remaining;
    uint[Max_Players] mission_kills;
}

struct Particle{
    float life;
    float angle;
    Vec3  pos;
    Vec3  vel;
    uint  texture_bg;
    uint  texture_fg;
}

// NOTE: The watermark member provides a fast way to "clear" all the particles in the ring buffer.
// When iterating particles, all particles after the watermark are ignored. The watermark rises
// as particles are added. We can set this field to zero to ignore all particles, avoiding the
// need to clear the life field of each particle or call memset on the entire ring buffer.
struct Particle_Emitter{
    Particle[] particles;
    uint       cursor;
    uint       watermark;
}

String[] Shader_Names = [
    "default",
    "text",
    "rect",
    "shadow_map",
    "view_depth",
    "bg_scroll",
    "menu_button",
];

String[Max_Players] Player_Index_Strings = [
    "P1",
    "P2",
    "P3",
    "P4",
];

Vec4[Max_Players] Player_Text_Colors = [
    Vec4(0.12f, 0.46f, 0.92f, 1.0f),
    Vec4(0.80f, 0.20f, 0.24f, 1.0f),
    Vec4(0.28f, 0.78f, 0.28f, 1.0f),
    Vec4(1.0f,  0.68f, 0.18f, 1.0f),
];

struct Settings{
    Player_Name player_name;
}

struct App_State{
    Allocator main_memory;
    Allocator frame_memory;
    Allocator editor_memory;
    Allocator campaign_memory;

    String     data_path;
    String     asset_path;
    String     campaigns_path;

    bool         running;
    float        time;
    Vec2         mouse_pixel;
    Vec2         mouse_world;
    World        world;
    Game_Mode    mode;
    Game_Mode    next_mode;
    Campaign     campaign;
    String       campaign_file_name;
    High_Scores  high_scores;
    Session      session;
    Vec3         world_camera_polar;
    Vec3         world_camera_target_pos;
    Xorshift32   rng;
    Score_Entry* score_to_detail;

    Settings settings;

    bool moving_camera;

    Menu      menu;
    Gui_State gui;

    Particle_Emitter emitter_treadmarks;
    Particle_Emitter emitter_bullet_contrails;
    Particle_Emitter emitter_explosion_flames;

    // Assets
    Font font_menu_large;
    Font font_menu_small;
    Font font_editor_small;
    Font font_title;

    Shader_Light light;

    Sound sfx_fire_bullet;
    Sound sfx_explosion;
    Sound sfx_treads;
    Sound sfx_ricochet;
    Sound sfx_mine_click;
    Sound sfx_pop;
    Sound sfx_mine_explosion;
    Sound sfx_menu_click;

    union{
        struct{
            Shader default_shader;
            Shader text_shader;
            Shader rect_shader;
            Shader shadow_map_shader;
            Shader view_depth;
            Shader shader_bg_scroll;
            Shader shader_menu_button;
        }
        Shader[7] shaders;
    }

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
    Material material_bullet;

    Texture img_blank_mesh;
    Texture img_blank_rect;
    Texture img_x_mark;
    Texture img_tread_marks;
    Texture img_wood;
    Texture img_smoke;
    Texture img_crosshair;
    Texture img_tank_icon;
    Texture img_block;
    Texture img_explosion;
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

struct AI_Timer{
    float time;
    float min_delay;
    float max_delay;
}

// Mine entity flags
enum Entity_Flag_Mine_Active = (1<<0);

struct Entity{
    Entity_ID   id;
    Entity_ID   parent_id;
    ulong       flags;
    Entity_Type type;
    uint        tank_type_index;

    Vec2     pos;
    Vec2     extents;
    Vec2     vel;
    Vec2     start_pos;
    float    angle;
    float    turret_angle;
    uint     health;
    Map_Cell cell_info;
    float    mine_timer;
    float    total_meters_moved;

    float fire_cooldown_timer;
    float mine_cooldown_timer;
    float action_stun_timer; // Time a tank cannot move after firing a bullet or laying a mine

    // AI related data:
    AI_Timer  fire_timer;
    AI_Timer  place_mine_timer;
    float     aim_timer;

    Vec2      aim_target_pos;
    float     target_angle;
    float     target_aim_angle;
}

struct World{
    Entity_ID   next_entity_id;
    Entity[512] entities;
    uint        entities_count;
    Rect        bounds;
}

struct Tank_Materials{
    Material[2] materials;
}

struct Player_Name{
    uint     count;
    char[32] text;
}

struct Player_Score{
    Player_Name name;
    uint        points;
    uint        kills;
    uint        tanks_lost;
}

enum High_Scores_Table_Size = 10;

struct Score_Entry{
    char[16]        date;
    uint            total_enemies;
    uint            total_lives;
    uint            last_mission_index;
    uint            players_count;
    float           time_spent_in_seconds;
    Player_Score[4] player_scores;
}

struct Variant_Scores{
    Score_Entry[High_Scores_Table_Size] entries;
}

struct High_Scores{
    String           campaign_file_name;
    Variant_Scores[] variants;
}

void set_name(Player_Name* name, String s){
    name.count = cast(uint)min(s.length, name.text.length);
    copy(s[0 .. name.count], name.text[0 .. name.count]);
}

uint get_total_score(Score_Entry* entry){
    uint result;
    foreach(player_entry; entry.player_scores[0 .. entry.players_count]){
        result += player_entry.points;
    }

    return result;
}

char[16] get_score_date(){
    import core.stdc.time;

    char[16] result = void;
    clear_to_zero(result);

    time_t time_val;
    time(&time_val);
    auto time_local = localtime(&time_val);
    strftime(result.ptr, result.length, "%Y%m%d%I%M%p", time_local);

    return result;
}

Score_Entry* maybe_post_highscore(Variant_Scores* scores, Score_Entry* current){
    Score_Entry* ranking;
    auto current_total_score = get_total_score(current);
    if(current_total_score > 0){
        foreach(i, ref entry; scores.entries){
            if(get_total_score(&entry) <= current_total_score){
                if(i+1 < scores.entries.length){
                    memmove(&scores.entries[i+1], &scores.entries[i],
                    (scores.entries.length - i - 1)*Score_Entry.sizeof);

                }
                ranking = &scores.entries[i];
                *ranking = *current;

                break;
            }
        }
    }

    return ranking;
}

enum Save_File_Version = 1;
enum Save_File_Magic   = ('T' << 0 | 'S' << 8 | 'a' << 16 | 'v' << 24);

struct Save_File_Header{
    uint magic;
    uint file_version;
}

bool verify_save_file_header(Save_File_Header* header, String file_name){
    if(header.magic != Save_File_Magic){
        log_error("Unexpected magic for save file {0}: got {1} but expected {2}", file_name, header.magic, Save_File_Magic);
        return false;
    }

    if(header.file_version != Save_File_Version){
        log_error("Unsupported file version for save file {0}: got {1} but expected {2}", file_name, header.file_version, Save_File_Version);
        return false;
    }
    return true;
}

String get_save_file_full_path(App_State* s, Allocator* allocator){
    auto result = concat(s.data_path, "tanks.save", allocator);
    return result;
}

bool load_high_scores_for_campaign(App_State* s){
    auto allocator = &s.campaign_memory;
    mixin(Scratch_Frame!());

    auto file_name = get_save_file_full_path(s, scratch);

    bool success = false;
    auto memory = read_file_into_memory(file_name, scratch, File_Flag_No_Open_Errors);
    if(memory.length){
        auto reader = Serializer(memory, scratch);
        auto header = eat_type!Save_File_Header(&reader);
        if(verify_save_file_header(header, file_name)){
            Settings settings;
            read(&reader, settings);
            High_Scores[] scores;
            read(&reader, scores);
            foreach(ref score; scores){
                if(score.campaign_file_name == s.high_scores.campaign_file_name){
                    s.high_scores.variants = dup_array(score.variants, allocator);
                    success = true;
                    break;
                }
            }
        }
    }

    if(!success){
        log("Unable to load highscores from file {0}\n", file_name);
    }

    return success;
}

bool load_preferences(App_State* s){
    auto allocator = &s.campaign_memory;
    mixin(Scratch_Frame!());

    auto file_name = get_save_file_full_path(s, scratch);

    bool success = false;
    auto memory = read_file_into_memory(file_name, scratch, File_Flag_No_Open_Errors);
    if(memory.length){
        auto reader = Serializer(memory, scratch);
        auto header = eat_type!Save_File_Header(&reader);
        if(verify_save_file_header(header, file_name)){
            read(&reader, s.settings);

            success = !reader.errors;
            if(!success){
                log_error("Unable to read settings from file {0}\n", file_name);
            }
        }
    }

    return success;
}

void save_preferences_and_scores(App_State* s){
    auto allocator = &s.campaign_memory;
    mixin(Scratch_Frame!());

    auto file_name = get_save_file_full_path(s, scratch);
    auto memory = read_file_into_memory(file_name, scratch, File_Flag_No_Open_Errors);
    High_Scores[] old_scores;
    if(memory){
        auto reader = Serializer(memory, scratch);
        auto header = eat_type!Save_File_Header(&reader);
        if(verify_save_file_header(header, file_name)){
            Settings settings;
            read(&reader, settings);
            read(&reader, old_scores);
        }
    }

    auto dest = begin_reserve_all(scratch);
    auto writer = Serializer(dest, scratch);

    auto header = Save_File_Header(Save_File_Magic, Save_File_Version);
    write(&writer, header);
    write(&writer, s.settings);
    auto scores_count = eat_type!uint(&writer);
    *scores_count     = cast(uint)old_scores.length;

    bool replaced_score = false;
    foreach(ref score; old_scores){
        if(score.campaign_file_name == s.high_scores.campaign_file_name){
            foreach(i, ref src_variant; score.variants){
                src_variant = s.high_scores.variants[i];
            }
            replaced_score = true;
        }
        write(&writer, score);
    }

    if(!replaced_score){
        *scores_count += 1;
        write(&writer, s.high_scores);
    }

    end_reserve_all(scratch, dest, writer.buffer_used);
    write_file_from_memory(file_name, dest[0 .. writer.buffer_used]);
}

bool load_campaign_from_file(App_State* s, String file_name){
    auto allocator = &s.campaign_memory;
    auto campaign = &s.campaign;

    mixin(Scratch_Frame!());

    auto full_path = concat(trim_path(s.campaigns_path), to_string(Dir_Char), file_name, scratch);

    bool success = false;
    auto memory = read_file_into_memory(full_path, scratch);
    if(memory.length){
        if(allocator.memory){
            os_dealloc(allocator.memory);
        }

        // We add 2 MiB for extra data such as tank materials and alignment of serialized members.
        auto campaign_memory_size = memory.length + 2*1024*1024; // TODO: Is this too arbitrary?
        *allocator = Allocator(os_alloc(campaign_memory_size, 0));
        allocator.scratch = scratch;

        s.campaign_file_name = dup_array(full_path, allocator);

        auto reader = Serializer(memory, allocator);
        auto header = eat_type!Asset_Header(&reader);
        if(verify_asset_header!Campaign_Meta(file_name, header)){
            read(&reader, *campaign);
            success = !reader.errors && campaign.variants.length > 0;

            // Setup enemy tank colors based on tank params
            auto tank_types = campaign.tank_types;
            s.materials_enemy_tank = alloc_array!Tank_Materials(allocator, tank_types.length);
            foreach(i, ref entry; tank_types){
                auto tank_mats = &s.materials_enemy_tank[i];
                setup_basic_material(&tank_mats.materials[0], s.img_blank_mesh, entry.main_color);
                setup_basic_material(&tank_mats.materials[1], s.img_blank_mesh, entry.alt_color, 256);
            }

            s.high_scores.campaign_file_name = file_name;
            if(!load_high_scores_for_campaign(s)){
                s.high_scores.variants = alloc_array!Variant_Scores(allocator, campaign.variants.length);
            }
        }
    }

    if(!success){
        log_error("Unable to load campaign from file {0}\n", file_name);
    }

    return success;
}

bool is_player_tank(Entity* e){
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

void setup_tank_by_type(App_State* s, Entity* e, uint tank_type, ubyte cell_info, Vec2 map_center){
    e.cell_info       = cell_info;
    e.tank_type_index = tank_type;

    auto is_player = (cell_info & Map_Cell_Is_Player);
    if(!is_player){
        auto tank_info = get_tank_info(&s.campaign, e);

        e.fire_timer = AI_Timer(0, tank_info.fire_timer_min, tank_info.fire_timer_max);
        e.place_mine_timer = AI_Timer(0, tank_info.mine_timer_min, tank_info.mine_timer_max);
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
}

Entity* spawn_tank(App_State* s, Vec2 pos, Vec2 map_center, ubyte cell_info, uint tank_type_min, uint tank_type_max){
    auto e = add_entity(&s.world, pos, Entity_Type.Tank);

    auto tank_type = tank_type_min;
    if(tank_type_min != tank_type_max){
        tank_type = random_u32_between(&s.rng, tank_type_min, tank_type_max);
    }
    setup_tank_by_type(s, e, tank_type, cell_info, map_center);
    return e;
}

void render_ground(App_State* s, Render_Pass* pass, Rect bounds){
    auto p = world_to_render_pos(bounds.center);
    auto ground_xform = mat4_translate(p)*mat4_scale(Vec3(bounds.extents.x, 1.0f, bounds.extents.y));
    render_mesh(pass, &s.ground_mesh, (&s.material_ground)[0..1], ground_xform);
}

void reset_all_particles(App_State* s){
    reset_particles(&s.emitter_treadmarks);
    reset_particles(&s.emitter_bullet_contrails);
    reset_particles(&s.emitter_explosion_flames);
}

void restart_campaign_mission(App_State* s){
    reset_all_particles(s);

    auto map = &s.campaign.maps[s.session.map_index];
    auto map_center = Vec2(map.width, map.height)*0.5f;

    foreach(ref e; iterate_entities(&s.world)){
        if(e.type == Entity_Type.Tank
        && (is_player_tank(&e) || e.health > 0)){
            auto cell_info = e.cell_info;
            auto tank_type = e.tank_type_index;

            make_entity(&e, e.id, e.start_pos, Entity_Type.Tank);
            setup_tank_by_type(s, &e, tank_type, cell_info, map_center);
        }
        else if(e.type != Entity_Type.Block){
            destroy_entity(&e);
        }
    }
    remove_destroyed_entities(&s.world);
}

void begin_mission(App_State* s, uint mission_index){
    push_frame(&s.campaign_memory);

    auto campaign = &s.campaign;

    auto world = &s.world;
    world.entities_count = 0;

    reset_all_particles(s);

    clear_to_zero(s.session.mission_kills);
    s.session.mission_enemy_tanks_count = 0;
    s.session.mission_index = mission_index;
    auto variant = &campaign.variants[s.session.variant_index];
    auto mission = &variant.missions[s.session.mission_index];

    uint next_map_index = mission.map_index_min;
    if(mission.map_index_min != mission.map_index_max){
        // Pick a random map that wasn't picked last time.
        while(true){
            next_map_index = random_u32_between(&s.rng, mission.map_index_min, mission.map_index_max+1);
            if(next_map_index != s.session.prev_map_index)
                break;
        }
    }
    s.session.prev_map_index = s.session.map_index;
    s.session.map_index = min(next_map_index, cast(uint)campaign.maps.length-1); // Sanity check

    auto map = &campaign.maps[s.session.map_index];
    s.world.bounds = rect_from_min_max(Vec2(0, 0), Vec2(map.width, map.height));
    auto map_center = s.world.bounds.center;
    s.world_camera_target_pos = world_to_render_pos(map_center);

    clear_to_zero(s.session.player_entity_ids);

    foreach(y; 0 .. map.height){
        foreach(x; 0 .. map.width){
            auto p = Vec2(x, y) + Vec2(0.5f, 0.5f);
            auto cell_info = map.cells[x + y * map.width];
            if(cell_info & Map_Cell_Is_Tank){
                auto tank_index = cell_info & Map_Cell_Index_Mask;
                bool is_player = (cell_info & Map_Cell_Is_Player) != 0;

                if(is_player){
                    assert(tank_index >= 0 && tank_index < Max_Players);
                    if(tank_index == 0){
                        auto e = spawn_tank(s, p, map_center, cell_info, 0, 0);
                        s.session.player_entity_ids[tank_index] = e.id;
                    }
                }
                else{
                    foreach(ref spawner; mission.enemies){
                        if(spawner.spawn_index == tank_index){
                            spawn_tank(s, p, map_center, cell_info, spawner.type_min, spawner.type_max);
                            s.session.mission_enemy_tanks_count++;
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

    auto score = &s.session.score;
    max(&score.last_mission_index, mission_index);
    score.total_enemies += s.session.mission_enemy_tanks_count;
}

void end_mission(App_State* s){
    pop_frame(&s.campaign_memory);
}


bool timer_update(AI_Timer* timer, float dt, Xorshift32* rng){
    timer.time -= dt;
    bool has_opportunity = false;
    if(timer.time <= 0.0f){
        has_opportunity = true;
        timer.time = random_f32_between(rng, timer.min_delay, timer.max_delay) - timer.time;
    }
    return has_opportunity;
}

Entity_ID[] get_player_entity_ids(Session* session){
    auto result = session.player_entity_ids[0 .. session.players_count];
    return result;
}

bool players_defeated(App_State* s){
    bool result = true;
    foreach(entity_id; get_player_entity_ids(&s.session)){
        auto player = get_entity_by_id(&s.world, entity_id);
        if(player && player.health > 0){
            result = false;
            break;
        }
    }

    return result;
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
    e.id        = id;
    e.type      = type;
    e.pos       = pos;
    e.start_pos = pos;

    final switch(type){
        case Entity_Type.None:
            assert(0);

        case Entity_Type.Tank:
            e.extents = Vec2(0.40f, 0.40f); break;

        case Entity_Type.Block:
            e.extents = Vec2(0.5f, 0.5f);
            break;

        case Entity_Type.Bullet:
            e.extents = Vec2(Bullet_Radius, Bullet_Radius); break;

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

Mesh load_mesh_from_obj(String dir_path, String file_name, Allocator* allocator){
    push_frame(allocator.scratch);
    scope(exit) pop_frame(allocator.scratch);

    auto full_path = concat(trim_path(dir_path), to_string(Dir_Char), file_name, allocator.scratch);

    auto source = cast(char[])read_file_into_memory(full_path, allocator.scratch);
    auto obj = parse_obj_file(source, allocator.scratch);
    auto result = obj_to_mesh(&obj, allocator);
    return result;
}

bool load_shader(Shader* shader, String name, String path, Allocator* allocator){
    push_frame(allocator.scratch);
    scope(exit) pop_frame(allocator.scratch);

    destroy_shader(shader);

    auto scratch = allocator.scratch;
    auto sep = to_string(Dir_Char);
    path = trim_ending_if_char(path, Dir_Char);

    auto vertex_file_name   = concat(path, sep, name, "_vert." ~ Shader_File_Extension, scratch);
    auto fragment_file_name = concat(path, sep, name, "_frag." ~ Shader_File_Extension, scratch);
    auto preamble_file_name = concat(path, sep, "common." ~ Shader_File_Extension, scratch);

    auto shader_preamble = cast(char[])read_file_into_memory(preamble_file_name, scratch);

    auto writer = begin_buffer_writer(scratch);
    put_raw_string(shader_preamble, &writer);
    read_file_into_memory(vertex_file_name, &writer);
    auto vertex_source = end_buffer_writer(scratch, &writer);

    writer = begin_buffer_writer(scratch);
    put_raw_string(shader_preamble, &writer);
    read_file_into_memory(fragment_file_name, &writer);
    auto fragment_source =  end_buffer_writer(scratch, &writer);

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

Vec2 get_bullet_spawn_pos(Vec2 tank_center, Vec2 turret_dir){
    auto result = tank_center + turret_dir*1.01f;
    return result;
}

Entity* spawn_bullet(World* world, Entity* tank, Tank_Type* tank_info, Vec2 spawn_pos, Vec2 turret_dir){
    auto e      = add_entity(world, spawn_pos, Entity_Type.Bullet);
    e.angle     = tank.turret_angle;
    e.parent_id = tank.id;
    e.health    = tank_info.bullet_ricochets+1;
    e.vel       = turret_dir*tank_info.bullet_speed;
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

Campaign_Mission* get_current_mission(App_State* s){
    auto variant = s.campaign.variants[s.session.variant_index];
    auto result = &variant.missions[s.session.mission_index];
    return result;
}

Campaign_Map* get_current_map(App_State* s){
    auto result = &s.campaign.maps[s.session.map_index];
    return result;
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

// Collision ID concept inspired by Handmade Hero
ulong make_collision_id(Entity_Type a, Entity_Type b){
    assert(a <= b);
    ulong result = (cast(ulong)b) | ((cast(ulong)a) << 24);
    return result;
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

bool is_about_to_explode(Entity* e){
    assert(e.type == Entity_Type.Mine);
    bool result = e.mine_timer >= Mine_Detonation_Time - 2.0f;
    return result;
}

bool is_exploding(Entity* e){
    assert(e.type == Entity_Type.Mine);
    bool result = e.mine_timer > Mine_Detonation_Time;
    return result;
}

void detonate(Entity* e){
    assert(e.type == Entity_Type.Mine);
    if(e.mine_timer < Mine_Detonation_Time){
        e.flags |= Entity_Flag_Mine_Active;
        e.mine_timer = Mine_Detonation_Time;
    }
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

bool is_tank_player(Entity* e){
    assert(e.type == Entity_Type.Tank);
    bool result = (e.cell_info & Map_Cell_Is_Player) != 0;
    return result;
}

void add_to_score_if_killed_by_player(App_State* s, Entity* tank, Entity_ID attacker_id){
    assert(tank.type == Entity_Type.Tank);
    if(!is_tank_player(tank)){
        foreach(player_index, entity_id; get_player_entity_ids(&s.session)){
            if(attacker_id == entity_id){
                auto score_entry = &s.session.score.player_scores[player_index];
                score_entry.kills += 1;
                score_entry.points += 1; // TODO: Make points based on proximity, plus ricochet count
                s.session.mission_kills[player_index]++;
            }
        }
    }
}

void emit_tank_explosion(Particle_Emitter* emitter, Vec2 pos, Xorshift32* rng){
    auto p = world_to_render_pos(pos);
    foreach(i; 0 .. 64){
        auto angle  = random_angle(rng);
        auto height = random_f32_between(rng, 0.25f, 0.75f);
        auto offset = Vec3(cos(angle)*0.5f, height, 0.0f);
        auto entry = add_particle(emitter, Tank_Explosion_Particles_Time, p + offset, 0);
        entry.texture_bg = random_u32_between(rng, 0, 2);
        entry.texture_fg = random_u32_between(rng, 0, 2);
        auto speed = random_f32_between(rng, 0.25f, 0.5f);
        entry.vel = Vec3(cos(angle)*speed, 0, sin(angle)*speed);
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

String trim_path(String path){
    auto result = trim_ending_if_char(path, Dir_Char);
    return result;
}

bool load_font(String file_path, String file_name, Font* font, Allocator* allocator){
    mixin(Scratch_Frame!());
    auto full_path = concat(trim_path(file_path), to_string(Dir_Char), file_name, scratch);

    bool result = false;
    Font source;
    Pixels pixels;
    if(load_font_from_file(full_path, &source, &pixels, allocator)){
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
    if(!highlighted){
        switch(e.type){
            default: {
                result = (&s.material_block)[0..1];
            } break;

            case Entity_Type.Bullet:{
                result = (&s.material_bullet)[0..1];
            } break;

            case Entity_Type.Mine:{
                if(is_exploding(e)){
                    result = (&s.material_eraser)[0..1]; // TODO: Have a dedicated explosion material
                }
                else{
                    result = (&s.material_bullet)[0..1];
                    if(is_about_to_explode(e)){
                        auto t = sin((e.mine_timer)*18.0f);
                        if(t > 0){
                            result = (&s.material_eraser)[0..1]; // TODO: Have a dedicated explosion material
                        }
                    }
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
                auto x_form = mat4_translate(pos)*mat4_scale(scale);

                render_mesh(rp.world, &s.cube_mesh, materials, x_form);
                render_mesh(rp.shadow_map, &s.cube_mesh, materials, x_form);
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

                auto base_x_form = mat_tran*mat4_rot_y(e.angle);
                auto top_x_form  = mat_tran*mat4_rot_y(e.turret_angle);
                render_mesh(rp.world, &s.tank_base_mesh, materials, base_x_form);
                render_mesh(rp.world, &s.tank_top_mesh, materials, top_x_form);
                render_mesh(rp.shadow_map, &s.tank_base_mesh, materials, base_x_form);
                render_mesh(rp.shadow_map, &s.tank_top_mesh, materials, top_x_form);
            }
            else{
                auto bounds = Rect(e.pos, Vec2(0.5f, 0.5f));
                render_ground_decal(rp.ground_decals, bounds, Vec4(1, 1, 1, 1), 0, s.img_x_mark);
            }
        } break;

        case Entity_Type.Bullet:{
            auto mat_tran = mat4_translate(p + Bullet_Ground_Offset);
            auto x_form = mat_tran*mat4_rot_y(e.angle);
            render_mesh(rp.world, &s.bullet_mesh, materials, x_form);
            render_mesh(rp.shadow_map, &s.bullet_mesh, materials, x_form);
        } break;

        case Entity_Type.Mine:{
            // TODO: Dynamic material? This thing needs to blink. Perhaps we should have
            // a shader for that?
            if(is_exploding(e)){
                auto radius = e.extents.x;
                auto scale = Vec3(radius, radius, radius)*2.0f;

                // TODO: The explosion should spin over time. This would only have any impact
                // once we add a texture to it.
                render_mesh(
                    rp.world, &s.half_sphere_mesh, materials,
                    mat4_translate(p)*mat4_scale(scale)
                );
            }
            else{
                auto x_form = mat4_translate(p)*mat4_scale(Vec3(0.5f, 0.5f, 0.5f));
                render_mesh(rp.world, &s.half_sphere_mesh, materials, x_form);
                render_mesh(rp.shadow_map, &s.half_sphere_mesh, materials, x_form);
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

    bool can_move = e.action_stun_timer <= 0.0f;
    if(input.turn_angle != 0.0f && can_move){
        float rot_speed = (PI)*dt;
        auto rotation   = rotate_tank_part(input.turn_angle, rot_speed, &e.target_angle);
        e.angle += rotation;

        // Calculate the meters turned by using the Arc Length of the tank's circular bounds
        // to calulate the Sector Area of said circle.
        // https://www.geogebra.org/m/NWWDJdu8
        float radius = e.extents.x;
        e.total_meters_moved += (squared(radius)*abs(rotation))/2.0f;
    }

    if(!is_player_tank(e)){
        auto target_angle = get_angle(e.aim_target_pos - e.pos);
        e.turret_angle = rotate_towards(e.turret_angle, target_angle, (PI*0.50f)*dt);
    }

    e.vel = Vec2(0, 0);
    auto facing = vec2_from_angle(e.angle);
    float speed = tank_info.speed;
    if(input.move_dir != 0 && can_move){
        e.vel = facing*(speed*cast(float)input.move_dir);
        e.total_meters_moved += speed*dt;
    }

    if(input.place_mine && e.mine_cooldown_timer <= 0.0f){
        auto count = get_child_entity_count(&s.world, e.id, Entity_Type.Mine);
        if(count < tank_info.mine_limit){
            play_sfx(&s.sfx_mine_click, 0, 2.0f);
            spawn_mine(&s.world, e.pos, e.id);
            e.mine_cooldown_timer = tank_info.mine_cooldown_time;
            e.action_stun_timer += tank_info.mine_stun_time;
        }
    }

    if(input.fire_bullet && e.fire_cooldown_timer <= 0.0f){
        auto turret_dir = vec2_from_angle(e.turret_angle);
        auto spawn_pos = get_bullet_spawn_pos(e.pos, turret_dir);

        auto count = get_child_entity_count(&s.world, e.id, Entity_Type.Bullet);
        if(count < tank_info.bullet_limit
        && !is_circle_inside_block(&s.world, spawn_pos, Bullet_Radius)){
            e.fire_cooldown_timer = tank_info.fire_cooldown_time;
            e.action_stun_timer     += tank_info.fire_stun_time;
            auto bullet = spawn_bullet(&s.world, e, tank_info, spawn_pos, turret_dir);
            auto pitch = random_f32_between(&s.rng, 1.0f - 0.10f, 1.0f + 0.10f);
            play_sfx(&s.sfx_fire_bullet, 0, 1.0f, pitch);
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

bool is_ally_within_range(World* world, Entity* e, float test_range){
    float min_dist_sq = float.max;
    foreach(ref target; iterate_entities(world)){
        if(target.health > 0 && target.type == Entity_Type.Tank
        && target.id != e.id){
            auto d = dist_sq(target.pos, e.pos);
            if(!is_player_tank(&target) && d < min_dist_sq){
                min_dist_sq = d;
            }
        }
    }

    bool result = min_dist_sq < squared(test_range);
    return result;
}

bool should_take_fire_opportunity(World* world, Entity* e, Tank_Type* tank_info, bool has_opportunity){
    if(is_ally_within_range(world, e, tank_info.bullet_min_ally_dist)){
        return false;
    }

    // NOTE: Enemy firing sight tests can pass through blocks when the bullet spawn position
    // is inside a block. This is not an issues since we don't allow bullets to be fired if the
    // spawn position is inside a block. A better way of handling that for future projects
    // would probably be to have collision tests report of the start of the ray is inside a
    // collision volume.
    auto ray_dir   = vec2_from_angle(e.turret_angle);
    auto ray_start = get_bullet_spawn_pos(e.pos, ray_dir);

    Vec2 collision_normal = void;
    auto result = false;
    uint iterations = tank_info.bullet_ricochets+1;

    // TODO: When test_radius is set to the bullet radius, shots are usually accurate. Figure out
    // why some shots miss.
    float test_radius = Bullet_Radius;
    auto world_bounds = world.bounds;
    outer: while(iterations){
        float t_min = 1.0f;

        // TODO: The higher the ray delta, the less accurate the hit location can be calculated.
        // Using 100 is safe, since none of the maps from the original game are that large. However,
        // custom should be able to support that. A less hackey way of doing this would be to use a
        // different style of ray test altogether. We should probably use functions that perform an
        // infinite ray cast and return a hit position and a normal.
        auto ray_delta = ray_dir*100.0f;
        foreach(ref target; iterate_entities(world)){
            if(target.type == Entity_Type.Block && !is_hole(&target)){
                auto bounds = Rect(target.pos, target.extents + Vec2(Bullet_Radius, Bullet_Radius));
                ray_vs_rect(ray_start, ray_delta, bounds, &t_min, &collision_normal);
            }
        }
        ray_vs_world_bounds(ray_start, ray_delta, world_bounds, &t_min, &collision_normal);

        if(t_min < 1.0f){
            auto ray_end = ray_start + ray_delta*t_min;

            auto obb_center  = ray_start + (ray_end - ray_start)*0.5f;
            auto obb_extents = Vec2(length(ray_delta*t_min)*0.5f, test_radius);
            auto obb_angle   = get_angle(ray_dir);

            foreach(ref target; world.entities){
                if(target.type == Entity_Type.Tank){
                    auto tank_radius = target.extents.x;
                    if(circle_overlaps_obb(target.pos, tank_radius + Bullet_Radius, obb_center, obb_extents, obb_angle)){
                        if(is_player_tank(&target)){
                            result = true;
                        }
                        else{
                            result = false;
                            break outer;
                        }
                    }
                }
            }

            if(g_debug_mode){
                auto line_color = Vec4(1, 1, 1, 1);
                if(has_opportunity){
                    line_color = Vec4(1, 0, 0, 1);
                }
                if(result){
                    //debug_pause(true);
                    line_color = Vec4(0, 1, 0, 1);
                }
                render_debug_line(g_debug_render_pass, ray_start, ray_end, line_color);
                render_debug_obb(g_debug_render_pass, obb_center, obb_extents, Vec4(1, 1, 1, 0.5f), obb_angle);
            }

            ray_dir   = reflect(ray_dir, collision_normal);
            ray_start = ray_end;
        }
        else{
            // Sanity check. The ray should always at the very least hit the world bounds.
            // However, if it doesn't, we'll just abort.
            break;
        }
        iterations--;
    }
    return result && has_opportunity;
}

bool should_take_mine_opportunity(World* world, Entity* e, Tank_Type* tank_info, bool has_opportunity, Xorshift32* rng){
    if(!has_opportunity) return false;

    auto chance = random_percent(rng);
    // TODO: Depending on the AI type, AI tanks shouldn't be allowed to lay mines
    // if they're in "survival mode."

    bool result = chance >= tank_info.mine_placement_chance
    && !is_ally_within_range(world, e, tank_info.mine_min_ally_dist);
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

    auto sight_range = 8.0f;           // TODO: Get this from tank params
    auto sight_angle = deg_to_rad(65); // TODO: Get this from tank params
    bool fire_opportunity = timer_update(&e.fire_timer, dt, &s.rng);
    if(should_take_fire_opportunity(&s.world, e, tank_info, fire_opportunity)){
        cmd.fire_bullet = true;
    }

    if(tank_info.mine_limit > 0){
        bool mine_opportunity = timer_update(&e.place_mine_timer, dt, &s.rng);
        if(should_take_mine_opportunity(&s.world, e, tank_info, mine_opportunity, &s.rng)){
            cmd.place_mine = true;
        }
    }

    e.aim_timer -= dt;
    if(e.aim_timer < 0.0f){
        e.aim_timer = tank_info.aim_timer + e.aim_timer;
        auto player = get_closest_live_player(s, e.pos);
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

Entity* get_closest_live_player(App_State* s, Vec2 pos){
    float min_dist_sq = float.max;

    Entity* result;
    foreach(entity_id; get_player_entity_ids(&s.session)){
        auto player = get_entity_by_id(&s.world, entity_id);
        if(player && player.health > 0){
            auto d = dist_sq(pos, player.pos);
            if(d < min_dist_sq){
                min_dist_sq = d;
                result = player;
            }
        }
    }

    return result;
}

struct Hit_Tester{
    float   t_min;
    Vec2    pos;
    Vec2    normal;
    Entity* entity;
}

void ray_vs_entity(Vec2 ray_start, Vec2 ray_delta, Entity* target, Vec2 e_extents, Hit_Tester* hit){
    if(target.type == Entity_Type.Block){
        auto bounds = Rect(target.pos, target.extents + e_extents);
        if(ray_vs_rect(ray_start, ray_delta, bounds, &hit.t_min, &hit.normal)){
            hit.pos = ray_start + ray_delta*hit.t_min;
            hit.entity = target;
        }
    }
    else{
        auto radius = target.extents.x + e_extents.x;
        if(ray_vs_circle(ray_start, ray_delta, target.pos, radius, &hit.t_min, &hit.normal)){
            hit.pos = ray_start + ray_delta*hit.t_min;
            hit.entity = target;
        }
    }
}

void ray_vs_world_bounds(Vec2 ray_start, Vec2 ray_delta, Entity* world_entity, Rect bounds, Hit_Tester* hit){
    auto delta_sign = Vec2(signf(ray_delta.x), signf(ray_delta.y));

    auto edge_x = bounds.extents.x * delta_sign.x + bounds.center.x;
    auto edge_y = bounds.extents.y * delta_sign.y + bounds.center.y;
    auto x_normal = Vec2(-delta_sign.x, 0);
    auto y_normal = Vec2(0, -delta_sign.y);

    bool result = false;
    if(ray_vs_segment(ray_start, ray_delta, Vec2(edge_x, bounds.center.y), x_normal, &hit.t_min)){
        hit.normal = x_normal;
        hit.pos    = ray_start + ray_delta*hit.t_min;
        hit.entity = world_entity;
    }

    if(ray_vs_segment(ray_start, ray_delta, Vec2(bounds.center.x, edge_y), y_normal, &hit.t_min)){
        hit.normal = y_normal;
        hit.pos    = ray_start + ray_delta*hit.t_min;
        hit.entity = world_entity;
    }
}

void do_collision_interaction(App_State* s, Entity* a, Entity* b, Hit_Tester* hit){
    if(a.type > b.type)
        swap(a, b);

    auto collision_id = make_collision_id(a.type, b.type);
    switch(collision_id){
        default: break;

        case make_collision_id(Entity_Type.Tank, Entity_Type.Bullet):{
            auto is_player = is_player_tank(a);
            bool is_immortal = is_player && Immortal;
            if(!is_immortal){
                if(is_player){
                    auto player_index = get_player_index(a);
                    s.session.score.player_scores[player_index].tanks_lost += 1;
                }

                emit_tank_explosion(&s.emitter_explosion_flames, a.pos, &s.rng);
                play_sfx(&s.sfx_explosion, 0, 2.0f);
                destroy_entity(a);
                destroy_entity(b);
                add_to_score_if_killed_by_player(s, a, b.parent_id);
            }
        } break;

        case make_collision_id(Entity_Type.Bullet, Entity_Type.Bullet):{
            // HACK: For now we use discrete collision tests. This means that we step entity A
            // and then check it's position against the position of all other entities before
            // we simulate entity B. In the case of two rapidly fired bullets, if the second
            // bullet is simulated first it could "catch up" to the first and cause a collision
            // before A has had a chance to move. This shouldn't happen. This hack should prevent
            // that case.
            if(dot(a.vel, b.vel) < 0){
                // TODO: Show minor explosion
                destroy_entity(a);
                destroy_entity(b);
                play_sfx(&s.sfx_pop, 0, 0.75f);
            }
        } break;

        case make_collision_id(Entity_Type.None, Entity_Type.Bullet): // HACK: Reflect off syntetic entities. For use against world bounds.
        case make_collision_id(Entity_Type.Block, Entity_Type.Bullet):{
            if(b.health > 1){
                b.health--;
                play_sfx(&s.sfx_ricochet, 0, 0.75f);
            }
            else{
                b.health = 0;
                play_sfx(&s.sfx_pop, 0, 0.75f);
            }
            auto new_dir = reflect(b.vel, hit.normal);
            b.angle = atan2(new_dir.y, new_dir.x);
        } break;

        case make_collision_id(Entity_Type.Bullet, Entity_Type.Mine):{
            destroy_entity(a);
            if(!is_exploding(b))
                detonate(b);
        } break;
    }
}

bool should_collide(Entity* a, Entity* b){
    if(a.type > b.type)
        swap(a, b);

    auto collision_id = make_collision_id(a.type, b.type);
    bool result = false;
    switch(collision_id){
        default: break;

        case make_collision_id(Entity_Type.Block, Entity_Type.Bullet):{
            result = !is_hole(a);
        } break;

        case make_collision_id(Entity_Type.Bullet, Entity_Type.Bullet):
        case make_collision_id(Entity_Type.None, Entity_Type.Bullet): // Bullet vs world bounds
        case make_collision_id(Entity_Type.Block, Entity_Type.Tank):
        case make_collision_id(Entity_Type.Tank, Entity_Type.Bullet):
        case make_collision_id(Entity_Type.Tank, Entity_Type.Tank):
        case make_collision_id(Entity_Type.Bullet, Entity_Type.Mine):
            result = true;
            break;
    }
    return result;
}

void handle_entity_overlap(App_State* s, Entity* a, Entity* b){
    if(a.type > b.type){
        swap(a, b);
    }

    auto collision_id = make_collision_id(a.type, b.type);
    switch(collision_id){
        default: break;

        case make_collision_id(Entity_Type.Block, Entity_Type.Mine):{
            if(is_breakable(a) && is_exploding(b)){
                destroy_entity(a);
            }
        } break;

        case make_collision_id(Entity_Type.Mine, Entity_Type.Mine):{
            if(is_exploding(a) && !is_exploding(b)){
                detonate(b);
            }
            else if(!is_exploding(a) && is_exploding(b)){
                detonate(a);
            }
        } break;

        case make_collision_id(Entity_Type.Tank, Entity_Type.Mine):{
            if(is_exploding(b)){
                if(is_player_tank(a)){
                    auto player_index = get_player_index(a);
                    s.session.score.player_scores[player_index].tanks_lost += 1;
                }

                destroy_entity(a);
                add_to_score_if_killed_by_player(s, a, b.parent_id);
            }
        } break;
    }
}

void simulate_world(App_State* s, Tank_Commands* input, float dt){
    // Entity simulation
    s.session.enemies_remaining = 0;

    auto map = get_current_map(s);
    auto world_bounds = rect_from_min_max(Vec2(0, 0), Vec2(map.width, map.height));

    s.session.score.time_spent_in_seconds += dt;

    // Simulate entities.
    foreach(ref e; iterate_entities(&s.world)){
        if(!is_dynamic_entity(e.type)) continue;
        if(is_destroyed(&e)) continue;

        auto synthetic_entity = zero_type!Entity;

        float meters_moved_prev = e.total_meters_moved;

        switch(e.type){
            default: break;

            case Entity_Type.Tank:{
                auto commands = zero_type!Tank_Commands;
                bool is_current_player = e.id == s.session.player_entity_ids[s.session.player_index];

                if(is_player_tank(&e)){
                    assert(is_current_player);
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

                e.fire_cooldown_timer -= dt;
                e.mine_cooldown_timer -= dt;
                if(e.action_stun_timer >= 0.0f){
                    e.action_stun_timer -= dt;
                }

                if(is_current_player){
                    e.turret_angle = get_angle(s.mouse_world - e.pos);
                }

                if(!is_player_tank(&e) && !is_destroyed(&e)){
                    s.session.enemies_remaining++;
                }

                if(passed_range(meters_moved_prev, e.total_meters_moved, Meters_Per_Treadmark)){
                    play_sfx(&s.sfx_treads, 0, 0.10f);
                    auto pos = world_to_render_pos(e.pos);
                    add_particle(&s.emitter_treadmarks, 1.0f, pos, e.angle + deg_to_rad(90));
                }
            } break;

            case Entity_Type.Mine:{
                if(e.flags & Entity_Flag_Mine_Active){
                    bool was_exploding = is_exploding(&e);
                    e.mine_timer += dt;
                    if(e.mine_timer > Mine_Explosion_End_Time){
                        destroy_entity(&e);
                    }
                    else if(is_exploding(&e)){
                        if(!was_exploding){
                            auto pitch = random_f32_between(&s.rng, 1.0f - 0.10f, 1.0f + 0.10f);
                            play_sfx(&s.sfx_mine_explosion, 0, 1.0f, pitch);
                        }

                        auto t = normalized_range_clamp(e.mine_timer, Mine_Detonation_Time, Mine_Explosion_End_Time);
                        auto radius = Mine_Explosion_Radius * sin(t);
                        e.extents = Vec2(radius, radius);
                    }
                    else if(!is_about_to_explode(&e)){
                        // Prime the mine to explode if a tank gets close enough
                        foreach(ref target; iterate_entities(&s.world)){
                            if(target.health > 0 && target.type == Entity_Type.Tank
                            && dist_sq(target.pos, e.pos) < squared(Mine_Explosion_Radius)){
                                e.mine_timer = Mine_Detonation_Time - 0.5f;
                            }
                        }
                    }
                }
                else{
                    auto parent = get_entity_by_id(&s.world, e.parent_id);
                    auto parent_within_activation_dist = parent && parent.health
                        && dist_sq(e.pos, parent.pos) <= squared(Mine_Activation_Dist);

                    if(!parent_within_activation_dist){
                        e.flags |= Entity_Flag_Mine_Active;
                    }
                }
            } break;

            case Entity_Type.Bullet:{
                // TODO: Is there a better way to get the speed than getting the length of the
                // bulelt velocity?
                e.total_meters_moved += length(e.vel)*dt;
                if(passed_range(meters_moved_prev, e.total_meters_moved, Meters_Per_Bullet_Smoke)){
                    auto pos = world_to_render_pos(e.pos) + Bullet_Ground_Offset;
                    add_particle(&s.emitter_bullet_contrails, Bullet_Smoke_Lifetime, pos, 0);
                }
            } break;
        }

        auto delta = e.vel*dt;
        foreach(iteration; 0 .. 4){
            auto hit = Hit_Tester(1.0f);
            ray_vs_world_bounds(e.pos, delta, &synthetic_entity, shrink(s.world.bounds, e.extents), &hit);

            // TODO: Broadphase, Spatial partitioning to limit the number of entitites
            // we check here.
            foreach(ref target; iterate_entities(&s.world)){
                if(is_destroyed(&target) || &target == &e) continue;
                if(should_collide(&e, &target)){
                    ray_vs_entity(e.pos, delta, &target, e.extents, &hit);
                }
            }

            if(hit.t_min < 1.0f){
                if(hit.entity){
                    do_collision_interaction(s, &e, hit.entity, &hit);
                }

                if(is_destroyed(&e))
                    break;

                e.pos = hit.pos + hit.normal*0.0001f;

                if(e.type == Entity_Type.Bullet){
                    e.vel = reflect(e.vel, hit.normal, 1.0f);
                }
                else{
                    e.vel = reflect(e.vel, hit.normal, 1.0f);
                }

                // TODO: Reflecting the delta this way results in loss of energy.
                // Figure out a way to conserve the energy.
                delta = reflect(delta, hit.normal, 0.0f);
                delta = delta*(1.0f - hit.t_min);
            }
            else{
                e.pos += delta;
                break;
            }
        }

        // Handle overlap with mines
        foreach(ref a; iterate_entities(&s.world)){
            foreach(ref b; iterate_entities(&s.world, 1)){
                if(circles_overlap(a.pos, a.extents.x, b.pos, b.extents.x)){
                    handle_entity_overlap(s, &a, &b);
                }
            }
        }
    }

    update_particles(&s.emitter_bullet_contrails, dt);
    update_particles(&s.emitter_explosion_flames, dt);

    remove_destroyed_entities(&s.world);

    if(s.session.enemies_remaining == 0){
        // TODO: End the campaign if this is the last mission
        s.session.state = Session_State.Mission_End;
        s.session.timer = 0.0f;
        auto mission = get_current_mission(s);
        if(mission.awards_tank_bonus){
            s.session.lives += 1;
            s.session.score.total_lives += 1;
        }
    }
    else if(players_defeated(s)){
        // TODO: Play defeat song
        if(s.session.lives > 0){
            s.session.state = Session_State.Restart_Mission;
            s.session.timer = 0.0f;

            s.session.lives = s.session.lives-1;
        }
        else{
            s.session.state = Session_State.Game_Over;
            s.session.timer = 0.0f;
        }
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

void reset_particles(Particle_Emitter* emitter){
    emitter.cursor    = 0;
    emitter.watermark = 0;
}

Particle[] get_particles(Particle_Emitter* emitter){
    auto result = emitter.particles[0 .. emitter.watermark];
    return result;
}

void update_particles(Particle_Emitter* emitter, float dt){
    foreach(ref p; get_particles(emitter)){
        p.life -= dt;
        p.pos += p.vel*dt;
    }
}

Particle* add_particle(Particle_Emitter* emitter, float life, Vec3 pos, float angle){
    auto p = &emitter.particles[emitter.cursor];
    p.life  = life;
    p.pos   = pos;
    p.angle = angle;

    emitter.cursor++;
    if(emitter.cursor >= emitter.particles.length){
        emitter.cursor = 0;
        emitter.watermark = cast(uint)emitter.particles.length;
    }
    else{
        emitter.watermark = max(emitter.watermark, emitter.cursor);
    }
    return p;
}

void init_particles(Particle_Emitter* emitter, uint count, Allocator* allocator){
    emitter.particles = alloc_array!Particle(allocator, count);
}

void simulate_menu(App_State* s, float dt, Rect canvas){
    auto menu = &s.menu;
    float title_block_height = 0.30f;

    immutable String[4] Score_Detail_Labels = [
        "Player 1",
        "Player 2",
        "Player 3",
        "Player 4",
    ];

    immutable two_column_style = [Style(0.5f, Align.Right), Style(0.5f, Align.Left)]; // We have to use immutable so D doesn't try to use the GC
    immutable score_detail_style = [Style(0.25f, Align.Right), Style(0.75f, Align.Left)]; // We have to use immutable so D doesn't try to use the GC

    bool menu_changed = menu.changed_menu;
    auto menu_id = menu.active_menu_id;
    switch(menu_id){
        case Menu_ID.None:
        default: break;

        case Menu_ID.Main_Menu:{
            if(menu_changed){
                begin_menu_def(menu);
                begin_block(menu, title_block_height);
                add_title(menu, "Tanks!");
                end_block(menu);
                begin_block(menu, 0.70f);
                add_button(menu, "Campaign", Menu_Action.Push_Menu, Menu_ID.Campaign);
                add_button(menu, "Scores", Menu_Action.Push_Menu, Menu_ID.High_Scores);
                add_button(menu, "Editor", Menu_Action.Open_Editor, Menu_ID.None);
                add_button(menu, "Options", Menu_Action.Push_Menu, Menu_ID.Options);
                add_button(menu, "Quit", Menu_Action.Quit_Game, Menu_ID.None);
                end_block(menu);
                end_menu_def(menu);
            }
        } break;

        case Menu_ID.Campaign:{
            enum {
                Label_Campaign_Variant_Name = 1,
                Label_Campaign_Name,
                Label_Campaign_Author,
                Label_Campaign_Version,
                Label_Campaign_Description,
            }

            auto campaign = &s.campaign;
            auto variant  = &campaign.variants[s.session.variant_index];
            if(menu_changed){
                begin_menu_def(menu);
                begin_block(menu, title_block_height);
                add_heading(menu, "Campaign");
                end_block(menu);
                begin_block(menu, 1.0f - title_block_height);

                add_button(menu, "Start", Menu_Action.Begin_Campaign, Menu_ID.None);

                // TODO: We want to be able to select the campaign from here somehow.
                set_style(menu, two_column_style[]);
                add_label(menu, "Name:");
                add_text_block(menu, "", Label_Campaign_Name);
                add_label(menu, "Authors:");
                add_text_block(menu, "", Label_Campaign_Author);
                add_label(menu, "Version:");
                add_text_block(menu, "", Label_Campaign_Version);
                add_label(menu, "Description:");
                add_text_block(menu, "", Label_Campaign_Description);
                add_index_picker(menu, &s.session.variant_index, cast(uint)campaign.variants.length, "Variant");
                add_text_block(menu, "", Label_Campaign_Variant_Name);
                set_default_style(menu);
                add_button(menu, "Back", Menu_Action.Pop_Menu, Menu_ID.None);
                end_block(menu);
                end_menu_def(menu);
            }

            foreach(ref item; menu.items[0 .. menu.items_count]){
                switch(item.user_id){
                    default: break;

                    case Label_Campaign_Name:
                        set_text(menu, &item, campaign.name); break;

                    case Label_Campaign_Author:
                        set_text(menu, &item, campaign.author); break;

                    case Label_Campaign_Description:
                        set_text(menu, &item, campaign.description); break;

                    case Label_Campaign_Version:
                        set_text(menu, &item, campaign.version_string); break;

                    case Label_Campaign_Variant_Name:
                        set_text(menu, &item, variant.name); break;
                }
            }
        } break;

        case Menu_ID.High_Scores:{
            enum {
                Menu_ID_High_Score = 1,
                Menu_ID_High_Score_End   = Menu_ID_High_Score + High_Scores_Table_Size,
                Menu_ID_Session_Score,
                Menu_ID_Variant_Name,
            }

            auto variant_index = s.menu.variant_index;
            auto variant = &s.campaign.variants[variant_index];
            Variant_Scores* score_table;
            if(variant_index < s.high_scores.variants.length){
                score_table = &s.high_scores.variants[variant_index];
            }

            if(menu_changed){
                begin_menu_def(menu);
                begin_block(menu, title_block_height);
                add_heading(menu, "High Scores");
                end_block(menu);
                begin_block(menu, 1.0f - title_block_height);

                // TODO: Show campaign name
                auto campaign = &s.campaign;
                set_style(menu, two_column_style[]);
                add_index_picker(menu, &menu.variant_index, cast(uint)campaign.variants.length, "Variant");
                add_text_block(menu, "", Menu_ID_Variant_Name);

                set_default_style(menu);
                add_high_score_table_head(menu, "Session High Score");
                add_high_score_row(menu, &s.session.score, 0, Menu_ID_Session_Score);

                add_high_score_table_head(menu, "High Scores");
                if(score_table){
                    foreach(i ; 0 .. High_Scores_Table_Size){
                        add_high_score_row(menu, null, i+1, Menu_ID_High_Score+i);
                    }
                }
                add_button(menu, "Back", Menu_Action.Pop_Menu, Menu_ID.None);
                end_block(menu);
                end_menu_def(menu);
            }

            foreach(ref item; menu.items[0 .. menu.items_count]){
                if(score_table && item.user_id >= Menu_ID_High_Score
                && item.user_id <= Menu_ID_High_Score_End){
                    auto score_index = item.user_id - Menu_ID_High_Score;
                    item.score_entry = &score_table.entries[score_index];
                }
                if(item.user_id == Menu_ID_Variant_Name){
                    set_text(menu, &item, variant.name);
                }
            }
        } break;

        case Menu_ID.High_Score_Details:{
            enum {
                Menu_ID_Overview = 1,
                Menu_ID_Score_Text,
                Menu_ID_Score_Text_End = Menu_ID_Score_Text+4,
            }

            auto variant_index = s.menu.variant_index;
            auto variant = &s.campaign.variants[variant_index];

            auto score = s.score_to_detail;
            if(menu_changed){
                begin_menu_def(menu);
                begin_block(menu, title_block_height);
                add_heading(menu, "High Score Details");
                end_block(menu);
                begin_block(menu, 1.0f - title_block_height);

                set_style(menu, two_column_style[]);
                add_label(menu, "General:");
                add_text_block(menu, "", Menu_ID_Overview);

                // TODO: Setting the style here overwrites the style used above. We should fix this.
                set_style(menu, score_detail_style[]);
                foreach(i; 0 .. min(4, score.players_count)){
                    add_label(menu, Score_Detail_Labels[i]);
                    add_text_block(menu, "", Menu_ID_Score_Text+i);
                }

                set_default_style(menu);
                add_button(menu, "Back", Menu_Action.Pop_Menu, Menu_ID.None);
                end_block(menu);
                end_menu_def(menu);
            }

            foreach(ref item; menu.items[0 .. menu.items_count]){
                if(item.user_id == Menu_ID_Overview){
                    char[32] date_buffer = void;
                    auto date = make_date_pretty(date_buffer, score.date);

                    uint hours   = cast(uint)((score.time_spent_in_seconds / 60.0f)/60.0f);
                    uint minutes = cast(uint)((score.time_spent_in_seconds / 60.0f));
                    uint seconds = cast(uint)(score.time_spent_in_seconds % 60.0f);

                    char[32] time_buffer;
                    auto time = format(time_buffer, "{0}:{1}:{2}", hours, minutes, seconds);

                    auto text = gen_string("Missions {0}/{1} Time: {2} Date: {3}",
                        score.last_mission_index+1, variant.missions.length,
                        time, date,
                        &s.frame_memory
                    );

                    set_text(menu, &item, text);
                }
                else if(item.user_id >= Menu_ID_Score_Text && item.user_id < Menu_ID_Score_Text_End){
                    auto score_index = item.user_id - Menu_ID_Score_Text;
                    auto detail = &score.player_scores[score_index];

                    auto name = detail.name.text[0 .. detail.name.count];
                    auto msg = gen_string("{0} Score: {1} Kills: {2}/{3} Tanks lost: {4}/{5}",
                        name, detail.points, detail.kills, score.total_enemies,
                        detail.tanks_lost, score.total_lives+1,
                        &s.frame_memory
                    );
                    set_text(menu, &item, msg);
                }
            }
        } break;

        case Menu_ID.Campaign_Pause:{
            if(menu_changed){
                begin_menu_def(menu);
                begin_block(menu, title_block_height);
                add_heading(menu, "Paused");
                end_block(menu);
                begin_block(menu, 1.0f-title_block_height);
                add_button(menu, "Resume", Menu_Action.Pop_Menu, Menu_ID.None);
                add_button(menu, "Quit", Menu_Action.Abort_Campaign, Menu_ID.None);
                end_block(menu);
                end_menu_def(menu);
            }
        } break;

        case Menu_ID.Options:{
            if(menu_changed){
                begin_menu_def(menu);
                begin_block(menu, title_block_height);
                add_heading(menu, "Options");
                end_block(menu);
                begin_block(menu, 1.0f-title_block_height);

                auto player_name = &s.settings.player_name;
                add_textfield(menu, "Player name: ", player_name.text[], &player_name.count);

                add_button(menu, "Back", Menu_Action.Pop_Menu, Menu_ID.None);
                end_block(menu);
                end_menu_def(menu);
            }
        } break;
    }

    menu_update(menu, canvas);
}

void app_quit(App_State* s){
    // TODO: If the game is running, make a temp save.
    // TODO: If the editor is running, make a temp save?
    s.running    = false;
    save_preferences_and_scores(s);
}

void handle_event_common(App_State* s, Event* evt, float dt){
    handle_event(&s.gui, evt);

    if(!evt.consumed){
        switch(evt.type){
            default: break;

            case Event_Type.Window_Close:{
                app_quit(s);
                evt.consumed = true;
            } break;

            case Event_Type.Button:{
                auto btn = &evt.button;
                if(btn.id == Button_ID.Mouse_Right){
                    if(can_move_camera(s) && btn.pressed){
                        s.moving_camera = true;
                        evt.consumed = true;
                    }
                    else
                        s.moving_camera = false;
                }
            } break;

            case Event_Type.Mouse_Motion:{
                auto motion = &evt.mouse_motion;
                if(s.moving_camera){
                    auto delta = Vec2(motion.rel_x, motion.rel_y);
                    float cam_speed = 4.0f;

                    s.world_camera_polar.x += delta.x*cam_speed*dt;
                    s.world_camera_polar.y += delta.y*cam_speed*dt;
                    s.world_camera_polar.y = clamp(s.world_camera_polar.y, -78.75f, 0.0f);
                }

                s.mouse_pixel = Vec2(motion.pixel_x, motion.pixel_y);
            } break;
        }
    }
}

void begin_campaign(App_State* s, uint variant_index, uint players_count, uint player_index){
    assert(players_count > 0 && players_count <= Max_Players);
    assert(player_index < Max_Players);
    auto variant = &s.campaign.variants[variant_index];

    s.world.next_entity_id = Null_Entity_ID+1;

    clear_to_zero(s.session);
    s.session.state = Session_State.Mission_Intro;
    s.session.lives = variant.lives;
    s.session.variant_index = variant_index;
    s.session.players_count = players_count;
    s.session.player_index  = player_index;

    auto score = &s.session.score;
    score.players_count = players_count;
    score.total_lives += s.session.lives;

    auto player_score = &score.player_scores[0];
    player_score.name = s.settings.player_name;

    //begin_mission(s, s.session.mission_index);
    begin_mission(s, 5);
}

void end_campaign(App_State* s, bool aborted){
    auto variant_scores = &s.high_scores.variants[s.session.variant_index];
    s.session.score.date = get_score_date();
    // TODO: Store the score slot somewhere so we can use it to highlight the latest high score.
    auto score_slot = maybe_post_highscore(variant_scores, &s.session.score);
    change_mode(s, Game_Mode.Menu);

    s.menu.newly_added_score = score_slot;
    set_menu(&s.menu, Menu_ID.High_Scores);
    s.menu.variant_index = s.session.variant_index;
    if(score_slot){
        save_preferences_and_scores(s);
    }
}

void handle_menu_event(App_State* s, Event* evt){
    if(evt.consumed) return;

    auto menu_prev_id = s.menu.active_menu_id;

    auto menu_evt = menu_process_event(&s.menu, evt);
    switch(menu_evt.action){
        default: break;

        case Menu_Action.Pop_Menu:{
            if(menu_prev_id == Menu_ID.High_Scores){
                s.menu.newly_added_score = null;
            }
        } break;

        case Menu_Action.Open_Editor:{
            change_mode(s, Game_Mode.Editor);
        } break;

        case Menu_Action.Begin_Campaign:{
            set_menu(&s.menu, Menu_ID.None);
            change_mode(s, Game_Mode.Campaign);
            begin_campaign(s, s.session.variant_index, 1, 0);
        } break;

        case Menu_Action.Abort_Campaign:{
            end_campaign(s, true);
        } break;

        case Menu_Action.Quit_Game:{
            app_quit(s);
        } break;

        case Menu_Action.Show_High_Score_Details:{
            auto item = get_item_by_user_id(&s.menu, menu_evt.user_id);
            if(item){
                auto score = item.score_entry;
                if(get_total_score(score) > 0){
                    push_menu(&s.menu, Menu_ID.High_Score_Details);
                    s.score_to_detail = score;
                }
            }
        } break;
    }
}

void campaign_simulate(App_State* s, Tank_Commands* player_input, float dt){
    mixin(Perf_Function!());

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
        handle_event_common(s, &evt, dt);
        handle_menu_event(s, &evt);
        if(!evt.consumed){
            switch(evt.type){
                default: break;

                case Event_Type.Button:{
                    auto btn = &evt.button;
                    if(btn.pressed){
                        switch(btn.id){
                            default: break;

                            // TODO: Buffer player inputs (other than movement)?
                            case Button_ID.Mouse_Right:{
                                player_input.place_mine = true;
                                evt.consumed = true;
                            } break;

                            case Button_ID.Mouse_Left:{
                                player_input.fire_bullet = true;
                                evt.consumed = true;
                            } break;
                        }
                    }
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

                        case Key_ID_Escape:{
                            if(key.pressed){
                                // NOTE: We shouldn't handle Escape when the menu is open,
                                // since that's handled internally by the Menu logic.
                                if(menu_is_closed(&s.menu)){
                                    set_menu(&s.menu, Menu_ID.Campaign_Pause);
                                    evt.consumed = true;
                                }
                            }
                        } break;

                        case Key_ID_A:{
                            if(key.pressed)
                                player_input.turn_angle = deg_to_rad(90);
                            else if(player_input.turn_angle > 0.0f)
                                player_input.turn_angle = 0.0f;
                            evt.consumed = true;
                        } break;

                        case Key_ID_D:{
                            if(key.pressed)
                                player_input.turn_angle = -deg_to_rad(90);
                            else if(player_input.turn_angle < 0.0f)
                                player_input.turn_angle = 0.0f;
                            evt.consumed = true;
                        } break;

                        case Key_ID_W:{
                            handle_dir_key(key.pressed, &player_input.move_dir, 1);
                            evt.consumed = true;
                        } break;

                        case Key_ID_S:{
                            handle_dir_key(key.pressed, &player_input.move_dir, -1);
                            evt.consumed = true;
                        } break;

                        case Key_ID_F2:
                            if(!key.is_repeat && key.pressed){
                                //editor_toggle(s);
                                g_debug_mode = !g_debug_mode;
                                if(!g_debug_mode){
                                    s.world_camera_polar = Default_World_Camera_Polar;
                                }
                                evt.consumed = true;
                            }
                            break;
                    }
                } break;
            }
        }
    }
    auto window = get_window_info();
    auto window_bounds = rect_from_min_max(Vec2(0, 0), Vec2(window.width, window.height));

    update_gui(&s.gui, dt);
    simulate_menu(s, dt, window_bounds);

    s.session.timer += dt;
    final switch(s.session.state){
        case Session_State.Inactive:
            break;

        case Session_State.Playing_Mission:{
            auto map = get_current_map(s);
            auto world_bounds = rect_from_min_max(Vec2(0, 0), Vec2(map.width, map.height));

            float light_radius = 8.0f;
            s.light.pos.x = world_bounds.center.x + cos(s.time*0.25f)*light_radius;
            s.light.pos.z = world_bounds.center.y + sin(s.time*0.25f)*light_radius;

            // TODO: The pause menu should only stop the simulation if this is a single-player
            // campaign.
            if(!g_debug_pause && menu_is_closed(&s.menu)){
                simulate_world(s, player_input, dt);
            }
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

                end_mission(s);
                auto variant = &s.campaign.variants[s.session.variant_index];
                if(s.session.mission_index < variant.missions.length){
                    begin_mission(s, s.session.mission_index);
                }
                else{
                    end_campaign(s, false);
                }
            }
        } break;

        case Session_State.Game_Over:{
            if(s.session.timer >= Mission_End_Max_Time){
                end_campaign(s, false);
            }
        } break;

        case Session_State.Restart_Mission:{
            if(s.session.timer >= Mission_End_Max_Time){
                reset_timer(&s.session.timer, Mission_End_Max_Time);
                s.session.state = Session_State.Mission_Intro;
                restart_campaign_mission(s);
            }
        } break;
    }

    player_input.fire_bullet = false;
    player_input.place_mine  = false;
}

Sound load_sfx(String path, String file_name, Allocator* allocator){
    mixin(Scratch_Frame!());
    auto full_path = concat(trim_path(path), to_string(Dir_Char), file_name, allocator.scratch);

    auto result = load_wave_file(full_path, Audio_Frames_Per_Sec, allocator);
    return result;
}

Texture load_texture(String path, String file_name, uint flags, Allocator* allocator, bool premultiply = true){
    mixin(Scratch_Frame!());
    auto full_path = concat(trim_path(path), to_string(Dir_Char), file_name, allocator.scratch);

    // NOTE: We must use the allocator directly for leading a TGA file. This is because the
    // function uses scratch memory to load the file into memory, then the pixel data is
    // allocated by the allocator itself.
    push_frame(allocator);
    scope(exit) pop_frame(allocator);
    auto pixels = load_tga_file(full_path, allocator);
    if(premultiply)
        premultiply_alpha(pixels.data);
    auto result = create_texture(pixels.data, pixels.width, pixels.height, flags);
    return result;
}

bool can_move_camera(App_State* s){
    bool result = g_debug_mode || s.mode == Game_Mode.Editor;
    return result;
}

Texture generate_solid_texture(uint color, uint flags){
    uint[4] pixels = color;
    auto result = create_texture(pixels[], 2, 2, flags);
    return result;
}

void change_mode(App_State* s, Game_Mode mode){
    s.next_mode = mode;
}

bool is_circle_inside_block(World* world, Vec2 pos, float radius){
    // TODO: We could speed this up by partitioning entities on a grid. The map is using grid
    // cells anyway, so this would be intuitive.
    bool result = false;
    Vec2 hit_normal = void;
    float hit_depth = void;
    foreach(ref e; iterate_entities(world)){
        if(e.type == Entity_Type.Block && !is_hole(&e)){
            if(rect_vs_circle(e.pos, e.extents, pos, radius, &hit_normal, &hit_depth)){
                result = true;
                break;
            }
        }
    }
    return result;
}

void sort_and_render_bullet_particles(Particle_Emitter* emitter, Render_Pass* pass, Texture texture, Allocator* scratch){
    mixin(Perf_Function!());

    push_frame(scratch);
    scope(exit) pop_frame(scratch);

    struct Sort_Entry{
        uint  index;
        float sort_key;
    }

    auto particles = get_particles(emitter);
    auto sort_list = alloc_array!Sort_Entry(scratch, particles.length, Alloc_Flag_No_Clear);
    uint sort_list_count;
    foreach(p_index, ref p; particles){
        if(p.life > 0){
            auto entry = &sort_list[sort_list_count++];
            entry.index = cast(uint)p_index;

            // Here we wish to sort particles by their distance to the camera, where the furthest
            // particle will be drawn first and particles closer will be drawn after. This is
            // done so that blending on semi-transparent particles will be correct. Intuition
            // would lead one to use the distance from the camera center to the particle center,
            // but this doesn't work because this game uses an orthographic camera. We can instead
            // project the particle center onto a ray from the camera's center towards it's facing
            // direction. This appears to work quite well, though this technique doesn't appear to be
            // mentioned anywhere on the Internet as near as I can tell.
            entry.sort_key = dot(pass.camera.facing, p.pos - pass.camera.center);
        }
    }

    quick_sort!("a.sort_key < b.sort_key")(sort_list[0 .. sort_list_count]);

    foreach(ref entry; sort_list[0 .. sort_list_count]){
        auto p = &particles[entry.index];
        assert(p.life > 0);

        auto t = 1.0f-normalized_range_clamp(p.life, 0, Bullet_Smoke_Lifetime);
        auto alpha = 0.0f;
        if(t < 0.15f){
            alpha = normalized_range_clamp(t, 0, 0.15f);
        }
        else{
            alpha = 1.0f-normalized_range_clamp(t, 0.15f, 1);
        }

        render_particle(pass, p.pos, Vec2(0.25f, 0.25f), Vec4(1, 1, 1, alpha), texture);
    }
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
        auto memory      = Allocator(app_memory);
        auto main_memory = make_sub_allocator(&memory, Main_Memory_Size);

        s = alloc_type!App_State(&main_memory);
        s.main_memory       = main_memory;
        s.frame_memory      = make_sub_allocator(&memory, Frame_Memory_Size);
        s.editor_memory     = make_sub_allocator(&memory, Editor_Memory_Size);
        auto scratch_memory = make_sub_allocator(&memory, Scratch_Memory_Size);
        s.campaign_memory = Allocator(null); // NOTE: The memory for this allocator is managed by load_campaign_from_file

        s.main_memory.scratch     = &scratch_memory;
        s.frame_memory.scratch    = &scratch_memory;
        s.editor_memory.scratch   = &scratch_memory;
        s.campaign_memory.scratch = &scratch_memory;
    }

    auto asset_path   = make_path_string("$APP_DIR/assets/", &s.main_memory);
    auto shaders_path = make_path_string("$APP_DIR/shaders/", &s.main_memory);
    s.data_path       = make_path_string("$DATA/tspike2k/tanks/", &s.main_memory);
    s.asset_path      = asset_path;
    s.campaigns_path  = make_path_string("$APP_DIR/campaigns/", &s.main_memory);

    build_directory_from_path("$DATA/", "tspike2k/tanks", &s.frame_memory);

    // TODO: Only use file watchers if we're in a testing build.
    File_Watcher file_watcher = watch_begin(alloc_array!void(&s.main_memory, 2048));
    scope(exit) watch_end(&file_watcher);

    auto shaders_watch_fd = watch_add(&file_watcher, "./build/shaders/", Watch_Event_Modified);

    // NOTE: These are the default names, these should be configurable by the player.
    set_name(&s.settings.player_name, "Player 1");
    load_preferences(s);

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

    seed(&s.rng, 1247865); // TODO: Seed using current time value?

    load_font(asset_path, "editor_small_en.fnt", &s.font_editor_small, &s.main_memory);
    load_font(asset_path, "menu_large_en.fnt", &s.font_menu_large, &s.main_memory);
    load_font(asset_path, "menu_small_en.fnt", &s.font_menu_small, &s.main_memory);
    load_font(asset_path, "title_font.fnt", &s.font_title, &s.main_memory);

    s.cube_mesh        = load_mesh_from_obj(asset_path, "cube.obj", &s.main_memory);
    s.tank_base_mesh   = load_mesh_from_obj(asset_path, "tank_base.obj", &s.main_memory);
    s.tank_top_mesh    = load_mesh_from_obj(asset_path, "tank_top.obj", &s.main_memory);
    s.bullet_mesh      = load_mesh_from_obj(asset_path, "bullet.obj", &s.main_memory);
    s.ground_mesh      = load_mesh_from_obj(asset_path, "ground.obj", &s.main_memory);
    s.hole_mesh        = load_mesh_from_obj(asset_path, "hole.obj", &s.main_memory);
    s.half_sphere_mesh = load_mesh_from_obj(asset_path, "half_sphere.obj", &s.main_memory);

    foreach(shader_index, ref shader; s.shaders){
        load_shader(&shader, Shader_Names[shader_index], shaders_path, &s.frame_memory);
    }

    s.sfx_fire_bullet    = load_sfx(asset_path, "fire_bullet.wav", &s.main_memory);
    s.sfx_explosion      = load_sfx(asset_path, "explosion.wav", &s.main_memory);
    s.sfx_treads         = load_sfx(asset_path, "treads.wav", &s.main_memory);
    s.sfx_ricochet       = load_sfx(asset_path, "ricochet.wav", &s.main_memory);
    s.sfx_mine_click     = load_sfx(asset_path, "mine_click.wav", &s.main_memory);
    s.sfx_pop            = load_sfx(asset_path, "pop.wav", &s.main_memory);
    s.sfx_mine_explosion = load_sfx(asset_path, "mine_explosion.wav", &s.main_memory);
    s.sfx_menu_click = load_sfx(asset_path, "menu_click.wav", &s.main_memory);

    s.img_blank_mesh  = generate_solid_texture(0xff000000, 0);
    s.img_blank_rect  = generate_solid_texture(0xffffffff, 0);
    s.img_x_mark      = load_texture(asset_path, "x_mark.tga", 0, &s.frame_memory);
    s.img_tread_marks = load_texture(asset_path, "tread_marks.tga", 0, &s.frame_memory);
    s.img_wood        = load_texture(asset_path, "wood.tga", 0, &s.frame_memory);
    s.img_smoke       = load_texture(asset_path, "smoke.tga", 0, &s.frame_memory);
    s.img_crosshair   = load_texture(asset_path, "crosshair.tga", 0, &s.frame_memory);
    s.img_tank_icon   = load_texture(asset_path, "tank_icon.tga", Texture_Flag_Wrap, &s.frame_memory);
    s.img_block       = load_texture(asset_path, "block.tga", 0, &s.frame_memory);
    s.img_explosion   = load_texture(asset_path, "explosion.tga", 0, &s.frame_memory);

    Vec3 light_color = Vec3(1.0f, 1.0f, 1.0f);
    s.light.ambient  = light_color*0.15f;
    s.light.diffuse  = light_color;
    s.light.specular = light_color;
    s.light.pos      = Vec3(0, 16, 0);

    setup_basic_material(&s.material_ground, s.img_wood);
    setup_basic_material(&s.material_player_tank[0], s.img_blank_mesh, Vec3(0.1f, 0.1f, 0.6f), 256);
    setup_basic_material(&s.material_player_tank[1], s.img_blank_mesh, Vec3(0.2f, 0.2f, 0.8f), 256);
    setup_basic_material(&s.material_block, s.img_block, Vec3(0.5f, 0.42f, 0.20f), 128);
    setup_basic_material(&s.material_bullet, s.img_blank_mesh, Vec3(0.6f, 0.6f, 0.65f), 256);
    setup_basic_material(&s.material_eraser, s.img_blank_mesh, Vec3(0.8f, 0.2f, 0.2f));
    setup_basic_material(&s.material_breakable_block, s.img_block);
    s.running = true;

    init_particles(&s.emitter_treadmarks, 2048, &s.main_memory);
    init_particles(&s.emitter_bullet_contrails, 2048, &s.main_memory);
    init_particles(&s.emitter_explosion_flames, 2048, &s.main_memory);

    auto player_input = zero_type!Tank_Commands;

    version(none){
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
    }

    load_campaign_from_file(s, Campaign_File_Name);

    s.mouse_pixel = Vec2(0, 0);

    init_gui(&s.gui);
    s.gui.font = &s.font_editor_small;

    auto target_latency = (Audio_Frames_Per_Sec/60)*4;   // TODO: Should be configurable by the user
    auto mixer_buffer_size_in_frames = target_latency*2; // TODO: Should be configurable by the user
    audio_init(Audio_Frames_Per_Sec, 2, target_latency, mixer_buffer_size_in_frames, &s.main_memory);
    scope(exit) audio_shutdown();

    //s.mode = Game_Mode.Campaign;
    s.mode = Game_Mode.Menu;
    s.next_mode = s.mode;
    s.menu.heading_font     = &s.font_menu_large;
    s.menu.title_font       = &s.font_title;
    s.menu.button_font      = &s.font_menu_small;
    s.menu.sfx_click        = &s.sfx_menu_click;
    set_menu(&s.menu, Menu_ID.Main_Menu);

    float target_dt = 1.0f/60.0f;
    ulong current_timestamp = ns_timestamp();
    ulong prev_timestamp    = current_timestamp;

    s.world_camera_polar = Default_World_Camera_Polar;

    while(s.running){
        auto perf_timer_frame = begin_perf_timer("Entire Frame");

        begin_frame();

        push_frame(&s.frame_memory);
        scope(exit) pop_frame(&s.frame_memory);

        auto window = get_window_info();

        auto dt = target_dt;
        s.time += dt;

        g_debug_pause = g_debug_pause_next;
        if(s.mode != s.next_mode){
            switch(s.next_mode){
                default: break;

                case Game_Mode.Editor:{
                    editor_toggle(s);
                } break;
            }
            s.mode = s.next_mode;
        }

        auto map = get_current_map(s);

        Camera hud_camera = void;
        set_hud_camera(&hud_camera, window.width, window.height);

        Camera shadow_map_camera = void;
        auto world_up_vector = Vec3(0, 1, 0);
        set_shadow_map_camera(&shadow_map_camera, &s.light, s.world_camera_target_pos, world_up_vector);

        float window_aspect_ratio = (cast(float)window.width)/(cast(float)window.height);
        Camera world_camera = void;
        set_world_view(&world_camera, s.world_camera_polar, s.world_camera_target_pos, world_up_vector);
        set_world_projection(&world_camera, map.width, map.height, window_aspect_ratio, 45.0f);
        //set_world_projection(&world_camera, map.width, map.height, window_aspect_ratio, 0);
        //set_world_view(&world_camera, world_to_render_pos(Vec2(map.width, map.height)*0.5f), 90);

        auto mouse_world_3d = camera_ray_vs_plane(&world_camera, s.mouse_pixel, window.width, window.height);
        s.mouse_world = Vec2(mouse_world_3d.x, -mouse_world_3d.z);

        render_begin_frame(
            window.width, window.height, Vec4(0, 0.05f, 0.12f, 1),
            s.time, Vec2(window.width, window.height), &s.frame_memory
        );

        Render_Passes render_passes;

        auto pass = add_render_pass(&shadow_map_camera);
        render_passes.shadow_map = pass;
        set_shader(pass, &s.shadow_map_shader);
        clear_target_to_color(pass, Vec4(0, 0, 0, 0));
        pass.flags = Render_Flag_Disable_Color;
        pass.render_target = Render_Target.Shadow_Map;

        pass = add_render_pass(&world_camera);
        render_passes.holes = pass;
        set_shader(pass, &s.default_shader);

        pass = add_render_pass(&world_camera);
        render_passes.hole_cutouts = pass;
        set_shader(pass, &s.default_shader);
        pass.flags = Render_Flag_Disable_Culling|Render_Flag_Disable_Color;

        pass = add_render_pass(&world_camera);
        render_passes.ground = pass;
        set_shader(pass, &s.default_shader);

        pass = add_render_pass(&world_camera);
        render_passes.ground_decals = pass;
        set_shader(pass, &s.default_shader);
        set_light(pass, &s.light);

        pass = add_render_pass(&world_camera);
        render_passes.ground_decals = pass;
        set_shader(pass, &s.text_shader);
        pass.flags = Render_Flag_Disable_Depth_Writes;
        pass.blend_mode = Blend_Mode.One_Minus_Source_Alpha;

        pass = add_render_pass(&world_camera);
        render_passes.world = pass;
        set_shader(pass, &s.default_shader);
        set_light(pass, &s.light);

        pass = add_render_pass(&world_camera);
        g_debug_render_pass = pass;
        set_shader(pass, &s.text_shader);
        set_texture(pass, s.img_blank_rect);

        pass = add_render_pass(&world_camera);
        render_passes.particles = pass;
        set_shader(pass, &s.text_shader); // TODO: Particles shader?
        pass.flags = Render_Flag_Disable_Depth_Writes;
        pass.blend_mode = Blend_Mode.One_Minus_Source_Alpha;

        pass = add_render_pass(&hud_camera);
        render_passes.bg_scroll = pass;
        set_shader(pass, &s.shader_bg_scroll);
        set_texture(pass, s.img_tank_icon);
        pass.flags = Render_Flag_Disable_Depth_Test;
        pass.blend_mode = Blend_Mode.One_Minus_Source_Alpha;

        // TODO: If we had push_shader/pop_shader functions we wouldn't have to
        // split hud_rects into hud_rects and hud_rect_fg. Is this what we would eventually
        // prefer?
        pass = add_render_pass(&hud_camera);
        render_passes.hud_rects = pass;
        set_shader(pass, &s.text_shader);
        set_texture(pass, s.img_blank_rect);
        pass.flags = Render_Flag_Disable_Depth_Test;
        pass.blend_mode = Blend_Mode.One_Minus_Source_Alpha;

        pass = add_render_pass(&hud_camera);
        render_passes.hud_button = pass;
        set_shader(pass, &s.shader_menu_button);
        set_texture(pass, s.img_blank_rect);
        pass.flags = Render_Flag_Disable_Depth_Test;

        pass = add_render_pass(&hud_camera);
        render_passes.hud_rects_fg = pass;
        set_shader(pass, &s.text_shader);
        set_texture(pass, s.img_blank_rect);
        pass.flags = Render_Flag_Disable_Depth_Test;

        pass = add_render_pass(&hud_camera);
        render_passes.hud_text = pass;
        set_shader(pass, &s.text_shader);
        pass.flags = Render_Flag_Disable_Depth_Test;
        pass.blend_mode = Blend_Mode.One_Minus_Source_Alpha;

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
                    handle_event_common(s, &evt, dt);
                    handle_menu_event(s, &evt);
                }
                simulate_menu(s, dt, window_bounds);
            } break;

            case Game_Mode.Campaign:{
                if(!g_debug_mode && menu_is_closed(&s.menu))
                    hide_and_grab_cursor_this_frame();
                campaign_simulate(s, &player_input, target_dt);
                render_mesh(render_passes.world, &s.cube_mesh, (&s.material_ground)[0..1], mat4_translate(s.light.pos));
            } break;
        }

        auto perf_render_prep = begin_perf_timer("Render Prep");
        final switch(s.mode){
            case Game_Mode.None: assert(0);

            case Game_Mode.Editor:{
                editor_render(s, render_passes);
            } break;

            case Game_Mode.Menu:{
                auto bg_bounds = rect_from_min_max(Vec2(0, 0), Vec2(window.width, window.height));
                render_rect(render_passes.bg_scroll, bg_bounds, Vec4(0.05f, 0.10f, 0.16f, 1));
            } break;

            case Game_Mode.Campaign:{
                if(s.session.state != Session_State.Mission_Intro){
                    render_ground(s, render_passes.ground, s.world.bounds);
                    foreach(ref p; get_particles(&s.emitter_treadmarks)){
                        auto pos = render_to_world_pos(p.pos);
                        render_ground_decal(
                            render_passes.ground_decals, Rect(pos, Vec2(0.25f, 0.10f)),
                            Vec4(1, 1, 1, 0.4f), p.angle, s.img_tread_marks
                        );
                    }

                    foreach(ref e; iterate_entities(&s.world)){
                        render_entity(s, &e, render_passes);
                    }
                }

                sort_and_render_bullet_particles(
                    &s.emitter_bullet_contrails, render_passes.particles,
                    s.img_smoke, s.main_memory.scratch
                );

                foreach(ref p; get_particles(&s.emitter_explosion_flames)){
                    if(p.life > 0){
                        enum color_red_0  = Vec4(1, 1.0f, 0.8f, 1.0f);
                        enum color_red_1  = Vec4(1, 1.0f, 1.0f, 0.8f);
                        enum color_black  = Vec4(0.25f, 0.25f, 0.25f, 1.0f);

                        Vec4 color = Vec4(1, 1, 1, 0);
                        auto t = 1.0f - normalized_range_clamp(p.life, 0, Tank_Explosion_Particles_Time);
                        if(t < 0.2f){
                            auto t0 = normalized_range_clamp(t, 0, 0.2f);
                            color = lerp(color_red_0, color_red_1, t0);
                        }
                        else if(t < 0.5f){
                            auto t0 = normalized_range_clamp(t, 0.2f, 0.5f);
                            color = lerp(color_red_1, color_black, t0);
                        }
                        else{
                            auto t0 = normalized_range_clamp(t, 0.5f, 1.0f);
                            color = color_black;
                            color.a = 1.0f-t0;
                        }

                        float angle = 0;

                        float column = p.texture_bg;
                        auto uvs = rect_from_min_wh(Vec2(0.5f*column, 0.5f), 0.5f, 0.5f);
                        render_particle(
                            render_passes.particles, p.pos, Vec2(0.5f, 0.5f), color,
                            s.img_explosion, angle, uvs
                        );
                        column = p.texture_fg;
                        uvs = rect_from_min_wh(Vec2(0.5f*column, 0), 0.5f, 0.5f);
                        render_particle(
                            render_passes.particles, p.pos, Vec2(0.5f, 0.5f), color,
                            s.img_explosion, angle, uvs
                        );
                    }
                }

                switch(s.session.state){
                    default: break;

                    case Session_State.Mission_Intro:{
                        auto variant = &s.campaign.variants[s.session.variant_index];
                        auto mission = &variant.missions[s.session.mission_index];

                        auto font_large = &s.font_menu_large;
                        auto font_small = &s.font_menu_small;
                        auto rp_text = render_passes.hud_text;

                        auto screen_bg_bounds = rect_from_min_max(Vec2(0, 0), Vec2(window.width, window.height));
                        render_rect(render_passes.bg_scroll, screen_bg_bounds, Vec4(0.05f, 0.10f, 0.16f, 1));

                        auto text_bg_bounds = Rect(
                            Vec2(window.width, window.height)*0.5f,
                            Vec2(window.width, window.height*0.25f)*0.5f
                        );

                        auto rp_rects = render_passes.hud_rects;
                        render_rect(rp_rects, text_bg_bounds, Vec4(0.72f, 0.24f, 0.18f, 1));

                        auto pen = Vec2(window.width, window.height)*0.5f;

                        auto mission_text = gen_string("Mission {0}", s.session.mission_index+1, &s.frame_memory);
                        auto enemies_text = gen_string("Enemy tanks: {0}", mission.enemies.length, &s.frame_memory);

                        render_text(
                            rp_text, font_large, pen + Vec2(6, -6), mission_text,
                            Vec4(0, 0, 0, 1), Text_Align.Center_X
                        );
                        render_text(
                            rp_text, font_large, pen, mission_text,
                            Text_White, Text_Align.Center_X
                        );

                        pen.y -= cast(float)font_large.metrics.line_gap;
                        render_text(
                            rp_text, font_small, pen + Vec2(4, -4), enemies_text,
                            Vec4(0, 0, 0, 1), Text_Align.Center_X
                        );
                        render_text(
                            rp_text, font_small, pen, enemies_text,
                            Text_White, Text_Align.Center_X
                        );
                    } break;

                    case Session_State.Mission_Start:{
                        foreach(player_index, entity_id; get_player_entity_ids(&s.session)){
                            auto player = get_entity_by_id(&s.world, entity_id);

                            float offset_y = 1.2f; // TODO: Offset value should be resolution independent.
                            auto screen_p = project(&world_camera, Vec3(player.pos.x, 0, -player.pos.y - offset_y), window.width, window.height);
                            auto player_text = Player_Index_Strings[player_index];
                            render_text(
                                render_passes.hud_text, &s.font_editor_small, screen_p, player_text,
                                Text_White, Text_Align.Center_X
                            );
                        }

                    } break;

                    case Session_State.Playing_Mission:{
                        if(s.session.timer < 2.0f){
                            // TODO: Fade the text in/out over time
                            auto pen = Vec2(window.width, window.height)*0.5f;
                            render_text(
                                render_passes.hud_text, &s.font_menu_large, pen,
                                "Start!", Text_White, Text_Align.Center_X
                            );
                        }

                        auto font = &s.font_menu_small;
                        auto enemies_msg = gen_string("X {0}", s.session.enemies_remaining, &s.frame_memory);
                        auto tw = get_text_width(font, enemies_msg);

                        auto baseline = Vec2(window.width - 24 - tw, 24);
                        render_text(render_passes.hud_text, font, baseline, enemies_msg, Vec4(1, 1, 1, 1));

                        // TODO: Icon aspect ratio is hard-coded. It would be better if we
                        // could access the width/height from the texture itself.
                        float icon_w = 1024.0f;
                        float icon_h =  512.0f;
                        auto  icon_offset = Vec2(418.0f/icon_w, 360.0f/icon_h);
                        float icon_aspect_ratio = icon_w/icon_h;
                        float target_icon_height = font.metrics.height;
                        auto icon_extents = Vec2(target_icon_height*icon_aspect_ratio, target_icon_height);

                        auto icon_center = Vec2(
                            baseline.x - icon_extents.x,
                            baseline.y + icon_offset.y*target_icon_height,
                        );

                        auto icon_bounds = Rect(icon_center, icon_extents);
                        set_texture(render_passes.hud_text, s.img_tank_icon);
                        render_rect(render_passes.hud_text, icon_bounds, Vec4(1, 1, 1, 1));
                    } break;

                    case Session_State.Mission_End:{
                        auto font_large = &s.font_menu_large;
                        auto font_small = &s.font_menu_small;
                        auto p_text = render_passes.hud_text;

                        auto window_bounds = rect_from_min_wh(Vec2(0, 0), window.width, window.height);

                        auto cleared_height = font_large.metrics.height + 0.08f*cast(float)window.height;
                        auto cleared_bounds = Rect(
                            window_bounds.center + Vec2(0, height(window_bounds)*0.25f),
                            Vec2(window_bounds.extents.x, cleared_height*0.5f)
                        );

                        auto bg_color = Vec4(0.65f, 0.62f, 0.58f, 0.75f);
                        auto cleared_msg = "Mission Cleared!";
                        auto baseline = center_text(font_large, cleared_msg, cleared_bounds);
                        render_rect(render_passes.hud_rects, cleared_bounds, bg_color);
                        render_text(p_text, font_large, baseline, cleared_msg, Vec4(0.8f, 0.8f, 0.2f, 1));

                        float score_height = font_large.metrics.height + font_large.metrics.line_gap + font_small.metrics.height;
                        auto score_bounds = Rect(
                            window_bounds.center - Vec2(0, score_height*0.5f),
                            Vec2(window_bounds.extents.x*0.75f, score_height*0.5f)
                        );

                        auto players_count = s.session.players_count;
                        auto players_text = alloc_array!String(&s.frame_memory, players_count);

                        float mission_scores_text_width = 0.0f;
                        auto mission_scores = s.session.mission_kills[0 .. players_count];
                        foreach(player_index, score; mission_scores){
                            auto writer = begin_buffer_writer(&s.frame_memory);
                            format(writer, "{0}: {1} ", Player_Index_Strings[player_index], score);
                            auto text = end_buffer_writer(&s.frame_memory, &writer);
                            players_text[player_index] = text;
                            mission_scores_text_width += get_text_width(font_small, text);
                        }

                        render_rect(render_passes.hud_rects, score_bounds, bg_color);

                        auto pen = Vec2(score_bounds.center.x, top(score_bounds));
                        pen.y -= cast(float)font_large.metrics.height;
                        auto score_head_text = "Destroyed:";
                        baseline = center_text(font_large, score_head_text, pen);
                        render_text(p_text, font_large, baseline, score_head_text, Text_White);

                        float score_advance = (width(score_bounds) - mission_scores_text_width)
                            / (cast(float)players_count+1);

                        pen.x = left(score_bounds);
                        pen.y -= cast(float)font_large.metrics.line_gap;

                        foreach(player_index, text; players_text){
                            pen.x += score_advance;
                            baseline = center_text(font_small, text, pen);
                            auto text_color = Player_Text_Colors[player_index];
                            render_text(p_text, font_small, pen, text, text_color);
                        }
                    } break;
                }

                if(!g_debug_mode && menu_is_closed(&s.menu)){
                    auto color = Player_Text_Colors[s.session.player_index];
                    auto cursor_p = Vec2(s.mouse_pixel.x, window.height - s.mouse_pixel.y);
                    set_texture(render_passes.hud_text, s.img_crosshair);
                    render_rect(render_passes.hud_text, Rect(cursor_p, Vec2(window.width, window.width)*0.025f), color);
                }
            } break;
        }

        render_gui(&s.gui, &hud_camera, &s.rect_shader, &s.text_shader);
        menu_render(&render_passes, &s.menu, s.time, &s.frame_memory);

        // Render the shadow map
        if(g_debug_mode){
            set_shader(render_passes.hud_rects, &s.view_depth);
            render_rect(render_passes.hud_rects, Rect(Vec2(200, 200), Vec2(100, 100)), Vec4(1, 1, 1, 1));
        }

        end_perf_timer(&perf_render_prep);
        render_end_frame();

        audio_update();

        current_timestamp = ns_timestamp();
        ulong target_frame_time = cast(ulong)(dt*1000000000.0f);
        ulong elapsed_time = current_timestamp - prev_timestamp;
        if(elapsed_time < target_frame_time){
            ns_sleep(target_frame_time - elapsed_time); // TODO: Better sleep time.
        }
        prev_timestamp = current_timestamp;

        if(!g_debug_pause)
            render_submit_frame();
        end_frame();

        end_perf_timer(&perf_timer_frame);
        update_perf_info(g_debug_mode);

        watch_update(&file_watcher);
        Watch_Event w_evt;
        while(watch_read_event(&file_watcher, &w_evt)){
            if(w_evt.event & Watch_Event_Modified){
                auto name = trim_file_extension(w_evt.name);
                if(ends_with(name, "_frag") || ends_with(name, "_vert")){
                    name = name[0 .. $-5];
                }
                foreach(shader_index, shader_name; Shader_Names){
                    if(name == shader_name){
                        log("Reloading shader {0}!\n", w_evt.name);
                        load_shader(&s.shaders[shader_index], name, shaders_path, &s.frame_memory);
                        break;
                    }
                }
            }
        }
    }

    return 0;
}
