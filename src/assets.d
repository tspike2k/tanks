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
        auto header_magic = (cast(char*)&header.magic)[0 .. 4];
        auto target_magic_raw = target.magic;
        auto target_magic = (cast(char*)&target_magic_raw)[0 .. 4];
        log("Error reading file {0}. Expected magic '{1}' but got '{2}' instead.\n", file_name, target_magic, header_magic);
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

enum Campaign_File_Magic = ('T' << 0 | 'a' << 8 | 'n' << 16 | 'k' << 24);
enum Campaign_File_Version = 4;

struct Campaign_Meta{
    enum magic        = Campaign_File_Magic;
    enum file_version = Campaign_File_Version;
    enum min_version  = file_version;
    enum type         = Asset_Type.Campaign;
}

enum Campaign_Difficuly : uint{
    Easy,
    Normal,
    Hard,
    Extreme,
    Impossible,
}

alias Map_Cell = ubyte;
enum Map_Cell Map_Cell_Is_Tank     = (1 << 7);
enum Map_Cell Map_Cell_Is_Special  = (1 << 6);
enum Map_Cell Map_Cell_Index_Mask  = (0b00001111);
enum Map_Cell Map_Cell_Facing_Mask = (0b00110000);

alias Map_Cell_Is_Breakable = Map_Cell_Is_Special;
alias Map_Cell_Is_Player    = Map_Cell_Is_Special;

// Each campaign map is borken up into cells. Each cell can contain zero or one entity.
// The type of entity and its properties are determined by the value stored in a given
// cell. If the value is zero, the cell is empty.
//
// Each cell value is a single byte. The bits in each byte are encoded like so:
//      tsffuiii
//
// t    - If set, the entity is a tank. If not set, the entity is a block.
// s    - Special flag. If set when entity is a block, the block is unbreakable.
//        If set when a tank, the tank is controlled by a player.
// ff   - The facing direction of a tank. Unused for tanks, but is set to non-zero for blocks
//        to prevent a block with no height (a hole) from being encoded as zero (the empty cell).
// u    - unused
// iii  - The "index" value of the entity. When a block, determines height. When a player tank,
//        determines the index of the player that controls the tank. For enemy tanks, determines
//        which spawner on the map should be used to generate the tank.
Map_Cell encode_map_cell(bool is_tank, bool is_special, ubyte index){
    Map_Cell result;

    if(is_tank)
        result |= Map_Cell_Is_Tank;
    else
        result |= Map_Cell_Facing_Mask; // Must always be set for blocks to ensure non-zero values.;

    if(is_special)
        result |= Map_Cell_Is_Special;

    result |= (index & Map_Cell_Index_Mask);
    return result;
}

struct Campaign_Map{
    uint[2]    reserved;
    uint       width;
    uint       height;
    Map_Cell[] cells;
}

// type_min/type_max: Determines the entry in the Campaign.tank_types array from which this
// tank should be spawned. If min and max are equal, then the value is the exact index into
// the array. Otherwise, the index is a random number between type_min and type_max, inclusive.
//
// spawn_index: The index of the tank spawner to use encoded in the map cells.
struct Enemy_Tank{
    uint type_min;
    uint type_max;
    uint spawn_index;
    uint reserved;
}

// Tank params based on "Wii Tanks AI Parameter Sheet" by BigKitty1011
struct Tank_Type{
    Vec3  main_color;
    Vec3  alt_color;
    bool  invisible;
    float speed;
    uint  bullet_limit;          // Word 30
    uint  bullet_ricochets;      // Word 34
    float bullet_speed;
    float bullet_min_ally_dist;  // Word 41

    uint  mine_limit;            // Word 3
    float mine_timer_min;        // Word 5
    float mine_timer_max;        // Word 4
    float mine_cooldown_time;    // Word 9
    float mine_stun_time;        // Word 10
    float mine_placement_chance; // Word 8
    float mine_min_ally_dist;    // Word 6

    float turret_turn_speed;     // Word 39

    bool aggressive_survival;    // Word 20

    float obstacle_sight_dist; // Obstacle Awareness (Movement)

    float fire_timer_min;     // Word 36
    float fire_timer_max;     // Word 35
    float fire_stun_time;     // Word 42
    float fire_cooldown_time; // Word 37
    float aim_timer;          // Word 40
    float aim_max_angle;      // Word 29
}

struct Campaign_Mission{
    bool awards_tank_bonus;
    uint map_index_min;
    uint map_index_max;
    Enemy_Tank[] enemies;
}

struct Campaign_Variant{
    uint               players;
    uint               lives;
    Campaign_Difficuly difficulty;
    uint[3]            reserved;
    String             name;
    Campaign_Mission[] missions;
}

struct Campaign{
    String             name;
    String             author;
    String             date;
    String             description;
    String             version_string;
    uint[4]            reserved;
    Campaign_Variant[] variants;
    Tank_Type[]        tank_types;
    Campaign_Map[]     maps;
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

struct Obj_Model{
    Obj_Model* next;
    Obj_Face[] faces;
    uint material_index;
}

struct Obj_Data{
    Obj_Model* model_first;
    uint models_count;

    Vec3[] vertices; // TODO: Rename this positions/ or something like that.
    Vec3[] normals;
    Vec4[] colors;
    Vec2[] uvs;
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

    auto reader = source;
    uint vertex_count, normals_count, uvs_count, faces_count;

    //
    // First-pass counts all the elements.
    // TODO: Should we use an expandable array instead?
    //
    Obj_Model* model;
    while(reader.length > 0){
        auto line = eat_line(reader);
        auto cmd = eat_obj_line_command(line);
        switch(cmd){
            default: break;

            case "o":{
                auto next = alloc_type!Obj_Model(allocator);
                if(!result.model_first){
                    result.model_first = next;
                }

                if(model){
                    model.faces = alloc_array!Obj_Face(allocator, faces_count);
                    model.next = next;
                }
                model = next;
                result.models_count++;
                faces_count = 0;
            } break;

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
    assert(model.faces.length == 0);
    model.faces = alloc_array!Obj_Face(allocator, faces_count);

    result.vertices = alloc_array!Vec3(allocator, vertex_count);
    result.normals  = alloc_array!Vec3(allocator, normals_count);
    result.uvs      = alloc_array!Vec2(allocator, uvs_count);

    reader = source;
    model = null;
    while(reader.length > 0){
        uint v_index, n_index, vt_index, f_index;
        second_pass: while(reader.length > 0){
            auto line = eat_line(reader);
            auto cmd = eat_obj_line_command(line);
            switch(cmd){
                default: break;

                case "o":{
                    if(!model)
                        model = result.model_first;
                    else
                        model = model.next;
                    f_index = 0;
                } break;

                case "usemtl":{
                    auto c = get_last_char(line, '.');
                    if(c){
                        auto index_string = line[c - line.ptr .. $];
                        to_int(&model.material_index, index_string);
                    }
                } break;

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
                    auto n = &result.uvs[vt_index++];
                    to_float(&n.x, eat_between_whitespace(line));
                    to_float(&n.y, eat_between_whitespace(line));
                } break;

                case "f":{
                    auto f = &model.faces[f_index++];
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
        read(&serializer, header);
        if(verify_asset_header!Font_Meta(file_name, &header)){
            // TODO: Read sections based on the sizes in the section header.
            // Have a function that will return the section payload, inflating compressed
            // data as needed.
            Font_Metrics* metrics;
            while(auto section = eat_type!Asset_Section(&serializer)){
                switch(cast(Font_Section)section.type){
                    default:
                        eat_bytes(&serializer, section.size);
                        break;

                    case Font_Section.Metrics:{
                        metrics = eat_type!Font_Metrics(&serializer);
                        font.metrics = *metrics;
                        //read(&serializer, font.metrics);
                        assert(section.size == Font_Metrics.sizeof);
                    } break;

                    case Font_Section.Glyphs:{
                        uint glyphs_count;
                        read(&serializer, glyphs_count);
                        if(glyphs_count > 0){
                            font.glyphs = eat_array!Font_Glyph(&serializer, glyphs_count);
                        }
                        assert(section.size == uint.sizeof + Font_Glyph.sizeof*glyphs_count);
                    } break;

                    case Font_Section.Kerning:{
                        uint kerning_count;
                        read(&serializer, kerning_count);
                        if(kerning_count > 0){
                            font.kerning_pairs   = alloc_array!Kerning_Pair(allocator.scratch, kerning_count);
                            font.kerning_advance = alloc_array!float(allocator.scratch, kerning_count);

                            foreach(ref entry; font.kerning_pairs){
                                read(&serializer, entry);
                            }

                            foreach(ref entry; font.kerning_advance){
                                read(&serializer, entry);
                            }
                        }
                    } break;

                    case Font_Section.Pixels:{
                        uint width, height;
                        read(&serializer, width);
                        read(&serializer, height);
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

Pixels load_tga_file(String file_name, Allocator *allocator){
    push_frame(allocator.scratch);
    scope(exit) pop_frame(allocator.scratch);

    auto file_contents = read_file_into_memory(file_name, allocator.scratch);
    auto reader = Serializer(file_contents);

    auto header = zero_type!TGA_Header;
    read(&reader, header);

    Pixels result;
    // TODO: Handle 24-bit pixel data
    if(header.data_type != TGA_Data_Type_Uncompressed_RGB){
        log_error("Unsupported TGA file for {0}. File must be an uncompressed RGB image.\n", file_name);
        return result;
    }

    if(header.bits_per_pixel != 32){
        log_error("Unsupported TGA file for {0}. File must be a 32-bit image (got {1}-bit).\n", file_name, header.bits_per_pixel);
        return result;
    }

    if(!(header.image_desc & TGA_Desc_Upper_Left_Origin)){
        log_error("Unsupported TGA file for {0}. Origin must be at the upper-left.\n", file_name);
        return result;
    }

    if(!is_non_interleaved(&header)){
        log_error("Unsupported TGA file for {0}. Pixel data must be non-interleaved.\n", file_name);
        return result;
    }

    uint width  = header.width;
    uint height = header.height;
    auto pixels = eat_array!uint(&reader, width*height);
    if(!pixels.length){
        log_error("Unable to read pixel data from TGA file {0}\n", file_name);
        return result;
    }

    foreach(ref pixel; pixels){
        ubyte a = (pixel >> 24) & 0xff;
        ubyte r = (pixel >> 16) & 0xff;
        ubyte g = (pixel >> 8)  & 0xff;
        ubyte b = (pixel)       & 0xff;

        pixel = (cast(uint)r)       | (cast(uint)g) << 8
              | (cast(uint)b) << 16 | (cast(uint)a) << 24;
    }

    result.width  = width;
    result.height = height;
    result.data   = dup_array(pixels, allocator);

    return result;
}

void save_tga_file(String file_name, uint *pixels, uint width, uint height, Allocator *allocator){
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
// WAVE Files
//
////

import audio : Sound;

private{
    struct Wave_Header{
        align(1):

        char[4] chunk_id; // Must be "RIFF"
        int     chunk_size;
        char[4] wave_id;  // Must be "WAVE"
    };

    struct Wave_Chunk_Header{
        align(1):

        char[4] chunk_id;
        int     size;
    };

    struct Wave_PCM_Format_Chunk{
        align(1):

        short format_type;
        short channels;
        int   samples_per_sec;
        int   avg_bytes_per_sec;
        short block_align;
        short bits_per_sample;
    };
}

Sound load_wave_file(String file_name, uint frames_per_sec, Allocator* allocator){
    push_frame(allocator.scratch);
    scope(exit) pop_frame(allocator.scratch);

    Sound result;
    auto source = read_file_into_memory(file_name, allocator.scratch);
    if(source.length){
        auto reader = Serializer(source);
        auto header = eat_type!Wave_Header(&reader);
        if(header && header.chunk_id[] == "RIFF" && header.wave_id[] == "WAVE"){
            Wave_PCM_Format_Chunk* format_chunk;
            void[] samples;

            while(auto chunk_header = eat_type!Wave_Chunk_Header(&reader)){
                void[] chunk_data = eat_bytes(&reader, chunk_header.size);

                if(chunk_header.chunk_id[] == "fmt " && chunk_header.size == Wave_PCM_Format_Chunk.sizeof){
                    format_chunk = cast(Wave_PCM_Format_Chunk*)chunk_data;
                }
                else if(chunk_header.chunk_id[] == "data"){
                    samples = chunk_data;
                }
            }

            if(format_chunk){
                if(samples.length > 0){
                    // TODO: Verify the other aspects of the format chunk are as we expect.
                    // TODO: Handle the block align!
                    if(format_chunk.samples_per_sec == frames_per_sec){
                        result.channels = format_chunk.channels;
                        result.samples  = dup_array(cast(short[])samples, allocator);
                    }
                    else{
                        log_error("File {0} uses unsupported sample rate. Expected {1} got {2} instead.\n", file_name, frames_per_sec, format_chunk.samples_per_sec);
                    }
                }
                else{
                   log_error("File {0} missing RIFF/WAVE data chunk.\n", file_name);
                }

            }
            else{
                log_error("WAVE file {0} doesn't contain format chunk.\n");
            }
        }
        else{
            log_error("File {0} has an invalid RIFF/WAVE header.\n", file_name);
        }
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
    auto canvas_width   = (average_width  * columns) + 2*padding*(packer.items_count+1);

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
