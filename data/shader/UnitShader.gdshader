shader_type canvas_item;

uniform bool grayscale = false;
uniform bool red_tint = false;
// 绿色背景抠除
uniform bool remove_background = true;

// 背景颜色
const vec3 BG_COLOR = vec3(128.0, 160.0, 128.0) / 255.0;

// 允许的颜色误差
const float BG_TOLERANCE = 0.02;

void fragment() {
    vec4 color = texture(TEXTURE, UV);
	vec3 c = color.rgb;
	if (remove_background) {
        if (distance(c, BG_COLOR) < BG_TOLERANCE) {
            color.a = 0.0;
        }
    }
    if (grayscale) {
        float gray = dot(color.rgb, vec3(0.299, 0.587, 0.114));
        color.rgb = vec3(gray);
    }

    if (red_tint) {
        float gray = dot(color.rgb, vec3(0.299, 0.587, 0.114));
        color.rgb = vec3(gray, gray * 0.3, gray * 0.25);
    }

    COLOR = color;
}