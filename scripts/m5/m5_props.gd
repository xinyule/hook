## M5 场景机关与可拾取道具管理器。
## 彩绘大罐（爆炸）、长矛（投掷互投）、冰柱（可踩反跳）、企鹅（彩蛋隐藏点）。
## 假 Hook 由 M5Arena 按人数生成（M5Boss），不在此管理。
## 数值全部来自 data/props_m5.json 与 stage JSON 的 spawn_props，不硬编码。
extends Node
class_name M5Props

var arena = null
var stage_id: String = ""

## 道具记录数组：{node, type, hp, max_hp, x, carried_by}
var prop_records: Array = []
## 企鹅记录：{node, x, hidden_point_id}
var penguins: Array = []
## 冰柱记录：{node, x, top_y, broken}
var ice_pillars: Array = []

## 初始化：清空并按当前关卡数据生成道具。
func setup(anode: Node3D, stage_id_str: String) -> void:
	arena = anode
	stage_id = stage_id_str
	clear_all()
	var sd: Dictionary = M3Data.stage(stage_id)
	var segs: Array = sd.get("segments", [])
	for seg in segs:
		var sp: Array = seg.get("spawn_props", [])
		for p in sp:
			spawn_prop(p.get("type", ""), float(p.get("x", 0.0)))

## 清空全部道具与机关。
func clear_all() -> void:
	for rec in prop_records:
		if is_instance_valid(rec.node):
			rec.node.queue_free()
	prop_records.clear()
	for c in penguins:
		if is_instance_valid(c.node):
			c.node.queue_free()
	penguins.clear()
	for b in ice_pillars:
		if is_instance_valid(b.node):
			b.node.queue_free()
	ice_pillars.clear()

## 生成单个道具实体。
func spawn_prop(type: String, x: float) -> void:
	if type in M5Data.props_m5() or type in ["painted_jar", "spear", "ice_pillar", "penguin"]:
		var n := Node3D.new()
		n.name = "Prop_%s" % type
		n.position = Vector3(x, 0.0, 0.0)
		arena.world_root.add_child(n)
		var rec := {"node": n, "type": type, "x": x, "carried_by": null}
		if type == "painted_jar":
			var jcfg: Dictionary = M5Data.painted_jar_cfg()
			rec.hp = int(jcfg.get("hp", 18))
			rec.max_hp = rec.hp
		elif type == "spear":
			## 长矛可拾取投掷，无 HP（拾取即消耗）。
			rec.hp = 1
			rec.max_hp = 1
		elif type == "ice_pillar":
			var icfg: Dictionary = M5Data.ice_pillar_cfg()
			rec.hp = int(icfg.get("hp", 20))
			rec.max_hp = rec.hp
			## 冰柱同时登记到 ice_pillars（可踩反跳）。
			var top_y := float(icfg.get("bounce_height_m", 1.2))
			ice_pillars.append({"node": n, "x": x, "top_y": top_y, "broken": false})
		elif type == "penguin":
			var pcfg: Dictionary = M5Data.penguin_cfg()
			rec.hp = int(pcfg.get("hp", 10))
			rec.max_hp = rec.hp
		prop_records.append(rec)

## 每帧推进：企鹅游荡。
func tick(dt: float) -> void:
	var pcfg: Dictionary = M5Data.penguin_cfg()
	var speed: float = float(pcfg.get("waddle_speed_mps", 0.6))
	for c in penguins:
		if not is_instance_valid(c.node):
			continue
		c.node.position.x += randf_range(-1.0, 1.0) * speed * dt

## 玩家攻击命中可击碎物件（彩绘大罐 / 冰柱 / 企鹅）。
func apply_attack_to_breakables(hb: Rect2, src: Node3D) -> void:
	var dmg: int = M5Data.break_attack_damage()
	for rec in prop_records:
		if rec.hp <= 0:
			continue
		var w: float = 0.6
		var prop_hb := Rect2(rec.x - w * 0.5, -w * 0.5, w, w)
		if hb.intersects(prop_hb):
			rec.hp -= dmg
			if rec.hp <= 0:
				_break_prop(rec, src)

## 物件击碎：彩绘大罐爆炸（范围伤害），冰柱/企鹅计分移除。
func _break_prop(rec: Dictionary, src: Node3D) -> void:
	if rec.type == "painted_jar":
		_explode_jar(rec)
		return
	var arena_score: Node = arena.score
	if rec.type == "ice_pillar":
		var icfg: Dictionary = M5Data.ice_pillar_cfg()
		if arena_score != null:
			arena_score.add_breakable(int(icfg.get("score", 200)))
		## 从冰柱列表移除。
		for b in ice_pillars:
			if b.node == rec.node:
				b.broken = true
				ice_pillars.erase(b)
				break
	elif rec.type == "penguin":
		var pcfg: Dictionary = M5Data.penguin_cfg()
		if arena_score != null:
			arena_score.add_breakable(int(pcfg.get("score", 300)))
			arena_score.add_hidden_point("penguin_%d" % rec.x)
		## 从企鹅列表移除。
		for c in penguins:
			if c.node == rec.node:
				penguins.erase(c)
				break
	rec.node.queue_free()
	prop_records.erase(rec)

## 彩绘大罐爆炸：范围内敌我受伤 + 震屏。
func _explode_jar(rec: Dictionary) -> void:
	var jcfg: Dictionary = M5Data.painted_jar_cfg()
	var radius: float = float(jcfg.get("explode_radius_m", 1.8))
	var dmg: int = int(jcfg.get("explode_damage", 12))
	var kb: float = float(jcfg.get("explode_knockback_m", 2.5))
	arena.trigger_screen_shake(float(jcfg.get("explode_shake", 0.6)))
	var arena_score: Node = arena.score
	if arena_score != null:
		arena_score.add_breakable(int(jcfg.get("score", 250)))
	## 伤害范围内敌人。
	for e in arena.enemies:
		if not is_instance_valid(e) or e.is_dead:
			continue
		if abs(e.global_position.x - rec.x) <= radius:
			var dir: int = 1 if rec.x >= e.global_position.x else -1
			e.take_damage(dmg, dir, kb, 950 + int(rec.x))
	## 伤害范围内玩家。
	var pm: M3PlayerManager = arena.player_manager
	if pm != null:
		for p in pm.active_players():
			if abs(p.global_position.x - rec.x) <= radius:
				var dir2: int = 1 if rec.x >= p.global_position.x else -1
				p.take_damage(dmg, dir2, kb, 960 + int(rec.x))
	rec.node.queue_free()
	prop_records.erase(rec)

## 玩家拾取长矛（可投掷互投）。
func check_pickups(player_manager: Node3D) -> void:
	for p in player_manager.active_players():
		for rec in prop_records:
			if rec.type != "spear" or rec.carried_by != null:
				continue
			if abs(p.global_position.x - rec.x) <= 1.0:
				rec.carried_by = p

## 玩家是否携带长矛。
func player_carries_spear(player: Node3D) -> bool:
	for rec in prop_records:
		if rec.type == "spear" and rec.carried_by == player:
			return true
	return false

## 消耗长矛（投出后）。
func consume_spear(player: Node3D) -> void:
	for rec in prop_records:
		if rec.type == "spear" and rec.carried_by == player:
			rec.carried_by = null
			break

## 长矛投掷命中结算（由 arena 在飞行道具落地时调用）。
func resolve_spear_hit(x: float, dmg: int, kb: float) -> void:
	for e in arena.enemies:
		if not is_instance_valid(e) or e.is_dead:
			continue
		if abs(e.global_position.x - x) <= 0.8:
			var dir: int = 1 if x >= e.global_position.x else -1
			e.take_damage(dmg, dir, kb, 970 + int(x))

## 冰柱可踩反跳检测：玩家落在冰柱顶部触发反跳。
## 返回 true 表示已处理（玩家被设为反跳）。
func check_ice_bounce(p: Node3D) -> bool:
	if not bool(M5Data.ice_surface_cfg().get("bounce_on_land", true)):
		return false
	for b in ice_pillars:
		if b.broken or not is_instance_valid(b.node):
			continue
		if abs(p.global_position.x - b.x) <= float(M5Data.ice_pillar_cfg().get("width_m", 0.6)):
			if p.global_position.y >= b.top_y - 0.1 and p.global_position.y <= b.top_y + 0.3:
				## 触发反跳：给玩家向上速度。
				var bounce: float = float(M5Data.ice_pillar_cfg().get("bounce_height_m", 1.2))
				p.vy = bounce
				p.on_floor = false
				return true
	return false

## 生成企鹅彩蛋（stage 数据驱动）。同时登记到 prop_records（可击碎）与 penguins（游荡）。
func spawn_penguin(x: float, hid_id: String) -> void:
	spawn_prop("penguin", x)
	var last: Dictionary = prop_records[prop_records.size() - 1]
	penguins.append({"node": last.node, "x": x, "hidden_point_id": hid_id})
