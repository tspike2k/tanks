/*
Authors:   tspike (github.com/tspike2k)
Copyright: Copyright (c) 2025
License:   Boost Software License 1.0 (https://www.boost.org/LICENSE_1_0.txt)
*/

import memory;
import math : Vec2, Rect;
private{
    import files;
    import logging;
}

enum Asset_File_Version = 1;
enum uint Asset_File_Magic = ('a' << 0 | 's' << 8 | 'e' << 16 | 't' << 24);

enum Compression_Type_None = 0;

enum{
    Asset_Type_Font   = 1,
    Asset_Type_Sprite = 2,
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
