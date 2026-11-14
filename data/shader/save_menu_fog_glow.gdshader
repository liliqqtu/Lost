shader_type canvas_item;

/** 雾气无缝采样贴图（FastNoiseLite 无缝噪声图） */
uniform sampler2D noise_texture : repeat_enable, filter_linear;

/** 发光色调（微带圣白/淡蓝，可调节为暖金色） */
uniform vec4 glow_color : source_color = vec4(0.88, 0.94, 1.0, 1.0);

/** 雾气上升速度（数值越大上升越快，建议 0.15~0.35） */
uniform float fog_speed : hint_range(0.01, 1.0) = 0.24;

/** 白雾浓度与可见度 */
uniform float fog_density : hint_range(0.0, 1.0) = 0.62;

/** 烟雾镂空切割下限（低于此值的区域彻底透明，露出清晰石碑） */
uniform float fog_cutoff_low : hint_range(0.0, 1.0) = 0.35;

/** 烟雾镂空切割上限（高于此值的区域成为饱满云团，决定烟雾边缘锐度） */
uniform float fog_cutoff_high : hint_range(0.0, 1.0) = 0.68;

/** 底部发光强度 */
uniform float bottom_glow_strength : hint_range(0.0, 2.0) = 0.75;

/** 底部光晕呼吸脉动频率 */
uniform float breathe_speed : hint_range(0.5, 5.0) = 2.2;

/** 脚本驱动时间累加值（0 表示自动回退使用系统内置 TIME） */
uniform float custom_time = 0.0;

void fragment() {
	vec2 uv = UV;

	// 优先使用脚本高频驱动的 custom_time，若为 0 则使用系统 TIME；取模防长期运行浮点溢出
	float t = custom_time > 0.0 ? custom_time : TIME;
	t = mod(t, 3600.0);

	// 1. 底部发光计算（以高次幂渐变约束在底部 35% 区域，配合柔和正弦呼吸）
	float vertical_gradient = pow(uv.y, 2.2);
	float breathe = 1.0 + 0.18 * sin(t * breathe_speed);
	float glow = vertical_gradient * bottom_glow_strength * breathe;

	// 2. 双层 UV 滚动采样（UV Scrolling）：通过时间偏移坐标，实现源源不断的传送带式升腾
	// 主雾层：沿 Y 轴向上升腾，附带微弱横向波浪摆动
	vec2 uv1 = uv * vec2(1.8, 1.2);
	uv1.y -= t * fog_speed;
	uv1.x += sin(t * 0.45 + uv.y * 3.0) * 0.06;
	float n1 = texture(noise_texture, uv1).r;

	// 次雾层：不同缩放与稍快的流速，形成丰富的视差层次
	vec2 uv2 = uv * vec2(2.3, 1.6) + vec2(0.43, 0.71);
	uv2.y -= t * (fog_speed * 1.35);
	uv2.x += cos(t * 0.55 + uv.y * 2.5) * 0.07;
	float n2 = texture(noise_texture, uv2).r;

	// 融合双层噪波
	float raw_fog = mix(n1, n2, 0.45);

	// 核心原理：对比度镂空切割（Smoothstep）
	// 将灰蒙蒙的连续噪波切割为“明显透明空隙”与“饱满云团”，产生肉眼极易感知的动态移动边缘
	float mist = smoothstep(fog_cutoff_low, fog_cutoff_high, raw_fog);

	// 纵向消散控制（底部浓厚，越往上越消散飘零，贴合 GBA 视觉风格）
	float vertical_fade = mix(0.18, 1.0, pow(uv.y, 0.7));
	float fog_alpha = mist * fog_density * vertical_fade;

	// 3. 综合叠加透明度与发光着色
	float total_alpha = clamp(glow * 0.55 + fog_alpha * 0.85, 0.0, 0.90);

	// 发光色彩混合：底部最亮处微泛神圣光泽
	vec3 col = glow_color.rgb;
	col += vec3(0.12) * vertical_gradient * breathe;

	COLOR = vec4(col, total_alpha);
}
