#version 330

#define Materials_Max 2

layout(std140) uniform Constants{
    mat4  mat_camera;
    vec3  camera_pos; // TODO: Is there some way to do lighting without this?
    float time;
    mat4  mat_model;
};


