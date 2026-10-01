class_name InfoProvider
extends Control
##"""信息查看系统：信息提供者
##挂在需要查看说明的 Control 下的子节点（编辑器里给 Label/TextureRect 等加一个
##名为 Info 的 InfoProvider 子节点，在 Inspector 填 description 即可被信息查看系统读取）。
##静态说明（人物属性/职业名词等）用本脚本 + Inspector 配置；
##动态说明（物品/技能/武器等级等随数据变化）由面板运行时创建 InfoProvider 赋 description，
##或由控件自身脚本实现同名的 get_info()（如 ItemRow）——InfoViewer 只认 get_info() 接口，
##不写 if item / if character 的类型判断。
##InfoData（标题+图标+多段文字的结构化资源）按规划暂不实现，需要时再扩展"""

## 描述信息（Inspector 多行编辑）
@export_multiline var description: String

## 统一信息接口：返回当前对象的说明
func get_info() -> String:
	return description
