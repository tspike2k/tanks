in vec2 f_uv;
in vec4 f_color;

out vec4 color;

void main(){
    vec4 color_a = f_color;
    vec4 color_b = vec4(f_color.xyz*0.5, 1);

    color = mix(color_a, color_b, 1.0-pow(sin(f_uv.y*3), 3));
}
