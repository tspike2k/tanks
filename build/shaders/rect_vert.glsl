#version 330

uniform mat4 mat_camera;
uniform mat4 mat_model;
uniform vec3 camera_pos; // TODO: Is there some way to do lighting without this?

in vec3 v_pos;
in vec4 v_common;
in vec2 v_uv;

out vec2 f_uv;
out vec4 f_color;

layout(std140) uniform Common_Data{
    float time;
};

void main(){
    gl_Position = mat_camera*vec4(v_pos, 1);
    f_color     = v_common;
    f_uv        = v_uv;
}
