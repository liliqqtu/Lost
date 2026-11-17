class_name ShopCatalog
extends RefCounted
## 默认货单仅提供场景预览；章节可向 open 注入自己的货单。
const DEFAULT_STOCK := [
	["iron_sword", "iron_lance", "iron_axe", "iron_bow", "steel_sword", "javelin", "hand_axe"],
	["vulnerary", "antitoxin", "pure_water", "fire", "lightning", "flux", "heal", "mend"],
	["brave_sword", "brave_lance", "brave_axe", "brave_bow", "physic", "hero_crest", "knight_s_crest", "elysian_whip", "guiding_ring"],
]
const TITLES := ["武器店", "道具店", "神秘商店"]
const LINES := {
	"welcome": ["欢迎光临武器店！\n想买些什么，还是卖些什么？", "欢迎光临道具店。\n有什么可以帮您？", "嘘……嘿嘿嘿……\n这里可是神秘商店哦！"],
	"buy": ["想要哪件武器？", "您需要些什么？", "嘿嘿……想要哪件宝贝？"],
	"sell": ["要卖哪件物品？", "您想卖些什么？", "让我看看你要卖的东西。"],
	"again": ["还有什么需要的吗？", "还需要其他东西吗？", "嘿嘿……还想要什么？"],
	"funds": ["钱不够啊！", "您的钱好像不够呢。", "嘿嘿……钱不够可不行！"],
	"bag_full": ["你已经拿不下了。\n要送到运输队吗？", "您的行囊满了。\n需要送到运输队吗？", "拿不下了吧……\n要送到运输队吗？"],
	"convoy_full": ["运输队也满了！\n先整理一下物品吧。", "运输队也放不下了。\n请整理后再来吧。", "嘿嘿……运输队也满了。\n先腾点地方吧。"],
	"no_convoy": ["没有运输队，没法寄送啊。", "现在没有运输队可以接收。", "嘿嘿……没有地方可送哦。"],
	"sent": ["好，这就送到运输队。", "好的，已经送到运输队了。", "嘿嘿……已经替你送去了。"],
	"bought": ["多谢惠顾！还有需要的吗？", "谢谢您，还需要些什么？", "嘿嘿……好眼光！还要吗？"],
	"sold": ["收下了。还有要卖的吗？", "谢谢，还有其他东西要卖吗？", "嘿嘿……还有什么要出手？"],
	"unsellable": ["这件东西不能收。", "抱歉，这件东西无法收购。", "嘿嘿……这可不能收啊。"],
	"empty": ["你没有可以卖的东西啊！", "您没有带物品呢。", "嘿嘿……你什么也没带啊。"],
	"unavailable": ["这件物品暂不出售。", "抱歉，这件暂时不卖。", "嘿嘿……这个可不卖哦。"],
	"bye": ["欢迎下次再来！", "下次也请再来看看。", "嘿嘿嘿……再会啦！"],
}

static func dialogue(key: String, shop_type: int) -> String:
	return LINES.get(key, LINES["again"])[clampi(shop_type, 0, 2)]

static func default_stock(shop_type: int) -> Array[Item]:
	var result: Array[Item] = []
	for item_id in DEFAULT_STOCK[clampi(shop_type, 0, 2)]:
		var path := "res://data/items/fe8/%s.tres" % item_id
		if ResourceLoader.exists(path):
			var item := load(path) as Item
			if item != null:
				result.append(item)
	return result
