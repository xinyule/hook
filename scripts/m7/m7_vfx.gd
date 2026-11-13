## M7 粒子特效与天气系统。
## 提供命中火花（轻/重分级）、爆炸、财宝爆裂与六关天气粒子
## （晴 / 雪 / 暮 / 冰雾 / 烛光余烬 / 决战）。
## 特效为自管理生命周期的简单粒子（无外部素材）；
## logic_only（headless 自测）下只做配置与逻辑记账，不创建节点。
## 所有数值来自 data/vfx_m7.json，不硬编码。
extends Node
class_name M7Vfx

## 进行中的特效记录：{kind, pos, life, max_life, node}。
var effects: Array = []
## 当前天气类型与配置。
var weather_type: String = ""
var weather_cfg: Dictionary = {}
## 天气粒子（真实模式）。
var weather_particles: Array = []
## 天气色调背景板（真实模式）。
var weather_tint: MeshInstance3D = null

## 生成命中火花。
func spawn_hit_spark(pos: Vector3, heavy: bool) -> void:
	var cfg := M7Data.hit_spark(heavy)
	_spawn_effect("hit_spark", pos, cfg)

## 生成爆炸特效（罐子 / 财宝等）。
func spawn_explosion(pos: Vector3, color: Color, scale: float) -> void:
	var cfg := M7Data.explosion()
	_spawn_effect("explosion", pos, cfg, color, scale)

## 生成财宝爆裂特效。
func spawn_treasure_burst(pos: Vector3) -> void:
	_spawn_effect("treasure_burst", pos, M7Data.treasure_burst())

## 内部：登记一个特效（真实模式建粒子节点，逻辑模式只记账）。
func _spawn_effect(kind: String, pos: Vector3, cfg: Dictionary, override_color: Color = Color.WHITE, scale: float = 1.0) -> void:
	var count := int(cfg.get("count", 4))
	var lifetime := float(cfg.get("lifetime", 0.25))
	var color := override_color if override_color != Color.WHITE else _c(cfg.get("color", Color.WHITE))
	var size := float(cfg.get("size", 0.12)) * scale
	var speed := float(cfg.get("speed", 2.0))
	var gravity := float(cfg.get("gravity", 6.0))
	for i in count:
		var life := lifetime
		var node: Node3D = null
		if not M7Data.logic_only:
			node = _make_particle(color, size, speed, gravity, pos)
		effects.append({"kind": kind, "pos": pos, "life": life, "max_life": lifetime, "node": node})

## 构建单个粒子节点（真实模式）。
func _make_particle(color: Color, size: float, speed: float, gravity: float, pos: Vector3) -> Node3D:
	var p := Node3D.new()
	var mesh_inst := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	mesh_inst.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_inst.material_override = mat
	p.add_child(mesh_inst)
	p.global_position = pos
	## 初速：水平随机 + 上抛。
	var angle := randf() * TAU
	var vx := cos(angle) * speed * randf_range(0.5, 1.0)
	var vy := speed * randf_range(0.3, 1.0)
	p.set("vel", Vector3(vx, vy, 0.0))
	p.set("grav", gravity)
	add_child(p)
	return p

## 应用指定关卡的天气（真实模式建天气粒子与色调板，逻辑模式只记配置）。
func apply_weather(stage_id: String) -> void:
	weather_cfg = M7Data.weather(stage_id)
	weather_type = weather_cfg.get("type", "clear")
	_clear_weather()
	if M7Data.logic_only or weather_type == "clear":
		return
	var count := int(weather_cfg.get("particles", 0))
	var color := _c(weather_cfg.get("tint", Color.WHITE))
	## 色调背景板（背景深处大平面，低透明）。
	weather_tint = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60.0, 20.0)
	weather_tint.mesh = plane
	var tmat := StandardMaterial3D.new()
	tmat.albedo_color = color
	tmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	weather_tint.material_override = tmat
	weather_tint.position = Vector3(0.0, 8.0, -6.0)
	add_child(weather_tint)
	## 天气粒子池。
	for i in count:
		var p := _make_weather_particle(_c(weather_cfg.get("tint", Color.WHITE)), float(weather_cfg.get("speed", 1.0)), float(weather_cfg.get("spread", 3.0)))
		weather_particles.append(p)

## 构建单个天气粒子。
func _make_weather_particle(color: Color, speed: float, spread: float) -> Node3D:
	var p := Node3D.new()
	var mesh_inst := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(0.12, 0.12)
	mesh_inst.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_inst.material_override = mat
	p.add_child(mesh_inst)
	p.global_position = Vector3(randf_range(-spread, spread), randf_range(0.0, 10.0), 0.0)
	p.set("vel", Vector3(randf_range(-0.3, 0.3), -speed, 0.0))
	add_child(p)
	return p

## 推进特效与天气。
func tick(dt: float) -> void:
	## 特效生命周期：到期回收。
	for i in range(effects.size() - 1, -1, -1):
		var e: Dictionary = effects[i]
		e["life"] -= dt
		if e["node"] != null and is_instance_valid(e["node"]):
			var p: Node3D = e["node"]
			var vel_v = p.get("vel")
			var vel: Vector3 = vel_v if vel_v != null else Vector3.ZERO
			var grav_v = p.get("grav")
			var grav: float = grav_v if grav_v != null else 0.0
			vel.y -= grav * dt
			p.global_position += vel * dt
			var s_v = p.get("scale_f")
			var s: float = s_v if s_v != null else 1.0
			s = s - dt * 2.0
			if s <= 0.0:
				s = 0.0
			p.set("scale_f", s)
			p.scale = Vector3(s + 0.001, s + 0.001, s + 0.001)
		if e["life"] <= 0.0:
			if e["node"] != null and is_instance_valid(e["node"]):
				e["node"].queue_free()
			effects.remove_at(i)
	## 天气粒子飘落与回环。
	if not weather_particles.is_empty():
		var spread := float(weather_cfg.get("spread", 3.0))
		for p in weather_particles:
			if not is_instance_valid(p):
				continue
			var vel_v = p.get("vel")
			var vel: Vector3 = vel_v if vel_v != null else Vector3.ZERO
			p.global_position += vel * dt
			if p.global_position.y < -1.0:
				p.global_position = Vector3(randf_range(-spread, spread), randf_range(9.0, 12.0), 0.0)

## 清空天气（切换关卡时调用）。
func _clear_weather() -> void:
	for p in weather_particles:
		if is_instance_valid(p):
			p.queue_free()
	weather_particles.clear()
	if weather_tint != null and is_instance_valid(weather_tint):
		weather_tint.queue_free()
	weather_tint = null

## 清空全部特效与天气。
func clear_all() -> void:
	for e in effects:
		if e["node"] != null and is_instance_valid(e["node"]):
			e["node"].queue_free()
	effects.clear()
	_clear_weather()

## 数组取色辅助。
static func _c(arr) -> Color:
	if arr is Array and arr.size() >= 3:
		return Color(float(arr[0]), float(arr[1]), float(arr[2]), float(arr[3]) if arr.size() >= 4 else 1.0)
	return Color.WHITE
