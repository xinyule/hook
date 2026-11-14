## M8 主场景控制器。
## 继承 M7Arena，在 M2-M7 全部逻辑与表现层之上挂载 M8 平衡与完整度：
## 三档难度、隐藏宝藏统计、成就、练习模式、最高分。
## 复用 M2-M7 逻辑层与表现层不改，M8 只做平衡与完整度挂载。
## 所有数值来自 data/*.json，不硬编码。
extends M7Arena
class_name M8Arena

## ---- M8 扩展 ----
var balance8: M8Balance = null
var treasure8: M8Treasure = null
var systems8: M8Systems = null
## 练习模式假人（静止靶，player 为 null 时不执行 AI）。
var _dummy_actors: Array = []
## 玩家本关是否受过伤（无伤通关成就判定）。
var _player_took_damage: bool = false

## ---- 构建 ----

## 初始化。
func _ready() -> void:
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	selftest = user_args.has("--selftest") or OS.get_cmdline_args().has("--selftest")
	M2Data.logic_only = selftest
	M3Data.logic_only = selftest
	M4Data.logic_only = selftest
	M5Data.logic_only = selftest
	M6Data.logic_only = selftest
	M7Data.logic_only = selftest
	M8Data.logic_only = selftest
	_ensure_input_actions()
	_build_world()
	_build_systems()
	if selftest:
		run_selftest()
	else:
		_start_game()

## 构建世界（M2-M7 世界与场景，M8 无额外视觉节点）。
func _build_world() -> void:
	super._build_world()

## 构建系统（M2-M7 系统 + M8 各管理器）。
func _build_systems() -> void:
	super._build_systems()
	balance8 = M8Balance.new()
	add_child(balance8)
	treasure8 = M8Treasure.new()
	add_child(treasure8)
	systems8 = M8Systems.new()
	add_child(systems8)

## 加载指定索引的关卡（M8 扩展：应用难度 TIME / 飞鹰倍率 + 宝藏登记）。
func _load_stage(index: int) -> void:
	super._load_stage(index)
	var sid: String = stage_runner.stage_data.get("id", "")
	## 应用难度 TIME 初值与飞鹰扣血倍率。
	if balance8 != null:
		balance8.apply_time(timer)
		balance8.apply_eagle(timer)
	## 登记隐藏宝藏。
	if treasure8 != null:
		treasure8.setup(sid, stage_runner.stage_data)
	## 重置无伤标志与假人。
	_player_took_damage = false
	_clear_dummies()

## 关卡完成：通知成就与最高分（M8 扩展）。
func _on_stage_complete() -> void:
	## 记录通关信息（在 super 推进前）。
	var hero_id := _current_hero_id()
	var stage_id := _current_stage_id()
	var final_score := int(score.score)
	## M3 框架推进（换关 / 回环）。
	super._on_stage_complete()
	## 通知成就与最高分。
	if systems8 != null:
		systems8.notify_hero_clear(hero_id)
		if not _player_took_damage:
			systems8.notify_no_damage_clear()
		systems8.update(hero_id, stage_id, final_score)

## 当前主角色 id。
func _current_hero_id() -> String:
	var all: Array = player_manager.all_players()
	if all.is_empty():
		return "hero_01"
	var p: M2Player = all[0]
	var aid: String = p.actor_id
	return aid if not aid.is_empty() else "hero_01"

## 当前关卡 id。
func _current_stage_id() -> String:
	return str(stage_runner.stage_data.get("id", "stage_01"))

## ---- 模拟帧 ----

## 模拟一帧（M8 扩展：练习假人、难度缩放、宝藏扫描、无伤检测）。
func simulate_tick(dt: float) -> void:
	## 练习模式时间减速。
	var scale: float = 1.0
	if systems8 != null:
		scale = systems8.time_scale()
	## 生成练习假人（如需）。
	_ensure_dummy()
	## M2-M7 逻辑（含难度缩放前的原始推进）。
	super.simulate_tick(dt * scale)
	## M8 难度缩放扫描（在场敌人补缩放一次）。
	if balance8 != null:
		for e in enemies:
			if e is M2Actor:
				balance8.apply_to_enemy(e)
	## M8 宝藏收集扫描。
	if treasure8 != null and systems8 != null:
		var gained := treasure8.scan(stage_runner, score)
		if gained > 0:
			systems8.notify_treasure(treasure8.discovered_count)
	## M8 无伤检测。
	_check_no_damage()

## 检测玩家是否受伤（任一玩家 HP 低于上限则标记）。
func _check_no_damage() -> void:
	if _player_took_damage:
		return
	for p in player_manager.all_players():
		if p.hp < p.max_hp:
			_player_took_damage = true
			return

## 确保练习假人存在（仅练习模式且配置允许时生成一个静止靶）。
func _ensure_dummy() -> void:
	if systems8 == null or not systems8.practice_spawn_dummy():
		return
	if not _dummy_actors.is_empty():
		return
	var e := M2Enemy.new()
	e.name = "PracticeDummy"
	add_child(e)
	e.setup_enemy("grunt", 0.0, 0)
	e.player = null
	e.hp = systems8.practice_dummy_hp()
	e.max_hp = e.hp
	enemies.append(e)
	_dummy_actors.append(e)

## 清空练习假人。
func _clear_dummies() -> void:
	for e in _dummy_actors:
		if is_instance_valid(e):
			e.queue_free()
	_dummy_actors.clear()

## ---- Headless 自测 ----

## 运行 M3 + M5 + M6 + M7 + M8 自测。
func run_selftest() -> void:
	var results: Array = []
	var counters := {"passed": 0, "failed": 0}
	## M3 框架层 42 项 + M5 扩展层 60 项 + M6 扩展层 50 项 + M7 扩展层 21 项 + M8 扩展层断言。
	_m3_selftest_checks(results, counters)
	_m5_selftest_checks(results, counters)
	_m6_selftest_checks(results, counters)
	_m7_selftest_checks(results, counters)
	_m8_selftest_checks(results, counters)
	_selftest_output(results, counters, "M8")

## M8 扩展层自测断言。
func _m8_selftest_checks(results: Array, counters: Dictionary) -> void:
	## 1. balance_m8 数据加载。
	var bal := M8Data.balance()
	_check(not bal.is_empty() and bal.has("difficulties") and bal.has("character_tuning"), "M8 balance_m8 数据加载", results, counters)

	## 2. 难度三档读取。
	var diffs: Dictionary = M8Data.difficulties()
	_check(diffs.has("easy") and diffs.has("normal") and diffs.has("hard"), "M8 难度三档读取（easy/normal/hard）", results, counters)

	## 3. 难度切换有效。
	_check(balance8.set_difficulty("hard"), "M8 难度切换 hard 有效", results, counters)

	## 4. 难度切换无效档拒绝。
	_check(not balance8.set_difficulty("nonexistent"), "M8 难度切换无效档拒绝", results, counters)

	## 5. easy 敌人 HP 倍率。
	balance8.set_difficulty("easy")
	_check(absf(balance8.enemy_hp_mult() - 0.8) < 0.001, "M8 easy 敌人 HP 倍率 0.8", results, counters)

	## 6. hard 敌人 HP 倍率。
	balance8.set_difficulty("hard")
	_check(absf(balance8.enemy_hp_mult() - 1.3) < 0.001, "M8 hard 敌人 HP 倍率 1.3", results, counters)

	## 7. 敌人 HP 缩放应用。
	var e := M2Enemy.new()
	add_child(e)
	e.setup_enemy("grunt", 1.0, 0)
	var orig_hp := e.max_hp
	balance8.set_difficulty("hard")
	var applied := balance8.apply_to_enemy(e)
	_check(applied and e.max_hp > orig_hp, "M8 敌人 HP 缩放应用（hard 上调）", results, counters)

	## 8. 敌人 HP 缩放幂等（meta 防重复）。
	var hp_after_first := e.max_hp
	var applied_twice := balance8.apply_to_enemy(e)
	_check(not applied_twice and e.max_hp == hp_after_first, "M8 敌人 HP 缩放幂等（meta 防重复）", results, counters)

	## 9. TIME 初值覆盖（easy）。
	balance8.set_difficulty("easy")
	balance8.apply_time(timer)
	_check(absf(timer.initial_time - 120.0) < 0.001, "M8 TIME 初值覆盖 easy=120", results, counters)

	## 10. TIME 初值覆盖（hard）。
	balance8.set_difficulty("hard")
	balance8.apply_time(timer)
	_check(absf(timer.initial_time - 75.0) < 0.001, "M8 TIME 初值覆盖 hard=75", results, counters)

	## 11. 飞鹰扣血倍率（easy）。
	balance8.set_difficulty("easy")
	balance8.apply_eagle(timer)
	_check(absf(timer.eagle_hp_cost_percent - 5.0 * 0.7) < 0.01, "M8 飞鹰扣血倍率 easy=3.5", results, counters)

	## 12. 飞鹰扣血倍率（hard）。
	balance8.set_difficulty("hard")
	balance8.apply_eagle(timer)
	_check(absf(timer.eagle_hp_cost_percent - 5.0 * 1.3) < 0.01, "M8 飞鹰扣血倍率 hard=6.5", results, counters)

	## 13. 飞鹰扣血不累积（多次 apply 保持倍率）。
	balance8.apply_eagle(timer)
	_check(absf(timer.eagle_hp_cost_percent - 5.0 * 1.3) < 0.01, "M8 飞鹰扣血不累积（多次 apply）", results, counters)

	## 14. 辅助开关读取。
	_check(M8Data.assist("friendly_fire_warning").get("enabled", false) == true, "M8 辅助开关读取（友伤警示）", results, counters)

	## 15. 角色调优读取。
	var tuning: Dictionary = M8Data.tuning("hero_01")
	_check(tuning.has("damage_mult") and tuning.has("downed_hits"), "M8 角色调优读取 hero_01", results, counters)

	## 16. RUFIO 补强条目。
	var rufio: Dictionary = M8Data.rufio_buff()
	_check(rufio.has("target") and rufio.has("speed_mult") and str(rufio.get("target")) == "hero_04", "M8 RUFIO 补强条目", results, counters)

	## 17. 隐藏宝藏登记。
	stage_runner.load_stage("stage_01")
	treasure8.setup("stage_01", stage_runner.stage_data)
	_check(not treasure8.total_points.is_empty(), "M8 隐藏宝藏登记 stage_01", results, counters)

	## 18. 隐藏宝藏去重（同 id 不重复登记）。
	var count_before := treasure8.total_points.size()
	## 重复 setup 同关卡应去重。
	treasure8.setup("stage_01", stage_runner.stage_data)
	_check(treasure8.total_points.size() == count_before, "M8 隐藏宝藏去重", results, counters)

	## 19. 隐藏宝藏统计（已收集）。
	score.reset()
	score.add_hidden_point("h1a_1")
	var gained := treasure8.scan(stage_runner, score)
	_check(gained >= 1 and treasure8.discovered_count >= 1, "M8 隐藏宝藏统计已收集", results, counters)

	## 20. 全收集判定。
	## 将全部点标记为已收集。
	for pt in treasure8.total_points:
		score.add_hidden_point(str(pt.get("id", "")))
	treasure8.scan(stage_runner, score)
	_check(treasure8.all_collected(), "M8 全收集判定", results, counters)

	## 21. 贪分规则读取。
	var sc: Dictionary = M8Data.scoring()
	_check(sc.has("combo_cap") and sc.has("no_damage_bonus") and sc.get("pk_mode", {}).has("winner_bonus"), "M8 贪分规则读取", results, counters)

	## 22. 成就定义加载。
	var achs: Array = M8Data.achievements()
	_check(achs.size() >= 5, "M8 成就定义加载（>=5 项）", results, counters)

	## 23. 成就击杀触发。
	systems8.reset_achievements()
	for i in 10:
		systems8.notify_kill(1)
	_check(systems8.is_unlocked("ach_first_blood"), "M8 成就击杀触发", results, counters)

	## 24. 成就连击触发。
	systems8.reset_achievements()
	systems8.notify_combo(30)
	_check(systems8.is_unlocked("ach_combo_master"), "M8 成就连击触发", results, counters)

	## 25. 成就去重（重复通知不重复解锁）。
	var cnt_before := systems8.unlocked_count()
	systems8.notify_combo(50)
	_check(systems8.unlocked_count() == cnt_before, "M8 成就去重（重复通知）", results, counters)

	## 26. 练习模式切换。
	var p_before := systems8.practice_active
	systems8.toggle_practice()
	_check(systems8.practice_active != p_before, "M8 练习模式切换", results, counters)

	## 27. 练习模式时间缩放。
	systems8.practice_active = true
	_check(absf(systems8.time_scale() - 0.5) < 0.001, "M8 练习模式时间缩放 0.5", results, counters)

	## 28. 最高分更新。
	systems8.highscores.clear()
	var updated := systems8.update("hero_01", "stage_01", 5000)
	_check(updated and systems8.get_highscore("hero_01", "stage_01") == 5000, "M8 最高分更新", results, counters)

	## 29. 最高分查询（低于记录不更新）。
	var not_updated := systems8.update("hero_01", "stage_01", 1000)
	_check(not not_updated and systems8.get_highscore("hero_01", "stage_01") == 5000, "M8 最高分查询（低于不更新）", results, counters)

	## 30. 最高分持久化路径。
	var path := str(M8Data.highscore_meta().get("persist_path", ""))
	_check(path.begins_with("user://hook3d_highscore"), "M8 最高分持久化路径", results, counters)

	## 31. M8 系统挂载。
	_check(balance8 != null and treasure8 != null and systems8 != null, "M8 系统挂载（balance/treasure/systems）", results, counters)

	## 32. 难度应用与复位（回到 normal）。
	balance8.set_difficulty("normal")
	_check(absf(balance8.enemy_hp_mult() - 1.0) < 0.001 and absf(balance8.score_mult() - 1.0) < 0.001, "M8 难度应用与复位 normal", results, counters)

	## 清理测试敌人。
	if is_instance_valid(e):
		e.queue_free()
	_clear_dummies()
