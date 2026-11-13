## M4 主场景控制器。
## 继承 M3Arena，扩展 Stage 1-2 的 Boss 战、机关道具与场景构建。
## 复用 M3 框架层（StageRunner / WaveDirector / PlayerManager / Timer /
## Score / Hud / Loop）与 M2 战斗核心，M4 只加场景、Boss、机关与自测。
## 所有数值来自 data/*.json，不硬编码。
extends M3Arena
class_name M4Arena

## ---- M4 扩展 ----
var props: M4Props = null
var stage_scene: M4StageScene = null
var boss: M4Boss = null
var boss_bar_label: Label = null
var boss_bar_progress: ProgressBar = null
var boss_bar_layer: CanvasLayer = null

## Boss 击败标志（延迟到 tick 末尾处理，避免信号重入）。
var _boss_defeated: bool = false

## ---- 构建 ----

## 初始化。
func _ready() -> void:
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	selftest = user_args.has("--selftest") or OS.get_cmdline_args().has("--selftest")
	M2Data.logic_only = selftest
	M3Data.logic_only = selftest
	M4Data.logic_only = selftest
	_ensure_input_actions()
	_build_world()
	_build_systems()
	if selftest:
		run_selftest()
	else:
		_start_game()

## 构建世界灰盒与 M4 场景。
func _build_world() -> void:
	## 调用 M3 的地面/墙/相机构建。
	super._build_world()
	## M4 场景构建器。
	stage_scene = M4StageScene.new()
	add_child(stage_scene)

## 构建 M3 系统 + M4 扩展。
func _build_systems() -> void:
	## 先构建 M3 系统。
	super._build_systems()
	## M4 机关道具管理器。
	props = M4Props.new()
	add_child(props)
	## Boss 血条 HUD。
	_build_boss_bar()

## 构建 Boss 血条（CanvasLayer）。
func _build_boss_bar() -> void:
	boss_bar_layer = CanvasLayer.new()
	add_child(boss_bar_layer)
	var panel := Panel.new()
	panel.position = Vector2(440.0, 10.0)
	panel.size = Vector2(400.0, 50.0)
	boss_bar_layer.add_child(panel)
	boss_bar_label = Label.new()
	boss_bar_label.text = ""
	boss_bar_label.position = Vector2(10.0, 5.0)
	boss_bar_label.size = Vector2(380.0, 20.0)
	boss_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(boss_bar_label)
	boss_bar_progress = ProgressBar.new()
	boss_bar_progress.position = Vector2(10.0, 28.0)
	boss_bar_progress.size = Vector2(380.0, 16.0)
	boss_bar_progress.min_value = 0.0
	boss_bar_progress.max_value = 100.0
	boss_bar_progress.value = 100.0
	panel.add_child(boss_bar_progress)

## 加载指定索引的关卡（M4 扩展：构建场景 + 初始化道具）。
func _load_stage(index: int) -> void:
	_loading_stage = true
	var order: Array = M3Data.stage_order()
	if index >= order.size():
		index = 0
	current_stage_index = index
	var sid: String = order[index]
	stage_runner.load_stage(sid)
	## 构建 M4 场景与光照。
	if stage_scene != null:
		stage_scene.build(sid, stage_runner.stage_data)
	## 初始化机关道具。
	if props != null:
		props.setup(self, sid)
	## 清空旧敌人与旧 Boss。
	_clear_enemies()
	_clear_boss()
	## 加载当前段波次（Boss 段则生成 Boss）。
	_load_segment_waves()
	## 重置计时器。
	timer.reset()
	## 生成默认 P1。
	if player_manager.all_players().is_empty():
		var heroes: Array = M2Data.characters().get("characters", [])
		if not heroes.is_empty():
			player_manager.join_player(0, heroes[0].get("id", "hero_01"))
	## 更新主玩家引用。
	var all: Array = player_manager.all_players()
	if not all.is_empty():
		player = all[0]
	_loading_stage = false

## 加载当前段波次。Boss 段则生成 Boss，不加载波次。
func _load_segment_waves() -> void:
	if stage_runner.is_boss_segment():
		_spawn_boss()
		return
	var waves: Array = stage_runner.segment_waves()
	if waves.is_empty():
		return
	var sx: float = _box() * 0.6
	wave_director.load_waves(waves, sx, -1)

## 生成当前关卡的 Boss。
func _spawn_boss() -> void:
	var stage_data: Dictionary = stage_runner.stage_data
	var boss_data: Dictionary = stage_data.get("boss", {})
	var boss_id: String = boss_data.get("id", "boss_01")
	var sx: float = _box() * 0.5
	_clear_boss()
	boss = M4Boss.new()
	## 先入树再初始化。
	add_child(boss)
	boss.setup_boss(boss_id, sx, self)
	## 指定目标玩家。
	var target: Array = player_manager.active_players()
	if not target.is_empty():
		boss.player = target[0]
	enemies.append(boss)
	## 连接击败信号。
	boss.defeat_sequence_finished.connect(_on_boss_defeated)

## 清空 Boss。
func _clear_boss() -> void:
	if boss != null and is_instance_valid(boss):
		boss.queue_free()
	boss = null

## Boss 击败信号回调（延迟处理）。
func _on_boss_defeated() -> void:
	_boss_defeated = true

## 段落清空回调：M4 复用 M3 逻辑，但 Boss 段由 Boss 击败驱动。
func _on_segment_cleared() -> void:
	if _loading_stage:
		return
	## Boss 段不通过波次清空推进，由 Boss 击败驱动。
	if stage_runner.is_boss_segment():
		return
	while true:
		if not stage_runner.advance_segment():
			_on_stage_complete()
			return
		var waves: Array = stage_runner.segment_waves()
		if waves.is_empty():
			continue
		_load_segment_waves()
		return

## ---- 模拟帧 ----

## 模拟一帧（M4 扩展：道具 tick、拾取检测、可击碎物件、Boss 血条）。
func simulate_tick(dt: float) -> void:
	## M3 基础逻辑。
	super.simulate_tick(dt)
	## M4 道具推进。
	if props != null:
		props.tick(dt)
	## 拾取检测。
	if props != null:
		props.check_pickups(player_manager)
	## 可击碎物件受击检测。
	_check_breakable_hits()
	## 更新 Boss 目标玩家引用。
	if boss != null and is_instance_valid(boss) and boss.player == null:
		var active: Array = player_manager.active_players()
		if not active.is_empty():
			boss.player = active[0]
	## 更新 Boss 血条。
	_update_boss_bar()
	## 处理 Boss 击败（延迟到帧末，避免信号重入）。
	if _boss_defeated:
		_boss_defeated = false
		_on_boss_defeated_tick()

## Boss 击败后的关卡推进。
func _on_boss_defeated_tick() -> void:
	## 清空 Boss。
	_clear_boss()
	## 推进到下一关或回环。
	_on_stage_complete()

## 检测玩家攻击命中可击碎物件。
func _check_breakable_hits() -> void:
	if props == null:
		return
	for p in player_manager.all_players():
		if p.is_dead or not is_instance_valid(p):
			continue
		if p.state in ["Attack1", "Attack2", "Attack3", "Attack4", "Special", "Heavy", "jump_attack"]:
			var hb: Rect2 = p.current_hitbox()
			if hb != Rect2():
				props.apply_attack_to_breakables(hb, p)

## 更新 Boss 血条显示。Boss 在场且未死亡时显示。
func _update_boss_bar() -> void:
	if boss_bar_label == null or boss_bar_progress == null:
		return
	if boss == null or not is_instance_valid(boss) or boss.is_dead:
		boss_bar_label.text = ""
		boss_bar_progress.value = 0.0
		return
	var name: String = boss.boss_cfg.get("display_name", "")
	boss_bar_label.text = name
	var pct: float = float(boss.hp) / float(boss.max_hp) * 100.0
	boss_bar_progress.value = pct

## ---- M4 兼容接口（供 m4_boss / m4_props 调用）----

## 召唤大铁球（由 JASON Boss 调用，委托给 props）。
func spawn_iron_ball(x: float) -> void:
	if props != null:
		props.spawn_iron_ball(x)

## ---- Headless 自测 ----

## 运行 M3 + M4 自测。
func run_selftest() -> void:
	var results: Array = []
	var counters := {"passed": 0, "failed": 0}
	## M3 框架层 42 项。
	_m3_selftest_checks(results, counters)
	## M4 扩展层断言。
	_m4_selftest_checks(results, counters)
	_selftest_output(results, counters, "M4")

## M4 扩展层自测断言。
func _m4_selftest_checks(results: Array, counters: Dictionary) -> void:
	## 1. stage_01 波次数据加载。
	stage_runner.load_stage("stage_01")
	var s1_segs: Array = stage_runner.stage_data.get("segments", [])
	_check(s1_segs.size() >= 3, "M4 stage_01 段落数 >= 3", results, counters)

	## 2. stage_01 波次数据非空。
	var s1_waves: Array = s1_segs[0].get("waves", [])
	_check(not s1_waves.is_empty(), "M4 stage_01 1-A 波次非空", results, counters)

	## 3. stage_02 波次数据加载。
	stage_runner.load_stage("stage_02")
	var s2_segs: Array = stage_runner.stage_data.get("segments", [])
	_check(s2_segs.size() >= 3, "M4 stage_02 段落数 >= 3", results, counters)

	## 4. stage_02 波次数据非空。
	var s2_waves: Array = s2_segs[0].get("waves", [])
	_check(not s2_waves.is_empty(), "M4 stage_02 2-A 波次非空", results, counters)

	## 5. BUTCHER Boss 数据加载。
	var butcher_cfg: Dictionary = M4Data.boss("boss_01")
	_check(not butcher_cfg.is_empty() and butcher_cfg.get("display_name") == "BUTCHER", "M4 BUTCHER Boss 数据加载", results, counters)

	## 6. JASON Boss 数据加载。
	var jason_cfg: Dictionary = M4Data.boss("boss_02")
	_check(not jason_cfg.is_empty() and jason_cfg.get("display_name") == "JASON", "M4 JASON Boss 数据加载", results, counters)

	## 7. props_m4 数据加载。
	var props_cfg: Dictionary = M4Data.props_m4()
	_check(not props_cfg.is_empty(), "M4 props_m4 数据加载", results, counters)

	## 8. 蜂窝配置读取。
	var honey_cfg: Dictionary = M4Data.honeycomb_cfg()
	_check(honey_cfg.has("pickup_range_m") and honey_cfg.has("auto_release_after_replaces"), "M4 蜂窝配置读取", results, counters)

	## 9. 铁球配置读取。
	var iron_cfg: Dictionary = M4Data.iron_ball_cfg()
	_check(iron_cfg.has("warning_radius_m") and iron_cfg.has("land_shake"), "M4 铁球配置读取", results, counters)

	## 10. 鸡群配置读取。
	var chicken_cfg: Dictionary = M4Data.chicken_cfg()
	_check(chicken_cfg.has("ambient_count_stage_01") and chicken_cfg.has("peck_damage"), "M4 鸡群配置读取", results, counters)

	## 11. 可击碎物件配置读取。
	var break_cfg: Dictionary = M4Data.breakables_cfg()
	_check(break_cfg.has("barrel") and break_cfg.has("crate") and break_cfg.has("pot") and break_cfg.has("anchor"), "M4 可击碎物件配置读取", results, counters)

	## 12. 食物配置读取。
	var food_cfg: Dictionary = M4Data.food_cfg()
	_check(food_cfg.has("heal_percent") and food_cfg.has("score"), "M4 食物配置读取", results, counters)

	## 13. Boss 血条配置读取。
	var bar_cfg: Dictionary = M4Data.boss_bar_cfg()
	_check(bar_cfg.has("width_m") and bar_cfg.has("height_m") and bar_cfg.has("name_font_size"), "M4 Boss 血条配置读取", results, counters)

	## 14. props 初始化 stage_01。
	props.setup(self, "stage_01")
	_check(not props.prop_records.is_empty(), "M4 props 初始化 stage_01 生成道具", results, counters)

	## 15. props 初始化 stage_02。
	props.setup(self, "stage_02")
	_check(not props.prop_records.is_empty(), "M4 props 初始化 stage_02 生成道具", results, counters)

	## 16. BUTCHER Boss 生成。
	var b1: M4Boss = M4Boss.new()
	add_child(b1)
	b1.setup_boss("boss_01", 5.0, self)
	_check(b1.hp > 0 and b1.max_hp > 0, "M4 BUTCHER Boss 生成", results, counters)

	## 17. JASON Boss 生成。
	var b2: M4Boss = M4Boss.new()
	add_child(b2)
	b2.setup_boss("boss_02", 5.0, self)
	_check(b2.hp > 0 and b2.max_hp > 0, "M4 JASON Boss 生成", results, counters)

	## 18. BUTCHER HP 数值。
	_check(b1.max_hp == int(butcher_cfg.get("hp", 0)), "M4 BUTCHER HP 数值匹配数据", results, counters)

	## 19. JASON HP 数值。
	_check(b2.max_hp == int(jason_cfg.get("hp", 0)), "M4 JASON HP 数值匹配数据", results, counters)

	## 20. BUTCHER 招式表加载。
	var butcher_moves: Dictionary = b1.moves_cfg
	_check(butcher_moves.has("chop") and butcher_moves.has("getup_swing"), "M4 BUTCHER 招式表加载", results, counters)

	## 21. JASON 招式表加载。
	var jason_moves: Dictionary = b2.moves_cfg
	_check(jason_moves.has("pipe_swing") and jason_moves.has("grab_bash"), "M4 JASON 招式表加载", results, counters)

	## 22. JASON 半血阈值配置。
	var jason_ai: Dictionary = b2.ai_cfg
	_check(jason_ai.has("phase_2_hp_percent") and int(jason_ai.get("phase_2_hp_percent")) == 50, "M4 JASON 半血阈值 50%", results, counters)

	## 23. BUTCHER 受击掉血。
	var hp_before: int = b1.hp
	b1.take_damage(30, 1, 1.0, 1001)
	_check(b1.hp < hp_before, "M4 BUTCHER 受击掉血", results, counters)

	## 24. BUTCHER 击败演出触发。
	b1.hp = 1
	b1.take_damage(999, 1, 1.0, 1002)
	_check(b1._defeat_started, "M4 BUTCHER 击败演出触发", results, counters)

	## 25. BUTCHER 击败演出终结。
	b1.finish_defeat()
	b1._tick_defeat()
	_check(b1.is_dead, "M4 BUTCHER 击败演出终结", results, counters)
	b1.queue_free()

	## 26. 蜂窝拾取携带。
	props.clear_all()
	player_manager.setup(3, -3.0)
	player_manager.join_player(0, "hero_01")
	var p0: M2Player = player_manager.players[0]
	p0.global_position = Vector3(4.0, 0.0, 0.0)
	## 手动生成蜂窝。
	props.spawn_prop("honeycomb", 4.0)
	props.check_pickups(player_manager)
	_check(props.player_carries_honeycomb(p0), "M4 蜂窝拾取携带", results, counters)

	## 27. 蜂窝替换计数。
	props.spawn_prop("honeycomb", 4.0)
	props.check_pickups(player_manager)
	var rc: int = int(props.replace_count.get(p0, 0))
	_check(rc == 1, "M4 蜂窝替换计数 +1", results, counters)

	## 28. 蜂窝两次替换后自动释放。
	props.spawn_prop("honeycomb", 4.0)
	props.check_pickups(player_manager)
	_check(not props.player_carries_honeycomb(p0), "M4 蜂窝两次替换后自动释放", results, counters)

	## 29. 铁球召唤。
	props.spawn_iron_ball(3.0)
	_check(props.iron_balls.size() == 1, "M4 铁球召唤", results, counters)

	## 30. 铁球落地结算。
	var ball: Dictionary = props.iron_balls[0]
	ball.timer = 1
	props.iron_balls[0] = ball
	props.tick(0.016)
	_check(props.iron_balls.is_empty(), "M4 铁球落地结算移除", results, counters)

	## 31. 鸡群生成。
	props.spawn_chickens(3, 0.0, "ambient")
	_check(props.chickens.size() == 3, "M4 鸡群生成", results, counters)

	## 32. 可击碎物件击碎计分。
	props.clear_all()
	score.reset()
	props.spawn_prop("barrel", 2.0)
	## 找到刚生成的 barrel 记录。
	var barrel_rec: Dictionary = {}
	for rec in props.prop_records:
		if rec.type == "barrel":
			barrel_rec = rec
			break
	barrel_rec.hp = 1
	var hb := Rect2(2.0 - 0.3, -0.3, 0.6, 0.6)
	props.apply_attack_to_breakables(hb, p0)
	_check(score.score > 0, "M4 可击碎物件击碎计分", results, counters)

	## 33. 食物拾取回血。
	props.setup(self, "stage_01")
	p0.hp = 10
	props.spawn_prop("food", 1.0)
	p0.global_position = Vector3(1.0, 0.0, 0.0)
	props.check_pickups(player_manager)
	_check(p0.hp > 10, "M4 食物拾取回血", results, counters)

	## 34. Boss 段进入生成 Boss。
	stage_runner.load_stage("stage_01")
	while not stage_runner.is_last_segment():
		stage_runner.advance_segment()
	_load_segment_waves()
	_check(boss != null and is_instance_valid(boss), "M4 Boss 段进入生成 Boss", results, counters)

	## 35. JASON 半血切换阶段 2。
	var b3: M4Boss = M4Boss.new()
	add_child(b3)
	b3.setup_boss("boss_02", 5.0, self)
	b3.hp = int(float(b3.max_hp) * 0.49)
	b3.tick(0.016, self)
	_check(b3.phase == 2, "M4 JASON 半血切换阶段 2", results, counters)

	## 36. JASON 铁球阶段召唤。
	b3.iron_ball_timer = 1
	b3.tick(0.016, self)
	_check(props.iron_balls.size() >= 1, "M4 JASON 铁球阶段召唤", results, counters)
	b3.queue_free()

	## 37. BUTCHER 卖血窗口触发。
	var b4: M4Boss = M4Boss.new()
	add_child(b4)
	b4.setup_boss("boss_01", 7.0, self)
	b4.global_position = Vector3(7.0, 0.0, 0.0)
	b4.vx = 1.0
	b4.on_wall_hit()
	_check(b4.sell_blood_window > 0, "M4 BUTCHER 卖血窗口触发", results, counters)
	b4.queue_free()

	## 38. Boss 血条 HUD 显示。
	_check(boss_bar_label != null and boss_bar_progress != null, "M4 Boss 血条 HUD 齐备", results, counters)

	## 39. Boss 血条 HP 更新。
	stage_runner.load_stage("stage_01")
	while not stage_runner.is_last_segment():
		stage_runner.advance_segment()
	_spawn_boss()
	_update_boss_bar()
	_check(boss_bar_label.text == "BUTCHER", "M4 Boss 血条显示 Boss 名", results, counters)
	_check(boss_bar_progress.value > 0.0, "M4 Boss 血条 HP 更新", results, counters)

	## 清理测试 Boss。
	_clear_boss()
