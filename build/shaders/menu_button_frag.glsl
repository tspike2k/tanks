in vec2 f_uv;
in vec4 f_color;

out vec4 color;

void main(){
    vec4 c = vec4(0.54, 0.68, 0.82, 1);
    vec4 color_a = vec4(c.xyz*0.5, 1);
    vec4 color_b = c;

    color = mix(color_b, color_a, 1.0-pow(sin(f_uv.y*3), 3));
}
