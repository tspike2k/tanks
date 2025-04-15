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

bool verify_header(alias target)(const(char)[] file_name, Asset_Header* header){
    if(header.magic != target.magic){
        format("Error reading file {0}. Expected magic {1} but got magic of {2} instead.\n", file_name, magic, target.magic);
        return false;
    }

    if(header.file_version >= target.min_version){
        format("Error reading file {0}. Minimum supported file version is {2} but got {1}.\n", file_name, header.file_version, target.min_version);
        return false;
    }

    if(header.file_version <= target.file_version){
        format("Error reading file {0}. Maximum supported file version is {2} but got {1}.\n", file_name, header.file_version, target.file_version);
        return false;
    }

    if(header.file_version <= target.file_version){
        format("Error reading file {0}. Maximum supported file version is {2} but got {1}.\n", file_name, header.file_version, target.file_version);
        return false;
    }

    if(header.type == target.type){
        format("Error reading file {0}. Asset type is marked as {1} when expecting {2}.\n", file_name, header.type, target.type);
        return false;
    }

    return true;
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

struct Pixels{
    uint   width;
    uint   height;
    uint[] data;
}

bool parse_font_file(void[] source, Font* font, Pixels* pixels){
    bool result = false;

    auto reader = source;
    auto header = stream_next!Asset_Header(reader);
    if(header && verify_asset_file_header!Font_Meta(header)){
        while(auto section = stream_next!Asset_Section(reader)){
            switch(cast(Font_Section)section.type){
                default: break;

                case Font_Section.Metrics:{
                    auto map = &campaign.maps[map_index++];

                    auto count = section.size / Cmd_Make_Block.sizeof;
                    map.blocks = alloc_array!Cmd_Make_Block(allocator, count);

                    foreach(i; 0 .. count){
                        auto cmd = stream_next!Cmd_Make_Block(reader);
                        map.blocks[i] = *cmd;
                    }
                } break;

                case Campaign_Section_Type.Tanks:{
                    auto level = &campaign.levels[level_index++];
                    auto count = section.size / Cmd_Make_Tank.sizeof;
                    level.tanks = alloc_array!Cmd_Make_Tank(allocator, count);

                    foreach(i; 0 .. count){
                        auto cmd = stream_next!Cmd_Make_Tank(reader);
                        level.tanks[i] = *cmd;
                    }
                } break;
            }
        }
    }

    return result;
}



version(none):


bool load_font_from_file(const(char)[] file_name, Asset_Font* font, Allocator* allocator){
    push_frame(allocator.scratch);
    scope(exit) pop_frame(allocator.scratch);

    bool succeeded = false;

    auto file = open_file(file_name, File_Flag_Read);
    if(is_open(&file)){
        auto source = read_file_into_memory(file_name, allocator.scratch);
        if(source.length >= Asset_File_Header.sizeof){
            auto header = cast(Asset_File_Header*)eat_bytes(source, Asset_File_Header.sizeof);
            if(verify_asset_file_header(header, file_name)){
                while(source.length > 0){
                    auto section = cast(Asset_File_Section*)eat_bytes(source, Asset_File_Section.sizeof);
                    auto data = eat_bytes(source, section.size);

                    // TODO: Skip the sections if the data size is not what we expect and report an error.
                    switch(section.type){
                        default: break;

                        case Font_Section_Metrics:{
                            font.metrics = *(cast(Font_Metrics*)data);
                        } break;

                        case Font_Section_Glyphs:{
                            uint glyphs_count = cast(uint)(data.length/Font_Glyph.sizeof);
                            if(glyphs_count > 0){
                                font.glyphs = alloc_array!Font_Glyph(allocator, glyphs_count);
                                memcpy(font.glyphs.ptr, data.ptr, glyphs_count*Font_Glyph.sizeof);
                                succeeded = true;
                            }
                            else{
                                // TODO: Report error?
                                assert(0);
                            }
                        } break;

                        case Font_Section_Pixels:{
                            auto pixels_header = cast(Font_Pixels_Header*)eat_bytes(data, Font_Pixels_Header.sizeof);
                            assert(pixels_header.compression == Compression_Type_None);
                            uint w = pixels_header.width;
                            uint h = pixels_header.height;

                            font.pixels.width  = w;
                            font.pixels.height = h;
                            font.pixels.data   = alloc_array!uint(allocator, w*h);
                            assert(data.length >= w*h*uint.sizeof);
                            memcpy(font.pixels.data.ptr, data.ptr, w*h*uint.sizeof);
                        } break;
                    }
                }
            }
        }
        else{
            log("File is to short to be an asset file.\n"); // TODO: Better format function. Print file name!
        }

        close_file(&file);
    }

    return succeeded;
}
