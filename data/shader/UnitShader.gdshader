shader_type canvas_item;

uniform int team = 0; // 0=我方(蓝), 1=敌方(红), 2=友军(绿)
uniform bool grayscale = false;
uniform bool red_tint = false;
// 绿色背景抠除
uniform bool remove_background = true;

// 背景颜色（地图精灵默认浅绿透明背景色）
const vec3 BG_COLOR = vec3(128.0, 160.0, 128.0) / 255.0;
const float BG_TOLERANCE = 0.02;

void fragment() {
    vec4 color = texture(TEXTURE, UV);
    vec3 c = color.rgb;

    // 1. 抠除透明背景色
    if (remove_background) {
        if (distance(c, BG_COLOR) < BG_TOLERANCE) {
            color.a = 0.0;
        }
    }

    // 2. 阵营调色（仅针对衣物蓝色系像素，绝不污染肤色、头发、鞋子与刀光）
    if (team == 2) {
        // ========== 友军（绿色调色） ==========
        if (distance(c, vec3(24.0, 240.0, 248.0) / 255.0) < 0.015) {
            c = vec3(80.0, 248.0, 56.0) / 255.0;
        } else if (distance(c, vec3(40.0, 160.0, 248.0) / 255.0) < 0.015) {
            c = vec3(24.0, 208.0, 16.0) / 255.0;
        } else if (distance(c, vec3(56.0, 80.0, 224.0) / 255.0) < 0.015) {
            c = vec3(8.0, 144.0, 0.0) / 255.0;
        } else if (distance(c, vec3(56.0, 56.0, 144.0) / 255.0) < 0.015) {
            c = vec3(32.0, 80.0, 16.0) / 255.0;
        } else if (distance(c, vec3(88.0, 72.0, 120.0) / 255.0) < 0.015) {
            c = vec3(56.0, 80.0, 56.0) / 255.0;
        } else if (distance(c, vec3(144.0, 184.0, 232.0) / 255.0) < 0.015) {
            c = vec3(152.0, 200.0, 128.0) / 255.0;
        } else if (distance(c, vec3(216.0, 232.0, 240.0) / 255.0) < 0.015) {
            c = vec3(216.0, 248.0, 184.0) / 255.0;
        }
    } else if (team == 1 || red_tint) {
        // ========== 敌方（红色调色） ==========
        if (distance(c, vec3(24.0, 240.0, 248.0) / 255.0) < 0.015) {
            c = vec3(248.0, 80.0, 72.0) / 255.0;
        } else if (distance(c, vec3(40.0, 160.0, 248.0) / 255.0) < 0.015) {
            c = vec3(224.0, 16.0, 16.0) / 255.0;
        } else if (distance(c, vec3(56.0, 80.0, 224.0) / 255.0) < 0.015) {
            c = vec3(168.0, 48.0, 40.0) / 255.0;
        } else if (distance(c, vec3(56.0, 56.0, 144.0) / 255.0) < 0.015) {
            c = vec3(96.0, 40.0, 32.0) / 255.0;
        } else if (distance(c, vec3(88.0, 72.0, 120.0) / 255.0) < 0.015) {
            c = vec3(104.0, 72.0, 96.0) / 255.0;
        } else if (distance(c, vec3(144.0, 184.0, 232.0) / 255.0) < 0.015) {
            c = vec3(192.0, 168.0, 184.0) / 255.0;
        } else if (distance(c, vec3(216.0, 232.0, 240.0) / 255.0) < 0.015) {
            c = vec3(224.0, 224.0, 224.0) / 255.0;
        }
    }

    // 3. 行动完毕灰度化
    if (grayscale) {
        float gray = dot(c, vec3(0.299, 0.587, 0.114));
        c = vec3(gray);
    }

    COLOR = vec4(c, color.a);
}
