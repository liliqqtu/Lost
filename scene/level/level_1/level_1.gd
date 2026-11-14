extends Level

##"""第一章：向崖底纵跃之人（The Leap into the Abyss）
##战场：断风隘口峡谷。两山夹峙，难民车队在此被山贼截杀。
##友方单位：
##  - 雷恩（佣兵）：从悬崖纵身跃下，自带 50% 残血，触发【热血重燃】与【惊鸿】。
##  - 薇拉（修女）：手持治愈之杖，从侧道赶来援护。
##说得机制：
##  - 忒 × 雷恩 -> 招募雷恩（变蓝方我方）
##  - 忒 × 薇拉 -> 招募薇拉（变蓝方我方）
##胜利条件：敌方全灭（击破山贼首领与余党）"""

const TE_CARD := preload("res://assets/graphics/Class Card/忒.png")
const ISAR_CARD := preload("res://assets/graphics/Class Card/Isar.png")
const REYN_CARD := preload("res://assets/graphics/Class Card/雷恩.png")
const VERA_CARD := preload("res://assets/graphics/Class Card/薇拉.png")
const BRETT_CARD := preload("res://assets/graphics/Class Card/布雷特.png")

##开场剧情：雷恩高呼英雄登场，飞身跳下十丈悬崖
const OPENING_LINES: Array = [
	{"speaker": "雷恩", "text": "薇拉！快看谷底！有一队难民被那些该死的狂徒堵在隘口了！", "side": "left1"},
	{"speaker": "薇拉", "text": "雷恩！你给我冷静点！下面到处都是山贼，而且山崖这么陡，绕下去至少要一刻钟！", "side": "right1"},
	{"speaker": "雷恩", "text": "一刻钟过去难民早被杀光了！骑士守则第一条：弱者遇难，利刃必出！", "side": "left1"},
	{"speaker": "薇拉", "text": "你只是个连正式骑士勋章都没有的佣兵！从这里跳下去你会摔断腿的！", "side": "right1"},
	{"speaker": "雷恩", "text": "哈哈！英雄登场，怎能走寻常路——看我的救世飞跃！！", "side": "left1"},
	{"speaker": "薇拉", "text": "雷恩——！！你这个彻头彻尾的笨蛋蠢货！！", "side": "right1"},
	{"speaker": "布雷特", "text": "什么鬼东西从天上掉下来了？！……操，是个摔得满脸是血的毛头小子！剁了他！", "side": "left2"},
	{"speaker": "忒", "text": "老师……刚才好像真有个人从天上跳下去了。", "side": "right1"},
	{"speaker": "伊萨尔", "text": "狂风呼啸之地，总有人做些匪夷所思的蠢事。但那份蠢气，或许正是打破沉闷虚无的烈火。全军出击，支援他们！", "side": "left1"},
]

##战斗中说得对话：忒 × 雷恩
const TALK_TE_REYN: Array = [
	{"speaker": "忒", "text": "你没事吧？刚才我看见你从那么高的悬崖直接跳下来……", "side": "right1"},
	{"speaker": "雷恩", "text": "（抹了一把脸上的血，龇牙咧嘴大笑）痛死了！但这点高度算什么！大爷我还站得稳！", "side": "left1"},
	{"speaker": "雷恩", "text": "兄弟，你们也是来砍这帮狂徒的吧？太好了，英雄需要战友，一起上吧！", "side": "left1"},
	{"speaker": "忒", "text": "……既然如此，那就请跟紧我，别再做毫无胜算的鲁莽之举了。", "side": "right1"},
	{"speaker": "雷恩", "text": "哈哈！交给我吧！利刃出鞘，绝不空回！", "side": "left1"},
]

##战斗中说得对话：忒 × 薇拉
const TALK_TE_VERA: Array = [
	{"speaker": "薇拉", "text": "呼……呼……累死我了！那个笨蛋雷恩，每次都这么不管不顾！", "side": "left1"},
	{"speaker": "忒", "text": "你是修女？前线非常凶险，请退到我们身后。", "side": "right1"},
	{"speaker": "薇拉", "text": "谢谢你……不过既然那个笨蛋在这里，我就绝不会丢下他一个人！我也来帮忙！", "side": "left1"},
	{"speaker": "薇拉", "text": "请收下这根治愈之杖，拜托你们，一定要保住那个笨蛋的命！", "side": "left1"},
	{"speaker": "忒", "text": "……我明白了。请注意安全，我们会保护你的。", "side": "right1"},
]

##战后剧情：雷恩的救世宣言与存在主义觉醒
const ENDING_LINES: Array = [
	{"speaker": "雷恩", "text": "哈哈哈哈！大获全胜！山贼全被我们打趴下了！", "side": "left1"},
	{"speaker": "雷恩", "text": "难民也安全了！怎么样两位，身手真不赖啊！要不要加入本大爷的『救世骑士团』？我们一起去拯救大陆！", "side": "left1"},
	{"speaker": "伊萨尔", "text": "（平静地合上魔导书）拯救大陆？大英雄并不存在，雷恩。", "side": "left2"},
	{"speaker": "伊萨尔", "text": "二十年前贤者们推开真理的暗门，宏大的命途早已崩解。世界正在不可逆地风化，神明未曾留下拯救的承诺。", "side": "left2"},
	{"speaker": "雷恩", "text": "（愣住，挠了挠头，眨巴着眼睛）……啊？什么意思？神仙没了？大英雄是假的？", "side": "left1"},
	{"speaker": "伊萨尔", "text": "是的，死后皆空，万物最终不过化作荒原上的白尘。", "side": "left2"},
	{"speaker": "雷恩", "text": "（沉默片刻，突然放声大笑）——哈哈！那又怎样！", "side": "left1"},
	{"speaker": "雷恩", "text": "如果我刚才装作看不见难民被杀，那我跟路边烂掉的风化死人有什么区别？！", "side": "left1"},
	{"speaker": "雷恩", "text": "既然这天地注定没有救世大英雄——从今天开始，本大爷就是我自己的英雄！！", "side": "left1"},
	{"speaker": "忒", "text": "（心神剧震）……我自己的……英雄吗。", "side": "right1"},
	{"speaker": "薇拉", "text": "哼，又在说不害臊的大话了。不过……既然你们要前往前方的绿洲庄园，请带上我们吧。至少有我在，某人不会把自己摔死。", "side": "right1"},
	{"speaker": "伊萨尔", "text": "欢迎同行。前方是第二章的绿洲庄园……据说那里有一座花亭，在风化蔓延的荒原中，奇迹般地开着花。", "side": "left2"},
	{"speaker": "忒", "text": "……为了自己的存在而拔剑吗。雷恩，薇拉，一起出发吧。", "side": "right1"},
]

##Boss 交战台词：布雷特 × 玩家角色
const BOSS_BATTLE_BRETT_REYN: Array = [
	{"speaker": "布雷特", "text": "又是你这个从悬崖上跳下来的毛头蠢货！这次老子直接把你劈成两半！", "side": "left1"},
	{"speaker": "雷恩", "text": "哈哈！大爷我摔不死，今天倒霉的就是你！接招吧，断恶救世的一击！", "side": "right1"},
]

const BOSS_BATTLE_BRETT_TE: Array = [
	{"speaker": "布雷特", "text": "小游牧民，这断风隘口就是你们的葬身之地！留下头颅和马匹！", "side": "left1"},
	{"speaker": "忒", "text": "……狂风能吹散荒原的沙，但吹不折逆风拉开的弓弦！", "side": "right1"},
]

const BOSS_BATTLE_BRETT_ISAR: Array = [
	{"speaker": "布雷特", "text": "魔道贤者？！为什么会有贤者插手这片废土！", "side": "left1"},
	{"speaker": "伊萨尔", "text": "天地正在风化，而你的暴行只会让绝望提前降临。止步吧。", "side": "right1"},
]

const BOSS_BATTLE_BRETT_GENERIC: Array = [
	{"speaker": "布雷特", "text": "敢阻拦断风寨的人，都得化作这山谷里的白骨！", "side": "left1"},
]

##Boss 临终遗言
const BOSS_DEFEAT_BRETT: Array = [
	{"speaker": "布雷特", "text": "混账……断风隘口……我的财宝……我不甘心……呃哇啊啊啊！", "side": "left1"},
]

@onready var enemy_node: Node2D = $Units/Enemy


##==================== 单位摆放 ====================

func _setup_units() -> void:
	_setup_player_units()
	_setup_allied_units()
	_setup_enemies()


func _setup_player_units() -> void:
	var te: Unit = $Units/Te
	te.cell = Vector2i(te.position) / Global.TILE_SIZE
	te.global_position = Vector2(te.cell) * Global.TILE_SIZE
	battle_manager.add_unit(te)

	var isar: Unit = $Units/Isar
	isar.cell = Vector2i(isar.position) / Global.TILE_SIZE
	isar.global_position = Vector2(isar.cell) * Global.TILE_SIZE
	battle_manager.add_unit(isar)


func _setup_allied_units() -> void:
	var reyn: Unit = $Units/Reyn
	reyn.cell = Vector2i(reyn.position) / Global.TILE_SIZE
	reyn.global_position = Vector2(reyn.cell) * Global.TILE_SIZE
	battle_manager.add_unit(reyn)

	var vera: Unit = $Units/Vera
	vera.cell = Vector2i(vera.position) / Global.TILE_SIZE
	vera.global_position = Vector2(vera.cell) * Global.TILE_SIZE
	battle_manager.add_unit(vera)


func _setup_enemies() -> void:
	for enemy in enemy_node.get_children():
		enemy.cell = Vector2i(enemy.global_position) / Global.TILE_SIZE
		if enemy.current_weapon == null:
			var axe := _create_iron_axe()
			enemy.add_item(axe)
			enemy.equip_item(axe)
		battle_manager.add_unit(enemy)


##==================== 对话数据 ====================

func get_talk_dialogue(unit: Unit, target: Unit) -> Dictionary:
	var pair := [unit.unit_name, target.unit_name]
	if pair.has("忒") and pair.has("雷恩"):
		return {
			"lines": TALK_TE_REYN,
			"portraits": {"忒": TE_CARD, "雷恩": REYN_CARD},
			"recruit": true
		}
	elif pair.has("忒") and pair.has("薇拉"):
		return {
			"lines": TALK_TE_VERA,
			"portraits": {"忒": TE_CARD, "薇拉": VERA_CARD},
			"recruit": true
		}
	return {}


func get_opening_dialogue() -> Dictionary:
	return {
		"lines": OPENING_LINES,
		"portraits": {
			"雷恩": REYN_CARD,
			"薇拉": VERA_CARD,
			"布雷特": BRETT_CARD,
			"忒": TE_CARD,
			"伊萨尔": ISAR_CARD
		}
	}


func get_ending_dialogue() -> Dictionary:
	return {
		"lines": ENDING_LINES,
		"portraits": {
			"雷恩": REYN_CARD,
			"薇拉": VERA_CARD,
			"忒": TE_CARD,
			"伊萨尔": ISAR_CARD
		}
	}


func get_boss_battle_dialogue(attacker: Unit, defender: Unit) -> Dictionary:
	var boss: Unit = defender if (defender != null and defender.unit_name == "布雷特") else (attacker if (attacker != null and attacker.unit_name == "布雷特") else null)
	if boss == null:
		return {}
	var other: Unit = attacker if defender == boss else defender
	if other != null and other.unit_name == "雷恩":
		return {"lines": BOSS_BATTLE_BRETT_REYN, "portraits": {"布雷特": BRETT_CARD, "雷恩": REYN_CARD}}
	elif other.unit_name == "忒":
		return {"lines": BOSS_BATTLE_BRETT_TE, "portraits": {"布雷特": BRETT_CARD, "忒": TE_CARD}}
	elif other.unit_name == "伊萨尔":
		return {"lines": BOSS_BATTLE_BRETT_ISAR, "portraits": {"布雷特": BRETT_CARD, "伊萨尔": ISAR_CARD}}
	else:
		return {"lines": BOSS_BATTLE_BRETT_GENERIC, "portraits": {"布雷特": BRETT_CARD}}


func get_boss_defeat_dialogue(boss: Unit, _killer: Unit) -> Dictionary:
	if boss.unit_name == "布雷特":
		return {"lines": BOSS_DEFEAT_BRETT, "portraits": {"布雷特": BRETT_CARD}}
	return {}


func get_next_chapter_path() -> String:
	return ""


func get_next_chapter_title() -> String:
	return "第二章 风化边缘的花亭"
