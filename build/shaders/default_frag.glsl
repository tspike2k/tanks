in vec2     f_uv;
in vec3     f_normal;
in vec3     f_world_pos;
in vec4     f_pos_in_lightspace;
flat in int f_material_index;

out vec4 out_color; // TODO: This should probably be called v_color

struct Material{
    vec3  tint;
    vec3  specular;
    float shininess;
};

layout(std140) uniform Materials{
    Material[Materials_Max] materials;
};

uniform sampler2D texture_diffuse;
uniform sampler2D texture_shadow_map;

layout(std140) uniform Light{
    vec3  light_pos;
    vec3  light_ambient;
    vec3  light_diffuse;
    vec3  light_specular;
};

vec3 blend_additive(vec3 src, vec3 dest){
    // Adapted from  github.com/jamieowen/glsl-blend
    return min(src+dest, vec3(1.0f));
}

// NOTE: Adapted from the following:
// https://learnopengl.com/Advanced-Lighting/Shadows/Shadow-Mapping
float calulcate_shadow(vec4 pos_in_lightspace){
    vec3 clip_space = pos_in_lightspace.xyz / pos_in_lightspace.w; // Perspective divide
    vec3 uvs = clip_space * 0.5 + 0.5;
    float shadow_depth = texture(texture_shadow_map, uvs.xy).r;
    float result = uvs.z > shadow_depth ? 1.0 : 0.0;
    return result;
}

void main(){
    vec3 view_dir  = normalize(camera_pos - f_world_pos);
    //vec3 light_dir = normalize(f_world_pos - light_pos);
    vec3 light_dir = vec3(0, -1, -0.75);
    vec3 normal    = normalize(f_normal); // Account for shortened normals thanks to interlolation. Thanks to https://stackoverflow.com/a/29720519

    // Phong shading adapted from both learnopengl.com and Tom Dalling's blog on Modern OpenGL.
    // Blin-phong adapted from the following sources:
    // https://en.wikipedia.org/wiki/Blinn%E2%80%93Phong_reflection_model
    // https://learnopengl.com/Advanced-Lighting/Advanced-Lighting

    Material material = materials[f_material_index];
    vec4 texture_color = texture(texture_diffuse, f_uv);

    //vec3 ambient = light_ambient * material_ambient;
    vec3 ambient = light_ambient * texture_color.rgb;

    float diffuse_intensity = max(dot(normal, -light_dir), 0.0);

    vec3 material_diffuse = blend_additive(texture_color.rgb, material.tint);
    vec3 diffuse = light_diffuse * diffuse_intensity * material_diffuse;

    // Fixed issue with specular passing through objects by multiplying the diffuse and
    // specular intensities together. Thanks to the comment by bjorke on this answer:
    // https://stackoverflow.com/a/20009586
    //
    // If shininess is set to zero, however, a small amount of specular still seeps through.
    // Avoid using a zero shininess value.

    vec3 half_vector = normalize(light_dir + view_dir);
    float specular_intensity = pow(max(dot(normal, half_vector), 0.0), material.shininess);
    vec3 specular = light_specular * (diffuse_intensity*specular_intensity * material.specular);

    float shadow = calulcate_shadow(f_pos_in_lightspace);

    vec3 linear_color = ambient + (diffuse + specular)*(1.0-shadow);
    out_color = vec4(linear_color, 1.0f);
}
