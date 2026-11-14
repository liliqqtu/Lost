shader_type canvas_item;

// 阵营与调色 (0=我方蓝, 1=敌方红, 2=友军绿)
uniform int team = 0;
uniform bool enemy_palette = false;
uniform bool ally_palette = false;

// 受击闪白强度
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;

// 绿色背景抠除
uniform bool remove_background = true;

// 背景颜色（战斗动画全屏贴图 168, 208, 160）
const vec3 BG_COLOR = vec3(168.0, 208.0, 160.0) / 255.0;
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
    // 2. 衣服阵营调色（仅着色蓝色衣物，保留肤色、头发与武器）
    // ========================================
    bool is_blue_lvl1 = distance(c, vec3(56.0, 56.0, 208.0) / 255.0) < 0.015 ||
                        distance(c, vec3(56.0, 56.0, 192.0) / 255.0) < 0.015 ||
                        distance(c, vec3(40.0, 64.0, 192.0) / 255.0) < 0.015;

    bool is_blue_lvl2 = distance(c, vec3(104.0, 152.0, 248.0) / 255.0) < 0.015 ||
                        distance(c, vec3(88.0, 136.0, 248.0) / 255.0) < 0.015 ||
                        distance(c, vec3(80.0, 128.0, 248.0) / 255.0) < 0.015;

    bool is_blue_lvl3 = distance(c, vec3(104.0, 232.0, 248.0) / 255.0) < 0.015 ||
                        distance(c, vec3(72.0, 216.0, 248.0) / 255.0) < 0.015 ||
                        distance(c, vec3(144.0, 200.0, 224.0) / 255.0) < 0.015;

    if (ally_palette || team == 2) {
        // 友军绿色调色
        if (is_blue_lvl1) {
            c = vec3(35.0, 105.0, 43.0) / 255.0;
        } else if (is_blue_lvl2) {
            c = vec3(58.0, 178.0, 65.0) / 255.0;
        } else if (is_blue_lvl3) {
            c = vec3(76.0, 235.0, 85.0) / 255.0;
        }
    } else if (enemy_palette || team == 1) {
        // 敌方红色调色
        if (is_blue_lvl1) {
            c = vec3(208.0, 56.0, 56.0) / 255.0;
        } else if (is_blue_lvl2) {
            c = vec3(248.0, 104.0, 104.0) / 255.0;
        } else if (is_blue_lvl3) {
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
