in vec3 v_pos;
in vec4 v_common;
in vec2 v_uv;
in int  v_material_index;

void main(){
    gl_Position = mat_camera*mat_model*vec4(v_pos, 1);
}
