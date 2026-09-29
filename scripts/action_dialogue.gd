class_name ActionDialogue extends MapAction
##"""事件动作：显示对话（阶段五 5E）
##打开对话框逐句播放，等待玩家播完后才继续后续动作"""

## 说话人名（空 = 不显示名字，如系统提示"获得了伤药！"）
@export var speaker := ""
## 台词（每句一次按键）
@export var lines: Array[String] = []


func execute(ctx) -> void:
	if lines.is_empty():
		return
	await ctx.battle_manager.open_dialogue(speaker, lines)
