in vec3 v_pos;
in vec4 v_common;
in vec2 v_uv;
in int  v_material_index;

out vec2 f_uv;
out vec3 f_normal;
out vec3 f_world_pos;
out vec4 f_pos_in_lightspace;
flat out int f_material_index;

void main(){
    vec3 normal = v_common.xyz;
    gl_Position = mat_camera*mat_model*vec4(v_pos, 1);
    mat3 mat_normal = mat3(transpose(inverse(mat_model))); // TODO: Precalculate the normal matrix

    f_normal    = normalize(mat_normal * normal);
    f_uv        = v_uv;
    f_world_pos = (mat_model*vec4(v_pos, 1)).xyz;
    f_pos_in_lightspace = mat_light*vec4(f_world_pos, 1.0);
    f_material_index = v_material_index;
}
