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
import files;
import math;

version(linux){
    __gshared String[] Font_Directories = [
        "/usr/share/fonts"
    ];
}

enum Atlas_Padding = 1;

struct Font_Entry{
    uint height;
    uint stroke;
    Vec4 fill_color;
    Vec4 stroke_color;
    String source_file_name;
    String dest_file_name;
};

struct Rasterized_Glyph{
    Pixels      pixels;
    Font_Glyph  glyph;
}

struct Font_Builder{
    Allocator*    allocator;
    Font_Entry*   font_entry;
    Font_Metrics  metrics;
    Atlas_Packer  atlas;

    FT_Library lib;
    FT_Face    face;
    FT_Stroker stroker;
    uint fill_color;
    uint stroke_color;
};

__gshared Font_Entry[] Font_Entries = [
    {
        height: 82, stroke: 1,
        fill_color: Vec4(1, 1, 1, 1), stroke_color: Vec4(0.16f, 0.34f, 0.68f, 1),
        dest_file_name: "./build/test_en.fnt", source_file_name: "LiberationSans-Regular.ttf"
    },
];

char[] get_path_for_ttf_file(String name, Allocator* allocator){
    char[] result;
    outer: foreach(dir_name; Font_Directories){
        foreach(entry; recurse_directory(dir_name, allocator)){
            if(entry.type == File_Type.File && is_match(name, entry.name)){
                result = get_full_path(&entry, allocator);
                break outer;
            }
        }
    }
    return result;
}

bool begin(Font_Builder* builder, Allocator* allocator){
    bool result = true;
    builder.allocator = allocator;
    if(FT_Init_FreeType(&builder.lib) != 0){
        // TODO: Get error diagnostic from Freetype? Can you?
        log_error("Unable to initialize Freetype2.\n");
    }
    return result;
}

void end(Font_Builder* builder){
    assert(builder.lib);
    FT_Done_FreeType(builder.lib);
}

uint blend_colors_premultiplied_alpha(uint source, uint dest){
    // Blending code adapted from Handmade Hero.
    // TODO: Cite which day of Handmade Hero it was from

    // TODO: Gamma corrected colors? See here for more information:
    // https://www.youtube.com/watch?v=fVyzTKCfchw&feature=youtu.be&t=3275
    Vec4 s = Vec4(
        (source >> 16) & 0xff, (source >>  8) & 0xff,
        (source >>  0) & 0xff, (source >> 24) & 0xff
    );

    Vec4 d = Vec4(
        (dest >> 16) & 0xff, (dest >>  8) & 0xff,
        (dest >>  0) & 0xff, (dest >> 24) & 0xff
    );

    float rsa = (s.a / 255.0f);
    float rda = (d.a / 255.0f);
    float inv_rsa = (1.0f - rsa);
    Vec4 out_c = Vec4(
        inv_rsa*d.r + s.r,
        inv_rsa*d.g + s.g,
        inv_rsa*d.b + s.b,
        (rsa + rda  - rsa * rda) * 255.0f
    );
    uint result = (cast(uint)out_c.a) << 24 | (cast(uint)out_c.r) << 16
                | (cast(uint)out_c.g) <<  8 | (cast(uint)out_c.b) <<  0;

    return result;
}

FT_BitmapGlyph make_bitmap_glyph(FT_Face face, FT_Stroker stroker, uint codepoint, uint stroke){
    // TODO: Error handling!
    FT_Load_Char(face, codepoint, FT_LOAD_DEFAULT | FT_LOAD_NO_BITMAP);
    FT_Glyph glyph_info;
    FT_Get_Glyph(face.glyph, &glyph_info);
    assert(glyph_info.format == FT_GLYPH_FORMAT_OUTLINE);

    if(stroke > 0)
        FT_Glyph_StrokeBorder(&glyph_info, stroker, false, true);

    FT_Glyph_To_Bitmap(&glyph_info, FT_RENDER_MODE_NORMAL, null, 1);
    FT_BitmapGlyph result = cast(FT_BitmapGlyph)glyph_info;
    return result;
}

void blit_to_dest(FT_BitmapGlyph bitmap_glyph, Pixels* pixels, uint target_color, uint offset_x, uint offset_y){
    uint w = bitmap_glyph.bitmap.width;
    uint h = bitmap_glyph.bitmap.rows;

    foreach(y; 0 .. h){
        foreach(x; 0 .. w){
            uint alpha = bitmap_glyph.bitmap.buffer[x + y*w];
            uint color = premultiply_alpha((target_color & 0x00ffffff) | (alpha << 24));

            auto pixel = &pixels.data[offset_x+x + (offset_y+y)*pixels.width];
            *pixel = blend_colors_premultiplied_alpha(color, *pixel);
        }
    }
}

bool rasterize_glyph_and_copy_metrics(Font_Builder *builder, uint codepoint, Font_Glyph *glyph, Pixels* pixels){
    // TODO: Better error handling!
    bool succeeded = true;

    FT_Face     face       = builder.face;
    FT_Stroker  stroker    = builder.stroker;
    Allocator*  allocator  = builder.allocator;
    Font_Entry* font_entry = builder.font_entry;

    auto bitmap_glyph = make_bitmap_glyph(face, stroker, codepoint, font_entry.stroke);
    pixels.width  = bitmap_glyph.bitmap.width;
    pixels.height = bitmap_glyph.bitmap.rows;
    pixels.data   = alloc_array!uint(allocator, pixels.width * pixels.height);

    // Copy glyph metrics
    glyph.codepoint = codepoint;
    glyph.width     = pixels.width;
    glyph.height    = pixels.height;
    glyph.offset.x  = bitmap_glyph.left;
    glyph.offset.y  = bitmap_glyph.bitmap.rows - bitmap_glyph.top;
    glyph.advance   = (cast(uint)face.glyph.advance.x) >> 6;

    uint target_color = font_entry.stroke == 0 ? builder.fill_color : builder.stroke_color;
    blit_to_dest(bitmap_glyph, pixels, target_color, 0, 0);

    if(font_entry.stroke){
        auto stroke_left = bitmap_glyph.left;
        auto stroke_top  = bitmap_glyph.top;

        bitmap_glyph = make_bitmap_glyph(face, stroker, codepoint, 0);
        uint fill_offset_x = bitmap_glyph.left - stroke_left;
        uint fill_offset_y = stroke_top - bitmap_glyph.top; // In Freetype the Y-axis of bitmaps grows upwards, hence the flipped subtraction.
        blit_to_dest(bitmap_glyph, pixels, builder.fill_color, fill_offset_x, fill_offset_y);

        glyph.offset.x += fill_offset_x;
        //glyph.offset.y += fille_offset_y; // TODO: Should we do this?
    }

    return succeeded;
}

bool begin_building_font(Font_Builder *builder, String source_file_name, Font_Entry *entry){
    push_frame(builder.allocator);

    builder.font_entry = entry;
    builder.fill_color   = rgba_to_uint(entry.fill_color);
    builder.stroke_color = rgba_to_uint(entry.stroke_color);

    if(FT_New_Face(builder.lib, source_file_name.ptr, 0, &builder.face) != 0){
        log("Unable to load font file {0}. Aborting...\n", source_file_name);
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

    builder.atlas = begin_atlas_packing(builder.allocator);

    return true;
}

void add_codepoint(Font_Builder* builder, uint codepoint){
    auto glyph = alloc_type!Rasterized_Glyph(builder.allocator);
    if(rasterize_glyph_and_copy_metrics(builder, codepoint, &glyph.glyph, &glyph.pixels)){
        add_item(&builder.atlas, glyph.pixels.width, glyph.pixels.height, glyph);
    }
    else{
        log_warn("Unable to add codepoint {0} to font file {1}", codepoint, builder.font_entry.dest_file_name);
    }
}

void end_building_font(Font_Builder* builder, Font_Entry *font_entry){
    auto atlas = &builder.atlas;
    end_atlas_packing(atlas, Atlas_Padding, true);

    auto canvas = Pixels(atlas.canvas_width, atlas.canvas_height);
    canvas.data = alloc_array!uint(builder.allocator, canvas.width*canvas.height);

    auto allocator = builder.allocator;

    auto node = atlas.items;
    while(node){
        auto glyph      = cast(Rasterized_Glyph*)node.source;
        auto glyph_info = glyph.glyph;
        auto source     = glyph.pixels;

        auto dest_x = node.x;
        auto dest_y = node.y;
        auto w = node.width;
        auto h = node.height;

        foreach(y; 0 .. h){
            foreach(x; 0 .. w){
                canvas.data[dest_x + x + (dest_y+y) * canvas.width] = source.data[x + y*w];
            }
        }

        // TODO: Sample from texel centers (add 0.5 to uv_min, subtract 0.5 from uv_max)?
        glyph_info.uv_min = Vec2(
            (cast(float)dest_x) / (cast(float)canvas.width),
            (cast(float)dest_y) / (cast(float)canvas.height)
        );

        glyph_info.uv_max = Vec2(
            (cast(float)(dest_x + source.width))  / (cast(float)canvas.width),
            (cast(float)(dest_y + source.height)) / (cast(float)canvas.height)
        );

        node = node.next;
    }

    save_to_tga("test.tga", canvas.data.ptr, canvas.width, canvas.height, allocator);

    auto file = open_file(font_entry.dest_file_name, File_Flag_Write|File_Flag_Trunc);
    if(is_open(&file)){
        push_frame(allocator.scratch);
        scope(exit) pop_frame(allocator.scratch);

        // TODO: Can we use the buffer_writer instead?

        auto dest = alloc_array!void(allocator, 8*1024*1024);
        auto writer = dest;

        auto header         = stream_next!Asset_Header(writer);
        header.magic        = Font_Meta.magic;
        header.file_version = Font_Meta.file_version;
        header.asset_type   = Font_Meta.type;

        auto section = begin_writing_section(writer, Font_Section.Metrics);
        auto metrics = stream_next!Font_Metrics(writer);
        *metrics = builder.metrics;
        end_writing_section(writer, section);

        section = begin_writing_section(writer, Font_Section.Pixels);
        auto dest_pixels_width  = cast(uint*)stream_next(writer, uint.sizeof);
        auto dest_pixels_height = cast(uint*)stream_next(writer, uint.sizeof);

        auto dest_pixels_size = canvas.width*canvas.height*uint.sizeof;
        auto dest_pixels = cast(uint[])stream_next(writer, dest_pixels_size);

        *dest_pixels_width  = canvas.width;
        *dest_pixels_height = canvas.height;
        copy(canvas.data, dest_pixels);
        end_writing_section(writer, section);

        section = begin_writing_section(writer, Font_Section.Glyphs);
        auto glyphs_count = cast(uint*)stream_next(writer, uint.sizeof);
        *glyphs_count = atlas.items_count;
        auto dest_glyphs = cast(Font_Glyph[])stream_next(writer, (*glyphs_count)*Font_Glyph.sizeof);
        uint glyph_index = 0;
        node = atlas.items;
        while(node){
            auto entry = cast(Rasterized_Glyph*)node.source;
            dest_glyphs[glyph_index++] = entry.glyph;
            node = node.next;
        }
        end_writing_section(writer, section);

        write_file(&file, 0, dest[0 .. writer.ptr - dest.ptr]);
        close_file(&file);
    }

    if(font_entry.stroke) FT_Stroker_Done(builder.stroker);
    FT_Done_Face(builder.face);

    pop_frame(builder.allocator);
}

extern(C) int main(){
    auto main_memory = os_alloc(128*1024*1024, 0);
    scope(exit) os_dealloc(main_memory);

    auto allocator = Allocator(main_memory);
    allocator.scratch = &allocator;

    Font_Builder builder = void;
    if(begin(&builder, &allocator)){
        foreach(ref entry; Font_Entries){
            auto src_file_path = get_path_for_ttf_file(entry.source_file_name, &allocator);
            if(src_file_path.length){
                if(begin_building_font(&builder, src_file_path, &entry)){
                    // TODO: Add the null glyph!
                    foreach(c; '!' .. '~'+1){
                        add_codepoint(&builder, c);
                    }
                    end_building_font(&builder, &entry);
                }
            }
            else{
                log_error("Unable to load font: {0}. Skipping.\n", entry.source_file_name, entry);
            }
        }
        end(&builder);
    }

    return 0;
}
