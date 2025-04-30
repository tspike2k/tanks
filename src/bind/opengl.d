/*
Copyright (c) 2025 tspike2k@github.com
Distributed under the Boost Software License, Version 1.0.
See accompanying file LICENSE_BOOST.txt or copy at http://www.boost.org/LICENSE_1_0.txt
*/

/+
Writing an OpenGl loader is... interesting. It sounds as though core OpenGL functions are required to be
provided in libgl by the OpenGL spec. If creating an OpenGL 3.2 context succeeds, then all the core functions
for that specific version MUST exist. This is comforting because the functions used to load OpenGL function
pointers (glXGetProcAddress, wglGetProcAddress) may return a non-null value even when the driver doesn't support
the requested function pointer. Good grief.
+/

module bind.opengl;

pragma(lib, "GL");

private import logging;

// Types retrieved from here:
// https://www.khronos.org/opengl/wiki/OpenGL_Type
alias GLchar     = char;
alias GLboolean  = uint;
alias GLbyte     = byte;
alias GLubyte    = ubyte;
alias GLshort    = short;
alias GLushort   = ushort;
alias GLint      = int;
alias GLuint     = uint;
alias GLfixed    = int;
alias GLint64    = long;
alias GLuint64   = ulong;
alias GLsizei    = uint;
alias GLenum     = uint;
alias GLintptr   = ptrdiff_t;
alias GLsizeiptr = ptrdiff_t;
alias GLsync     = ptrdiff_t; // TODO: Is this unsigned? Glad uses a struct pointer. What should we really do?
alias GLbitfield = uint;
alias GLhalf     = ushort; // TODO: Is there a better type to use for half-floats?
alias GLfloat    = float;
alias GLclampf   = float;
alias GLdouble   = double;
alias GLclampd   = double;
alias GLvoid     = void;

alias OpenGL_Debug_Proc = extern(C) void function(GLenum, GLenum, GLuint, GLenum, GLsizei, GLchar*, GLvoid*);

// Constants
// Retrieved from GL/gl.h and GL/glext.h

/* Boolean values */
enum GL_FALSE = 0;
enum GL_TRUE = 1;

/* Data types */
enum GL_BYTE = 0x1400;
enum GL_UNSIGNED_BYTE = 0x1401;
enum GL_SHORT = 0x1402;
enum GL_UNSIGNED_SHORT = 0x1403;
enum GL_INT = 0x1404;
enum GL_UNSIGNED_INT = 0x1405;
enum GL_FLOAT = 0x1406;
enum GL_2_BYTES = 0x1407;
enum GL_3_BYTES = 0x1408;
enum GL_4_BYTES = 0x1409;
enum GL_DOUBLE = 0x140A;

/* Primitives */
enum GL_POINTS = 0x0000;
enum GL_LINES = 0x0001;
enum GL_LINE_LOOP = 0x0002;
enum GL_LINE_STRIP = 0x0003;
enum GL_TRIANGLES = 0x0004;
enum GL_TRIANGLE_STRIP = 0x0005;
enum GL_TRIANGLE_FAN = 0x0006;
enum GL_QUADS = 0x0007;
enum GL_QUAD_STRIP = 0x0008;
enum GL_POLYGON = 0x0009;

/* Vertex Arrays */
enum GL_VERTEX_ARRAY = 0x8074;
enum GL_NORMAL_ARRAY = 0x8075;
enum GL_COLOR_ARRAY = 0x8076;
enum GL_INDEX_ARRAY = 0x8077;
enum GL_TEXTURE_COORD_ARRAY = 0x8078;
enum GL_EDGE_FLAG_ARRAY = 0x8079;
enum GL_VERTEX_ARRAY_SIZE = 0x807A;
enum GL_VERTEX_ARRAY_TYPE = 0x807B;
enum GL_VERTEX_ARRAY_STRIDE = 0x807C;
enum GL_NORMAL_ARRAY_TYPE = 0x807E;
enum GL_NORMAL_ARRAY_STRIDE = 0x807F;
enum GL_COLOR_ARRAY_SIZE = 0x8081;
enum GL_COLOR_ARRAY_TYPE = 0x8082;
enum GL_COLOR_ARRAY_STRIDE = 0x8083;
enum GL_INDEX_ARRAY_TYPE = 0x8085;
enum GL_INDEX_ARRAY_STRIDE = 0x8086;
enum GL_TEXTURE_COORD_ARRAY_SIZE = 0x8088;
enum GL_TEXTURE_COORD_ARRAY_TYPE = 0x8089;
enum GL_TEXTURE_COORD_ARRAY_STRIDE = 0x808A;
enum GL_EDGE_FLAG_ARRAY_STRIDE = 0x808C;
enum GL_VERTEX_ARRAY_POINTER = 0x808E;
enum GL_NORMAL_ARRAY_POINTER = 0x808F;
enum GL_COLOR_ARRAY_POINTER = 0x8090;
enum GL_INDEX_ARRAY_POINTER = 0x8091;
enum GL_TEXTURE_COORD_ARRAY_POINTER = 0x8092;
enum GL_EDGE_FLAG_ARRAY_POINTER = 0x8093;
enum GL_V2F = 0x2A20;
enum GL_V3F = 0x2A21;
enum GL_C4UB_V2F = 0x2A22;
enum GL_C4UB_V3F = 0x2A23;
enum GL_C3F_V3F = 0x2A24;
enum GL_N3F_V3F = 0x2A25;
enum GL_C4F_N3F_V3F = 0x2A26;
enum GL_T2F_V3F = 0x2A27;
enum GL_T4F_V4F = 0x2A28;
enum GL_T2F_C4UB_V3F = 0x2A29;
enum GL_T2F_C3F_V3F = 0x2A2A;
enum GL_T2F_N3F_V3F = 0x2A2B;
enum GL_T2F_C4F_N3F_V3F = 0x2A2C;
enum GL_T4F_C4F_N3F_V4F = 0x2A2D;

/* Matrix Mode */
enum GL_MATRIX_MODE = 0x0BA0;
enum GL_MODELVIEW = 0x1700;
enum GL_PROJECTION = 0x1701;
enum GL_TEXTURE = 0x1702;

/* Points */
enum GL_POINT_SMOOTH = 0x0B10;
enum GL_POINT_SIZE = 0x0B11;
enum GL_POINT_SIZE_GRANULARITY = 0x0B13;
enum GL_POINT_SIZE_RANGE = 0x0B12;

/* Lines */
enum GL_LINE_SMOOTH = 0x0B20;
enum GL_LINE_STIPPLE = 0x0B24;
enum GL_LINE_STIPPLE_PATTERN = 0x0B25;
enum GL_LINE_STIPPLE_REPEAT = 0x0B26;
enum GL_LINE_WIDTH = 0x0B21;
enum GL_LINE_WIDTH_GRANULARITY = 0x0B23;
enum GL_LINE_WIDTH_RANGE = 0x0B22;

/* Polygons */
enum GL_POINT = 0x1B00;
enum GL_LINE = 0x1B01;
enum GL_FILL = 0x1B02;
enum GL_CW = 0x0900;
enum GL_CCW = 0x0901;
enum GL_FRONT = 0x0404;
enum GL_BACK = 0x0405;
enum GL_POLYGON_MODE = 0x0B40;
enum GL_POLYGON_SMOOTH = 0x0B41;
enum GL_POLYGON_STIPPLE = 0x0B42;
enum GL_EDGE_FLAG = 0x0B43;
enum GL_CULL_FACE = 0x0B44;
enum GL_CULL_FACE_MODE = 0x0B45;
enum GL_FRONT_FACE = 0x0B46;
enum GL_POLYGON_OFFSET_FACTOR = 0x8038;
enum GL_POLYGON_OFFSET_UNITS = 0x2A00;
enum GL_POLYGON_OFFSET_POINT = 0x2A01;
enum GL_POLYGON_OFFSET_LINE = 0x2A02;
enum GL_POLYGON_OFFSET_FILL = 0x8037;

/* Display Lists */
enum GL_COMPILE = 0x1300;
enum GL_COMPILE_AND_EXECUTE = 0x1301;
enum GL_LIST_BASE = 0x0B32;
enum GL_LIST_INDEX = 0x0B33;
enum GL_LIST_MODE = 0x0B30;

/* Depth buffer */
enum GL_NEVER = 0x0200;
enum GL_LESS = 0x0201;
enum GL_EQUAL = 0x0202;
enum GL_LEQUAL = 0x0203;
enum GL_GREATER = 0x0204;
enum GL_NOTEQUAL = 0x0205;
enum GL_GEQUAL = 0x0206;
enum GL_ALWAYS = 0x0207;
enum GL_DEPTH_TEST = 0x0B71;
enum GL_DEPTH_BITS = 0x0D56;
enum GL_DEPTH_CLEAR_VALUE = 0x0B73;
enum GL_DEPTH_FUNC = 0x0B74;
enum GL_DEPTH_RANGE = 0x0B70;
enum GL_DEPTH_WRITEMASK = 0x0B72;
enum GL_DEPTH_COMPONENT = 0x1902;

/* Lighting */
enum GL_LIGHTING = 0x0B50;
enum GL_LIGHT0 = 0x4000;
enum GL_LIGHT1 = 0x4001;
enum GL_LIGHT2 = 0x4002;
enum GL_LIGHT3 = 0x4003;
enum GL_LIGHT4 = 0x4004;
enum GL_LIGHT5 = 0x4005;
enum GL_LIGHT6 = 0x4006;
enum GL_LIGHT7 = 0x4007;
enum GL_SPOT_EXPONENT = 0x1205;
enum GL_SPOT_CUTOFF = 0x1206;
enum GL_CONSTANT_ATTENUATION = 0x1207;
enum GL_LINEAR_ATTENUATION = 0x1208;
enum GL_QUADRATIC_ATTENUATION = 0x1209;
enum GL_AMBIENT = 0x1200;
enum GL_DIFFUSE = 0x1201;
enum GL_SPECULAR = 0x1202;
enum GL_SHININESS = 0x1601;
enum GL_EMISSION = 0x1600;
enum GL_POSITION = 0x1203;
enum GL_SPOT_DIRECTION = 0x1204;
enum GL_AMBIENT_AND_DIFFUSE = 0x1602;
enum GL_COLOR_INDEXES = 0x1603;
enum GL_LIGHT_MODEL_TWO_SIDE = 0x0B52;
enum GL_LIGHT_MODEL_LOCAL_VIEWER = 0x0B51;
enum GL_LIGHT_MODEL_AMBIENT = 0x0B53;
enum GL_FRONT_AND_BACK = 0x0408;
enum GL_SHADE_MODEL = 0x0B54;
enum GL_FLAT = 0x1D00;
enum GL_SMOOTH = 0x1D01;
enum GL_COLOR_MATERIAL = 0x0B57;
enum GL_COLOR_MATERIAL_FACE = 0x0B55;
enum GL_COLOR_MATERIAL_PARAMETER = 0x0B56;
enum GL_NORMALIZE = 0x0BA1;

/* User clipping planes */
enum GL_CLIP_PLANE0 = 0x3000;
enum GL_CLIP_PLANE1 = 0x3001;
enum GL_CLIP_PLANE2 = 0x3002;
enum GL_CLIP_PLANE3 = 0x3003;
enum GL_CLIP_PLANE4 = 0x3004;
enum GL_CLIP_PLANE5 = 0x3005;

/* Accumulation buffer */
enum GL_ACCUM_RED_BITS = 0x0D58;
enum GL_ACCUM_GREEN_BITS = 0x0D59;
enum GL_ACCUM_BLUE_BITS = 0x0D5A;
enum GL_ACCUM_ALPHA_BITS = 0x0D5B;
enum GL_ACCUM_CLEAR_VALUE = 0x0B80;
enum GL_ACCUM = 0x0100;
enum GL_ADD = 0x0104;
enum GL_LOAD = 0x0101;
enum GL_MULT = 0x0103;
enum GL_RETURN = 0x0102;

/* Alpha testing */
enum GL_ALPHA_TEST = 0x0BC0;
enum GL_ALPHA_TEST_REF = 0x0BC2;
enum GL_ALPHA_TEST_FUNC = 0x0BC1;

/* Blending */
enum GL_BLEND = 0x0BE2;
enum GL_BLEND_SRC = 0x0BE1;
enum GL_BLEND_DST = 0x0BE0;
enum GL_ZERO = 0;
enum GL_ONE = 1;
enum GL_SRC_COLOR = 0x0300;
enum GL_ONE_MINUS_SRC_COLOR = 0x0301;
enum GL_SRC_ALPHA = 0x0302;
enum GL_ONE_MINUS_SRC_ALPHA = 0x0303;
enum GL_DST_ALPHA = 0x0304;
enum GL_ONE_MINUS_DST_ALPHA = 0x0305;
enum GL_DST_COLOR = 0x0306;
enum GL_ONE_MINUS_DST_COLOR = 0x0307;
enum GL_SRC_ALPHA_SATURATE = 0x0308;

/* Render Mode */
enum GL_FEEDBACK = 0x1C01;
enum GL_RENDER = 0x1C00;
enum GL_SELECT = 0x1C02;

/* Feedback */
enum GL_2D = 0x0600;
enum GL_3D = 0x0601;
enum GL_3D_COLOR = 0x0602;
enum GL_3D_COLOR_TEXTURE = 0x0603;
enum GL_4D_COLOR_TEXTURE = 0x0604;
enum GL_POINT_TOKEN = 0x0701;
enum GL_LINE_TOKEN = 0x0702;
enum GL_LINE_RESET_TOKEN = 0x0707;
enum GL_POLYGON_TOKEN = 0x0703;
enum GL_BITMAP_TOKEN = 0x0704;
enum GL_DRAW_PIXEL_TOKEN = 0x0705;
enum GL_COPY_PIXEL_TOKEN = 0x0706;
enum GL_PASS_THROUGH_TOKEN = 0x0700;
enum GL_FEEDBACK_BUFFER_POINTER = 0x0DF0;
enum GL_FEEDBACK_BUFFER_SIZE = 0x0DF1;
enum GL_FEEDBACK_BUFFER_TYPE = 0x0DF2;

/* Selection */
enum GL_SELECTION_BUFFER_POINTER = 0x0DF3;
enum GL_SELECTION_BUFFER_SIZE = 0x0DF4;

/* Fog */
enum GL_FOG = 0x0B60;
enum GL_FOG_MODE = 0x0B65;
enum GL_FOG_DENSITY = 0x0B62;
enum GL_FOG_COLOR = 0x0B66;
enum GL_FOG_INDEX = 0x0B61;
enum GL_FOG_START = 0x0B63;
enum GL_FOG_END = 0x0B64;
enum GL_LINEAR = 0x2601;
enum GL_EXP = 0x0800;
enum GL_EXP2 = 0x0801;

/* Logic Ops */
enum GL_LOGIC_OP = 0x0BF1;
enum GL_INDEX_LOGIC_OP = 0x0BF1;
enum GL_COLOR_LOGIC_OP = 0x0BF2;
enum GL_LOGIC_OP_MODE = 0x0BF0;
enum GL_CLEAR = 0x1500;
enum GL_SET = 0x150F;
enum GL_COPY = 0x1503;
enum GL_COPY_INVERTED = 0x150C;
enum GL_NOOP = 0x1505;
enum GL_INVERT = 0x150A;
enum GL_AND = 0x1501;
enum GL_NAND = 0x150E;
enum GL_OR = 0x1507;
enum GL_NOR = 0x1508;
enum GL_XOR = 0x1506;
enum GL_EQUIV = 0x1509;
enum GL_AND_REVERSE = 0x1502;
enum GL_AND_INVERTED = 0x1504;
enum GL_OR_REVERSE = 0x150B;
enum GL_OR_INVERTED = 0x150D;

/* Stencil */
enum GL_STENCIL_BITS = 0x0D57;
enum GL_STENCIL_TEST = 0x0B90;
enum GL_STENCIL_CLEAR_VALUE = 0x0B91;
enum GL_STENCIL_FUNC = 0x0B92;
enum GL_STENCIL_VALUE_MASK = 0x0B93;
enum GL_STENCIL_FAIL = 0x0B94;
enum GL_STENCIL_PASS_DEPTH_FAIL = 0x0B95;
enum GL_STENCIL_PASS_DEPTH_PASS = 0x0B96;
enum GL_STENCIL_REF = 0x0B97;
enum GL_STENCIL_WRITEMASK = 0x0B98;
enum GL_STENCIL_INDEX = 0x1901;
enum GL_KEEP = 0x1E00;
enum GL_REPLACE = 0x1E01;
enum GL_INCR = 0x1E02;
enum GL_DECR = 0x1E03;

/* Buffers, Pixel Drawing/Reading */
enum GL_NONE = 0;
enum GL_LEFT = 0x0406;
enum GL_RIGHT = 0x0407;
/*GL_FRONT					0x0404 */
/*GL_BACK					0x0405 */
/*GL_FRONT_AND_BACK				0x0408 */
enum GL_FRONT_LEFT = 0x0400;
enum GL_FRONT_RIGHT = 0x0401;
enum GL_BACK_LEFT = 0x0402;
enum GL_BACK_RIGHT = 0x0403;
enum GL_AUX0 = 0x0409;
enum GL_AUX1 = 0x040A;
enum GL_AUX2 = 0x040B;
enum GL_AUX3 = 0x040C;
enum GL_COLOR_INDEX = 0x1900;
enum GL_RED = 0x1903;
enum GL_GREEN = 0x1904;
enum GL_BLUE = 0x1905;
enum GL_ALPHA = 0x1906;
enum GL_LUMINANCE = 0x1909;
enum GL_LUMINANCE_ALPHA = 0x190A;
enum GL_ALPHA_BITS = 0x0D55;
enum GL_RED_BITS = 0x0D52;
enum GL_GREEN_BITS = 0x0D53;
enum GL_BLUE_BITS = 0x0D54;
enum GL_INDEX_BITS = 0x0D51;
enum GL_SUBPIXEL_BITS = 0x0D50;
enum GL_AUX_BUFFERS = 0x0C00;
enum GL_READ_BUFFER = 0x0C02;
enum GL_DRAW_BUFFER = 0x0C01;
enum GL_DOUBLEBUFFER = 0x0C32;
enum GL_STEREO = 0x0C33;
enum GL_BITMAP = 0x1A00;
enum GL_COLOR = 0x1800;
enum GL_DEPTH = 0x1801;
enum GL_STENCIL = 0x1802;
enum GL_DITHER = 0x0BD0;
enum GL_RGB = 0x1907;
enum GL_RGBA = 0x1908;

/* Implementation limits */
enum GL_MAX_LIST_NESTING = 0x0B31;
enum GL_MAX_EVAL_ORDER = 0x0D30;
enum GL_MAX_LIGHTS = 0x0D31;
enum GL_MAX_CLIP_PLANES = 0x0D32;
enum GL_MAX_TEXTURE_SIZE = 0x0D33;
enum GL_MAX_PIXEL_MAP_TABLE = 0x0D34;
enum GL_MAX_ATTRIB_STACK_DEPTH = 0x0D35;
enum GL_MAX_MODELVIEW_STACK_DEPTH = 0x0D36;
enum GL_MAX_NAME_STACK_DEPTH = 0x0D37;
enum GL_MAX_PROJECTION_STACK_DEPTH = 0x0D38;
enum GL_MAX_TEXTURE_STACK_DEPTH = 0x0D39;
enum GL_MAX_VIEWPORT_DIMS = 0x0D3A;
enum GL_MAX_CLIENT_ATTRIB_STACK_DEPTH = 0x0D3B;

/* Gets */
enum GL_ATTRIB_STACK_DEPTH = 0x0BB0;
enum GL_CLIENT_ATTRIB_STACK_DEPTH = 0x0BB1;
enum GL_COLOR_CLEAR_VALUE = 0x0C22;
enum GL_COLOR_WRITEMASK = 0x0C23;
enum GL_CURRENT_INDEX = 0x0B01;
enum GL_CURRENT_COLOR = 0x0B00;
enum GL_CURRENT_NORMAL = 0x0B02;
enum GL_CURRENT_RASTER_COLOR = 0x0B04;
enum GL_CURRENT_RASTER_DISTANCE = 0x0B09;
enum GL_CURRENT_RASTER_INDEX = 0x0B05;
enum GL_CURRENT_RASTER_POSITION = 0x0B07;
enum GL_CURRENT_RASTER_TEXTURE_COORDS = 0x0B06;
enum GL_CURRENT_RASTER_POSITION_VALID = 0x0B08;
enum GL_CURRENT_TEXTURE_COORDS = 0x0B03;
enum GL_INDEX_CLEAR_VALUE = 0x0C20;
enum GL_INDEX_MODE = 0x0C30;
enum GL_INDEX_WRITEMASK = 0x0C21;
enum GL_MODELVIEW_MATRIX = 0x0BA6;
enum GL_MODELVIEW_STACK_DEPTH = 0x0BA3;
enum GL_NAME_STACK_DEPTH = 0x0D70;
enum GL_PROJECTION_MATRIX = 0x0BA7;
enum GL_PROJECTION_STACK_DEPTH = 0x0BA4;
enum GL_RENDER_MODE = 0x0C40;
enum GL_RGBA_MODE = 0x0C31;
enum GL_TEXTURE_MATRIX = 0x0BA8;
enum GL_TEXTURE_STACK_DEPTH = 0x0BA5;
enum GL_VIEWPORT = 0x0BA2;

/* Evaluators */
enum GL_AUTO_NORMAL = 0x0D80;
enum GL_MAP1_COLOR_4 = 0x0D90;
enum GL_MAP1_INDEX = 0x0D91;
enum GL_MAP1_NORMAL = 0x0D92;
enum GL_MAP1_TEXTURE_COORD_1 = 0x0D93;
enum GL_MAP1_TEXTURE_COORD_2 = 0x0D94;
enum GL_MAP1_TEXTURE_COORD_3 = 0x0D95;
enum GL_MAP1_TEXTURE_COORD_4 = 0x0D96;
enum GL_MAP1_VERTEX_3 = 0x0D97;
enum GL_MAP1_VERTEX_4 = 0x0D98;
enum GL_MAP2_COLOR_4 = 0x0DB0;
enum GL_MAP2_INDEX = 0x0DB1;
enum GL_MAP2_NORMAL = 0x0DB2;
enum GL_MAP2_TEXTURE_COORD_1 = 0x0DB3;
enum GL_MAP2_TEXTURE_COORD_2 = 0x0DB4;
enum GL_MAP2_TEXTURE_COORD_3 = 0x0DB5;
enum GL_MAP2_TEXTURE_COORD_4 = 0x0DB6;
enum GL_MAP2_VERTEX_3 = 0x0DB7;
enum GL_MAP2_VERTEX_4 = 0x0DB8;
enum GL_MAP1_GRID_DOMAIN = 0x0DD0;
enum GL_MAP1_GRID_SEGMENTS = 0x0DD1;
enum GL_MAP2_GRID_DOMAIN = 0x0DD2;
enum GL_MAP2_GRID_SEGMENTS = 0x0DD3;
enum GL_COEFF = 0x0A00;
enum GL_ORDER = 0x0A01;
enum GL_DOMAIN = 0x0A02;

/* Hints */
enum GL_PERSPECTIVE_CORRECTION_HINT = 0x0C50;
enum GL_POINT_SMOOTH_HINT = 0x0C51;
enum GL_LINE_SMOOTH_HINT = 0x0C52;
enum GL_POLYGON_SMOOTH_HINT = 0x0C53;
enum GL_FOG_HINT = 0x0C54;
enum GL_DONT_CARE = 0x1100;
enum GL_FASTEST = 0x1101;
enum GL_NICEST = 0x1102;

/* Scissor box */
enum GL_SCISSOR_BOX = 0x0C10;
enum GL_SCISSOR_TEST = 0x0C11;

/* Pixel Mode / Transfer */
enum GL_MAP_COLOR = 0x0D10;
enum GL_MAP_STENCIL = 0x0D11;
enum GL_INDEX_SHIFT = 0x0D12;
enum GL_INDEX_OFFSET = 0x0D13;
enum GL_RED_SCALE = 0x0D14;
enum GL_RED_BIAS = 0x0D15;
enum GL_GREEN_SCALE = 0x0D18;
enum GL_GREEN_BIAS = 0x0D19;
enum GL_BLUE_SCALE = 0x0D1A;
enum GL_BLUE_BIAS = 0x0D1B;
enum GL_ALPHA_SCALE = 0x0D1C;
enum GL_ALPHA_BIAS = 0x0D1D;
enum GL_DEPTH_SCALE = 0x0D1E;
enum GL_DEPTH_BIAS = 0x0D1F;
enum GL_PIXEL_MAP_S_TO_S_SIZE = 0x0CB1;
enum GL_PIXEL_MAP_I_TO_I_SIZE = 0x0CB0;
enum GL_PIXEL_MAP_I_TO_R_SIZE = 0x0CB2;
enum GL_PIXEL_MAP_I_TO_G_SIZE = 0x0CB3;
enum GL_PIXEL_MAP_I_TO_B_SIZE = 0x0CB4;
enum GL_PIXEL_MAP_I_TO_A_SIZE = 0x0CB5;
enum GL_PIXEL_MAP_R_TO_R_SIZE = 0x0CB6;
enum GL_PIXEL_MAP_G_TO_G_SIZE = 0x0CB7;
enum GL_PIXEL_MAP_B_TO_B_SIZE = 0x0CB8;
enum GL_PIXEL_MAP_A_TO_A_SIZE = 0x0CB9;
enum GL_PIXEL_MAP_S_TO_S = 0x0C71;
enum GL_PIXEL_MAP_I_TO_I = 0x0C70;
enum GL_PIXEL_MAP_I_TO_R = 0x0C72;
enum GL_PIXEL_MAP_I_TO_G = 0x0C73;
enum GL_PIXEL_MAP_I_TO_B = 0x0C74;
enum GL_PIXEL_MAP_I_TO_A = 0x0C75;
enum GL_PIXEL_MAP_R_TO_R = 0x0C76;
enum GL_PIXEL_MAP_G_TO_G = 0x0C77;
enum GL_PIXEL_MAP_B_TO_B = 0x0C78;
enum GL_PIXEL_MAP_A_TO_A = 0x0C79;
enum GL_PACK_ALIGNMENT = 0x0D05;
enum GL_PACK_LSB_FIRST = 0x0D01;
enum GL_PACK_ROW_LENGTH = 0x0D02;
enum GL_PACK_SKIP_PIXELS = 0x0D04;
enum GL_PACK_SKIP_ROWS = 0x0D03;
enum GL_PACK_SWAP_BYTES = 0x0D00;
enum GL_UNPACK_ALIGNMENT = 0x0CF5;
enum GL_UNPACK_LSB_FIRST = 0x0CF1;
enum GL_UNPACK_ROW_LENGTH = 0x0CF2;
enum GL_UNPACK_SKIP_PIXELS = 0x0CF4;
enum GL_UNPACK_SKIP_ROWS = 0x0CF3;
enum GL_UNPACK_SWAP_BYTES = 0x0CF0;
enum GL_ZOOM_X = 0x0D16;
enum GL_ZOOM_Y = 0x0D17;

/* Texture mapping */
enum GL_TEXTURE_ENV = 0x2300;
enum GL_TEXTURE_ENV_MODE = 0x2200;
enum GL_TEXTURE_1D = 0x0DE0;
enum GL_TEXTURE_2D = 0x0DE1;
enum GL_TEXTURE_WRAP_S = 0x2802;
enum GL_TEXTURE_WRAP_T = 0x2803;
enum GL_TEXTURE_MAG_FILTER = 0x2800;
enum GL_TEXTURE_MIN_FILTER = 0x2801;
enum GL_TEXTURE_ENV_COLOR = 0x2201;
enum GL_TEXTURE_GEN_S = 0x0C60;
enum GL_TEXTURE_GEN_T = 0x0C61;
enum GL_TEXTURE_GEN_R = 0x0C62;
enum GL_TEXTURE_GEN_Q = 0x0C63;
enum GL_TEXTURE_GEN_MODE = 0x2500;
enum GL_TEXTURE_BORDER_COLOR = 0x1004;
enum GL_TEXTURE_WIDTH = 0x1000;
enum GL_TEXTURE_HEIGHT = 0x1001;
enum GL_TEXTURE_BORDER = 0x1005;
enum GL_TEXTURE_COMPONENTS = 0x1003;
enum GL_TEXTURE_RED_SIZE = 0x805C;
enum GL_TEXTURE_GREEN_SIZE = 0x805D;
enum GL_TEXTURE_BLUE_SIZE = 0x805E;
enum GL_TEXTURE_ALPHA_SIZE = 0x805F;
enum GL_TEXTURE_LUMINANCE_SIZE = 0x8060;
enum GL_TEXTURE_INTENSITY_SIZE = 0x8061;
enum GL_NEAREST_MIPMAP_NEAREST = 0x2700;
enum GL_NEAREST_MIPMAP_LINEAR = 0x2702;
enum GL_LINEAR_MIPMAP_NEAREST = 0x2701;
enum GL_LINEAR_MIPMAP_LINEAR = 0x2703;
enum GL_OBJECT_LINEAR = 0x2401;
enum GL_OBJECT_PLANE = 0x2501;
enum GL_EYE_LINEAR = 0x2400;
enum GL_EYE_PLANE = 0x2502;
enum GL_SPHERE_MAP = 0x2402;
enum GL_DECAL = 0x2101;
enum GL_MODULATE = 0x2100;
enum GL_NEAREST = 0x2600;
enum GL_REPEAT = 0x2901;
enum GL_CLAMP = 0x2900;
enum GL_S = 0x2000;
enum GL_T = 0x2001;
enum GL_R = 0x2002;
enum GL_Q = 0x2003;

/* Utility */
enum GL_VENDOR = 0x1F00;
enum GL_RENDERER = 0x1F01;
enum GL_VERSION = 0x1F02;
enum GL_EXTENSIONS = 0x1F03;

/* Errors */
enum GL_NO_ERROR = 0;
enum GL_INVALID_ENUM = 0x0500;
enum GL_INVALID_VALUE = 0x0501;
enum GL_INVALID_OPERATION = 0x0502;
enum GL_STACK_OVERFLOW = 0x0503;
enum GL_STACK_UNDERFLOW = 0x0504;
enum GL_OUT_OF_MEMORY = 0x0505;

/* glPush/PopAttrib bits */
enum GL_CURRENT_BIT = 0x00000001;
enum GL_POINT_BIT = 0x00000002;
enum GL_LINE_BIT = 0x00000004;
enum GL_POLYGON_BIT = 0x00000008;
enum GL_POLYGON_STIPPLE_BIT = 0x00000010;
enum GL_PIXEL_MODE_BIT = 0x00000020;
enum GL_LIGHTING_BIT = 0x00000040;
enum GL_FOG_BIT = 0x00000080;
enum GL_DEPTH_BUFFER_BIT = 0x00000100;
enum GL_ACCUM_BUFFER_BIT = 0x00000200;
enum GL_STENCIL_BUFFER_BIT = 0x00000400;
enum GL_VIEWPORT_BIT = 0x00000800;
enum GL_TRANSFORM_BIT = 0x00001000;
enum GL_ENABLE_BIT = 0x00002000;
enum GL_COLOR_BUFFER_BIT = 0x00004000;
enum GL_HINT_BIT = 0x00008000;
enum GL_EVAL_BIT = 0x00010000;
enum GL_LIST_BIT = 0x00020000;
enum GL_TEXTURE_BIT = 0x00040000;
enum GL_SCISSOR_BIT = 0x00080000;
enum GL_ALL_ATTRIB_BITS = 0xFFFFFFFF;


/* OpenGL 1.1 */
enum GL_PROXY_TEXTURE_1D = 0x8063;
enum GL_PROXY_TEXTURE_2D = 0x8064;
enum GL_TEXTURE_PRIORITY = 0x8066;
enum GL_TEXTURE_RESIDENT = 0x8067;
enum GL_TEXTURE_BINDING_1D = 0x8068;
enum GL_TEXTURE_BINDING_2D = 0x8069;
enum GL_TEXTURE_INTERNAL_FORMAT = 0x1003;
enum GL_ALPHA4 = 0x803B;
enum GL_ALPHA8 = 0x803C;
enum GL_ALPHA12 = 0x803D;
enum GL_ALPHA16 = 0x803E;
enum GL_LUMINANCE4 = 0x803F;
enum GL_LUMINANCE8 = 0x8040;
enum GL_LUMINANCE12 = 0x8041;
enum GL_LUMINANCE16 = 0x8042;
enum GL_LUMINANCE4_ALPHA4 = 0x8043;
enum GL_LUMINANCE6_ALPHA2 = 0x8044;
enum GL_LUMINANCE8_ALPHA8 = 0x8045;
enum GL_LUMINANCE12_ALPHA4 = 0x8046;
enum GL_LUMINANCE12_ALPHA12 = 0x8047;
enum GL_LUMINANCE16_ALPHA16 = 0x8048;
enum GL_INTENSITY = 0x8049;
enum GL_INTENSITY4 = 0x804A;
enum GL_INTENSITY8 = 0x804B;
enum GL_INTENSITY12 = 0x804C;
enum GL_INTENSITY16 = 0x804D;
enum GL_R3_G3_B2 = 0x2A10;
enum GL_RGB4 = 0x804F;
enum GL_RGB5 = 0x8050;
enum GL_RGB8 = 0x8051;
enum GL_RGB10 = 0x8052;
enum GL_RGB12 = 0x8053;
enum GL_RGB16 = 0x8054;
enum GL_RGBA2 = 0x8055;
enum GL_RGBA4 = 0x8056;
enum GL_RGB5_A1 = 0x8057;
enum GL_RGBA8 = 0x8058;
enum GL_RGB10_A2 = 0x8059;
enum GL_RGBA12 = 0x805A;
enum GL_RGBA16 = 0x805B;
enum GL_CLIENT_PIXEL_STORE_BIT = 0x00000001;
enum GL_CLIENT_VERTEX_ARRAY_BIT = 0x00000002;
enum GL_ALL_CLIENT_ATTRIB_BITS = 0xFFFFFFFF;
enum GL_CLIENT_ALL_ATTRIB_BITS = 0xFFFFFFFF;

// From glext.h
enum GL_BLEND_EQUATION_RGB = 0x8009;
enum GL_VERTEX_ATTRIB_ARRAY_ENABLED = 0x8622;
enum GL_VERTEX_ATTRIB_ARRAY_SIZE = 0x8623;
enum GL_VERTEX_ATTRIB_ARRAY_STRIDE = 0x8624;
enum GL_VERTEX_ATTRIB_ARRAY_TYPE = 0x8625;
enum GL_CURRENT_VERTEX_ATTRIB = 0x8626;
enum GL_VERTEX_PROGRAM_POINT_SIZE = 0x8642;
enum GL_VERTEX_ATTRIB_ARRAY_POINTER = 0x8645;
enum GL_STENCIL_BACK_FUNC = 0x8800;
enum GL_STENCIL_BACK_FAIL = 0x8801;
enum GL_STENCIL_BACK_PASS_DEPTH_FAIL = 0x8802;
enum GL_STENCIL_BACK_PASS_DEPTH_PASS = 0x8803;
enum GL_MAX_DRAW_BUFFERS = 0x8824;
enum GL_DRAW_BUFFER0 = 0x8825;
enum GL_DRAW_BUFFER1 = 0x8826;
enum GL_DRAW_BUFFER2 = 0x8827;
enum GL_DRAW_BUFFER3 = 0x8828;
enum GL_DRAW_BUFFER4 = 0x8829;
enum GL_DRAW_BUFFER5 = 0x882A;
enum GL_DRAW_BUFFER6 = 0x882B;
enum GL_DRAW_BUFFER7 = 0x882C;
enum GL_DRAW_BUFFER8 = 0x882D;
enum GL_DRAW_BUFFER9 = 0x882E;
enum GL_DRAW_BUFFER10 = 0x882F;
enum GL_DRAW_BUFFER11 = 0x8830;
enum GL_DRAW_BUFFER12 = 0x8831;
enum GL_DRAW_BUFFER13 = 0x8832;
enum GL_DRAW_BUFFER14 = 0x8833;
enum GL_DRAW_BUFFER15 = 0x8834;
enum GL_BLEND_EQUATION_ALPHA = 0x883D;
enum GL_MAX_VERTEX_ATTRIBS = 0x8869;
enum GL_VERTEX_ATTRIB_ARRAY_NORMALIZED = 0x886A;
enum GL_MAX_TEXTURE_IMAGE_UNITS = 0x8872;
enum GL_FRAGMENT_SHADER = 0x8B30;
enum GL_VERTEX_SHADER = 0x8B31;
enum GL_MAX_FRAGMENT_UNIFORM_COMPONENTS = 0x8B49;
enum GL_MAX_VERTEX_UNIFORM_COMPONENTS = 0x8B4A;
enum GL_MAX_VARYING_FLOATS = 0x8B4B;
enum GL_MAX_VERTEX_TEXTURE_IMAGE_UNITS = 0x8B4C;
enum GL_MAX_COMBINED_TEXTURE_IMAGE_UNITS = 0x8B4D;
enum GL_SHADER_TYPE = 0x8B4F;
enum GL_FLOAT_VEC2 = 0x8B50;
enum GL_FLOAT_VEC3 = 0x8B51;
enum GL_FLOAT_VEC4 = 0x8B52;
enum GL_INT_VEC2 = 0x8B53;
enum GL_INT_VEC3 = 0x8B54;
enum GL_INT_VEC4 = 0x8B55;
enum GL_BOOL = 0x8B56;
enum GL_BOOL_VEC2 = 0x8B57;
enum GL_BOOL_VEC3 = 0x8B58;
enum GL_BOOL_VEC4 = 0x8B59;
enum GL_FLOAT_MAT2 = 0x8B5A;
enum GL_FLOAT_MAT3 = 0x8B5B;
enum GL_FLOAT_MAT4 = 0x8B5C;
enum GL_SAMPLER_1D = 0x8B5D;
enum GL_SAMPLER_2D = 0x8B5E;
enum GL_SAMPLER_3D = 0x8B5F;
enum GL_SAMPLER_CUBE = 0x8B60;
enum GL_SAMPLER_1D_SHADOW = 0x8B61;
enum GL_SAMPLER_2D_SHADOW = 0x8B62;
enum GL_DELETE_STATUS = 0x8B80;
enum GL_COMPILE_STATUS = 0x8B81;
enum GL_LINK_STATUS = 0x8B82;
enum GL_VALIDATE_STATUS = 0x8B83;
enum GL_INFO_LOG_LENGTH = 0x8B84;
enum GL_ATTACHED_SHADERS = 0x8B85;
enum GL_ACTIVE_UNIFORMS = 0x8B86;
enum GL_ACTIVE_UNIFORM_MAX_LENGTH = 0x8B87;
enum GL_SHADER_SOURCE_LENGTH = 0x8B88;
enum GL_ACTIVE_ATTRIBUTES = 0x8B89;
enum GL_ACTIVE_ATTRIBUTE_MAX_LENGTH = 0x8B8A;
enum GL_FRAGMENT_SHADER_DERIVATIVE_HINT = 0x8B8B;
enum GL_SHADING_LANGUAGE_VERSION = 0x8B8C;
enum GL_CURRENT_PROGRAM = 0x8B8D;
enum GL_POINT_SPRITE_COORD_ORIGIN = 0x8CA0;
enum GL_LOWER_LEFT = 0x8CA1;
enum GL_UPPER_LEFT = 0x8CA2;
enum GL_STENCIL_BACK_REF = 0x8CA3;
enum GL_STENCIL_BACK_VALUE_MASK = 0x8CA4;
enum GL_STENCIL_BACK_WRITEMASK = 0x8CA5;
enum GL_VERTEX_PROGRAM_TWO_SIDE = 0x8643;
enum GL_POINT_SPRITE = 0x8861;
enum GL_COORD_REPLACE = 0x8862;
enum GL_MAX_TEXTURE_COORDS = 0x8871;

enum GL_BUFFER_SIZE = 0x8764;
enum GL_BUFFER_USAGE = 0x8765;
enum GL_QUERY_COUNTER_BITS = 0x8864;
enum GL_CURRENT_QUERY = 0x8865;
enum GL_QUERY_RESULT = 0x8866;
enum GL_QUERY_RESULT_AVAILABLE = 0x8867;
enum GL_ARRAY_BUFFER = 0x8892;
enum GL_ELEMENT_ARRAY_BUFFER = 0x8893;
enum GL_ARRAY_BUFFER_BINDING = 0x8894;
enum GL_ELEMENT_ARRAY_BUFFER_BINDING = 0x8895;
enum GL_VERTEX_ATTRIB_ARRAY_BUFFER_BINDING = 0x889F;
enum GL_READ_ONLY = 0x88B8;
enum GL_WRITE_ONLY = 0x88B9;
enum GL_READ_WRITE = 0x88BA;
enum GL_BUFFER_ACCESS = 0x88BB;
enum GL_BUFFER_MAPPED = 0x88BC;
enum GL_BUFFER_MAP_POINTER = 0x88BD;
enum GL_STREAM_DRAW = 0x88E0;
enum GL_STREAM_READ = 0x88E1;
enum GL_STREAM_COPY = 0x88E2;
enum GL_STATIC_DRAW = 0x88E4;
enum GL_STATIC_READ = 0x88E5;
enum GL_STATIC_COPY = 0x88E6;
enum GL_DYNAMIC_DRAW = 0x88E8;
enum GL_DYNAMIC_READ = 0x88E9;
enum GL_DYNAMIC_COPY = 0x88EA;
enum GL_SAMPLES_PASSED = 0x8914;
enum GL_SRC1_ALPHA = 0x8589;
enum GL_VERTEX_ARRAY_BUFFER_BINDING = 0x8896;
enum GL_NORMAL_ARRAY_BUFFER_BINDING = 0x8897;
enum GL_COLOR_ARRAY_BUFFER_BINDING = 0x8898;
enum GL_INDEX_ARRAY_BUFFER_BINDING = 0x8899;
enum GL_TEXTURE_COORD_ARRAY_BUFFER_BINDING = 0x889A;
enum GL_EDGE_FLAG_ARRAY_BUFFER_BINDING = 0x889B;
enum GL_SECONDARY_COLOR_ARRAY_BUFFER_BINDING = 0x889C;
enum GL_FOG_COORDINATE_ARRAY_BUFFER_BINDING = 0x889D;
enum GL_WEIGHT_ARRAY_BUFFER_BINDING = 0x889E;
enum GL_FOG_COORD_SRC = 0x8450;
enum GL_FOG_COORD = 0x8451;
enum GL_CURRENT_FOG_COORD = 0x8453;
enum GL_FOG_COORD_ARRAY_TYPE = 0x8454;
enum GL_FOG_COORD_ARRAY_STRIDE = 0x8455;
enum GL_FOG_COORD_ARRAY_POINTER = 0x8456;
enum GL_FOG_COORD_ARRAY = 0x8457;
enum GL_FOG_COORD_ARRAY_BUFFER_BINDING = 0x889D;
enum GL_SRC0_RGB = 0x8580;
enum GL_SRC1_RGB = 0x8581;
enum GL_SRC2_RGB = 0x8582;
enum GL_SRC0_ALPHA = 0x8588;
enum GL_SRC2_ALPHA = 0x858A;
enum GL_DEBUG_CALLBACK_FUNCTION = 0x8244;
enum GL_DEBUG_CALLBACK_USER_PARAM = 0x8245;
enum GL_DEBUG_SOURCE_API = 0x8246;
enum GL_DEBUG_SOURCE_WINDOW_SYSTEM = 0x8247;
enum GL_DEBUG_SOURCE_SHADER_COMPILER = 0x8248;
enum GL_DEBUG_SOURCE_THIRD_PARTY = 0x8249;
enum GL_DEBUG_SOURCE_APPLICATION = 0x824A;
enum GL_DEBUG_SOURCE_OTHER = 0x824B;
enum GL_DEBUG_TYPE_ERROR = 0x824C;
enum GL_DEBUG_TYPE_DEPRECATED_BEHAVIOR = 0x824D;
enum GL_DEBUG_TYPE_UNDEFINED_BEHAVIOR = 0x824E;
enum GL_DEBUG_TYPE_PORTABILITY = 0x824F;
enum GL_DEBUG_TYPE_PERFORMANCE = 0x8250;
enum GL_DEBUG_TYPE_OTHER = 0x8251;
enum GL_MAX_DEBUG_MESSAGE_LENGTH = 0x9143;
enum GL_MAX_DEBUG_LOGGED_MESSAGES = 0x9144;
enum GL_DEBUG_LOGGED_MESSAGES = 0x9145;
enum GL_DEBUG_SEVERITY_HIGH = 0x9146;
enum GL_DEBUG_SEVERITY_MEDIUM = 0x9147;
enum GL_DEBUG_SEVERITY_LOW = 0x9148;
enum GL_DEBUG_TYPE_MARKER = 0x8268;
enum GL_DEBUG_TYPE_PUSH_GROUP = 0x8269;
enum GL_DEBUG_TYPE_POP_GROUP = 0x826A;
enum GL_DEBUG_SEVERITY_NOTIFICATION = 0x826B;
enum GL_DEBUG_OUTPUT = 0x92E0;
enum GL_DEBUG_OUTPUT_SYNCHRONOUS = 0x8242;

enum GL_UNIFORM_BUFFER = 0x8A11;
enum GL_UNIFORM_BUFFER_BINDING = 0x8A28;
enum GL_UNIFORM_BUFFER_START = 0x8A29;
enum GL_UNIFORM_BUFFER_SIZE = 0x8A2A;
enum GL_INVALID_INDEX = 0xFFFFFFFFu;

enum GL_CLAMP_TO_EDGE   = 0x812F;
enum GL_CLAMP_TO_BORDER = 0x812D;

extern(C){
    alias glGetStringFunc = const(GLubyte)* function(GLenum name);
    alias glEnableFunc = void function(GLenum cap);
    alias glDisableFunc = void function(GLenum cap);
    alias glClearColorFunc = void function(GLfloat red, GLfloat green, GLfloat blue, GLfloat alpha);
    alias glBlendFuncFunc = void function(GLenum sfactor, GLenum dfactor);
    alias glGenBuffersFunc = void function(GLsizei n, GLuint *buffers);
    alias glBindBufferFunc = void function(GLenum target, GLuint buffer);
    alias glBufferDataFunc = void function(GLenum target, GLsizeiptr size, const GLvoid *data, GLenum usage);
    alias glBufferSubDataFunc = void function(GLenum target, GLintptr offset, GLsizeiptr size, const(GLvoid)* data);
    alias glBindVertexArrayFunc = void function(GLuint array);
    alias glUseProgramFunc = void function(GLuint program);
    alias glViewportFunc = void function(GLint x, GLint y, GLsizei width, GLsizei height);
    alias glScissorFunc = void function(GLint x, GLint y, GLsizei width, GLsizei height);
    alias glClearFunc = void function(GLbitfield mask);
    alias glGetUniformLocationFunc = GLint function(GLuint program, const GLchar *name);
    alias glUniformMatrix4fvFunc = void function(GLint location, GLsizei count, GLboolean transpose, const GLfloat *value);
    alias glUniform1fFunc = void function(GLint location, GLfloat v0);
    alias glUniform2fFunc = void function(GLint location, GLfloat v0, GLfloat v1);
    alias glUniform3fFunc = void function(GLint location, GLfloat v0, GLfloat v1, GLfloat v2);
    alias glDrawElementsFunc = void function(GLenum mode, GLsizei count, GLenum type, const GLvoid *indices);
    alias glBindTextureFunc = void function(GLenum target, GLuint texture);
    alias glGenTexturesFunc = void function(GLsizei n, GLuint *textures);
    alias glDeleteTexturesFunc = void function(GLsizei n, const GLuint *textures);
    alias glTexImage2DFunc = void function(GLenum target, GLint level, GLint internalFormat, GLsizei width, GLsizei height, GLint border, GLenum format, GLenum type, const GLvoid *data);
    alias glTexParameteriFunc = void function(GLenum target, GLenum pname, GLint param);
    alias glDeleteProgramFunc = void function(GLuint program);
    alias glDebugMessageCallbackFunc = void function(OpenGL_Debug_Proc callback, void* userParam);
    alias glCreateShaderFunc = GLuint function(GLenum shaderType);
    alias glShaderSourceFunc = void function(GLuint shader, GLsizei count, const GLchar **string, const GLint *length);
    alias glCompileShaderFunc = void function(GLuint shader);
    alias glGetShaderivFunc = void function(GLuint shader, GLenum pname, GLint *params);
    alias glGetShaderInfoLogFunc = void function(GLuint shader, GLsizei maxLength, GLsizei *length, GLchar *infoLog);
    alias glDeleteShaderFunc = void function(GLuint shader);
    alias glCreateProgramFunc = GLuint function();
    alias glBindAttribLocationFunc = void function(GLuint program, GLuint index, const GLchar *name);
    alias glAttachShaderFunc = void function(GLuint program, GLuint shader);
    alias glLinkProgramFunc = void function(GLuint program);
    alias glGetProgramivFunc = void function(GLuint program, GLenum pname, GLint *params);
    alias glGetProgramInfoLogFunc = void function(GLuint program, GLsizei maxLength, GLsizei *length, GLchar *infoLog);
    alias glDetachShaderFunc = void function(GLuint program,	GLuint 	shader);
    alias glGenVertexArraysFunc = void function(GLsizei n, GLuint *arrays);
    alias glEnableVertexAttribArrayFunc = void function(GLuint index);
    alias glDisableVertexAttribArrayFunc = void function(GLuint index);
    alias glVertexAttribPointerFunc = void function(GLuint index, GLint size, GLenum type, GLboolean normalized, GLsizei stride, const GLvoid *pointer);
    alias glUniformBlockBindingFunc = void function(GLuint program, GLuint uniformBlockIndex, GLuint uniformBlockBinding);
    alias glBindBufferRangeFunc = void function(GLenum target, GLuint index, GLuint buffer, GLintptr offset, GLsizeiptr size);
    alias glGetUniformBlockIndexFunc = GLuint function(GLuint program, const GLchar *uniformBlockName);
    alias glDrawArraysFunc = void function(GLenum mode, GLint first, GLsizei count);
    alias glCullFaceFunc = void function(GLenum mode);
    alias glFrontFaceFunc = void function(GLenum mode);
    alias glDepthMaskFunc = void function(GLboolean flag);
    alias glDepthFuncFunc = void function(GLenum func);
    alias glDepthRangeFunc = void function(GLclampd nearVal, GLclampd farVal);
    alias glClearDepthFunc = void function(GLclampd depth);
    alias glColorMaskFunc = void function(GLboolean red, GLboolean green, GLboolean blue, GLboolean alpha);
}

__gshared glGetStringFunc glGetString;
__gshared glEnableFunc glEnable;
__gshared glDisableFunc glDisable;
__gshared glClearColorFunc glClearColor;
__gshared glBlendFuncFunc glBlendFunc;
__gshared glGenBuffersFunc glGenBuffers;
__gshared glBindBufferFunc glBindBuffer;
__gshared glBufferDataFunc glBufferData;
__gshared glBufferSubDataFunc glBufferSubData;
__gshared glBindVertexArrayFunc glBindVertexArray;
__gshared glUseProgramFunc glUseProgram;
__gshared glViewportFunc glViewport;
__gshared glScissorFunc glScissor;
__gshared glClearFunc glClear;
__gshared glGetUniformLocationFunc glGetUniformLocation;
__gshared glUniformMatrix4fvFunc glUniformMatrix4fv;
__gshared glUniform1fFunc glUniform1f;
__gshared glUniform2fFunc glUniform2f;
__gshared glUniform3fFunc glUniform3f;
__gshared glDrawElementsFunc glDrawElements;
__gshared glBindTextureFunc glBindTexture;
__gshared glGenTexturesFunc glGenTextures;
__gshared glDeleteTexturesFunc glDeleteTextures;
__gshared glTexImage2DFunc glTexImage2D;
__gshared glTexParameteriFunc glTexParameteri;
__gshared glDeleteProgramFunc glDeleteProgram;
__gshared glDebugMessageCallbackFunc glDebugMessageCallback;
__gshared glCreateShaderFunc glCreateShader;
__gshared glShaderSourceFunc glShaderSource;
__gshared glCompileShaderFunc glCompileShader;
__gshared glGetShaderivFunc glGetShaderiv;
__gshared glGetShaderInfoLogFunc glGetShaderInfoLog;
__gshared glDeleteShaderFunc glDeleteShader;
__gshared glCreateProgramFunc glCreateProgram;
__gshared glBindAttribLocationFunc glBindAttribLocation;
__gshared glAttachShaderFunc glAttachShader;
__gshared glLinkProgramFunc glLinkProgram;
__gshared glGetProgramivFunc glGetProgramiv;
__gshared glGetProgramInfoLogFunc glGetProgramInfoLog;
__gshared glDetachShaderFunc glDetachShader;
__gshared glGenVertexArraysFunc glGenVertexArrays;
__gshared glEnableVertexAttribArrayFunc glEnableVertexAttribArray;
__gshared glDisableVertexAttribArrayFunc glDisableVertexAttribArray;
__gshared glVertexAttribPointerFunc glVertexAttribPointer;
__gshared glUniformBlockBindingFunc glUniformBlockBinding;
__gshared glBindBufferRangeFunc glBindBufferRange;
__gshared glGetUniformBlockIndexFunc glGetUniformBlockIndex;
__gshared glDrawArraysFunc glDrawArrays;
__gshared glCullFaceFunc glCullFace;
__gshared glFrontFaceFunc glFrontFace;
__gshared glDepthMaskFunc glDepthMask;
__gshared glDepthFuncFunc glDepthFunc;
__gshared glDepthRangeFunc glDepthRange;
__gshared glClearDepthFunc glClearDepth;
__gshared glColorMaskFunc glColorMask;

alias OpenGL_Load_Sym_Func = void* function(const(char)*);

void load_opengl_functions(OpenGL_Load_Sym_Func load){
    glGetString = cast(glGetStringFunc)load("glGetString");
    glEnable = cast(glEnableFunc)load("glEnable");
    glDisable = cast(glDisableFunc)load("glDisable");
    glClearColor = cast(glClearColorFunc)load("glClearColor");
    glBlendFunc = cast(glBlendFuncFunc)load("glBlendFunc");
    glGenBuffers = cast(glGenBuffersFunc)load("glGenBuffers");
    glBindBuffer = cast(glBindBufferFunc)load("glBindBuffer");
    glBufferData = cast(glBufferDataFunc)load("glBufferData");
    glBufferSubData = cast(glBufferSubDataFunc)load("glBufferSubData");
    glBindVertexArray = cast(glBindVertexArrayFunc)load("glBindVertexArray");
    glUseProgram = cast(glUseProgramFunc)load("glUseProgram");
    glViewport = cast(glViewportFunc)load("glViewport");
    glScissor = cast(glScissorFunc)load("glScissor");
    glClear = cast(glClearFunc)load("glClear");
    glGetUniformLocation = cast(glGetUniformLocationFunc)load("glGetUniformLocation");
    glUniformMatrix4fv = cast(glUniformMatrix4fvFunc)load("glUniformMatrix4fv");
    glUniform1f = cast(glUniform1fFunc)load("glUniform1f");
    glUniform2f = cast(glUniform2fFunc)load("glUniform2f");
    glUniform3f = cast(glUniform3fFunc)load("glUniform3f");
    glDrawElements = cast(glDrawElementsFunc)load("glDrawElements");
    glBindTexture = cast(glBindTextureFunc)load("glBindTexture");
    glGenTextures = cast(glGenTexturesFunc)load("glGenTextures");
    glDeleteTextures = cast(glDeleteTexturesFunc)load("glDeleteTextures");
    glTexImage2D = cast(glTexImage2DFunc)load("glTexImage2D");
    glTexParameteri = cast(glTexParameteriFunc)load("glTexParameteri");
    glDeleteProgram = cast(glDeleteProgramFunc)load("glDeleteProgram");
    glDebugMessageCallback = cast(glDebugMessageCallbackFunc)load("glDebugMessageCallback");
    glCreateShader = cast(glCreateShaderFunc)load("glCreateShader");
    glShaderSource = cast(glShaderSourceFunc)load("glShaderSource");
    glCompileShader = cast(glCompileShaderFunc)load("glCompileShader");
    glGetShaderiv = cast(glGetShaderivFunc)load("glGetShaderiv");
    glGetShaderInfoLog = cast(glGetShaderInfoLogFunc)load("glGetShaderInfoLog");
    glDeleteShader = cast(glDeleteShaderFunc)load("glDeleteShader");
    glCreateProgram = cast(glCreateProgramFunc)load("glCreateProgram");
    glBindAttribLocation = cast(glBindAttribLocationFunc)load("glBindAttribLocation");
    glAttachShader = cast(glAttachShaderFunc)load("glAttachShader");
    glLinkProgram = cast(glLinkProgramFunc)load("glLinkProgram");
    glGetProgramiv = cast(glGetProgramivFunc)load("glGetProgramiv");
    glGetProgramInfoLog = cast(glGetProgramInfoLogFunc)load("glGetProgramInfoLog");
    glDetachShader = cast(glDetachShaderFunc)load("glDetachShader");
    glGenVertexArrays = cast(glGenVertexArraysFunc)load("glGenVertexArrays");
    glEnableVertexAttribArray = cast(glEnableVertexAttribArrayFunc)load("glEnableVertexAttribArray");
    glDisableVertexAttribArray = cast(glDisableVertexAttribArrayFunc)load("glDisableVertexAttribArray");
    glVertexAttribPointer = cast(glVertexAttribPointerFunc)load("glVertexAttribPointer");
    glUniformBlockBinding = cast(glUniformBlockBindingFunc)load("glUniformBlockBinding");
    glBindBufferRange = cast(glBindBufferRangeFunc)load("glBindBufferRange");
    glGetUniformBlockIndex = cast(glGetUniformBlockIndexFunc)load("glGetUniformBlockIndex");
    glDrawArrays = cast(glDrawArraysFunc)load("glDrawArrays");
    glCullFace = cast(glCullFaceFunc)load("glCullFace");
    glFrontFace = cast(glFrontFaceFunc)load("glFrontFace");
    glDepthMask = cast(glDepthMaskFunc)load("glDepthMask");
    glDepthFunc = cast(glDepthFuncFunc)load("glDepthFunc");
    glDepthRange = cast(glDepthRangeFunc)load("glDepthRange");
    glClearDepth = cast(glClearDepthFunc)load("glClearDepth");
    glColorMask = cast(glColorMaskFunc)load("glColorMask");
}
