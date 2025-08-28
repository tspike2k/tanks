in vec2  f_uv;
in vec4  f_color;

out vec4 out_color;

uniform sampler2D uTexture;

void main(){
    vec4 tex_color = texture(uTexture, f_uv*30.0 + vec2(time, time));
	out_color = tex_color*vec4(f_color.rgb*f_color.a, f_color.a);
}
