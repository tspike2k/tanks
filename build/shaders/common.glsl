#version 330

#define Materials_Max 2
#define App_Res_X 1920.0
#define App_Res_Y 1080.0

layout(std140) uniform Constants{
    mat4  mat_camera;
    vec3  camera_pos; // TODO: Is there some way to do lighting without this?
    float time;
    vec2  screen_size;
    mat4  mat_model;
    mat4  mat_light;
};


