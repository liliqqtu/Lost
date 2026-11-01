shader_type canvas_item;

// 在 Inspector 检查器里可以自由调节这 3 个颜色
/** 主笔画颜色（默认纯白）*/
uniform vec4 main_color : source_color = vec4(1.0, 1.0, 1.0, 1.0); 
/** 阴影颜色（默认暗灰）*/      
uniform vec4 shadow_color : source_color = vec4(0.3, 0.3, 0.3, 1.0);  
/** 底色（设为 alpha=0 即透明） */  
uniform vec4 bg_color : source_color = vec4(0.0, 0.0, 0.0, 0.0);        

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    if (tex.a > 0.0) {
        if (tex.r < 0.25) { 
            // 匹配深色主笔画 (40/255 ≈ 0.157) -> 替换为你想要的主颜色
            COLOR = main_color;
        } else if (tex.r < 0.75) { 
            // 匹配灰色阴影 (168/255 ≈ 0.659) -> 替换为阴影颜色
            COLOR = shadow_color;
        } else { 
            // 匹配浅灰底色 (224/255 ≈ 0.878) -> 替换为背景色
            COLOR = bg_color;
        }
    } else {
        COLOR = vec4(0.0);
    }
}