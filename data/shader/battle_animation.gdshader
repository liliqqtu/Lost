shader_type canvas_item;

// 敌方红色调色
uniform bool enemy_palette = false;

// 受击闪白强度
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;

// 绿色背景抠除
uniform bool remove_background = true;

// 背景颜色
const vec3 BG_COLOR = vec3(168.0, 208.0, 160.0) / 255.0;

// 允许的颜色误差
const float BG_TOLERANCE = 0.02;


void fragment() {
    vec4 color = texture(TEXTURE, UV);
    vec3 c = color.rgb;

    // ========================================
    // 1. 抠除绿色背景
    // ========================================

    if (remove_background) {
        if (distance(c, BG_COLOR) < BG_TOLERANCE) {
            color.a = 0.0;
        }
    }


    // ========================================
    // 2. 敌方红色调色
    // ========================================

    if (enemy_palette) {

        // 深蓝 → 深红
        if (distance(c, vec3(56.0, 56.0, 208.0) / 255.0) < 0.01) {
            c = vec3(208.0, 56.0, 56.0) / 255.0;
        }

        // 蓝色 → 红色
        else if (distance(c, vec3(104.0, 152.0, 248.0) / 255.0) < 0.01) {
            c = vec3(248.0, 104.0, 104.0) / 255.0;
        }

        // 青蓝 → 浅红
        else if (distance(c, vec3(104.0, 232.0, 248.0) / 255.0) < 0.01) {
            c = vec3(248.0, 104.0, 104.0) / 255.0;
        }
    }


    // ========================================
    // 3. 受击闪白
    // ========================================

    c = mix(c, vec3(1.0), flash_amount);


    // ========================================
    // 4. 输出
    // ========================================

    COLOR = vec4(c, color.a);
}