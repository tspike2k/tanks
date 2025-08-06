in vec2  f_uv;
in vec4  f_color;

out vec4 out_color;

uniform sampler2D uTexture; // TODO: We don't set the texture index explicitly. Is this well defined?

void main(){
    vec4 tex_color = texture(uTexture, f_uv);
	out_color = tex_color*vec4(f_color.rgb*f_color.a, f_color.a);
}
