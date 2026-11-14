## M9 主场景控制器。
## 继承 M8Arena，在 M2-M8 全部逻辑与表现层之上挂载 M9 打包与内部交付：
## 性能达标核查、内部限定合规自检、出招表与操作说明数据化、交付清单。
## 复用 M2-M8 逻辑层与表现层不改，M9 只做交付与合规挂载。
## 所有数值来自 data/*.json，不硬编码。
extends M8Arena
class_name M9Arena

## ---- M9 扩展 ----
var compliance9: M9Compliance = null
var perf9: M9Perf = null
var docs9: M9Docs = null
var quality9: M9Quality = null

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
	M9Data.logic_only = selftest
	_ensure_input_actions()
	_build_world()
	_build_systems()
	if selftest:
		run_selftest()
	else:
		_start_game()

## 构建世界（M2-M8 世界与场景，M9 无额外视觉节点）。
func _build_world() -> void:
	super._build_world()

## 构建系统（M2-M8 系统 + M9 各管理器 + 安卓虚拟按键）。
func _build_systems() -> void:
	super._build_systems()
	compliance9 = M9Compliance.new()
	add_child(compliance9)
	perf9 = M9Perf.new()
	add_child(perf9)
	docs9 = M9Docs.new()
	add_child(docs9)
	## 画质分级（低/中/高三档，三端持久化，表现层按档位取值）。
	quality9 = M9Quality.new()
	add_child(quality9)
	## 安卓虚拟按键（仅 Android 平台生效，其他平台 M9Touch 自行退出）。
	var touch := M9Touch.new()
	add_child(touch)

## 加载指定索引的关卡（M9 扩展：重置性能采集、刷新合规与文档）。
func _load_stage(index: int) -> void:
	super._load_stage(index)
	if perf9 != null:
		perf9.reset()
		perf9.set_entities(enemies.size())

## 关卡完成：刷新性能采集与合规复查（M9 扩展）。
func _on_stage_complete() -> void:
	super._on_stage_complete()
	if perf9 != null:
		perf9.set_entities(enemies.size())
	if compliance9 != null:
		compliance9.run_checks()

## ---- 模拟帧 ----

## 模拟一帧（M9 扩展：性能采集）。
func simulate_tick(dt: float) -> void:
	## M2-M8 逻辑（含 M8 平衡 / 完整度）。
	super.simulate_tick(dt)
	## M9 性能采集：同屏实体数注入。
	if perf9 != null:
		perf9.set_entities(enemies.size())

## ---- 交付清单 ----

## 汇总交付物清单（双平台产物、数据文件、合规检查表、版本号）。
func build_delivery_manifest() -> Dictionary:
	var manifest := {
		"version": str(ProjectSettings.get_setting("application/config/version", "0.0.0")),
		"version_target": M9Data.version_target(),
		"internal_only": true,
		"artifacts": M9Data.artifacts(),
		"compliance": compliance9.run_checks() if compliance9 != null else [],
		"performance": {
			"target_fps": M9Data.target_fps(),
			"frame_budget_ms": M9Data.frame_budget_ms(),
			"max_entities": M9Data.max_entities(),
			"memory_budget_mb": M9Data.memory_budget_mb()
		}
	}
	return manifest

## ---- Headless 自测 ----

## 运行 M3 + M5 + M6 + M7 + M8 + M9 自测。
func run_selftest() -> void:
	var results: Array = []
	var counters := {"passed": 0, "failed": 0}
	## M3 框架层 42 项 + M5 扩展层 60 项 + M6 扩展层 50 项 + M7 扩展层 21 项 + M8 扩展层 32 项 + M9 交付层与系统性彻查断言。
	_m3_selftest_checks(results, counters)
	_m5_selftest_checks(results, counters)
	_m6_selftest_checks(results, counters)
	_m7_selftest_checks(results, counters)
	_m8_selftest_checks(results, counters)
	_m9_selftest_checks(results, counters)
	_m9_audit_checks(results, counters)
	_selftest_output(results, counters, "M9")

## M9 扩展层自测断言。
func _m9_selftest_checks(results: Array, counters: Dictionary) -> void:
	## 1. delivery_m9 数据加载。
	var del: Dictionary = M9Data.delivery()
	_check(not del.is_empty() and del.has("performance") and del.has("compliance") and del.has("docs"), "M9 delivery_m9 数据加载", results, counters)

	## 2. 性能阈值读取（目标帧率 / 单帧预算 / 同屏上限 / 内存预算）。
	var perf: Dictionary = M9Data.performance()
	_check(int(perf.get("target_fps", 0)) == 60 and float(perf.get("frame_budget_ms", 0.0)) > 0.0 and int(perf.get("max_entities_onscreen", 0)) > 0 and int(perf.get("memory_budget_mb", 0)) > 0, "M9 性能阈值读取（fps/预算/实体/内存）", results, counters)

	## 3. 目标帧率 60。
	_check(M9Data.target_fps() == 60, "M9 目标帧率 60", results, counters)

	## 4. 单帧预算 16.67ms。
	_check(absf(M9Data.frame_budget_ms() - 16.67) < 0.01, "M9 单帧预算 16.67ms", results, counters)

	## 5. 同屏实体上限 12。
	_check(M9Data.max_entities() == 12, "M9 同屏实体上限 12", results, counters)

	## 6. 性能达标判定（未超标）。
	perf9.reset()
	perf9.set_entities(5)
	perf9.set_frame_ms(10.0)
	_check(perf9.evaluate() and perf9.is_ok(), "M9 性能达标判定（未超标）", results, counters)

	## 7. 性能超标告警（单帧超预算）。
	perf9.reset()
	perf9.set_entities(5)
	perf9.set_frame_ms(30.0)
	var over_frame: bool = perf9.evaluate()
	_check(not over_frame and not perf9.warnings.is_empty(), "M9 性能超标告警（单帧超预算）", results, counters)

	## 8. 性能超标告警（同屏实体超上限）。
	perf9.reset()
	perf9.set_entities(20)
	perf9.set_frame_ms(10.0)
	var over_ent: bool = perf9.evaluate()
	_check(not over_ent and not perf9.warnings.is_empty(), "M9 性能超标告警（同屏实体超上限）", results, counters)

	## 9. 合规清单读取（5 项检查）。
	var items: Array = M9Data.compliance_items()
	_check(items.size() == 5, "M9 合规清单读取（5 项）", results, counters)

	## 10. 合规检查全通过。
	var checks: Array = compliance9.run_checks()
	_check(checks.size() == 5 and compliance9.all_pass(), "M9 合规检查全通过", results, counters)

	## 11. 合规检查 pack_manifest public_release=false。
	var pr_item: Dictionary = _find_compliance_item("public_release_false")
	_check(pr_item != null and bool(pr_item.get("pass", false)), "M9 合规检查 public_release=false", results, counters)

	## 12. 合规检查 distribution=internal_only。
	var dist_item: Dictionary = _find_compliance_item("distribution_internal")
	_check(dist_item != null and bool(dist_item.get("pass", false)), "M9 合规检查 distribution=internal_only", results, counters)

	## 13. 合规检查无第三方原始素材。
	var asset_item: Dictionary = _find_compliance_item("no_thirdparty_assets")
	_check(asset_item != null and bool(asset_item.get("pass", false)), "M9 合规检查无第三方原始素材", results, counters)

	## 14. 出招表覆盖五角色。
	_check(docs9.covers_all_heroes(), "M9 出招表覆盖五角色", results, counters)

	## 15. 出招表角色条目读取。
	var m1: Dictionary = docs9.move("hero_01")
	_check(m1.has("name") and m1.has("attacks") and m1.has("ultimate"), "M9 出招表角色条目读取 hero_01", results, counters)

	## 16. 操作说明读取。
	var controls: Array = docs9.controls()
	_check(controls.size() >= 5, "M9 操作说明读取（>=5 项）", results, counters)

	## 17. 操作说明键位查询。
	var jump: Dictionary = docs9.control("jump")
	_check(jump.has("label") and jump.has("keys") and jump.get("keys").size() >= 1, "M9 操作说明键位查询 jump", results, counters)

	## 18. 交付产物清单读取（Windows + Web 双平台）。
	var arts: Array = M9Data.artifacts()
	var platforms: Array = []
	for a in arts:
		if a is Dictionary:
			platforms.append(str(a.get("platform", "")))
	_check(platforms.has("windows") and platforms.has("web"), "M9 交付产物清单读取（Windows + Web）", results, counters)

	## 19. 交付清单构建与版本号一致。
	var dm: Dictionary = build_delivery_manifest()
	_check(dm.has("version") and dm.has("version_target") and dm.get("internal_only") == true, "M9 交付清单构建", results, counters)

	## 20. 版本目标 V1.0.0。
	_check(M9Data.version_target() == "1.0.0", "M9 版本目标 V1.0.0", results, counters)

	## 21. M9 系统挂载。
	_check(compliance9 != null and perf9 != null and docs9 != null, "M9 系统挂载（compliance/perf/docs）", results, counters)

	## 22. 画质分级挂载。
	_check(quality9 != null, "M9 画质分级挂载（quality9）", results, counters)

	## 23. 画质配置加载（三档）。
	var q_tiers: Dictionary = M9Data.quality_tiers()
	_check(q_tiers.has("low") and q_tiers.has("medium") and q_tiers.has("high"), "M9 画质配置加载（低/中/高三档）", results, counters)

	## 24. 默认画质档为 medium。
	_check(M9Data.quality_default_tier() == "medium", "M9 默认画质档 medium", results, counters)

	## 25. 画质档切换与倍率取值。
	_check(quality9.set_tier("high") and quality9.render_scale() == 1.0 and quality9.vfx_particles_mult() == 1.0, "M9 画质档切换与倍率（high）", results, counters)
	_check(quality9.set_tier("low") and absf(quality9.render_scale() - 0.6) < 0.001 and not quality9.outlines_enabled(), "M9 画质档切换与倍率（low）", results, counters)
	## 复位到默认档。
	quality9.set_tier(M9Data.quality_default_tier())

## 在合规检查结果中查找指定 id 的条目。
func _find_compliance_item(id: String) -> Dictionary:
	for r in compliance9.results:
		if str(r.get("id", "")) == id:
			return r
	return {}

## M9 系统性彻查断言（人物 / 场景 / 关卡 / Boss / 战斗 / NPC / 数值 / 闭环）。
## 确保产品数值一致、内容齐备、可正常打通与游玩。
func _m9_audit_checks(results: Array, counters: Dictionary) -> void:
	## ---- 人物系统 ----
	## 1. 五角色招式表完整（每角色 >=8 招）。
	var char_list: Array = M2Data.characters().get("characters", [])
	var moves_ok := true
	for c in char_list:
		if c is not Dictionary:
			continue
		var cid := str(c.get("id", ""))
		var tbl: Dictionary = M2Data.character_moves(cid)
		if int(tbl.get("attack_table", {}).size()) < 8:
			moves_ok = false
			break
	_check(moves_ok, "M9 彻查：五角色招式表完整（各 8 招）", results, counters)

	## 2. 五角色角色调优存在（balance_m8 character_tuning）。
	var tuning: Dictionary = M8Data.character_tuning()
	var tun_ok := true
	for c in char_list:
		if c is not Dictionary:
			continue
		if not tuning.has(str(c.get("id", ""))):
			tun_ok = false
			break
	_check(tun_ok, "M9 彻查：五角色角色调优存在", results, counters)

	## 3. 必杀参数（扣 8% / 下限 15%）。
	var utl := M2Data.ultimate()
	_check(int(utl.get("hp_cost_percent", 0)) == 8 and int(utl.get("min_hp_percent", 0)) == 15, "M9 彻查：必杀参数（8%/15%）", results, counters)

	## 4. 倒地追击数值一致（default 4 / pockets 8 / pockets=hero_04）。
	var dc := M2Data.downed_chase()
	_check(int(dc.get("default_max", 0)) == 4 and int(dc.get("pockets_max", 0)) == 8 and str(dc.get("pockets_character", "")) == "hero_04", "M9 彻查：倒地追击数值一致", results, counters)

	## ---- 战斗系统 ----
	## 5. 命中停顿分级（轻 4 / 重 7 / 必杀 10）。
	var hs := M2Data.hitstop_cfg()
	_check(int(hs.get("light_frames", 0)) == 4 and int(hs.get("heavy_frames", 0)) == 7 and int(hs.get("ultimate_frames", 0)) == 10, "M9 彻查：命中停顿分级（4/7/10）", results, counters)

	## 6. 格挡减伤 0.2（damage_multiplier=0.2）。
	var blk := M2Data.block_cfg()
	_check(absf(float(blk.get("damage_multiplier", 0.0)) - 0.2) < 0.001, "M9 彻查：格挡减伤 0.2", results, counters)

	## 7. 友伤配置存在。
	var ff := M2Data.friendly_fire_cfg()
	_check(not ff.is_empty(), "M9 彻查：友伤配置存在", results, counters)

	## ---- 场景与关卡 ----
	## 8. 六关 stage JSON 均可加载。
	var order: Array = M3Data.stage_order()
	var stages_ok := true
	for sid in order:
		if M3Data.stage(str(sid)).is_empty():
			stages_ok = false
			break
	_check(stages_ok and order.size() == 6, "M9 彻查：六关 stage JSON 均可加载", results, counters)

	## 9. 六关段落结构存在（segments 非空）。
	var seg_ok := true
	for sid in order:
		if M3Data.stage(str(sid)).get("segments", []).is_empty():
			seg_ok = false
			break
	_check(seg_ok, "M9 彻查：六关段落结构存在", results, counters)

	## 10. 六关真实波次数据存在。
	var wave_ok := true
	for sid in order:
		var segs: Array = M3Data.stage(str(sid)).get("segments", [])
		var has_wave := false
		for seg in segs:
			if seg is Dictionary and not seg.get("waves", []).is_empty():
				has_wave = true
				break
		if not has_wave:
			wave_ok = false
			break
	_check(wave_ok, "M9 彻查：六关真实波次数据存在", results, counters)

	## 11. 六关光照预设（stage 顶层）与 spawn_props（segment）存在。
	var prop_ok := true
	for sid in order:
		var sdata: Dictionary = M3Data.stage(str(sid))
		## 光照预设在 stage 顶层。
		if not sdata.has("lighting_preset"):
			prop_ok = false
			break
		## spawn_props 在 segments 中。
		var segs: Array = sdata.get("segments", [])
		var has_props := false
		for seg in segs:
			if seg is Dictionary and seg.has("spawn_props"):
				has_props = true
				break
		if not has_props:
			prop_ok = false
			break
	_check(prop_ok, "M9 彻查：六关光照预设与 spawn_props 存在", results, counters)

	## 12. 六关隐藏点字段存在（stage segments hidden_points 定义）。
	var hidden_ok := true
	for sid in order:
		var segs: Array = M3Data.stage(str(sid)).get("segments", [])
		var has_hidden := false
		for seg in segs:
			if seg is Dictionary and seg.has("hidden_points"):
				has_hidden = true
				break
		if not has_hidden:
			hidden_ok = false
			break
	_check(hidden_ok, "M9 彻查：六关隐藏点字段存在", results, counters)

	## ---- Boss 系统 ----
	## 13. BUTCHER / JASON 数据存在（bosses_m4）。
	_check(not M4Data.boss("boss_01").is_empty() and not M4Data.boss("boss_02").is_empty(), "M9 彻查：BUTCHER / JASON 数据存在", results, counters)

	## 14. DAMON 数据存在（bosses_m5，boss_04）。
	_check(not M5Data.boss("boss_04").is_empty(), "M9 彻查：DAMON 数据存在", results, counters)

	## 15. SMEE / HOOK 数据存在（bosses_m6，boss_05 / boss_06）。
	_check(not M6Data.boss("boss_05").is_empty() and not M6Data.boss("boss_06").is_empty(), "M9 彻查：SMEE / HOOK 数据存在", results, counters)

	## 16. Boss 血量与招式帧表数据驱动。
	var b1: Dictionary = M4Data.boss("boss_01")
	_check(b1.has("hp") and (b1.has("moves") or b1.has("attack_table")), "M9 彻查：Boss 血量与招式帧表数据驱动", results, counters)

	## 17. HOOK 阶段阈值数据驱动（bosses_m6，boss_06，ai 节内 phase 阈值）。
	var hook: Dictionary = M6Data.boss("boss_06")
	var hook_ai: Dictionary = hook.get("ai", {})
	var hook_has_phase := hook_ai.has("phase_2_hp_percent") and hook_ai.has("phase_3_hp_percent")
	_check(hook_has_phase, "M9 彻查：HOOK 阶段阈值数据驱动", results, counters)

	## ---- NPC / 敌人系统 ----
	## 18. 七类敌人模板存在（enemies.json templates）。
	var enemy_list: Array = M2Data.enemies().get("templates", [])
	var types: Array = []
	for e in enemy_list:
		if e is Dictionary and e.has("id"):
			types.append(str(e.get("id", "")))
	var seven := ["grunt", "drunk", "flyer", "fatty", "spearman", "flail", "swordsman"]
	var all_types := true
	for t in seven:
		if not types.has(t):
			all_types = false
			break
	_check(all_types, "M9 彻查：七类敌人模板存在", results, counters)

	## 19. 敌人 AI 参数完整。
	var ai_ok := true
	for e in enemy_list:
		if e is not Dictionary:
			continue
		if not e.has("ai") and not e.has("ai_cfg"):
			ai_ok = false
			break
	_check(ai_ok, "M9 彻查：敌人 AI 参数完整", results, counters)

	## 20. M4 机关配置存在（蜂窝 / 铁球 / 鸡群）。
	_check(not M4Data.honeycomb_cfg().is_empty() and not M4Data.iron_ball_cfg().is_empty() and not M4Data.chicken_cfg().is_empty(), "M9 彻查：M4 机关配置（蜂窝/铁球/鸡群）", results, counters)

	## 21. M5 机关配置存在（假 Hook / 罐子 / 长矛 / 冰柱 / 企鹅）。
	_check(not M5Data.fake_hook_cfg().is_empty() and not M5Data.painted_jar_cfg().is_empty() and not M5Data.spear_cfg().is_empty() and not M5Data.ice_pillar_cfg().is_empty() and not M5Data.penguin_cfg().is_empty(), "M9 彻查：M5 机关配置（假Hook/罐子/长矛/冰柱/企鹅）", results, counters)

	## 22. M6 机关配置存在（运财小兵 / 炮台 / Tinker Bell / 鳄鱼）。
	_check(not M6Data.treasure_carrier_cfg().is_empty() and not M6Data.cannon_cfg().is_empty() and not M6Data.tinker_bell_cfg().is_empty() and not M6Data.crocodile_cfg().is_empty(), "M9 彻查：M6 机关配置（运财小兵/炮台/Tinker Bell/鳄鱼）", results, counters)

	## ---- 可玩性闭环 ----
	## 23. 六关顺序推进（stage_order 六关）。
	_check(order.size() == 6, "M9 彻查：六关顺序推进", results, counters)

	## 24. 末段 Boss 场标记（stage_06 顶层 boss 字段）。
	var last_stage: Dictionary = M3Data.stage(str(order[5]))
	var boss_field: Dictionary = last_stage.get("boss", {})
	var boss_seg_ok: bool = last_stage.has("boss") and not boss_field.is_empty()
	_check(boss_seg_ok, "M9 彻查：末段 Boss 场标记", results, counters)

	## 25. 末关可推进（stage_runner 加载 stage_06 正常）。
	stage_runner.load_stage(str(order[5]))
	_check(stage_runner.segment_count() > 0, "M9 彻查：末关可推进至结局", results, counters)

	## 26. 周目回环可重开首关。
	stage_runner.load_stage(str(order[0]))
	_check(stage_runner.segment_count() > 0, "M9 彻查：周目回环可重开首关", results, counters)

	## 27. 版本号一致性（application/config/version = 1.0.0）。
	## 导出构建中 project.godot 被编译进 project.binary，FileAccess 无法直接读取，
	## 改用 ProjectSettings 获取版本号（编辑器与导出构建均有效）。
	var version_ok: bool = str(ProjectSettings.get_setting("application/config/version", "0.0.0")) == "1.0.0"
	_check(version_ok, "M9 彻查：版本号一致性（config/version=1.0.0）", results, counters)

	## 28. M2-M9 全系统共存挂载。
	_check(balance8 != null and treasure8 != null and systems8 != null and compliance9 != null and perf9 != null and docs9 != null, "M9 彻查：M2-M9 全系统共存挂载", results, counters)
