/*
Copyright (c) 2025 tspike2k@github.com
Distributed under the Boost Software License, Version 1.0.
See accompanying file LICENSE_BOOST.txt or copy at http://www.boost.org/LICENSE_1_0.txt
*/

module bind.freetype2;

enum FT_LOAD_DEFAULT                      = 0x0;
enum FT_LOAD_NO_SCALE                     = ( 1L << 0  );
enum FT_LOAD_NO_HINTING                   = ( 1L << 1  );
enum FT_LOAD_RENDER                       = ( 1L << 2  );
enum FT_LOAD_NO_BITMAP                    = ( 1L << 3  );
enum FT_LOAD_VERTICAL_LAYOUT              = ( 1L << 4  );
enum FT_LOAD_FORCE_AUTOHINT               = ( 1L << 5  );
enum FT_LOAD_CROP_BITMAP                  = ( 1L << 6  );
enum FT_LOAD_PEDANTIC                     = ( 1L << 7  );
enum FT_LOAD_IGNORE_GLOBAL_ADVANCE_WIDTH  = ( 1L << 9  );
enum FT_LOAD_NO_RECURSE                   = ( 1L << 10 );
enum FT_LOAD_IGNORE_TRANSFORM             = ( 1L << 11 );
enum FT_LOAD_MONOCHROME                   = ( 1L << 12 );
enum FT_LOAD_LINEAR_DESIGN                = ( 1L << 13 );
enum FT_LOAD_SBITS_ONLY                   = ( 1L << 14 );
enum FT_LOAD_NO_AUTOHINT                  = ( 1L << 15 );
enum FT_LOAD_COLOR                        = ( 1L << 20 );
enum FT_LOAD_COMPUTE_METRICS              = ( 1L << 21 );
enum FT_LOAD_BITMAP_METRICS_ONLY          = ( 1L << 22 );
enum FT_LOAD_NO_SVG                       = ( 1L << 24 );

enum{
    FT_GLYPH_FORMAT_NONE      = FT_IMAGE_TAG(0, 0, 0, 0),
    FT_GLYPH_FORMAT_COMPOSITE = FT_IMAGE_TAG('c', 'o', 'm', 'p'),
    FT_GLYPH_FORMAT_BITMAP    = FT_IMAGE_TAG('b', 'i', 't', 's'),
    FT_GLYPH_FORMAT_OUTLINE   = FT_IMAGE_TAG('o', 'u', 't', 'l'),
    FT_GLYPH_FORMAT_PLOTTER   = FT_IMAGE_TAG('p', 'l', 'o', 't'),
    FT_GLYPH_FORMAT_SVG       = FT_IMAGE_TAG('S', 'V', 'G', ' ')
}

enum{
    FT_RENDER_MODE_NORMAL = 0,
    FT_RENDER_MODE_LIGHT,
    FT_RENDER_MODE_MONO,
    FT_RENDER_MODE_LCD,
    FT_RENDER_MODE_LCD_V,
    FT_RENDER_MODE_SDF,

    FT_RENDER_MODE_MAX
}

enum {
    FT_KERNING_DEFAULT = 0,
    FT_KERNING_UNFITTED,
    FT_KERNING_UNSCALED
}

// Additional integer size conversion information can be found here:
// https://wiki.dlang.org/D_binding_for_C
import core.stdc.config : c_ulong, c_long;
alias c_enum              = int; // TODO: Is this correct?
alias FT_Bool             = ubyte;
alias FT_Int              = int;
alias FT_Int32            = int;
alias FT_UInt             = uint;
alias FT_Short            = short;
alias FT_UShort           = ushort;
alias FT_Long             = c_long;
alias FT_ULong            = c_ulong;
alias FT_String           = char;
alias FT_Error            = int;
alias FT_Pos              = c_long;
alias FT_Fixed            = c_long;
alias FT_Stroker_LineCap  = c_enum;
alias FT_Stroker_LineJoin = c_enum;
alias FT_Glyph_Format     = c_enum;
alias FT_Render_Mode      = c_enum;
alias FT_Kerning_Mode     = c_enum;

struct FT_LibraryRec;
struct FT_CharMapRec;
struct FT_StrokerRec;
struct FT_SubGlyphRec;

alias  FT_CharMap     = FT_CharMapRec*;
alias  FT_Library     = FT_LibraryRec*;
alias  FT_Size        = FT_SizeRec*;
alias  FT_Face        = FT_FaceRec*;
alias  FT_Stroker     = FT_StrokerRec*;
alias  FT_GlyphSlot   = FT_GlyphSlotRec*;
alias  FT_SubGlyph    = FT_SubGlyphRec*;
alias  FT_BitmapGlyph = FT_BitmapGlyphRec*;
alias  FT_Glyph       = FT_GlyphRec*;
alias  FT_Glyph_Class = void*;

alias FT_Generic_Finalizer = void function(void* object);

enum{
    FT_STROKER_LINECAP_BUTT = 0,
    FT_STROKER_LINECAP_ROUND,
    FT_STROKER_LINECAP_SQUARE
}

enum{
    FT_STROKER_LINEJOIN_ROUND          = 0,
    FT_STROKER_LINEJOIN_BEVEL          = 1,
    FT_STROKER_LINEJOIN_MITER_VARIABLE = 2,
    FT_STROKER_LINEJOIN_MITER          = FT_STROKER_LINEJOIN_MITER_VARIABLE,
    FT_STROKER_LINEJOIN_MITER_FIXED    = 3
}

struct FT_Generic{
    void*                data;
    FT_Generic_Finalizer finalizer;
}

struct FT_Bitmap_Size{
    FT_Short  height;
    FT_Short  width;

    FT_Pos    size;

    FT_Pos    x_ppem;
    FT_Pos    y_ppem;
}

struct FT_BBox{
    FT_Pos  xMin, yMin;
    FT_Pos  xMax, yMax;
};

struct FT_Vector{
    FT_Pos  x;
    FT_Pos  y;
}

struct  FT_Outline{
    ushort           n_contours;  /* number of contours in glyph        */
    ushort           n_points;    /* number of points in the glyph      */

    FT_Vector*       points;      /* the outline's points               */
    ubyte*           tags;        /* the points flags                   */
    ushort*          contours;    /* the contour end points             */

    int              flags;       /* outline masks                      */
}

struct FT_FaceRec{
    FT_Long           num_faces;
    FT_Long           face_index;

    FT_Long           face_flags;
    FT_Long           style_flags;

    FT_Long           num_glyphs;

    FT_String*        family_name;
    FT_String*        style_name;

    FT_Int            num_fixed_sizes;
    FT_Bitmap_Size*   available_sizes;

    FT_Int            num_charmaps;
    FT_CharMap*       charmaps;

    FT_Generic        generic;

    /* The following member variables (down to `underline_thickness`) */
    /* are only relevant to scalable outlines; cf. @FT_Bitmap_Size    */
    /* for bitmap fonts.                                              */
    FT_BBox           bbox;

    FT_UShort         units_per_EM;
    FT_Short          ascender;
    FT_Short          descender;
    FT_Short          height;

    FT_Short          max_advance_width;
    FT_Short          max_advance_height;

    FT_Short          underline_position;
    FT_Short          underline_thickness;

    FT_GlyphSlot      glyph;
    FT_Size           size;
    FT_CharMap        charmap;

    /* private fields, internal to FreeType */

    /+
    FT_Driver         driver;
    FT_Memory         memory;
    FT_Stream         stream;

    FT_ListRec        sizes_list;

    FT_Generic        autohint;   /* face-specific auto-hinter data */
    void*             extensions; /* unused                         */

    FT_Face_Internal  internal;+/
}

struct FT_Glyph_Metrics{
    FT_Pos  width;
    FT_Pos  height;

    FT_Pos  horiBearingX;
    FT_Pos  horiBearingY;
    FT_Pos  horiAdvance;

    FT_Pos  vertBearingX;
    FT_Pos  vertBearingY;
    FT_Pos  vertAdvance;
}

struct FT_GlyphSlotRec{
    FT_Library        library;
    FT_Face           face;
    FT_GlyphSlot      next;
    FT_UInt           glyph_index; /* new in 2.10; was reserved previously */
    FT_Generic        generic;

    FT_Glyph_Metrics  metrics;
    FT_Fixed          linearHoriAdvance;
    FT_Fixed          linearVertAdvance;
    FT_Vector         advance;

    FT_Glyph_Format   format;

    FT_Bitmap         bitmap;
    FT_Int            bitmap_left;
    FT_Int            bitmap_top;

    FT_Outline        outline;

    FT_UInt           num_subglyphs;
    FT_SubGlyph       subglyphs;

    void*             control_data;
    long              control_len;

    FT_Pos            lsb_delta;
    FT_Pos            rsb_delta;

    void*             other;

    void*             internal;
};

struct FT_Size_Metrics{
    FT_UShort  x_ppem;      /* horizontal pixels per EM               */
    FT_UShort  y_ppem;      /* vertical pixels per EM                 */

    FT_Fixed   x_scale;     /* scaling values used to convert font    */
    FT_Fixed   y_scale;     /* units to 26.6 fractional pixels        */

    FT_Pos     ascender;    /* ascender in 26.6 frac. pixels          */
    FT_Pos     descender;   /* descender in 26.6 frac. pixels         */
    FT_Pos     height;      /* text height in 26.6 frac. pixels       */
    FT_Pos     max_advance; /* max horizontal advance, in 26.6 pixels */
}

struct  FT_SizeRec{
    FT_Face          face;      /* parent face object              */
    FT_Generic       generic;   /* generic pointer for client uses */
    FT_Size_Metrics  metrics;   /* size metrics                    */
    void*            internal;
}

struct FT_Bitmap{
    uint    rows;
    uint    width;
    int     pitch;
    ubyte*  buffer;
    ushort  num_grays;
    ubyte   pixel_mode;
    ubyte   palette_mode;
    void*   palette;
}

struct FT_BitmapGlyphRec{
    FT_GlyphRec  root;
    FT_Int       left;
    FT_Int       top;
    FT_Bitmap    bitmap;
}

struct FT_GlyphRec{
    FT_Library             library;
    const FT_Glyph_Class*  clazz;
    FT_Glyph_Format        format;
    FT_Vector              advance;
};

extern(C){
    FT_Error FT_Init_FreeType(FT_Library* library);
    FT_Error FT_Done_FreeType(FT_Library library);
    FT_Error FT_New_Face(FT_Library library, const(char)* filepathname, FT_Long face_index, FT_Face* aface);
    FT_Error FT_Done_Face(FT_Face face);
    FT_Error FT_Set_Pixel_Sizes(FT_Face face, FT_UInt pixel_width, FT_UInt pixel_height);
    void FT_Stroker_Set(FT_Stroker stroker, FT_Fixed radius, FT_Stroker_LineCap line_cap, FT_Stroker_LineJoin  line_join, FT_Fixed miter_limit);
    FT_Error FT_Load_Char(FT_Face face, FT_ULong char_code, FT_Int32 load_flags);
    FT_Error FT_Stroker_New(FT_Library library, FT_Stroker* astroker);
    void FT_Stroker_Done(FT_Stroker stroker);
    FT_Error FT_Glyph_StrokeBorder(FT_Glyph* pglyph, FT_Stroker stroker, FT_Bool inside, FT_Bool destroy);
    FT_Error FT_Get_Glyph(FT_GlyphSlot slot, FT_Glyph* aglyph);
    FT_Error FT_Glyph_To_Bitmap(FT_Glyph* the_glyph, FT_Render_Mode render_mode, const(FT_Vector)* origin, FT_Bool destroy);
    FT_UInt  FT_Get_Char_Index(FT_Face face, FT_ULong charcode);
    FT_Error FT_Get_Kerning(FT_Face face, FT_UInt left_glyph, FT_UInt right_glyph, FT_UInt kern_mode, FT_Vector* akerning);
}

// This is a compromise. The Freetype2 uses a macro that takes the result as the first parameter and
// sets it via the macro. Here we return the value instead.
uint FT_IMAGE_TAG(uint x1, uint x2, uint x3, uint x4){
    uint result = x1 << 24 | x2 << 16 | x3 << 8 | x4;
    return result;
}
