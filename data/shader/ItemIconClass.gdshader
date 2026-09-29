shader_type canvas_item;

// 是否启用变暗
uniform bool dark = true;

// 变暗程度
// 0.0 = 原色
// 1.0 = 完全黑
uniform float dark_amount : hint_range(0.0, 1.0) = 0.55;


void fragment()
{
    vec4 tex = texture(TEXTURE, UV);

    // 根据 dark 决定是否变暗
    float amount = float(dark) * dark_amount;

    tex.rgb *= 1.0 - amount;

    COLOR = tex;
}