#version 330

in vec2  f_uv;
in vec3  f_normal;
in vec3  f_world_pos;

out vec4 out_color;

uniform mat4 mat_camera;
uniform mat4 mat_model;
uniform vec3 camera_pos; // TODO: Is there some way to do lighting without this?

layout(std140) uniform Constants{
    float time;
};

layout(std140) uniform Material{
    vec3  material_ambient;
    vec3  material_diffuse;
    vec3  material_specular;
    float material_shininess;
};

layout(std140) uniform Light{
    vec3  light_pos;
    vec3  light_ambient;
    vec3  light_diffuse;
    vec3  light_specular;
};

void main(){
    vec3 view_dir  = normalize(camera_pos - f_world_pos);
    //vec3 light_dir = normalize(light_pos - f_world_pos);
    vec3 light_dir = vec3(0, -1, -0.75);
    vec3 normal    = normalize(f_normal); // Account for shortened normals thanks to interlolation. Thanks to https://stackoverflow.com/a/29720519

    // Phong shading adapted from both learnopengl.com and Tom Dalling's blog on Modern OpenGL.
    // Blin-phong adapted from the following sources:
    // https://en.wikipedia.org/wiki/Blinn%E2%80%93Phong_reflection_model
    // https://learnopengl.com/Advanced-Lighting/Advanced-Lighting

    vec3 ambient = light_ambient * material_ambient;

    float diffuse_intensity = max(dot(normal, -light_dir), 0.0);
    vec3 diffuse = light_diffuse * (diffuse_intensity * material_diffuse);

    // Fixed issue with specular passing through objects by multiplying the diffuse and
    // specular intensities together. Thanks to the comment by bjorke on this answer:
    // https://stackoverflow.com/a/20009586
    //
    // If shininess is set to zero, however, a small amount of specular still seeps through.
    // Avoid using a zero shininess value.

    vec3 half_vector = normalize(light_dir + view_dir);
    float specular_intensity = pow(max(dot(normal, half_vector), 0.0), material_shininess);
    vec3 specular = light_specular * (diffuse_intensity*specular_intensity * material_specular);

    vec3 linear_color = ambient + diffuse + specular;
    out_color = vec4(linear_color, 1.0f);
}
