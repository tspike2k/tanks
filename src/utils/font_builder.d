/*
Copyright (c) 2025 tspike2k@github.com
Distributed under the Boost Software License, Version 1.0.
See accompanying file LICENSE_BOOST.txt or copy at http://www.boost.org/LICENSE_1_0.txt
*/

pragma(lib, "freetype");

import bind.freetype2;
import memory;
import assets;
import logging;

version(linux){
    String[] Font_Directories = [
        "/usr/share/fonts"
    ];
}

struct Font_Entry{
    uint height;
    uint stroke;
    uint fill_color;
    uint stroke_color;
    String source_file_name;
    String dest_file_name;

    // TODO: Rather than have the user determine the canvas size, we should determine this programatically.
    // We can do that by using a bin-packing algorithm to determine glyph placement and then
    // get the min and max canvas based on that.
    uint canvas_w;
    uint canvas_h;
};

struct Font_Builder{
    //Memory_Block *allocator;
    //Font_Entry     *font_entry;
    //Glyph_Entry    *glyph_entries;
    Font_Metrics    metrics;

    FT_Library lib;
    FT_Face    face;
    FT_Stroker stroker;
};

Font_Entry[] Font_Entries = [
    {
        height: 12, stroke: 1, fill_color: 0xFFFFFFFF, stroke_color: 0x000000FF,
        dest_file_name: "", source_file_name: ""
    },
];

void[] find_and_load_ttf_file(String name, Allocator* allocator){
    void[] result;
    foreach(dir; Font_Directories){
        auto path = recursive_file_search(dir, name, allocator.scratch);
        if(path.length){
            concat(dir, name);
            read_file_into_memory;
        }
    }
    return result;
}

bool begin_building_font(Font_Builder *builder, Font_Entry *entry){
    auto src_file = entry.source_file_name;

    if(FT_New_Face(builder.lib, src_file.ptr, 0, &builder.face) != 0){
        log("Unable to load font file {0}. Aborting...\n", src_file);
        return false;
    }

    FT_Set_Pixel_Sizes(builder.face, 0, entry.height);
    if(entry.stroke > 0){
        FT_Stroker_New(builder.lib, &builder.stroker);
        FT_Stroker_Set(builder.stroker, entry.stroke*64, FT_STROKER_LINECAP_ROUND, FT_STROKER_LINEJOIN_ROUND, 0);
    }

    // See here for a discussion on calculating the line gap:
    // https://freetype.nongnu.narkive.com/MyeGsd2a/ft-vert-advance-on-line-break
    // https://stackoverflow.com/a/30793586
    Font_Metrics *metrics = &builder.metrics;
    FT_Face face = builder.face;
    uint internal_leading = cast(uint)((face.size.metrics.ascender - face.size.metrics.descender) >> 6) - face.size.metrics.y_ppem;
    metrics.height      = entry.height; // TODO: Is it safe to assume the font height given by Freetype2 will match our request?
    metrics.line_gap    = cast(uint)(face.size.metrics.height) >> 6;
    metrics.cap_height  = cast(uint)((face.size.metrics.ascender >> 6) - internal_leading);
    metrics.char_height = cast(uint)(face.bbox.yMax - face.bbox.yMin) >> 6;

    FT_Load_Char(face, ' ', FT_LOAD_DEFAULT);
    metrics.space_width = cast(uint)(face.glyph.advance.x >> 6);

    return true;
}

void end_building_font(Font_Builder* builder, Font_Entry *font_entry){
    Pixels pixels = pack_glyphs_and_gen_texture(builder.glyph_entries, builder.allocator);

    // TODO: Is bulk clearing the memory faster than clearing on each call to push_writer?
    // I suspect that's true.
    memset(&file_memory[0], 0, Array_Length(file_memory));

    Slice writer = {(char*)&file_memory[0], Array_Length(file_memory)};
    Asset_File_Header *header = push_writer_type(writer, Asset_File_Header);
    header.magic      = Asset_File_Magic;
    header.version    = Asset_File_Version;
    header.asset_type = Asset_Type_Font;

    Asset_File_Section *section = push_writer_type(writer, Asset_File_Section);
    section.type = Font_Section_Metrics;
    section.size = sizeof(Font_Metrics);

    Font_Metrics *metrics = push_writer_type(writer, Font_Metrics);
    *metrics = builder.metrics;

    section = push_writer_type(writer, Asset_File_Section);
    section.type = Font_Section_Glyphs;

    // TODO: The null glyph must be the first entry in the list!
    Glyph_Entry *entry = builder.glyph_entries;
    while(entry){
        Font_Glyph *g = push_writer_type(writer, Font_Glyph);
        *g = entry.glyph;
        section.size += sizeof(Font_Glyph);

        entry = entry.next;
    }

    section = push_writer_type(writer, Asset_File_Section);
    section.type = Font_Section_Pixels;

    Font_Pixels_Header *pixels_header = push_writer_type(writer, Font_Pixels_Header);
    pixels_header.compression = Font_Compression_None;
    pixels_header.width  = pixels.width;
    pixels_header.height = pixels.height;
    slice_write(&writer, pixels.data, pixels.width*pixels.height*sizeof(u32));
    section.size = writer.data - (char*)section - sizeof(Asset_File_Section);

    // TODO: Depricate File_Flag_Trunc. It's too easy to forget it. Most of the time we want to
    // truncate anyway. Add a flag for appending to a file instead.
    File file;
    if(open_file(&file, font_entry.dest_file_name, File_Flag_Write|File_Flag_Trunc)){
        write_file(&file, 0, &file_memory[0], &writer.data[0] - &file_memory[0]);
        close_file(&file);
    }

    // TODO: Pick a filename based on the name of the destination filename
    save_to_tga("test.tga", &pixels.data[0], pixels.width, pixels.height, builder.allocator);

    if(font_entry.stroke) FT_Stroker_Done(builder.stroker);
    FT_Done_Face(builder.face);
}

extern(C) int main(){
    auto main_memory = os_alloc(4*1024*1024);
    scope(exit) os_dealloc(main_memory);

    auto allocator = Allocator(main_memory);
    allocator.scratch = &allocator;

    return 0;
}
