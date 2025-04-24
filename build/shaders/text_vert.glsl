#version 330

in vec3 v_pos;
in vec3 v_normal;
in vec2 v_uv;

out vec2 f_uv;
out vec4 f_color;

layout(std140) uniform Common_Data{
    mat4  mat_camera;
    float time;
};

void main(){
    gl_Position = mat_camera*vec4(v_pos, 1);
    f_color     = vec4(1, 1, 1, 1); // TODO: Allow text clor modulation somehow?
    f_uv        = v_uv;
}
