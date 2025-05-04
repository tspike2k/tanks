#version 330

in vec2 f_uv;
in vec4 f_color;

out vec4 color;

void main(){
    // TODO: Should we allow textured rects?
	color = vec4(f_color.rgb*f_color.a, f_color.a);
}
