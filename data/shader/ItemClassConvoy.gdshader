shader_type canvas_item;

// 闪烁速度
uniform float flash_speed : hint_range(0.1, 10.0) = 4.0;

// 最低亮度
uniform float min_brightness : hint_range(0.0, 1.0) = 0.35;

// 最高亮度
uniform float max_brightness : hint_range(0.0, 2.0) = 1.0;


void fragment()
{
    vec4 tex = texture(TEXTURE, UV);

    // 闪烁 0~1
    float pulse = (sin(TIME * flash_speed) + 1.0) * 0.5;

    // 映射到最低亮度 ~ 最高亮度
    float brightness = mix(
        min_brightness,
        max_brightness,
        pulse
    );

    // 保留原来的 Alpha，
    // RGB 全部变成白色
    vec3 color = vec3(1.0) * brightness;

    COLOR = vec4(color, tex.a);
}