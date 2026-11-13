## M4 场景机关与可拾取道具管理器。
## 蜂窝拾取 / 携带 / 替换 / 自动释放；可击碎物件；食物；鸡群；铁球落点预警。
## 数值全部来自 data/props_m4.json 与 stage JSON 的 spawn_props，不硬编码。
extends Node
class_name M4Props

var arena = null
var stage_id: String = ""

## 道具记录数组：{node, type, hp, max_hp, x, carried_by}
var prop_records: Array = []
## 携带蜂窝的玩家：player -> prop_record
var carried: Dictionary = {}
## 每玩家蜂窝替换计数。
var replace_count: Dictionary = {}
## 鸡群记录：{node, mode, target, speed}
var chickens: Array = []
## 铁球记录：{node, x, timer}
var iron_balls: Array = []

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
	## Stage 1 环境鸡群（仅视觉，逻辑层跳过移动）。
	if stage_id == "stage_01" and not M2Data.logic_only:
		var cc := M4Data.chicken_cfg()
		spawn_chickens(int(cc.get("ambient_count_stage_01", 6)), 0.0, "ambient")

## 清空全部道具与机关。
func clear_all() -> void:
	for rec in prop_records:
		if is_instance_valid(rec.node):
			rec.node.queue_free()
	prop_records.clear()
	carried.clear()
	replace_count.clear()
	for c in chickens:
		if is_instance_valid(c.node):
			c.node.queue_free()
	chickens.clear()
	for b in iron_balls:
		if is_instance_valid(b.node):
			b.node.queue_free()
	iron_balls.clear()

## 生成单个道具实体。
func spawn_prop(type: String, x: float) -> void:
	if type == "honeycomb" or type in M4Data.breakables_cfg() or type == "food" or type == "spike_cage":
		var n := Node3D.new()
		n.name = "Prop_%s" % type
		n.position = Vector3(x, 0.0, 0.0)
		arena.world_root.add_child(n)
		var rec := {"node": n, "type": type, "x": x, "carried_by": null}
		if type in M4Data.breakables_cfg():
			var bcfg: Dictionary = M4Data.breakables_cfg().get(type, {})
			rec.hp = int(bcfg.get("hp", 20))
			rec.max_hp = rec.hp
		prop_records.append(rec)

## 每帧推进：铁球预警倒计时、鸡群移动。
func tick(dt: float) -> void:
	## 铁球：预警帧结束后落地结算。倒序遍历避免 erase 后索引错位。
	for i in range(iron_balls.size() - 1, -1, -1):
		var b: Dictionary = iron_balls[i]
		b.timer -= 1
		if b.timer <= 0:
			_resolve_iron_ball(b)
			iron_balls.remove_at(i)
			if is_instance_valid(b.node):
				b.node.queue_free()
	## 鸡群：向目标汇聚（演出）或缓慢游荡（环境）。
	var cc := M4Data.chicken_cfg()
	var speed: float = float(cc.get("speed_mps", 1.2))
	for c in chickens:
		if not is_instance_valid(c.node):
			continue
		if c.mode == "defeat" and c.target != Vector2.ZERO:
			var tx: float = c.target.x - c.node.position.x
			if abs(tx) > 0.1:
				c.node.position.x += signf(tx) * speed * dt
		else:
			c.node.position.x += randf_range(-1.0, 1.0) * speed * 0.3 * dt

## 在指定位置召唤大铁球（落点预警）。
func spawn_iron_ball(x: float) -> void:
	var boss_cfg: Dictionary = M4Data.boss("boss_02").get("ai", {}).get("iron_ball", {})
	var n := Node3D.new()
	n.name = "IronBall"
	n.position = Vector3(x, 0.0, 0.0)
	arena.world_root.add_child(n)
	iron_balls.append({"node": n, "x": x, "timer": int(boss_cfg.get("warning_frames", 30))})

## 铁球落地结算：范围内玩家受伤；JASON 击败演出中则压死终结。
func _resolve_iron_ball(b: Dictionary) -> void:
	var icfg: Dictionary = M4Data.iron_ball_cfg()
	var boss_cfg: Dictionary = M4Data.boss("boss_02").get("ai", {}).get("iron_ball", {})
	var radius: float = float(boss_cfg.get("radius_m", 0.9))
	var dmg: int = int(boss_cfg.get("damage", 30))
	var kb: float = float(boss_cfg.get("knockback_m", 3.0))
	arena.trigger_screen_shake(float(icfg.get("land_shake", 0.5)))
	## 压死 JASON 演出：Boss 处于铁球压死演出时，铁球落地即终结。
	var boss: Node = arena.boss
	if boss != null and is_instance_valid(boss) and boss._defeat_started and boss.defeat_type == "iron_ball_crush":
		boss.finish_defeat()
	var pm: M3PlayerManager = arena.player_manager
	if pm == null:
		return
	for p in pm.active_players():
		if abs(p.global_position.x - b.x) <= radius and abs(p.global_position.y) <= radius:
			var dir: int = 1 if b.x >= p.global_position.x else -1
			p.take_damage(dmg, dir, kb, 900 + b.x)
			arena.register_enemy_hit(p, dir)

## 玩家拾取检测：蜂窝与食物。
func check_pickups(player_manager: Node3D) -> void:
	var hcfg: Dictionary = M4Data.honeycomb_cfg()
	var pickup_range: float = float(hcfg.get("pickup_range_m", 1.0))
	for p in player_manager.active_players():
		## 蜂窝拾取 / 替换 / 自动释放。
		for rec in prop_records:
			if rec.type != "honeycomb" or rec.carried_by != null:
				continue
			if abs(p.global_position.x - rec.x) <= pickup_range:
				_pickup_honeycomb(p, rec)
		## 食物拾取回血。
		for rec in prop_records:
			if rec.type != "food":
				continue
			if abs(p.global_position.x - rec.x) <= pickup_range:
				_pickup_food(p, rec)

## 拾取蜂窝：未携带则携带；已携带则替换，两次替换后自动释放。
func _pickup_honeycomb(player: Node3D, rec: Dictionary) -> void:
	var hcfg: Dictionary = M4Data.honeycomb_cfg()
	if not carried.has(player):
		carried[player] = rec
		rec.carried_by = player
		return
	## 已携带：替换计数 +1，旧蜂窝掉落。
	replace_count[player] = int(replace_count.get(player, 0)) + 1
	_drop_honeycomb(player, carried[player])
	carried.erase(player)
	if replace_count[player] >= int(hcfg.get("auto_release_after_replaces", 2)):
		## 两次替换后自动释放：新蜂窝也掉落，不携带。
		replace_count[player] = 0
		_drop_honeycomb(player, rec)
	else:
		carried[player] = rec
		rec.carried_by = player

## 放下蜂窝（掉落在玩家侧方 1.5m，避免立即重新拾取）。
func _drop_honeycomb(player: Node3D, rec: Dictionary) -> void:
	rec.carried_by = null
	rec.x = player.global_position.x + 1.5
	rec.node.position = Vector3(rec.x, 0.0, 0.0)

## 消耗携带的蜂窝（投出后）。
func consume_honeycomb(player: Node3D) -> void:
	if carried.has(player):
		_drop_honeycomb(player, carried[player])
		carried.erase(player)

## 玩家是否携带蜂窝。
func player_carries_honeycomb(player: Node3D) -> bool:
	return carried.has(player)

## 拾取食物：回血并计分。
func _pickup_food(player: Node3D, rec: Dictionary) -> void:
	var fcfg: Dictionary = M4Data.food_cfg()
	var heal: int = int(float(player.max_hp) * float(fcfg.get("heal_percent", 25)) / 100.0)
	player.hp = mini(player.hp + heal, player.max_hp)
	var arena_score: Node = arena.score
	if arena_score != null:
		arena_score.add_breakable(int(fcfg.get("score", 100)))
	rec.node.queue_free()
	prop_records.erase(rec)

## 玩家攻击命中可击碎物件。
func apply_attack_to_breakables(hb: Rect2, src: Node3D) -> void:
	var dmg: int = M4Data.break_attack_damage()
	for rec in prop_records:
		if rec.type not in M4Data.breakables_cfg() or rec.hp <= 0:
			continue
		var w: float = 0.6
		var prop_hb := Rect2(rec.x - w * 0.5, -w * 0.5, w, w)
		if hb.intersects(prop_hb):
			rec.hp -= dmg
			if rec.hp <= 0:
				_break_prop(rec)

## 物件击碎：计分并移除。
func _break_prop(rec: Dictionary) -> void:
	var bcfg: Dictionary = M4Data.breakables_cfg().get(rec.type, {})
	var arena_score: Node = arena.score
	if arena_score != null:
		arena_score.add_breakable(int(bcfg.get("score", 200)))
	rec.node.queue_free()
	prop_records.erase(rec)

## 生成鸡群。mode：defeat（向目标汇聚）/ ambient（游荡）。
func spawn_chickens(count: int, around_x: float, mode: String) -> void:
	for i in count:
		var n := Node3D.new()
		n.name = "Chicken"
		n.position = Vector3(around_x + randf_range(-2.0, 2.0), 0.0, 0.0)
		arena.world_root.add_child(n)
		chickens.append({"node": n, "mode": mode, "target": Vector2.ZERO, "speed": 1.2})

## 设置鸡群汇聚目标（击败演出用）。
func set_chicken_target(pos: Vector3) -> void:
	for c in chickens:
		c.target = Vector2(pos.x, pos.y)
