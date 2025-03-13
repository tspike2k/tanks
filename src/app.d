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

enum Main_Memory_Size    =  4*1024*1024;
enum Frame_Memory_Size   =  8*1024*1024;
enum Scratch_Memory_Size = 16*1024*1024;

struct App_State{
    Allocator main_memory;
    Allocator frame_memory;

    float player_angle;
    Vec2  player_pos;
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

extern(C) int main(){
    auto app_memory = os_alloc(Main_Memory_Size + Scratch_Memory_Size + Frame_Memory_Size, 0);
    scope(exit) os_dealloc(app_memory);

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

    bool running = true;
    while(running){
        begin_frame();

        Event evt;
        while(next_event(&evt)){
            switch(evt.type){
                default: break;

                case Event_Type.Window_Close:{
                    // TODO: Save state before exit in a temp/suspend file.
                    running = false;
                } break;
            }
        }

        render_begin_frame(0, 0, &s.frame_memory);
        clear_target_to_color(Vec4(1, 0, 0, 1));
        render_end_frame();

        end_frame();
    }

    return 0;
}
