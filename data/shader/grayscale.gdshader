shader_type canvas_item;

uniform bool grayscale = false;
uniform bool flash = false;
uniform vec4 tint : source_color = vec4(1.0);

void fragment() {

    vec4 color = texture(TEXTURE, UV);

    if (grayscale) {
        float gray = dot(color.rgb, vec3(0.299,0.587,0.114));
        color.rgb = vec3(gray);
    }

    if (flash) {
        color.rgb = vec3(1.0);
    }

    color *= tint;

    COLOR = color;
}