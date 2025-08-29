in vec2  f_uv;
in vec4  f_color;

out vec4 out_color;

uniform sampler2D uTexture;

void main(){
    ivec2 texture_size = textureSize(uTexture, 0);
    float texture_ratio = texture_size.x/texture_size.y;

    float tanks_per_row = 12;
    float aspect_ratio = screen_size.y/screen_size.x;
    vec2 size = vec2(f_uv.x*tanks_per_row, f_uv.y*tanks_per_row*texture_ratio*aspect_ratio);

    vec4 tex_color = texture(uTexture, size + vec2(time, time)*0.25f);
	out_color = tex_color*vec4(f_color.rgb*f_color.a, f_color.a);
}
