## M5 主场景控制器。
## 继承 M3Arena，扩展 Stage 3-4 的 Boss 战（假 Hook / DAMON）、机关道具
## （彩绘大罐 / 长矛 / 冰柱 / 企鹅）与场景构建。
## 复用 M3 框架层（StageRunner / WaveDirector / PlayerManager / Timer /
## Score / Hud / Loop）与 M2 战斗核心，M5 只加场景、Boss、机关与自测。
## 所有数值来自 data/*.json，不硬编码。
extends M3Arena
class_name M5Arena

## ---- M5 扩展 ----
var props: M5Props = null
var stage_scene: M5StageScene = null
var boss: M5Boss = null
var fake_hooks: Array = []
var boss_bar_label: Label = null
var boss_bar_progress: ProgressBar = null
var boss_bar_layer: CanvasLayer = null

## 气功波飞行道具：{x, dir, range, damage, kb, traveled}
var ki_waves: Array = []
## Boss 击败标志（延迟到 tick 末尾处理，避免信号重入）。
var _boss_defeated: bool = false
## 假 Hook 段清空标志。
var _fake_hook_cleared: bool = false

## ---- 构建 ----

## 初始化。
func _ready() -> void:
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	selftest = user_args.has("--selftest") or OS.get_cmdline_args().has("--selftest")
	M2Data.logic_only = selftest
	M3Data.logic_only = selftest
	M4Data.logic_only = selftest
	M5Data.logic_only = selftest
	_ensure_input_actions()
	_build_world()
	_build_systems()
	if selftest:
		run_selftest()
	else:
		_start_game()

## 构建世界灰盒与 M5 场景。
func _build_world() -> void:
	## 调用 M3 的地面/墙/相机构建。
	super._build_world()
	## M5 场景构建器。
	stage_scene = M5StageScene.new()
	add_child(stage_scene)

## 构建 M3 系统 + M5 扩展。
func _build_systems() -> void:
	## 先构建 M3 系统。
	super._build_systems()
	## M5 机关道具管理器。
	props = M5Props.new()
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

## 加载指定索引的关卡（M5 扩展：构建场景 + 初始化道具）。
func _load_stage(index: int) -> void:
	_loading_stage = true
	var order: Array = M3Data.stage_order()
	if index >= order.size():
		index = 0
	current_stage_index = index
	var sid: String = order[index]
	stage_runner.load_stage(sid)
	## 构建 M5 场景与光照。
	if stage_scene != null:
		stage_scene.build(sid, stage_runner.stage_data)
	## 初始化机关道具。
	if props != null:
		props.setup(self, sid)
	## 清空旧敌人与旧 Boss。
	_clear_enemies()
	_clear_boss()
	fake_hooks.clear()
	_fake_hook_cleared = false
	ki_waves.clear()
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

## 生成当前关卡的 Boss（假 Hook 或 DAMON）。
func _spawn_boss() -> void:
	var stage_data: Dictionary = stage_runner.stage_data
	var boss_data: Dictionary = stage_data.get("boss", {})
	var boss_id: String = boss_data.get("id", "boss_04")
	var sx: float = _box() * 0.5
	_clear_boss()
	fake_hooks.clear()
	if M5Data.is_fake_boss(boss_id):
		## 假 Hook：按人数生成多个，无血条。
		var count: int = M5Data.fake_hook_count(player_manager.active_players().size())
		for i in count:
			var fh := M5Boss.new()
			add_child(fh)
			fh.setup_boss(boss_id, sx + float(i) * 1.2, self)
			var target: Array = player_manager.active_players()
			if not target.is_empty():
				fh.player = target[0]
			enemies.append(fh)
			fake_hooks.append(fh)
	else:
		## DAMON：真 Boss，有血条。
		boss = M5Boss.new()
		add_child(boss)
		boss.setup_boss(boss_id, sx, self)
		var target: Array = player_manager.active_players()
		if not target.is_empty():
			boss.player = target[0]
		enemies.append(boss)
		boss.defeat_sequence_finished.connect(_on_boss_defeated)

## 清空 Boss 与假 Hook。
func _clear_boss() -> void:
	if boss != null and is_instance_valid(boss):
		boss.queue_free()
	boss = null
	for fh in fake_hooks:
		if is_instance_valid(fh):
			fh.queue_free()
	fake_hooks.clear()

## Boss 击败信号回调（延迟处理）。
func _on_boss_defeated() -> void:
	_boss_defeated = true

## 段落清空回调：M5 复用 M3 逻辑，但 Boss 段由 Boss 击败 / 假 Hook 清空驱动。
func _on_segment_cleared() -> void:
	if _loading_stage:
		return
	## Boss 段不通过波次清空推进，由 Boss 击败 / 假 Hook 清空驱动。
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

## ---- 兼容接口（供 m5_boss 调用）----

## 召唤气功波（由 DAMON 调用，记录飞行道具）。
func spawn_ki_wave(x: float, dir: int, range: float, damage: int, kb: float) -> void:
	ki_waves.append({"x": x, "dir": dir, "range": range, "damage": damage, "kb": kb, "traveled": 0.0})

## 召唤冰柱当墙（由 DAMON 调用，委托给 props）。
func spawn_ice_pillar(x: float) -> void:
	if props != null:
		props.spawn_prop("ice_pillar", x)

## ---- 模拟帧 ----

## 模拟一帧（M5 扩展：道具 tick、拾取、可击碎、冰柱反跳、气功波、Boss 血条）。
func simulate_tick(dt: float) -> void:
	## M3 基础逻辑。
	super.simulate_tick(dt)
	## M5 道具推进。
	if props != null:
		props.tick(dt)
	## 拾取检测。
	if props != null:
		props.check_pickups(player_manager)
	## 可击碎物件受击检测。
	_check_breakable_hits()
	## 冰柱反跳检测。
	_check_ice_bounces()
	## 气功波推进与命中。
	_tick_ki_waves(dt)
	## 假 Hook 段清空检测。
	_check_fake_hook_cleared()
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
	_clear_boss()
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

## 冰柱反跳检测：玩家落在冰柱顶部触发反跳。
func _check_ice_bounces() -> void:
	if props == null:
		return
	for p in player_manager.all_players():
		if p.is_dead or not is_instance_valid(p):
			continue
		props.check_ice_bounce(p)

## 气功波推进：移动、命中玩家、超距移除。
func _tick_ki_waves(dt: float) -> void:
	for i in range(ki_waves.size() - 1, -1, -1):
		var kw: Dictionary = ki_waves[i]
		var speed: float = float(M5Data.boss("boss_04").get("ai", {}).get("ki_wave_speed_mps", 8.0))
		kw.x += kw.dir * speed * dt
		kw.traveled += speed * dt
		## 命中玩家。
		var pm: M3PlayerManager = player_manager
		if pm != null:
			for p in pm.active_players():
				if abs(p.global_position.x - kw.x) <= 0.6:
					var dir: int = 1 if kw.x >= p.global_position.x else -1
					p.take_damage(int(kw.damage), dir, float(kw.kb), 980 + i)
					break
		## 超距移除。
		if kw.traveled >= kw.range:
			ki_waves.remove_at(i)

## 假 Hook 段清空检测：所有假 Hook 消失后推进段落。
func _check_fake_hook_cleared() -> void:
	if _fake_hook_cleared or not stage_runner.is_boss_segment():
		return
	var boss_data: Dictionary = stage_runner.stage_data.get("boss", {})
	if not M5Data.is_fake_boss(boss_data.get("id", "")):
		return
	## 检查是否还有存活假 Hook。
	var alive := 0
	for fh in fake_hooks:
		if is_instance_valid(fh) and not fh.is_dead:
			alive += 1
	if alive == 0 and not _fake_hook_cleared:
		_fake_hook_cleared = true
		_on_segment_cleared()

## 更新 Boss 血条显示。Boss 在场且未死亡时显示（仅真 Boss）。
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

## ---- Headless 自测 ----

## 运行 M3 + M5 自测。
func run_selftest() -> void:
	var results: Array = []
	var counters := {"passed": 0, "failed": 0}
	## M3 框架层 42 项。
	_m3_selftest_checks(results, counters)
	## M5 扩展层断言。
	_m5_selftest_checks(results, counters)
	_selftest_output(results, counters, "M5")

## M5 扩展层自测断言。
func _m5_selftest_checks(results: Array, counters: Dictionary) -> void:
	## 1. stage_03 波次数据加载。
	stage_runner.load_stage("stage_03")
	var s3_segs: Array = stage_runner.stage_data.get("segments", [])
	_check(s3_segs.size() >= 3, "M5 stage_03 段落数 >= 3", results, counters)

	## 2. stage_03 波次数据非空。
	var s3_waves: Array = s3_segs[0].get("waves", [])
	_check(not s3_waves.is_empty(), "M5 stage_03 3-A 波次非空", results, counters)

	## 3. stage_04 波次数据加载。
	stage_runner.load_stage("stage_04")
	var s4_segs: Array = stage_runner.stage_data.get("segments", [])
	_check(s4_segs.size() >= 3, "M5 stage_04 段落数 >= 3", results, counters)

	## 4. stage_04 波次数据非空。
	var s4_waves: Array = s4_segs[0].get("waves", [])
	_check(not s4_waves.is_empty(), "M5 stage_04 4-A 波次非空", results, counters)

	## 5. 假 Hook Boss 数据加载。
	var hook_cfg: Dictionary = M5Data.boss("boss_03")
	_check(not hook_cfg.is_empty() and hook_cfg.get("display_name") == "FAKE_HOOK", "M5 假 Hook Boss 数据加载", results, counters)

	## 6. DAMON Boss 数据加载。
	var damon_cfg: Dictionary = M5Data.boss("boss_04")
	_check(not damon_cfg.is_empty() and damon_cfg.get("display_name") == "DAMON", "M5 DAMON Boss 数据加载", results, counters)

	## 7. bosses_m5 数据加载。
	var bosses_cfg: Dictionary = M5Data.bosses_m5()
	_check(not bosses_cfg.is_empty(), "M5 bosses_m5 数据加载", results, counters)

	## 8. props_m5 数据加载。
	var props_cfg: Dictionary = M5Data.props_m5()
	_check(not props_cfg.is_empty(), "M5 props_m5 数据加载", results, counters)

	## 9. 假 Hook 配置读取。
	var fh_cfg: Dictionary = M5Data.fake_hook_cfg()
	_check(fh_cfg.has("throw_damage") and fh_cfg.has("throw_land_radius_m"), "M5 假 Hook 配置读取", results, counters)

	## 10. 彩绘大罐配置读取。
	var jar_cfg: Dictionary = M5Data.painted_jar_cfg()
	_check(jar_cfg.has("explode_radius_m") and jar_cfg.has("explode_damage"), "M5 彩绘大罐配置读取", results, counters)

	## 11. 长矛配置读取。
	var spear_cfg: Dictionary = M5Data.spear_cfg()
	_check(spear_cfg.has("throw_range_m") and spear_cfg.has("damage"), "M5 长矛配置读取", results, counters)

	## 12. 冰柱配置读取。
	var ice_cfg: Dictionary = M5Data.ice_pillar_cfg()
	_check(ice_cfg.has("standable") and ice_cfg.has("bounce_height_m"), "M5 冰柱配置读取", results, counters)

	## 13. 企鹅配置读取。
	var penguin_cfg: Dictionary = M5Data.penguin_cfg()
	_check(penguin_cfg.has("hidden_point_score") and penguin_cfg.has("score"), "M5 企鹅配置读取", results, counters)

	## 14. 冰面反跳配置读取。
	var ice_surf: Dictionary = M5Data.ice_surface_cfg()
	_check(ice_surf.has("bounce_on_land"), "M5 冰面反跳配置读取", results, counters)

	## 15. Boss 血条配置读取。
	var bar_cfg: Dictionary = M5Data.boss_bar_cfg()
	_check(bar_cfg.has("width_m") and bar_cfg.has("height_m"), "M5 Boss 血条配置读取", results, counters)

	## 16. 假 Hook 数量 1 人 = 2。
	_check(M5Data.fake_hook_count(1) == 2, "M5 假 Hook 1 人数量=2", results, counters)

	## 17. 假 Hook 数量 2 人 = 3。
	_check(M5Data.fake_hook_count(2) == 3, "M5 假 Hook 2 人数量=3", results, counters)

	## 18. 假 Hook 数量 4 人 = 3。
	_check(M5Data.fake_hook_count(4) == 3, "M5 假 Hook 4 人数量=3", results, counters)

	## 19. props 初始化 stage_03。
	props.setup(self, "stage_03")
	_check(not props.prop_records.is_empty(), "M5 props 初始化 stage_03 生成道具", results, counters)

	## 20. props 初始化 stage_04。
	props.setup(self, "stage_04")
	_check(not props.prop_records.is_empty(), "M5 props 初始化 stage_04 生成道具", results, counters)

	## 21. 假 Hook Boss 生成。
	var fh1: M5Boss = M5Boss.new()
	add_child(fh1)
	fh1.setup_boss("boss_03", 5.0, self)
	_check(fh1.hp > 0 and fh1.max_hp > 0, "M5 假 Hook Boss 生成", results, counters)

	## 22. DAMON Boss 生成。
	var dm1: M5Boss = M5Boss.new()
	add_child(dm1)
	dm1.setup_boss("boss_04", 5.0, self)
	_check(dm1.hp > 0 and dm1.max_hp > 0, "M5 DAMON Boss 生成", results, counters)

	## 23. 假 Hook HP 数值。
	_check(fh1.max_hp == int(hook_cfg.get("hp", 0)), "M5 假 Hook HP 数值匹配数据", results, counters)

	## 24. DAMON HP 数值。
	_check(dm1.max_hp == int(damon_cfg.get("hp", 0)), "M5 DAMON HP 数值匹配数据", results, counters)

	## 25. 假 Hook 招式表加载。
	var fh_moves: Dictionary = fh1.moves_cfg
	_check(fh_moves.has("slash"), "M5 假 Hook 招式表加载", results, counters)

	## 26. DAMON 招式表加载。
	var dm_moves: Dictionary = dm1.moves_cfg
	_check(dm_moves.has("kick") and dm_moves.has("ki_wave") and dm_moves.has("ice_pillar"), "M5 DAMON 招式表加载", results, counters)

	## 27. DAMON 影子预警配置。
	var dm_ai: Dictionary = dm1.ai_cfg
	_check(dm_ai.has("shadow_warning_frames"), "M5 DAMON 影子预警配置", results, counters)

	## 28. DAMON 半血阈值（无阶段切换，验证 AI 参数）。
	_check(dm_ai.has("ki_wave_interval_frames") and dm_ai.has("ice_pillar_interval_frames"), "M5 DAMON 气功波/冰柱定时配置", results, counters)

	## 29. 假 Hook 受击掉血。
	var fh_hp_before: int = fh1.hp
	fh1.take_damage(30, 1, 1.0, 2001)
	_check(fh1.hp < fh_hp_before, "M5 假 Hook 受击掉血", results, counters)

	## 30. 假 Hook 击败消失演出触发。
	fh1.hp = 1
	fh1.take_damage(999, 1, 1.0, 2002)
	_check(fh1._defeat_started, "M5 假 Hook 击败消失演出触发", results, counters)

	## 31. 假 Hook 击败演出终结。
	fh1.finish_defeat()
	fh1._tick_defeat(self)
	_check(fh1.is_dead, "M5 假 Hook 击败演出终结", results, counters)
	fh1.queue_free()

	## 32. DAMON 受击掉血。
	var dm_hp_before: int = dm1.hp
	dm1.take_damage(40, 1, 1.0, 2003)
	_check(dm1.hp < dm_hp_before, "M5 DAMON 受击掉血", results, counters)

	## 33. DAMON 击败演出触发。
	dm1.hp = 1
	dm1.take_damage(999, 1, 1.0, 2004)
	_check(dm1._defeat_started, "M5 DAMON 击败演出触发", results, counters)

	## 34. DAMON 击败演出终结。
	dm1.finish_defeat()
	dm1._tick_defeat(self)
	_check(dm1.is_dead, "M5 DAMON 击败演出终结", results, counters)
	dm1.queue_free()

	## 35. DAMON 影子预警触发。
	var dm2: M5Boss = M5Boss.new()
	add_child(dm2)
	dm2.setup_boss("boss_04", 5.0, self)
	dm2.player = player
	dm2._begin_move("kick")
	_check(dm2.shadow_warning > 0, "M5 DAMON 影子预警触发", results, counters)

	## 36. DAMON 气功波发射。
	ki_waves.clear()
	dm2.ki_wave_timer = 1
	dm2._ai_tick(0.016, self)
	_check(ki_waves.size() >= 1, "M5 DAMON 气功波发射", results, counters)

	## 37. DAMON 冰柱召唤。
	props.clear_all()
	var pillars_before: int = props.ice_pillars.size()
	dm2.ice_pillar_timer = 1
	dm2._ai_tick(0.016, self)
	_check(props.ice_pillars.size() > pillars_before, "M5 DAMON 冰柱召唤", results, counters)
	dm2.queue_free()

	## 38. 气功波命中玩家。
	props.clear_all()
	ki_waves.clear()
	player_manager.setup(3, -3.0)
	player_manager.join_player(0, "hero_01")
	var p0: M2Player = player_manager.players[0]
	p0.global_position = Vector3(3.0, 0.0, 0.0)
	p0.invincible_frames = 0
	ki_waves.append({"x": 2.5, "dir": 1, "range": 6.0, "damage": 14, "kb": 1.5, "traveled": 0.0})
	_tick_ki_waves(0.016)
	_check(p0.hp < p0.max_hp, "M5 气功波命中玩家扣血", results, counters)

	## 39. 气功波超距移除。
	ki_waves.clear()
	ki_waves.append({"x": 0.0, "dir": 1, "range": 1.0, "damage": 14, "kb": 1.5, "traveled": 0.0})
	_tick_ki_waves(0.5)
	_check(ki_waves.is_empty(), "M5 气功波超距移除", results, counters)

	## 40. 彩绘大罐生成与击碎爆炸。
	props.clear_all()
	score.reset()
	props.spawn_prop("painted_jar", 2.0)
	var jar_rec: Dictionary = {}
	for rec in props.prop_records:
		if rec.type == "painted_jar":
			jar_rec = rec
			break
	jar_rec.hp = 1
	var hb := Rect2(2.0 - 0.3, -0.3, 0.6, 0.6)
	props.apply_attack_to_breakables(hb, p0)
	_check(score.score > 0, "M5 彩绘大罐击碎爆炸计分", results, counters)

	## 41. 彩绘大罐爆炸伤害敌人。
	props.clear_all()
	var dm3: M5Boss = M5Boss.new()
	add_child(dm3)
	dm3.setup_boss("boss_04", 2.0, self)
	enemies.append(dm3)
	props.spawn_prop("painted_jar", 2.0)
	var jar_rec2: Dictionary = {}
	for rec in props.prop_records:
		if rec.type == "painted_jar":
			jar_rec2 = rec
			break
	jar_rec2.hp = 1
	props.apply_attack_to_breakables(Rect2(2.0 - 0.3, -0.3, 0.6, 0.6), p0)
	_check(dm3.hp < dm3.max_hp, "M5 彩绘大罐爆炸伤害敌人", results, counters)
	dm3.queue_free()

	## 42. 长矛拾取携带。
	props.clear_all()
	props.spawn_prop("spear", 1.0)
	p0.global_position = Vector3(1.0, 0.0, 0.0)
	props.check_pickups(player_manager)
	_check(props.player_carries_spear(p0), "M5 长矛拾取携带", results, counters)

	## 43. 长矛投掷命中敌人。
	props.consume_spear(p0)
	var dm4: M5Boss = M5Boss.new()
	add_child(dm4)
	dm4.setup_boss("boss_04", 3.0, self)
	enemies.append(dm4)
	props.resolve_spear_hit(3.0, 8, 1.5)
	_check(dm4.hp < dm4.max_hp, "M5 长矛投掷命中敌人", results, counters)
	dm4.queue_free()

	## 44. 冰柱生成与可踩。
	props.clear_all()
	props.spawn_prop("ice_pillar", 2.0)
	_check(props.ice_pillars.size() == 1, "M5 冰柱生成登记", results, counters)

	## 45. 冰柱踩踏反跳。
	p0.global_position = Vector3(2.0, 1.2, 0.0)
	p0.vy = 0.0
	p0.on_floor = true
	var bounced := props.check_ice_bounce(p0)
	_check(bounced and p0.vy > 0, "M5 冰柱踩踏反跳", results, counters)

	## 46. 冰柱击碎计分。
	props.clear_all()
	score.reset()
	props.spawn_prop("ice_pillar", 2.0)
	var ice_rec: Dictionary = {}
	for rec in props.prop_records:
		if rec.type == "ice_pillar":
			ice_rec = rec
			break
	ice_rec.hp = 1
	props.apply_attack_to_breakables(Rect2(2.0 - 0.3, -0.3, 0.6, 0.6), p0)
	_check(score.score > 0, "M5 冰柱击碎计分", results, counters)

	## 47. 企鹅生成与彩蛋隐藏点。
	props.clear_all()
	score.reset()
	props.spawn_penguin(1.0, "penguin_test")
	_check(props.penguins.size() == 1, "M5 企鹅生成", results, counters)
	var penguin_rec: Dictionary = {}
	for rec in props.prop_records:
		if rec.type == "penguin":
			penguin_rec = rec
			break
	if penguin_rec.is_empty():
		penguin_rec = {"node": props.penguins[0].node, "type": "penguin", "x": 1.0}
	penguin_rec.hp = 1
	props.apply_attack_to_breakables(Rect2(1.0 - 0.3, -0.3, 0.6, 0.6), p0)
	_check(score.score > 0, "M5 企鹅彩蛋计分", results, counters)

	## 48. Boss 段进入生成 DAMON。
	stage_runner.load_stage("stage_04")
	while not stage_runner.is_last_segment():
		stage_runner.advance_segment()
	_load_segment_waves()
	_check(boss != null and is_instance_valid(boss), "M5 Boss 段进入生成 DAMON", results, counters)

	## 49. Boss 段进入生成假 Hook（stage_03）。
	_clear_boss()
	stage_runner.load_stage("stage_03")
	while not stage_runner.is_last_segment():
		stage_runner.advance_segment()
	_load_segment_waves()
	_check(not fake_hooks.is_empty(), "M5 Boss 段进入生成假 Hook", results, counters)

	## 50. 假 Hook 数量随人数（1 人）。
	_clear_boss()
	player_manager.setup(3, -3.0)
	player_manager.join_player(0, "hero_01")
	stage_runner.load_stage("stage_03")
	while not stage_runner.is_last_segment():
		stage_runner.advance_segment()
	_load_segment_waves()
	_check(fake_hooks.size() == 2, "M5 假 Hook 1 人生成 2 个", results, counters)

	## 51. 假 Hook 数量随人数（2 人）。
	_clear_boss()
	player_manager.join_player(1, "hero_02")
	stage_runner.load_stage("stage_03")
	while not stage_runner.is_last_segment():
		stage_runner.advance_segment()
	_load_segment_waves()
	_check(fake_hooks.size() == 3, "M5 假 Hook 2 人生成 3 个", results, counters)

	## 52. Boss 血条 HUD 齐备。
	_check(boss_bar_label != null and boss_bar_progress != null, "M5 Boss 血条 HUD 齐备", results, counters)

	## 53. Boss 血条显示 DAMON 名。
	_clear_boss()
	stage_runner.load_stage("stage_04")
	while not stage_runner.is_last_segment():
		stage_runner.advance_segment()
	_spawn_boss()
	_update_boss_bar()
	_check(boss_bar_label.text == "DAMON", "M5 Boss 血条显示 DAMON 名", results, counters)
	_check(boss_bar_progress.value > 0.0, "M5 Boss 血条 HP 更新", results, counters)
	_clear_boss()

	## 54. 假 Hook 无血条（boss 为空）。
	_clear_boss()
	stage_runner.load_stage("stage_03")
	while not stage_runner.is_last_segment():
		stage_runner.advance_segment()
	_spawn_boss()
	_update_boss_bar()
	_check(boss == null and boss_bar_label.text == "", "M5 假 Hook 段无血条", results, counters)

	## 55. 假 Hook 互投伤害。
	_clear_boss()
	props.clear_all()
	var fh_a: M5Boss = M5Boss.new()
	add_child(fh_a)
	fh_a.setup_boss("boss_03", 2.0, self)
	enemies.append(fh_a)
	var fh_b: M5Boss = M5Boss.new()
	add_child(fh_b)
	fh_b.setup_boss("boss_03", 2.5, self)
	enemies.append(fh_b)
	var fh_b_hp: int = fh_b.hp
	fh_a.start_throw(1)
	fh_a.global_position = Vector3(2.0, 0.0, 0.0)
	fh_a.on_floor = true
	fh_a._check_throw_land(self)
	_check(fh_b.hp < fh_b_hp, "M5 假 Hook 互投伤害", results, counters)
	fh_a.queue_free()
	fh_b.queue_free()

	## 56. stage_03 隐藏点配置。
	stage_runner.load_stage("stage_03")
	var s3_hp: Array = stage_runner.stage_data.get("segments", [])[0].get("hidden_points", [])
	_check(not s3_hp.is_empty(), "M5 stage_03 隐藏点配置", results, counters)

	## 57. stage_04 隐藏点配置。
	stage_runner.load_stage("stage_04")
	var s4_hp: Array = stage_runner.stage_data.get("segments", [])[0].get("hidden_points", [])
	_check(not s4_hp.is_empty(), "M5 stage_04 隐藏点配置", results, counters)

	## 58. 数据驱动：bosses_m5 招式帧表完整。
	_check(bosses_cfg.get("bosses", {}).has("boss_03") and bosses_cfg.get("bosses", {}).has("boss_04"), "M5 bosses_m5 双 Boss 齐备", results, counters)

	## 清理测试 Boss。
	_clear_boss()
	props.clear_all()
