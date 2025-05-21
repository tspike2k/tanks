/*
Authors:   tspike (github.com/tspike2k)
Copyright: Copyright (c) 2025
License:   Boost Software License 1.0 (https://www.boost.org/LICENSE_1_0.txt)
*/

import memory;
import math;
import files;
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

    if(header.file_version < target.min_version){
        log("Error reading file {0}. Minimum supported file version is {2} but got {1}.\n", file_name, header.file_version, target.min_version);
        return false;
    }

    if(header.file_version > target.file_version){
        log("Error reading file {0}. Maximum supported file version is {2} but got {1}.\n", file_name, header.file_version, target.file_version);
        return false;
    }

    if(header.asset_type != cast(uint)target.type){
        log("Error reading file {0}. Asset type is marked as {1} when expecting {2}.\n", file_name, cast(typeof(target.type))header.asset_type, target.type);
        return false;
    }

    return true;
}

Asset_Section* begin_writing_section(Serializer* dest, uint section_type){
    auto result = eat_type!Asset_Section(dest);
    result.type = section_type;
    return result;
}

void end_writing_section(Serializer* dest, Asset_Section* section){
    assert(cast(void*)(section + 1) <= &dest.buffer[dest.buffer_used]);
    section.size = cast(uint)(&dest.buffer[dest.buffer_used] - cast(void*)(section + 1));
}

Asset_Section* get_asset_section(Serializer* serializer){
    auto result = eat_type!Asset_Section(serializer);
    if(result && result.size > bytes_left(serializer)){
        result = null;
    }

    return result;

    return result;
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
enum Campaign_File_Version = 1;

struct Campaign_Meta{
    enum magic        = Campaign_File_Magic;
    enum file_version = Campaign_File_Version;
    enum min_version  = file_version;
    enum type         = Asset_Type.Campaign;
}

enum Campaign_Section_Type : uint{
    None,
    Info,
    Blocks, // Depricated
    Tanks,  // Depricated
    Level,
    Map,
}

enum Campaign_Difficuly : uint{
    Easy,
    Normal,
    Hard,
    Extreme,
    Impossible,
}

struct Campaign_Info{
    String             name;
    String             author;
    String             date;
    String             description;
    Campaign_Difficuly difficulty;
    uint               players_count;
    uint               levels_count;
    uint               maps_count;
    uint               next_map_id; // For editing
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

////
//
// Fonts
//
////

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

struct Kerning_Pair{
    uint a;
    uint b;
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
    Font_Metrics   metrics;
    Font_Glyph[]   glyphs; // TODO: Use a seperate array for the glyph codepoints. This way, lookups will be fast
    Kerning_Pair[] kerning_pairs;
    float[]        kerning_advance;
    ulong          texture_id;
}

Font_Glyph* get_glyph(Font* font, uint codepoint){
    Font_Glyph* result = &font.glyphs[0]; // TODO: Use a better fallback glyph.
    foreach(ref glyph; font.glyphs){
        if(glyph.codepoint == codepoint){
            result = &glyph;
            break;
        }
    }
    return result;
}

float get_codepoint_kerning_advance(Font* font, uint prev_codepoint, uint codepoint){
    float result = 0;
    auto key = Kerning_Pair(prev_codepoint, codepoint);

    // TODO: Should we prefer a hash table? With modern CPU caches, a linear search should
    // probably suffice. If the L1 cache is 16K large, that means we can search through
    // 2048 entries before we have a cache miss. That should be good enough, I suspect.
    // In the future we may wish to switch to a HashTable, though.
    foreach(i, ref entry; font.kerning_pairs){
        if(entry == key){
            result = font.kerning_advance[i];
            break;
        }
    }
    return result;
}

bool load_font_from_file(String file_name, Font* font, Pixels* pixels, Allocator* allocator){
    bool result = false;
    auto source = read_file_into_memory(file_name, allocator.scratch);
    if(source.length){
        auto serializer = Serializer(source);
        Asset_Header header;
        read(&serializer, to_void(&header));
        if(verify_asset_header!Font_Meta(file_name, &header)){
            // TODO: Read sections based on the sizes in the section header.
            // Have a function that will return the section payload, deflating compressed
            // data as needed.
            Font_Metrics* metrics;
            while(auto section = get_asset_section(&serializer)){
                switch(cast(Font_Section)section.type){
                    default:
                        eat_bytes(&serializer, section.size);
                        break;

                    case Font_Section.Metrics:{
                        metrics = eat_type!Font_Metrics(&serializer);
                        font.metrics = *metrics;
                    } break;

                    case Font_Section.Glyphs:{
                        uint glyphs_count;
                        read(&serializer, to_void(&glyphs_count));
                        if(glyphs_count > 0){
                            font.glyphs = eat_array!Font_Glyph(&serializer, glyphs_count);
                        }
                    } break;

                    case Font_Section.Kerning:{
                        uint kerning_count;
                        read(&serializer, to_void(&kerning_count));
                        if(kerning_count > 0){
                            font.kerning_pairs   = alloc_array!Kerning_Pair(allocator.scratch, kerning_count);
                            font.kerning_advance = alloc_array!float(allocator.scratch, kerning_count);

                            foreach(ref entry; font.kerning_pairs){
                                read(&serializer, to_void(&entry));
                            }

                            foreach(ref entry; font.kerning_advance){
                                read(&serializer, to_void(&entry));
                            }
                        }
                    } break;

                    case Font_Section.Pixels:{
                        uint width, height;
                        read(&serializer, to_void(&width));
                        read(&serializer, to_void(&height));
                        if(width && height){
                            pixels.data   = eat_array!uint(&serializer, width*height);
                            pixels.width  = width;
                            pixels.height = height;
                        }
                    } break;
                }
            }

            result = metrics && pixels.data.length && font.glyphs.length;
        }
    }

    return result;
}

////
//
// TGA Files
//
////

/*
TGA loading cade based on text from the following source:
https://paulbourke.net/dataformats/tga/
*/

enum TGA_Data_Type_Uncompressed_RGB = 2;
enum TGA_Desc_Upper_Left_Origin = (1 << 5);

bool is_non_interleaved(TGA_Header* header){
    auto desc = header.image_desc;
    auto result = !((desc) & ((1 << 6) | (1 << 7)));
    return result;
}

struct TGA_Header{
    align(1):
    ubyte id_length;
    ubyte colormap_type;
    ubyte data_type;
    short colormap_origin;
    short colormap_length;
    ubyte colormap_depth;
    short x_origin;
    short y_origin;
    short width;  // TODO: Is this really signed?
    short height; // TODO: Is this really signed?
    ubyte bits_per_pixel;
    ubyte image_desc;
}
static assert(TGA_Header.sizeof == 18);

/+
Pixels load_pixels_from_tga(void[] file_contents, String file_name, Memory_Block *block){
    Pixels result;
    if(file_contents.length < TGA_Header_Size){
        log(Cyu_Err "File {0} is too small to contain a valid TGA header.\n", file_name);
        return result;
    }

    assert(sizeof(TGA_Header) == TGA_Header_Size);
    TGA_Header *header = (TGA_Header*)file_contents.data;

    // TODO: Handle 24-bit pixel data
    if(header.data_type != TGA_Data_Type_Uncompressed_RGB){
        log(Cyu_Err "Unsupported TGA file for {0}. File must be an uncompressed RGB image.\n", file_name);
        return result;
    }

    if(header.bits_per_pixel != 32){
        log(Cyu_Err "Unsupported TGA file for {0}. File must be a 32-bit image (got {1}-bit).\n", file_name), fmt_u(header.bits_per_pixel));
        return result;
    }

    if(!(header.image_desc & TGA_Desc_Upper_Left_Origin)){
        log(Cyu_Err "Unsupported TGA file for {0}. Origin must be at the upper-left.\n", file_name);
        return result;
    }

    if(!is_non_interleaved(header.image_desc)){
        log(Cyu_Err "Unsupported TGA file for {0}. Pixel data must be non-interleaved.\n", file_name);
        return result;
    }

    u32 w = header.width;
    u32 h = header.height;
    char* pixels_start = file_contents.data + TGA_Header_Size + header.id_length;

    if(file_contents.length < w*h*sizeof(u32) + (pixels_start - file_contents.data)){
        log(Cyu_Err "Invalid TGA file for {0}. File is too small to contain {1}x{2} pixel data.\n", fmt_cstr(file_name), fmt_u(w), fmt_u(h));
        return result;
    }

    u32* source = (u32*)(pixels_start);
    u32 pixel_count = w*h;
    u32 *dest = (u32*)memory_alloc(block, pixel_count*sizeof(u32), 0, Default_Align);
    if(!dest){
        log(Cyu_Err "Unable to allocate memory for pixels for file {0}.\n", fmt_cstr(file_name));
        return result;
    }

    for(u32 pixel_index = 0; pixel_index < pixel_count; pixel_index++){
        u32 *pixel = &source[pixel_index];

        u8 a = (*pixel >> 24) & 0xff;
        u8 r = (*pixel >> 16) & 0xff;
        u8 g = (*pixel >> 8)  & 0xff;
        u8 b = (*pixel)       & 0xff;

        dest[pixel_index] = ((u32)r) | ((u32)g) << 8
            | ((u32)b) << 16 | ((u32)a) << 24;
    }

    result.width  = w;
    result.height = h;
    result.data   = dest;

    return result;
}+/

void save_to_tga(String file_name, uint *pixels, uint width, uint height, Allocator *allocator){
    auto scratch = allocator.scratch;
    push_frame(scratch);
    scope(exit) pop_frame(scratch);

    auto file = open_file(file_name, File_Flag_Write);
    if(is_open(&file)){
        size_t dest_size = TGA_Header.sizeof + uint.sizeof*width*height;
        auto dest = alloc_array!void(scratch, dest_size);

        auto header           = cast(TGA_Header*)dest;
        header.data_type      = TGA_Data_Type_Uncompressed_RGB;
        header.bits_per_pixel = 32;
        header.width          = cast(short)width;
        header.height         = cast(short)height;
        header.image_desc     = TGA_Desc_Upper_Left_Origin;

        auto out_pixels = cast(uint[])dest[TGA_Header.sizeof .. $];
        foreach(pixel_index, ref out_pixel; out_pixels){
            auto pixel = &pixels[pixel_index];

            ubyte a = (*pixel >> 24) & 0xff;
            ubyte r = (*pixel >> 16) & 0xff;
            ubyte g = (*pixel >> 8)  & 0xff;
            ubyte b = (*pixel)       & 0xff;

            out_pixel = (cast(uint)a) << 24 | (cast(uint)b) << 16
                      | (cast(uint)g) << 8 | (cast(uint)r);
        }

        write_file(&file, 0, dest);
        close_file(&file);
    }
}

////
//
// Atlas Packer
//
////

struct Atlas_Packer{
    struct Node{
        Node* next;

        // X grows to the right
        // Y grows to the bottom
        uint x;
        uint y;
        uint width;
        uint height;
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

Atlas_Packer begin_atlas_packing(Allocator* allocator){
    Atlas_Packer packer;
    packer.scratch = allocator.scratch;
    return packer;
}

void add_item(Atlas_Packer* packer, uint width, uint height, void* source){
    auto node = alloc_type!(Atlas_Packer.Node)(packer.scratch);
    node.next = packer.items;
    packer.items = node;

    node.width  = width;
    node.height = height;
    node.source = source;

    packer.items_count++;
    packer.items_width  += width;
    packer.items_height += height;
}

void end_atlas_packing(Atlas_Packer* packer, uint padding, bool use_powers_of_two){
    // Using this algorithm, we estimate the desired canvas width and grow the height as
    // much as we need.
    //
    // TODO: Perhaps there's a better way to handle this? It seems to work pretty well so far.
    // We may need to use maximum item width rather than everage item width for things other
    // than fonts.
    auto columns = cast(uint)ceil(sqrt(cast(float)packer.items_count));
    auto average_width  = packer.items_width  / packer.items_count;
    auto canvas_width   = (average_width  * columns) + padding*(packer.items_count+1);

    if(use_powers_of_two){
        canvas_width  = round_up_power_of_two(canvas_width);
    }

    uint pen_x = padding;
    uint pen_y = padding;

    auto node = packer.items;

    uint canvas_height = 0;
    uint max_line_height = 0;
    while(node){
        if(pen_x + node.width + padding >= canvas_width){
            pen_y += max_line_height + padding;
            pen_x = padding;
            max_line_height = 0;
        }

        assert(pen_x + node.width + padding < canvas_width);
        node.x = pen_x;
        node.y = pen_y;
        max_line_height = max(max_line_height, node.height);
        canvas_height   = max(canvas_height, pen_y + max_line_height + padding);

        pen_x += node.width + padding;

        node = node.next;
    }

    if(use_powers_of_two)
        canvas_height = round_up_power_of_two(canvas_height);

    packer.canvas_width  = canvas_width;
    packer.canvas_height = canvas_height;
}
