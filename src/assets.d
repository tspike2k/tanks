/*
Authors:   tspike (github.com/tspike2k)
Copyright: Copyright (c) 2025
License:   Boost Software License 1.0 (https://www.boost.org/LICENSE_1_0.txt)
*/

import memory;
import math;
import render : Mesh;
private{
    import files;
    import logging;
}

struct Asset_Header{
    align(1):

    uint     magic;
    uint     file_version;
    uint     asset_type;
    uint[13] reserved;
}

enum Asset_Type : uint{
    None,
    Font,
    Campaign,
}

enum Compression : uint{
    None,
}

struct Asset_Section{
    align(1):
    uint        type;
    Compression compression;
    uint        size;
    uint        compressed_size;
}

bool verify_asset_header(alias target)(const(char)[] file_name, Asset_Header* header){
    if(!header){
        log("Header for file {0} is null. Perhaps the file is too short to read.\n");
        return false;
    }

    if(header.magic != target.magic){
        log("Error reading file {0}. Expected magic {1} but got magic of {2} instead.\n", file_name, header.magic, target.magic);
        return false;
    }

    if(header.file_version >= target.min_version){
        log("Error reading file {0}. Minimum supported file version is {2} but got {1}.\n", file_name, header.file_version, target.min_version);
        return false;
    }

    if(header.file_version <= target.file_version){
        log("Error reading file {0}. Maximum supported file version is {2} but got {1}.\n", file_name, header.file_version, target.file_version);
        return false;
    }

    if(header.file_version <= target.file_version){
        log("Error reading file {0}. Maximum supported file version is {2} but got {1}.\n", file_name, header.file_version, target.file_version);
        return false;
    }

    if(header.asset_type == target.type){
        log("Error reading file {0}. Asset type is marked as {1} when expecting {2}.\n", file_name, header.asset_type, target.type);
        return false;
    }

    return true;
}

struct Pixels{
    uint   width;
    uint   height;
    uint[] data;
}

////
//
// Campaign files
//
////

// TODO: Convert Campaign files to using the Asset structure.

enum Campaign_File_Magic = ('T' << 0 | 'a' << 8 | 'n' << 16 | 'k' << 24);
enum Campaign_File_Version = 0;

struct Campaign_Meta{
    enum magic        = Campaign_File_Magic;
    enum file_version = Campaign_File_Version;
    enum min_version  = file_version;
    enum type         = Asset_Type.Campaign;
}

enum Campaign_Section_Type : uint{
    None,
    Info,
    Blocks,
    Tanks,
}

struct Campaign_Section{
    Campaign_Section_Type type;
    uint                  size;
}

////
//
// Obj Files
//
////

struct Obj_Face_Point{
    uint v;
    uint n;
    uint uv;
}

struct Obj_Face{
    Obj_Face_Point[3] points;
}

struct Obj_Data{
    Vec3[]     vertices; // TODO: Rename this positions/ or something like that.
    Vec3[]     normals;
    Vec4[]     colors;
    Vec2[]     uvs;
    Obj_Face[] faces;
}

String eat_obj_line_command(ref String reader){
    String result;

    foreach(i, c; reader){
        if(is_whitespace(c)){
            result = reader[0 .. i];
            reader = reader[i+1..$];
            break;
        }
    }

    return result;
}

Obj_Data parse_obj_file(String source, Allocator* allocator){
    Obj_Data result;

    //
    // First-pass counts all the elements.
    // TODO: Should we use an expandable array instead?
    //
    {
        uint vertex_count, normals_count, uvs_count, faces_count;

        auto reader = source;
        while(reader.length){
            auto line = eat_line(reader);

            auto cmd = eat_obj_line_command(line);
            switch(cmd){
                default: break;

                case "v":{
                    vertex_count++;
                } break;

                case "vn":{
                    normals_count++;
                } break;

                case "vt":{
                    uvs_count++;
                } break;

                case "f":{
                    faces_count++;
                } break;
            }
        }

        result.vertices = alloc_array!Vec3(allocator, vertex_count);
        result.faces    = alloc_array!Obj_Face(allocator, faces_count);
        result.normals =  alloc_array!Vec3(allocator, normals_count);
    }

    uint v_index, f_index, n_index;

    auto reader = source;
    while(reader.length){
        auto line = eat_line(reader);

        auto cmd = eat_obj_line_command(line);
        switch(cmd){
            default: break;

            case "v":{
                auto v = &result.vertices[v_index++];
                to_float(&v.x, eat_between_whitespace(line));
                to_float(&v.y, eat_between_whitespace(line));
                to_float(&v.z, eat_between_whitespace(line));
            } break;

            case "vn":{
                auto n = &result.normals[n_index++];
                to_float(&n.x, eat_between_whitespace(line));
                to_float(&n.y, eat_between_whitespace(line));
                to_float(&n.z, eat_between_whitespace(line));
            } break;

            case "vt":{

            } break;

            case "f":{
                auto f = &result.faces[f_index++];
                if(result.normals.length == 0 && result.uvs.length == 0){
                    to_int(&f.points[0].v, eat_between_whitespace(line));
                    to_int(&f.points[1].v, eat_between_whitespace(line));
                    to_int(&f.points[2].v, eat_between_whitespace(line));
                }
                else{
                    // TODO: Handle face entries that bundle normal and uvs indeces.
                    foreach(i; 0 .. 3){
                        auto entry = eat_between_whitespace(line);
                        auto p = &f.points[i];
                        to_int(&p.v, eat_between_char(entry, '/'));
                        to_int(&p.uv, eat_between_char(entry, '/'));
                        to_int(&p.n, eat_between_char(entry, '/'));
                    }
                }
            } break;
        }
    }

    return result;
}

struct Font_Meta{
    enum magic        = ('F' << 0 | 'o' << 8 | 'n' << 16 | 't' << 24);
    enum file_version = 0;
    enum min_version  = file_version;
    enum type         = Asset_Type.Font;
}

enum Font_Section : uint{
    None    = 0,
    Metrics = 1,
    Glyphs  = 2,
    Kerning = 3,
    Pixels  = 4,
}

struct Font_Metrics{
    uint height;
    uint line_gap;
    uint space_width;
    uint cap_height;
    uint char_height; // NOTE: Maximum character height
}

struct Font_Glyph{
    uint codepoint;
    uint width;
    uint height;
    uint advance;
    Vec2 offset;
    Vec2 uv_min;
    Vec2 uv_max;
}

struct Font{
    Font_Metrics metrics;
    Font_Glyph[] glyphs;
    // TODO: Include the kerning table here.
    uint   bitmap_width;
    uint   bitmap_height;
    uint[] bitmap_pixels;
}

bool parse_font_file(String file_name, void[] source, Font* font, Pixels* pixels, Allocator* allocator){
    auto reader = source;
    auto header = stream_next!Asset_Header(reader);

    // TODO: Read sections based on the sizes in the section header.
    // Have a function that will return the section payload, deflating compressed
    // data as needed.
    bool result = false;
    if(verify_asset_header!Font_Meta(file_name, header)){
        Font_Metrics* metrics;
        Font_Glyph[]  glyphs;

        while(auto section_header = stream_next!Asset_Section(reader)){
            switch(cast(Font_Section)section_header.type){
                default: break;

                case Font_Section.Metrics:{
                    metrics = stream_next!Font_Metrics(reader);
                } break;

                case Font_Section.Glyphs:{
                    auto glyphs_count = stream_next!uint(reader);
                    if(glyphs_count){
                        glyphs = cast(Font_Glyph[])stream_next(reader, Font_Glyph.sizeof * (*glyphs_count));
                    }
                } break;

                case Font_Section.Pixels:{
                    auto width  = stream_next!uint(reader);
                    auto height = stream_next!uint(reader);
                    if(width && height){
                        pixels.width  = *width;
                        pixels.height = *height;
                        pixels.data   = cast(uint[])stream_next(reader, (*width)*(*height)*uint.sizeof);
                    }
                } break;
            }
        }

        if(metrics){
            font.metrics = *metrics;
        }
        result = metrics && glyphs.length && pixels.data.length;
    }

    return result;
}

////
//
// Atlas Packer
//
////

struct Atlas_Packer{
    struct Node{
        Node* next;
        Rect  bounds;
        void* source;
    }

    Allocator* scratch;
    uint       canvas_width;
    uint       canvas_height;

    Node*      items;
    uint       items_count;
    uint       items_height;
    uint       items_width;
}

Atlas_Packer begin_packing(Allocator* allocator){
    Atlas_Packer packer;
    packer.scratch = allocator.scratch;
    return packer;
}

void add_rect(Atlas_Packer* packer, Rect bounds, void* source){
    auto node = alloc_type!Atlas_Packer.Node(scratch);
    node.next = packer.items;
    packer.items = node;

    packer.items_count++;
    packer.items_width  += cast(uint)width(bounds);
    packer.items_height += cast(uint)height(bounds);
}

void end_packing(Atlas_Packer* packer, uint padding){

}
