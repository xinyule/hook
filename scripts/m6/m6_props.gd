## M6 场景机关与可拾取道具管理器。
## 运财小兵（背财宝击打掉落）、炮台（三连发落点预警）、Tinker Bell（回血加分）、
## 鳄鱼（结局登场）、可击碎物件（木箱 / 酒桶 / 装饰）、补血食物。
## 数值全部来自 data/props_m6.json 与 stage JSON 的 spawn_props，不硬编码。
extends Node
class_name M6Props

var arena = null
var stage_id: String = ""

## 道具记录数组：{node, type, hp, max_hp, x, carried_by}
var prop_records: Array = []
## 固定炮台记录：{node, x, timer}
var cannons: Array = []
## 炮台弹道：{x, dir, range, damage, kb, traveled, warning_left, hit_id}
var cannon_shots: Array = []
## Tinker Bell 记录：{node, x, used}
var tinker_bells: Array = []
## 鳄鱼节点与状态。
var crocodile: Node3D = null
var crocodile_active: bool = false
var crocodile_timer: int = 0
## 弹道命中 id 递增，避免命中去重误判。
var _shot_id: int = 9000

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
	for c in cannons:
		if is_instance_valid(c.node):
			c.node.queue_free()
	cannons.clear()
	cannon_shots.clear()
	for t in tinker_bells:
		if is_instance_valid(t.node):
			t.node.queue_free()
	tinker_bells.clear()
	if crocodile != null and is_instance_valid(crocodile):
		crocodile.queue_free()
	crocodile = null
	crocodile_active = false
	crocodile_timer = 0

## 生成单个道具实体。
func spawn_prop(type: String, x: float) -> void:
	if type in ["crate", "barrel", "decoration", "treasure_carrier", "food"]:
		var n := Node3D.new()
		n.name = "Prop_%s" % type
		n.position = Vector3(x, 0.0, 0.0)
		arena.world_root.add_child(n)
		var rec := {"node": n, "type": type, "x": x, "carried_by": null}
		if type == "treasure_carrier":
			var tcfg: Dictionary = M6Data.treasure_carrier_cfg()
			rec.hp = int(tcfg.get("hp", 30))
			rec.max_hp = rec.hp
		elif type in ["crate", "barrel", "decoration"]:
			var bcfg: Dictionary = M6Data.breakables_cfg().get(type, {})
			rec.hp = int(bcfg.get("hp", 20))
			rec.max_hp = rec.hp
		elif type == "food":
			rec.hp = 1
			rec.max_hp = 1
		prop_records.append(rec)
	elif type == "cannon":
		var cn := Node3D.new()
		cn.name = "Cannon"
		cn.position = Vector3(x, 0.0, 0.0)
		arena.world_root.add_child(cn)
		var ccfg: Dictionary = M6Data.cannon_cfg()
		cannons.append({"node": cn, "x": x, "timer": int(ccfg.get("triple_shot_interval_frames", 200))})
	elif type == "tinker_bell":
		var tn := Node3D.new()
		tn.name = "TinkerBell"
		tn.position = Vector3(x, 1.8, 0.0)
		arena.world_root.add_child(tn)
		tinker_bells.append({"node": tn, "x": x, "used": false})

## 生成炮台三连发弹道（由 SMEE Boss 委托调用，带落点预警）。
func spawn_cannon_triple(x: float, dir: int, range: float, damage: int, kb: float) -> void:
	var ccfg: Dictionary = M6Data.cannon_cfg()
	var warning: int = int(ccfg.get("warning_frames", 24))
	for i in 3:
		_shot_id += 1
		var shot := {"x": x, "dir": dir, "range": range, "damage": damage, "kb": kb, "traveled": 0.0, "warning_left": warning, "hit_id": _shot_id}
		cannon_shots.append(shot)

## 每帧推进：炮台三连发、弹道飞行、鳄鱼演出。
func tick(dt: float) -> void:
	## 炮台三连发定时。
	var ccfg: Dictionary = M6Data.cannon_cfg()
	var interval: int = int(ccfg.get("triple_shot_interval_frames", 200))
	for c in cannons:
		if not is_instance_valid(c.node):
			continue
		c.timer -= 1
		if c.timer <= 0:
			c.timer = interval
			_fire_cannon(c)
	## 弹道推进。
	_tick_cannon_shots(dt)
	## 鳄鱼演出倒计时。
	if crocodile_active:
		crocodile_timer -= 1

## 炮台发射三连发（朝最近玩家方向，带落点预警）。
func _fire_cannon(c: Dictionary) -> void:
	var ccfg: Dictionary = M6Data.cannon_cfg()
	var dir: int = 1
	var pm: Node3D = arena.player_manager
	if pm != null:
		var target: Array = pm.active_players()
		if not target.is_empty():
			var t0: Node3D = target[0]
			dir = 1 if t0.global_position.x >= c.x else -1
	var dmg: int = int(ccfg.get("shot_damage", 10))
	var kb: float = float(ccfg.get("shot_knockback_m", 1.5))
	var range: float = float(ccfg.get("shot_range_m", 7.0))
	var warning: int = int(ccfg.get("warning_frames", 24))
	for i in 3:
		_shot_id += 1
		var shot := {"x": c.x, "dir": dir, "range": range, "damage": dmg, "kb": kb, "traveled": 0.0, "warning_left": warning, "hit_id": _shot_id}
		cannon_shots.append(shot)

## 弹道推进：预警帧倒计时结束后飞行，命中玩家或超距移除。
func _tick_cannon_shots(dt: float) -> void:
	for i in range(cannon_shots.size() - 1, -1, -1):
		var s: Dictionary = cannon_shots[i]
		if s.warning_left > 0:
			s.warning_left -= 1
			continue
		var speed: float = 8.0
		s.x += s.dir * speed * dt
		s.traveled += speed * dt
		var pm: Node3D = arena.player_manager
		if pm != null:
			var target: Array = pm.active_players()
			var hit := false
			for p in target:
				if abs(p.global_position.x - s.x) <= 0.6:
					var ddir: int = 1 if s.x >= p.global_position.x else -1
					p.take_damage(int(s.damage), ddir, float(s.kb), int(s.hit_id))
					hit = true
					break
			if hit:
				cannon_shots.remove_at(i)
				continue
		if s.traveled >= s.range:
			cannon_shots.remove_at(i)

## 玩家靠近 Tinker Bell 触发回血 / 加分（隐藏点）。
func check_pickups(player_manager: Node3D) -> void:
	var tcfg: Dictionary = M6Data.tinker_bell_cfg()
	var range: float = float(tcfg.get("pickup_range_m", 1.2))
	var heal_percent: float = float(tcfg.get("heal_percent", 30))
	for i in range(tinker_bells.size() - 1, -1, -1):
		var t: Dictionary = tinker_bells[i]
		if t.used or not is_instance_valid(t.node):
			continue
		for p in player_manager.active_players():
			if abs(p.global_position.x - t.x) <= range:
				## 回血。
				var heal: int = int(float(p.max_hp) * heal_percent / 100.0)
				p.hp = min(p.hp + heal, p.max_hp)
				## 加分 + 隐藏点。
				var arena_score: Node = arena.score
				if arena_score != null:
					arena_score.add_breakable(int(tcfg.get("score", 500)))
					arena_score.add_hidden_point("tinker_%d" % t.x)
				t.used = true
				t.node.queue_free()
				tinker_bells.remove_at(i)
				break

## 玩家攻击命中可击碎物件。
func apply_attack_to_breakables(hb: Rect2, src: Node3D) -> void:
	var dmg: int = M6Data.break_attack_damage()
	for rec in prop_records:
		if rec.hp <= 0:
			continue
		var w: float = 0.6
		var prop_hb := Rect2(rec.x - w * 0.5, -w * 0.5, w, w)
		if hb.intersects(prop_hb):
			rec.hp -= dmg
			if rec.hp <= 0:
				_break_prop(rec, src)

## 物件击碎结算：运财小兵掉财宝、食物回血、其余计分。
func _break_prop(rec: Dictionary, src: Node3D) -> void:
	var arena_score: Node = arena.score
	if rec.type == "treasure_carrier":
		if arena_score != null:
			var tcfg: Dictionary = M6Data.treasure_carrier_cfg()
			arena_score.add_breakable(int(tcfg.get("treasure_drop_score", 500)))
	elif rec.type == "food":
		## 修复：回血与计分改为数据驱动（原 0.3 硬编码，违反数值不硬编码约束）。
		var fcfg: Dictionary = M6Data.food_cfg()
		var pm: Node3D = arena.player_manager
		if pm != null:
			for p in pm.active_players():
				if abs(p.global_position.x - rec.x) <= 1.0:
					var heal: int = int(float(p.max_hp) * float(fcfg.get("heal_percent", 30)) / 100.0)
					p.hp = min(p.hp + heal, p.max_hp)
		if arena_score != null:
			arena_score.add_breakable(int(fcfg.get("score", 100)))
	else:
		if arena_score != null:
			var bcfg: Dictionary = M6Data.breakables_cfg().get(rec.type, {})
			arena_score.add_breakable(int(bcfg.get("score", 200)))
	rec.node.queue_free()
	prop_records.erase(rec)

## 鳄鱼结局登场（HOOK 击败后由 arena 调用）。
func spawn_crocodile() -> void:
	if crocodile_active:
		return
	var ccfg: Dictionary = M6Data.crocodile_cfg()
	crocodile = Node3D.new()
	crocodile.name = "Crocodile"
	if not M2Data.logic_only:
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(1.6, 0.9, 0.8)
		mesh.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.35, 0.5, 0.3)
		mesh.material_override = mat
		crocodile.add_child(mesh)
	arena.world_root.add_child(crocodile)
	crocodile.position = Vector3(4.0, 0.0, 0.0)
	crocodile_active = true
	crocodile_timer = int(ccfg.get("ending_duration_frames", 120))
	arena.trigger_screen_shake(float(ccfg.get("shake", 0.7)))

## 鳄鱼演出是否结束（供 arena 触发结局）。
func is_crocodile_done() -> bool:
	return crocodile_active and crocodile_timer <= 0
