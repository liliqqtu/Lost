shader_type canvas_item;

// 闪烁速度
uniform float flash_speed : hint_range(0.1, 10.0) = 4.0;

// 最低亮度
uniform float min_brightness : hint_range(0.0, 1.0) = 0.35;

// 最高亮度
uniform float max_brightness : hint_range(0.0, 2.0) = 1.0;

// 指定要闪烁的颜色（这里以绿色为例）
uniform vec3 flash_color : source_color = vec3(0.0, 0.69, 0.0);

// 允许的颜色误差
uniform float color_tolerance : hint_range(0.0, 1.0) = 0.1;

void fragment()
{
    vec4 tex = texture(TEXTURE, UV);

    // 闪烁 0~1
    float pulse = (sin(TIME * flash_speed) + 1.0) * 0.5;

    // 映射到最低亮度 ~ 最高亮度
    float brightness = mix(min_brightness, max_brightness, pulse);

    // 计算当前像素与目标颜色的距离
    float color_dist = distance(tex.rgb, flash_color);

    // 如果在容差范围内，就应用闪烁；否则保持原样
    if (color_dist < color_tolerance) {
        // 目标颜色区域：变成白色再乘亮度（或你想保留原色变亮也行）
        vec3 color = vec3(1.0) * brightness;
        COLOR = vec4(color, tex.a);
    } else {
        // 非目标颜色区域：保持原样
        COLOR = tex;
    }
}