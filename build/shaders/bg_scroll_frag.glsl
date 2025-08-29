in vec2  f_uv;
in vec4  f_color;

out vec4 out_color;

uniform sampler2D uTexture;

void main(){
    ivec2 texture_size = textureSize(uTexture, 0);

    float target_width = (texture_size.x*22)/App_Res_X;
    float aspect_ratio = screen_size.x/screen_size.y;
    vec2 size = f_uv*target_width;
    size.y *= aspect_ratio;

    vec4 tex_color = texture(uTexture, size + vec2(time, time)*0.5f);
	out_color = tex_color*vec4(f_color.rgb*f_color.a, f_color.a);
}
