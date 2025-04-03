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

////
//
// Campaign files
//
////

enum Campaign_File_Magic = ('T' << 0 | 'a' << 8 | 'n' << 16 | 'k' << 24);
enum Campaign_File_Version = 0;

struct Campaign_Header{
    align(1):

    uint     magic;
    uint     file_version;
    uint[14] reserved;
}

enum Campaign_Section_Type: uint{
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


version(none):


enum Asset_File_Version = 1;
enum uint Asset_File_Magic = ('a' << 0 | 's' << 8 | 'e' << 16 | 't' << 24);

enum Compression_Type_None = 0;

enum{
    Asset_Type_Font   = 1,
    Asset_Type_Sprite = 2,
    Asset_Type_Level  = 3,
}

enum{
    Font_Section_Metrics = 1,
    Font_Section_Glyphs  = 2,
    Font_Section_Kerning = 3,
    Font_Section_Pixels  = 4,
}

struct Asset_File_Header{
    align(1):

    uint magic;
    uint file_version;
    uint asset_type;
    uint cpu_id;
    uint[12] reserved;
}

struct Asset_File_Section{
    align(1):

    uint  type;
    uint  version_info;
    ulong size;
}

struct Font_Pixels_Header{
    align(1):

    uint compression;
    uint width;
    uint height;
}

struct Pixels{
    uint[] data;
    uint   width;
    uint   height;
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

struct Asset_Font{
    Font_Metrics metrics;
    Font_Glyph[] glyphs;
    Pixels       pixels;
}

private bool verify_asset_file_header(Asset_File_Header* header, const(char)[] file_name){
    bool succeeded = false;
    if(header.magic == Asset_File_Magic){
        if(header.file_version <= Asset_File_Version){
            succeeded = true;
        }
        else{
            // TODO: Log error
            assert(0);
        }
    }
    else{
        // TODO: Log error
        assert(0);
    }
    return succeeded;
}

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
