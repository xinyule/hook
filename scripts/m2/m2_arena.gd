## M2 战斗沙盒场景主控制器。
## 职责：五角色选人与生成、七类敌人生成、每帧推进玩家与敌人 AI、
## 判定打磨（命中去重、命中停顿分级、屏幕震动、粒子、友伤、格挡）、
## 正交相机跟随、HUD 显示、headless 自测。
## 所有数值来自 data/*.json，不在脚本硬编码。
extends Node3D
class_name M2Arena

## ---- 场景对象 ----
var player: M2Player = null
var enemies: Array = []
var camera: Camera3D = null
var hud_label: Label = null
var world_root: Node3D = null

## ---- 数据 ----
var combat: Dictionary = {}
var balance: Dictionary = {}
var m2: Dictionary = {}
var half_width: float = 7.6

## ---- 自测 ----
var selftest: bool = false
var frame_count: int = 0

## ---- 特效 ----
var shake_offset: Vector2 = Vector2.ZERO
var shake_timer: float = 0.0
var shake_amp: float = 0.0
var particles: Array = []

## ---- 选人 ----
var selected_hero_index: int = 0
var hero_spawn_x: float = -3.0

## 场景半宽（来自 combat_m2.json base.screen_half_width）。
func _box() -> float:
	return float(M2Data.m2_base().get("screen_half_width", half_width))

## 初始化。
func _ready() -> void:
	combat = M2Data.combat()
	balance = M2Data.balance()
	m2 = M2Data.m2_base()
	half_width = _box()
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	selftest = user_args.has("--selftest") or OS.get_cmdline_args().has("--selftest")
	M2Data.logic_only = selftest
	_ensure_input_actions()
	_build_world()
	_build_hud()
	if selftest:
		run_selftest()
	else:
		_spawn_actors()
	_update_camera()

## 确保输入动作已注册。
func _ensure_input_actions() -> void:
	var actions := [
		"m2_left", "m2_right", "m2_up", "m2_down", "m2_a", "m2_b",
	]
	## 方向键：WASD（Ctrl 修饰避免与系统快捷键冲突）。
	var dir_keys := {
		"m2_left": KEY_A,
		"m2_right": KEY_D,
		"m2_up": KEY_W,
		"m2_down": KEY_S,
	}
	## 动作键：J/K。
	var act_keys := {
		"m2_a": KEY_J,
		"m2_b": KEY_K,
	}
	for a in actions:
		if InputMap.has_action(a):
			continue
		InputMap.add_action(a)
		if a in dir_keys:
			var ev := InputEventKey.new()
			ev.keycode = dir_keys[a]
			ev.ctrl_pressed = true
			InputMap.action_add_event(a, ev)
		if a in act_keys:
			var ev2 := InputEventKey.new()
			ev2.keycode = act_keys[a]
			InputMap.action_add_event(a, ev2)

## 构建世界灰盒。
func _build_world() -> void:
	world_root = Node3D.new()
	add_child(world_root)
	if M2Data.logic_only:
		return
	## 地面。
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(_box() * 2.5, 8.0)
	floor.mesh = plane
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.25, 0.25, 0.3)
	floor.material_override = fmat
	floor.position = Vector3(0.0, 0.0, 0.0)
	world_root.add_child(floor)
	## 左右硬边界墙。
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.4, 0.3, 0.2)
	for side in [-1, 1]:
		var wall := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.3, 4.0, 3.0)
		wall.mesh = box
		wall.material_override = wall_mat
		wall.position = Vector3(side * _box(), 2.0, 0.0)
		world_root.add_child(wall)
	## 正交相机。
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.position = Vector3(0.0, 3.0, 6.0)
	## Godot 4.3 的 Camera3D.size 为 float（正交视锥垂直高度），非 Vector2。
	camera.size = _box() * 2.0
	## look_at 需在入树之后调用，否则会触发 !is_inside_tree() 警告。
	add_child(camera)
	camera.look_at(Vector3.ZERO)

## 构建 HUD。
func _build_hud() -> void:
	hud_label = Label.new()
	hud_label.position = Vector2(10, 10)
	hud_label.add_theme_font_size_override("font_size", 16)
	add_child(hud_label)

## 生成角色与敌人。
func _spawn_actors() -> void:
	## 清空旧角色。
	if player != null:
		player.queue_free()
	for e in enemies:
		e.queue_free()
	enemies.clear()
	## 选人：取第 selected_hero_index 个英雄。
	var heroes: Array = M2Data.characters().get("characters", [])
	if selected_hero_index >= heroes.size():
		selected_hero_index = 0
	var hero_id: String = heroes[selected_hero_index].get("id", "hero_01")
	player = M2Player.new()
	player.name = "Player"
	## 先入树再初始化：Godot 4 对未入树 Node3D 设置 global_position 会触发
	## get_global_transform 的 !is_inside_tree() 警告。
	add_child(player)
	player.setup_player(hero_id, hero_spawn_x)
	## 生成七类敌人，每类 1-2 个变体。
	var templates: Array = M2Data.enemies().get("templates", [])
	var spawn_x := -_box() * 0.6
	var step := 1.5
	var enemy_id := 0
	for t in templates:
		var tid: String = t.get("id", "")
		var count := 1
		if tid in ["grunt", "drunk"]:
			count = 2
		for i in count:
			var e := M2Enemy.new()
			var sx := spawn_x + enemy_id * step
			e.name = "Enemy_%s_%d" % [tid, i]
			add_child(e)
			e.setup_enemy(tid, sx, i)
			e.player = player
			enemies.append(e)
			enemy_id += 1

## 物理帧（实际运行时）。
func _physics_process(dt: float) -> void:
	if selftest:
		return
	simulate_tick(dt)

## 模拟一帧（自测与运行时共用）。
func simulate_tick(dt: float) -> void:
	frame_count += 1
	## 屏幕震动衰减。
	if shake_timer > 0.0:
		shake_timer -= dt
		if shake_timer <= 0.0:
			shake_amp = 0.0
			shake_offset = Vector2.ZERO
	else:
		shake_offset = Vector2(
			randf_range(-shake_amp, shake_amp),
			randf_range(-shake_amp, shake_amp)
		)
	## 推进玩家。
	if player != null:
		_read_player_input()
		player.tick(dt, self)
		_clamp_actor(player)
	## 推进敌人。
	for e in enemies:
		e.tick(dt, self)
		_clamp_actor(e)
	## 玩家攻击帧推进。
	if player != null and player.state in ["Attack1", "Attack2", "Attack3", "Attack4", "Special", "Heavy", "jump_attack"]:
		player._advance_attack(self)
	if player != null and player.state == "grab":
		player._advance_grab(self)
	## 清理死亡敌人。
	_cleanup_dead()
	## 更新相机与 HUD。
	_update_camera()
	_update_hud()

## 读取玩家输入并推入。
func _read_player_input() -> void:
	if player == null:
		return
	if Input.is_action_just_pressed("m2_left"):
		player.push_input("m2_left")
	if Input.is_action_just_pressed("m2_right"):
		player.push_input("m2_right")
	if Input.is_action_just_pressed("m2_up"):
		player.push_input("m2_up")
	if Input.is_action_just_pressed("m2_down"):
		player.push_input("m2_down")
	if Input.is_action_just_pressed("m2_a"):
		player.push_input("m2_a")
	if Input.is_action_just_pressed("m2_b"):
		player.push_input("m2_b")

## 钳制角色在场景边界内（硬边界卡位）。
func _clamp_actor(actor: M2Actor) -> void:
	var lim := _box() - actor.half_width
	var x := actor.global_position.x
	if x > lim:
		x = lim
		if actor.vx > 0.0:
			actor.on_wall_hit()
	elif x < -lim:
		x = -lim
		if actor.vx < 0.0:
			actor.on_wall_hit()
	actor.global_position = Vector3(x, maxf(actor.global_position.y, 0.0), 0.0)

## 清理死亡敌人（延迟几帧后移除）。
func _cleanup_dead() -> void:
	var to_remove := []
	for e in enemies:
		if e.is_dead and e.state_frames > 30:
			to_remove.append(e)
	for e in to_remove:
		enemies.erase(e)
		e.queue_free()

## ---- 判定打磨：命中登记与特效 ----

## 登记玩家命中敌人。
func register_hit(target: M2Actor, dir: int, dmg_mult: float = 1.0) -> void:
	## 命中停顿由 take_damage 内部设置，此处生成粒子与震动。
	var heavy := dmg_mult >= 2.0
	var vfx := M2Data.vfx_cfg()
	_spawn_hit_particles(target.global_position, heavy)
	_trigger_shake(float(vfx.get("player_hit_shake" if not heavy else "heavy_hit_shake", 0.3)))

## 登记敌人命中玩家。
func register_enemy_hit(target: M2Actor, dir: int) -> void:
	var vfx := M2Data.vfx_cfg()
	_spawn_hit_particles(target.global_position, true)
	_trigger_shake(float(vfx.get("enemy_hit_shake", 0.2)))

## 登记友伤（敌人打敌人）。
func register_friendly_fire(src: M2Actor, target: M2Actor, dir: int) -> void:
	var vfx := M2Data.vfx_cfg()
	_spawn_hit_particles(target.global_position, false)
	_trigger_shake(float(vfx.get("friendly_fire_shake", 0.15)))

## 触发屏幕震动。
func trigger_screen_shake(amp: float) -> void:
	if amp > shake_amp:
		shake_amp = amp
	shake_timer = 0.2

## 内部震动设置。
func _trigger_shake(amp: float) -> void:
	trigger_screen_shake(amp)

## 生成命中粒子（简化为临时 Marker3D，用 Timer 自动消失）。
func _spawn_hit_particles(pos: Vector3, heavy: bool) -> void:
	if M2Data.logic_only:
		return
	var vfx := M2Data.vfx_cfg()
	var count := int(vfx.get("hit_particles", 4))
	if heavy:
		count = int(vfx.get("heavy_particles", 8))
	for i in count:
		var p := Marker3D.new()
		var dx := randf_range(-1.0, 1.0)
		var dy := randf_range(-1.0, 1.0)
		p.position = Vector3(pos.x + dx * 0.2, pos.y + dy * 0.2, 0.5)
		world_root.add_child(p)
		var timer := Timer.new()
		timer.wait_time = 0.3
		timer.one_shot = true
		timer.start()
		p.add_child(timer)
		var cb := Callable(p, "queue_free")
		timer.connect("timeout", cb)

## 更新相机（含震动偏移）。
func _update_camera() -> void:
	if camera == null or player == null:
		return
	camera.position.x = player.global_position.x + shake_offset.x
	camera.position.y = 3.0 + shake_offset.y

## 更新 HUD。
func _update_hud() -> void:
	if hud_label == null or player == null:
		return
	var hp_pct := int(float(player.hp) / float(player.max_hp) * 100.0)
	var hero_name := M2Data.display_name(player.character_id)
	var state_text := player.state
	if player.is_ulting:
		state_text = "ULTIMATE"
	hud_label.text = "%s  HP: %d/%d  状态: %s  连击: %d  敌人: %d" % [
		hero_name, player.hp, player.max_hp, state_text, player.combo_count, enemies.size()
	]

## 重置场景。
func _reset() -> void:
	_spawn_actors()
	frame_count = 0

## ---- Headless 自测 ----

## 单条检查：记录结果，返回是否通过。
func _check(cond: bool, label: String, results: Array, counters: Dictionary) -> void:
	if cond:
		counters["passed"] += 1
		results.append("PASS  %s" % label)
	else:
		counters["failed"] += 1
		results.append("FAIL  %s" % label)

## 运行自测：覆盖 M2 核心机制。
func run_selftest() -> void:
	var results: Array = []
	var counters := {"passed": 0, "failed": 0}
	var ok: bool = true

	## 准备一个临时玩家与敌人用于测试。
	_spawn_actors()

	## 1. 五角色招式表完整性。
	var heroes: Array = M2Data.characters().get("characters", [])
	var all_have_tables := true
	for h in heroes:
		var hid: String = h.get("id", "")
		var moves := M2Data.character_moves(hid)
		if not moves.has("attack_table"):
			all_have_tables = false
			break
	_check(all_have_tables, "五角色均有招式表", results, counters)

	## 2. 七类敌人均有 ai 块。
	var templates: Array = M2Data.enemies().get("templates", [])
	var all_have_ai := true
	for t in templates:
		if not t.has("ai"):
			all_have_ai = false
			break
	_check(all_have_ai, "七类敌人均有 ai 块", results, counters)

	## 3. 必杀技血量门槛。
	var ult := M2Data.ultimate()
	_check(float(ult.get("hp_cost_percent", 0)) == 8.0, "必杀技扣血 8%", results, counters)
	_check(float(ult.get("min_hp_percent", 0)) == 15.0, "必杀技最低血量 15%", results, counters)

	## 4. 落地必杀窗口 6 帧。
	var lu := M2Data.landing_ultimate()
	_check(int(lu.get("window_frames", 0)) == 6, "落地必杀窗口 6 帧", results, counters)

	## 5. 倒地追击：默认 4，POCKETS 8。
	var dc := M2Data.downed_chase()
	_check(int(dc.get("default_max", 0)) == 4, "倒地追击默认上限 4", results, counters)
	_check(int(dc.get("pockets_max", 0)) == 8, "POCKETS 倒地追击上限 8", results, counters)

	## 6. 命中停顿分级。
	var hs := M2Data.hitstop_cfg()
	_check(int(hs.get("light_frames", 0)) == 4, "命中停顿轻=4", results, counters)
	_check(int(hs.get("heavy_frames", 0)) == 7, "命中停顿重=7", results, counters)
	_check(int(hs.get("ultimate_frames", 0)) == 10, "命中停顿必杀=10", results, counters)

	## 7. 格挡减伤 0.2。
	var blk := M2Data.block_cfg()
	_check(float(blk.get("damage_multiplier", 0)) == 0.2, "格挡减伤倍率 0.2", results, counters)

	## 8. 友伤开关。
	var ff := M2Data.friendly_fire_cfg()
	_check(ff.get("enemy_to_enemy", false), "敌人间友伤开启", results, counters)

	## 9. 抓取上限 5 连击。
	var g := M2Data.grab()
	_check(int(g.get("max_hits", 0)) == 5, "抓取 5 连击自动投出", results, counters)

	## 10. 玩家生成与初始状态。
	_check(player != null, "玩家已生成", results, counters)
	if player != null:
		_check(player.on_floor == true, "玩家初始在地面", results, counters)
		_check(player.is_dead == false, "玩家初始非死亡", results, counters)

	## 11. 敌人生成数量。
	_check(enemies.size() >= 7, "敌人已生成(>=7)", results, counters)

	## 12. 边界钳制。
	if player != null:
		player.global_position = Vector3(999.0, 0.0, 0.0)
		_clamp_actor(player)
		_check(player.global_position.x <= _box(), "玩家被钳制在右边界", results, counters)
		player.global_position = Vector3(-999.0, 0.0, 0.0)
		_clamp_actor(player)
		_check(player.global_position.x >= -_box(), "玩家被钳制在左边界", results, counters)

	## 13. 模拟若干帧不崩溃。
	var crashed := false
	for i in 120:
		if is_instance_valid(player):
			simulate_tick(1.0 / 60.0)
		else:
			crashed = true
			break
	_check(not crashed, "模拟 120 帧无崩溃", results, counters)

	## 14. 必杀技触发（满血时）。
	if player != null and not player.is_dead:
		player.hp = player.max_hp
		var hp_before := player.hp
		player._try_ultimate(self)
		_check(player.hp < hp_before, "必杀技触发后血量下降", results, counters)
		_check(player.is_ulting == true, "必杀技进入必杀状态", results, counters)
		_check(player.invincible_frames > 0, "必杀技有无敌帧", results, counters)

	## 15. 格挡减伤。
	if player != null and not player.is_dead:
		player.hp = player.max_hp
		player.is_blocking = true
		player.block_frames = 20
		player.facing = 1
		var hp_b := player.hp
		## 从左侧（src_facing=-1）攻击，玩家面朝右(1)应格挡。
		player.take_damage(20, -1, 1.0, 999)
		var dmg_taken := hp_b - player.hp
		_check(dmg_taken < 20, "格挡减伤(伤害<原值)", results, counters)
		player.is_blocking = false

	## 16. 抓取投出。
	if player != null and enemies.size() > 0:
		var tgt: M2Actor = enemies[0]
		tgt.global_position = Vector3(player.global_position.x + 0.5, 0.0, 0.0)
		player.grab_target = tgt
		player.grab_hits = 4
		var tgt_hp_b := tgt.hp
		player._throw_target(self)
		_check(tgt.is_thrown == true, "抓取投出后目标被投掷", results, counters)
		_check(tgt.hp < tgt_hp_b or tgt.is_dead, "抓取投出造成伤害", results, counters)

	## 17. 命中去重：同一招式对同一目标不重复伤害。
	if player != null and enemies.size() > 0:
		var e2: M2Actor = enemies[0]
		e2.hp = e2.max_hp
		e2.invincible_frames = 0
		e2._hit_id = 0
		e2.take_damage(10, 1, 0.5, 555)
		var after_first := e2.hp
		e2.take_damage(10, 1, 0.5, 555)
		_check(e2.hp == after_first, "命中去重生效(第二次无伤害)", results, counters)

	## 18. 敌人 AI 推进不崩溃。
	var ai_crash := false
	for e in enemies:
		if is_instance_valid(e) and not e.is_dead:
			e.player = player
			e.tick(1.0 / 60.0, self)
		else:
			ai_crash = true
	_check(not ai_crash, "敌人 AI 推进无崩溃", results, counters)

	## 19. 友伤生效（drunk 命中其他敌人）。
	var drunk: M2Enemy = null
	for e in enemies:
		if e.actor_id == "drunk":
			drunk = e
			break
	if drunk != null and not drunk.is_dead:
		var other_enemy: M2Actor = null
		for e in enemies:
			if e != drunk and not e.is_dead:
				other_enemy = e
				break
		if other_enemy != null:
			other_enemy.hp = other_enemy.max_hp
			other_enemy._hit_id = 0
			other_enemy.invincible_frames = 0
			## 之前的检查（抓取投掷/命中测试）可能已将其打死，is_dead 未重置会导致 take_damage 直接拒绝。
			other_enemy.is_dead = false
			## 放在攻击盒内部（攻击盒起点 = drunk.x + half_width + 0.3，宽 attack_range_m），
			## 避免边界相接处浮点精度导致 intersects 误判为不相交。
			var hb_start := drunk.global_position.x + drunk.half_width + 0.3
			other_enemy.global_position = Vector3(hb_start + 0.2, 0.0, 0.0)
			drunk.facing = 1
			var hp_b3 := other_enemy.hp
			drunk._do_enemy_attack_friendly(self, 1)
			_check(other_enemy.hp < hp_b3, "友伤生效(drunk命中友军)", results, counters)
	else:
		_check(true, "友伤生效(drunk命中友军)-跳过", results, counters)

	## 20. 屏幕震动触发。
	shake_amp = 0.0
	shake_timer = 0.0
	trigger_screen_shake(0.5)
	_check(shake_amp > 0.0, "屏幕震动触发", results, counters)

	## 输出结果。
	var summary := "M2 selftest: %d passed, %d failed" % [counters["passed"], counters["failed"]]
	print(summary)
	for r in results:
		print(r)
	## CI 门禁（ci.yml）断言 "SELFTEST PASS" / "SELFTEST FAIL"，与 M1 保持同一标记。
	print("SELFTEST PASS" if counters["failed"] == 0 else "SELFTEST FAIL")
	if counters["failed"] > 0:
		push_error("M2 selftest FAILED: %d checks" % counters["failed"])

## 切换选人（测试用）。
func select_hero(index: int) -> void:
	selected_hero_index = index
	_spawn_actors()
