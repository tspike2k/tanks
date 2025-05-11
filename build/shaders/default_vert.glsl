#version 330

layout(std140) uniform Constants{
    float time;
};

layout(std140) uniform Camera{
    mat4 mat_camera;
    vec3 camera_pos; // TODO: Is there some way to do lighting without this?
};

uniform mat4 mat_model;

in vec3 v_pos;
in vec4 v_common;
in vec2 v_uv;

out vec2 f_uv;
out vec3 f_normal;
out vec3 f_world_pos;

void main(){
    vec3 normal = v_common.xyz;
    gl_Position = mat_camera*mat_model*vec4(v_pos, 1);
    mat3 mat_normal = mat3(transpose(inverse(mat_model))); // TODO: Precalculate the normal matrix

    f_normal    = normalize(mat_normal * normal);
    f_uv        = v_uv;
    f_world_pos = (mat_model*vec4(v_pos, 1)).xyz;
}
