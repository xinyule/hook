## M7 主场景控制器。
## 继承 M6Arena，在 M2-M6 全部逻辑层之上挂载 M7 表现层：
## 风格化视觉升级（Toon 块状模型 + 描边）、粒子 VFX 与六关天气、
## 程序化音频（SFX + BGM）。复用 M2-M6 逻辑层不改，M7 只做视觉与音频挂载。
## 所有数值来自 data/*.json，不硬编码。
extends M6Arena
class_name M7Arena

## ---- M7 扩展 ----
var visual7: M7Visual = null
var vfx7: M7Vfx = null
var audio7: M7Audio = null
## 上一帧道具快照（观测道具消失以触发爆炸 VFX）。
var _prop_seen: Dictionary = {}

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
	_ensure_input_actions()
	_build_world()
	_build_systems()
	if selftest:
		run_selftest()
	else:
		_start_game()

## 构建世界（M2-M6 世界与场景 + M7 VFX / 音频节点）。
func _build_world() -> void:
	super._build_world()
	vfx7 = M7Vfx.new()
	add_child(vfx7)
	audio7 = M7Audio.new()
	add_child(audio7)

## 构建系统（M2-M6 系统 + M7 视觉升级管理器）。
func _build_systems() -> void:
	super._build_systems()
	visual7 = M7Visual.new()
	add_child(visual7)

## 加载指定索引的关卡（M7 扩展：天气与 BGM）。
func _load_stage(index: int) -> void:
	super._load_stage(index)
	var sid: String = stage_runner.stage_data.get("id", "")
	if vfx7 != null:
		vfx7.apply_weather(sid)
	if audio7 != null:
		audio7.start_bgm(sid)
	_prop_seen = {}

## ---- 视觉升级挂载 ----

## 对当前在场角色 / 敌人 / Boss 做一次性风格化视觉升级（幂等）。
func _upgrade_actor_visuals() -> void:
	if visual7 == null:
		return
	for a in enemies:
		if a is M2Actor:
			visual7.upgrade_actor(a)
	for p in player_manager.all_players():
		visual7.upgrade_actor(p)
	if boss != null and is_instance_valid(boss):
		visual7.upgrade_actor(boss)
	if boss6 != null and is_instance_valid(boss6):
		visual7.upgrade_actor(boss6)

## ---- VFX 挂载 ----

## 覆盖 M2 命中粒子挂载点：路由到 M7 增强 VFX。
func _spawn_hit_particles(pos: Vector3, heavy: bool) -> void:
	if vfx7 != null:
		vfx7.spawn_hit_spark(pos, heavy)
	else:
		super._spawn_hit_particles(pos, heavy)

## 道具消失观测：上一帧存在的爆炸型道具本帧消失则触发爆炸 VFX。
func _track_prop_explosions() -> void:
	if vfx7 == null:
		return
	var seen_now := {}
	for holder in [props, props6]:
		if holder == null:
			continue
		for rec in holder.prop_records:
			var t := str(rec.get("type", ""))
			seen_now[t] = {"x": float(rec.get("x", 0.0)), "y": float(rec.get("y", 0.0))}
	for pending in _pending_explosions(_prop_seen, seen_now):
		vfx7.spawn_explosion(pending.pos, Color(1.0, 0.6, 0.2), 1.0)
	_prop_seen = seen_now

## 计算消失的爆炸型道具（纯函数，供自测）。
## prev/cur 为 {type: {x, y}} 快照，返回 [{type, pos}]。
func _pending_explosions(prev_seen: Dictionary, cur_seen: Dictionary) -> Array:
	var out: Array = []
	for t in prev_seen:
		if t in cur_seen:
			continue
		if not (t in _explosive_types()):
			continue
		out.append({"type": t, "pos": Vector3(float(prev_seen[t].get("x", 0.0)), float(prev_seen[t].get("y", 0.0)), 0.0)})
	return out

## 从 M5 道具数据收集带爆炸配置的道具类型。
func _explosive_types() -> Array:
	var out: Array = []
	var pm5 := M5Data.props_m5()
	for key in pm5.keys():
		var v = pm5[key]
		if v is Dictionary and v.has("explode_radius_m"):
			out.append(key)
	return out

## ---- 模拟帧 ----

## 模拟一帧（M7 扩展：视觉升级、VFX、道具爆炸观测、BGM）。
func simulate_tick(dt: float) -> void:
	## M2-M6 逻辑（含 M6 道具 / Boss / 结局）。
	super.simulate_tick(dt)
	## M7 视觉升级（幂等，仅首次构建）。
	_upgrade_actor_visuals()
	## M7 VFX 与道具爆炸观测。
	if vfx7 != null:
		_track_prop_explosions()
		vfx7.tick(dt)
	## M7 BGM 调度。
	if audio7 != null:
		audio7.tick(dt)

## ---- Headless 自测 ----

## 运行 M3 + M5 + M6 + M7 自测。
func run_selftest() -> void:
	var results: Array = []
	var counters := {"passed": 0, "failed": 0}
	## M3 框架层 42 项 + M5 扩展层 60 项 + M6 扩展层 50 项 + M7 扩展层断言。
	_m3_selftest_checks(results, counters)
	_m5_selftest_checks(results, counters)
	_m6_selftest_checks(results, counters)
	_m7_selftest_checks(results, counters)
	_selftest_output(results, counters, "M7")

## M7 扩展层自测断言。
func _m7_selftest_checks(results: Array, counters: Dictionary) -> void:
	## 1. visual_m7 数据加载。
	var vis := M7Data.visual()
	_check(not vis.is_empty() and not vis.get("palettes", {}).is_empty(), "M7 visual_m7 数据加载", results, counters)

	## 2. 调色板齐全（5 角色 + 7 敌人 + 6 Boss = 18）。
	var pals: Dictionary = vis.get("palettes", {})
	_check(pals.size() == 18, "M7 调色板 18 项齐全（5 角色 + 7 敌人 + 6 Boss）", results, counters)

	## 3. Toon 风格参数。
	var style := M7Data.style()
	_check(float(style.get("outline_scale", 0.0)) > 1.0 and style.has("outline_color"), "M7 Toon 风格参数（描边缩放/色）", results, counters)

	## 4. 角色调色板查询。
	var h1 := M7Data.palette("hero_01")
	_check(h1.has("primary") and h1.has("secondary") and h1.has("accent") and h1.has("skin"), "M7 角色调色板查询 hero_01", results, counters)

	## 5. 敌人调色板查询。
	_check(not M7Data.palette("grunt").is_empty(), "M7 敌人调色板查询 grunt", results, counters)

	## 6. Boss 调色板查询。
	_check(not M7Data.palette("boss_05").is_empty() and not M7Data.palette("boss_06").is_empty(), "M7 Boss 调色板查询 boss_05/boss_06", results, counters)

	## 7. vfx_m7 数据加载。
	var vfx := M7Data.vfx()
	_check(vfx.has("hit_spark") and vfx.has("explosion") and vfx.has("treasure_burst") and vfx.has("weather"), "M7 vfx_m7 数据加载", results, counters)

	## 8. 命中火花配置（轻/重）。
	var hs_l := M7Data.hit_spark(false)
	var hs_h := M7Data.hit_spark(true)
	_check(int(hs_l.get("count", 0)) > 0 and float(hs_l.get("lifetime", 0.0)) > 0.0 and int(hs_h.get("count", 0)) >= int(hs_l.get("count", 1)), "M7 命中火花配置（轻/重分级）", results, counters)

	## 9. 爆炸与财宝爆裂配置。
	var exp := M7Data.explosion()
	var tb := M7Data.treasure_burst()
	_check(int(exp.get("count", 0)) > 0 and float(exp.get("shake", 0.0)) > 0.0 and int(tb.get("count", 0)) > 0, "M7 爆炸与财宝爆裂配置", results, counters)

	## 10. 六关天气配置。
	var weather: Dictionary = vfx.get("weather", {})
	var types := []
	for i in range(1, 7):
		types.append(weather.get("stage_0%d" % i, {}).get("type", ""))
	_check(types == ["clear", "snow", "dusk", "ice_fog", "ember", "final"], "M7 六关天气配置（晴/雪/暮/冰雾/烛光/决战）", results, counters)

	## 11. apply_weather 切换。
	vfx7.apply_weather("stage_02")
	_check(vfx7.weather_type == "snow", "M7 apply_weather stage_02 雪", results, counters)

	## 12. 天气切换清空重建。
	vfx7.apply_weather("stage_01")
	_check(vfx7.weather_type == "clear", "M7 apply_weather stage_01 晴", results, counters)

	## 13. VFX 生成与生命周期回收。
	var before: int = vfx7.effects.size()
	vfx7.spawn_hit_spark(Vector3(1.0, 0.0, 0.0), false)
	var spawned: int = vfx7.effects.size() - before
	vfx7.tick(0.5)
	_check(spawned > 0 and vfx7.effects.size() == before, "M7 VFX 生成与生命周期回收", results, counters)

	## 14. 爆炸 VFX 生成。
	before = vfx7.effects.size()
	vfx7.spawn_explosion(Vector3(2.0, 0.0, 0.0), Color(1.0, 0.6, 0.2), 1.0)
	_check(vfx7.effects.size() > before, "M7 爆炸 VFX 生成", results, counters)
	vfx7.tick(1.0)

	## 15. SFX 参数。
	var hit := M7Data.sfx("hit_light")
	var ult := M7Data.sfx("ultimate")
	_check(float(hit.get("freq", 0.0)) > 0.0 and float(hit.get("duration", 0.0)) > 0.0 and float(ult.get("duration", 0.0)) > float(hit.get("duration", 1.0)), "M7 SFX 参数读取（命中/必杀）", results, counters)

	## 16. BGM 音符表六关非空。
	var bgm: Dictionary = M7Data.audio().get("bgm", {})
	var stages: Dictionary = bgm.get("stages", {})
	var all_notes := true
	for i in range(1, 7):
		if stages.get("stage_0%d" % i, {}).get("notes", []).is_empty():
			all_notes = false
	_check(all_notes and float(bgm.get("tempo_bpm", 0.0)) > 0.0, "M7 BGM 音符表六关非空", results, counters)

	## 17. BGM 调度计算。
	var sched := audio7.bgm_schedule_for("stage_01")
	var note_count := int(stages.get("stage_01", {}).get("notes", []).size())
	_check(sched.size() == note_count, "M7 BGM 调度长度与音符数一致", results, counters)

	## 18. 音名频率换算。
	_check(absf(M7Audio.note_freq("C4") - 261.63) < 0.1 and M7Audio.note_freq("rest") == 0.0, "M7 音名频率换算（C4=261.63Hz）", results, counters)

	## 19. UI 对齐参数。
	var ui_cfg: Dictionary = M7Data.ui().get("hud", {})
	_check(ui_cfg.has("hp_bar_width") and ui_cfg.has("boss_bar_width") and ui_cfg.has("time_bar_width"), "M7 UI 对齐参数读取", results, counters)

	## 20. 风格化分块规划与视觉升级幂等。
	var e := M2Enemy.new()
	add_child(e)
	e.setup_enemy("grunt", 1.0, 0)
	var parts := visual7.plan_parts(e)
	var ok1 := visual7.upgrade_actor(e)
	var ok2 := visual7.upgrade_actor(e)
	_check(parts.size() == 6 and ok1 and ok2 and e.get_meta(M7Visual.UPGRADE_FLAG, false) == true, "M7 风格化分块（6 块）与视觉升级幂等", results, counters)
	e.queue_free()

	## 21. 爆炸型道具消失观测。
	var pending := _pending_explosions(
		{"painted_jar": {"x": 2.0, "y": 0.0}, "crate": {"x": 1.0, "y": 0.0}},
		{"crate": {"x": 1.0, "y": 0.0}})
	_check(pending.size() == 1 and str(pending[0].get("type", "")) == "painted_jar", "M7 爆炸型道具消失观测（painted_jar）", results, counters)
