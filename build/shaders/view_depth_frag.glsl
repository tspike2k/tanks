in vec2  f_uv;
in vec4  f_color;

out vec4 out_color;

uniform sampler2D texture_shadow_map;

void main(){
    vec4 tex_color = vec4(texture(texture_shadow_map, f_uv).rrr, 1.0);
	out_color = tex_color*vec4(f_color.rgb*f_color.a, f_color.a);
}
