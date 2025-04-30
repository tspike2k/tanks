#version 330

uniform mat4 mat_camera;
uniform mat4 mat_model;
uniform vec3 camera_pos; // TODO: Is there some way to do lighting without this?

in vec3 v_pos;
in vec3 v_normal;
in vec2 v_uv;

out vec2 f_uv;
out vec3 f_normal;
out vec3 f_world_pos;

layout(std140) uniform Constants{
    float time;
};

void main(){
    gl_Position = mat_camera*mat_model*vec4(v_pos, 1);
    mat3 mat_normal = mat3(transpose(inverse(mat_model))); // TODO: Precalculate the normal matrix

    f_normal    = normalize(mat_normal * v_normal);
    f_uv        = v_uv;
    f_world_pos = (mat_model*vec4(v_pos, 1)).xyz;
}
