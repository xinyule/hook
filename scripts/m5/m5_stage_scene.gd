## M5 关卡场景构建器（Stage 3-4 灰盒 + 光照预设）。
## Stage 3 船甲板：木板地、金绳栏杆、桅柱、彩绘大罐、船体轮廓、暖金夕阳。
## Stage 4 冰海：冰面、冰山、巨大船体、冰柱群、冷蓝晴空、飘雪。
## 资产沿用灰盒模块化（M7 替换最终美术）。光照参数取自 stage JSON 的 lighting_preset 块。
extends Node3D
class_name M5StageScene

## 构建指定关卡的场景与光照。
func build(stage_id: String, stage_data: Dictionary) -> void:
	clear_scene()
	if M2Data.logic_only:
		return
	if stage_id == "stage_03":
		_build_deck(stage_data)
	elif stage_id == "stage_04":
		_build_ice(stage_data)
	_apply_lighting(stage_data)

## 清空场景节点。
func clear_scene() -> void:
	for c in get_children():
		c.queue_free()

## 光照预设：主光 + 环境光，参数来自 stage JSON。
func _apply_lighting(stage_data: Dictionary) -> void:
	var preset: Dictionary = stage_data.get("lighting_preset", {})
	if preset.is_empty():
		return
	var sun := DirectionalLight3D.new()
	var sc: Array = preset.get("sun_color", [1.0, 0.9, 0.7])
	sun.light_color = Color(float(sc[0]), float(sc[1]), float(sc[2]))
	sun.light_energy = float(preset.get("sun_intensity", 1.0))
	sun.transform.basis = Basis.from_euler(Vector3(-PI * 0.35, 0.0, 0.0))
	add_child(sun)
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	var ac: Array = preset.get("ambient", [0.5, 0.55, 0.65])
	env.ambient_light_color = Color(float(ac[0]), float(ac[1]), float(ac[2]))
	env.ambient_light_energy = 0.6
	world_env.environment = env
	add_child(world_env)

## Stage 3 船甲板：木板地、金绳栏杆、桅柱、彩绘大罐、船体轮廓。
func _build_deck(stage_data: Dictionary) -> void:
	var half_w: float = float(M2Data.m2_base().get("screen_half_width", 7.6))
	## 圆木竹编甲板。
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(half_w * 2.5, 8.0)
	floor.mesh = plane
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.5, 0.36, 0.2)
	floor.material_override = fmat
	add_child(floor)
	## 金色绳结栏杆（两侧）。
	var rail_mat := StandardMaterial3D.new()
	rail_mat.albedo_color = Color(0.75, 0.6, 0.25)
	for side in [-1, 1]:
		for i in 4:
			var post := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.1, 1.4, 0.1)
			post.mesh = box
			post.material_override = rail_mat
			post.position = Vector3(side * (half_w - 0.5), 0.7, -1.5 + i * 1.0)
			add_child(post)
	## 两根桅柱。
	var mast_mat := StandardMaterial3D.new()
	mast_mat.albedo_color = Color(0.4, 0.28, 0.18)
	for mx in [-2.5, 2.5]:
		var mast := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.18, 3.2, 0.18)
		mast.mesh = box
		mast.material_override = mast_mat
		mast.position = Vector3(mx, 1.6, -1.0)
		add_child(mast)
	## 彩绘大罐（装饰，可击碎逻辑由 props 管理）。
	var jar_mat := StandardMaterial3D.new()
	jar_mat.albedo_color = Color(0.85, 0.6, 0.2)
	for jx in [-3.0, 0.0, 3.0]:
		var jar := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.radius = 0.35
		cyl.height = 0.7
		jar.mesh = cyl
		jar.material_override = jar_mat
		jar.position = Vector3(jx, 0.35, 1.2)
		add_child(jar)
	## 海面（远层半透明）。
	var sea := MeshInstance3D.new()
	var sea_plane := PlaneMesh.new()
	sea_plane.size = Vector2(half_w * 4.0, 12.0)
	sea.mesh = sea_plane
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.2, 0.45, 0.65, 0.6)
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sea.material_override = smat
	sea.position = Vector3(0.0, -0.05, -4.0)
	add_child(sea)

## Stage 4 冰海：冰面、冰山、巨大船体、冰柱群。
func _build_ice(stage_data: Dictionary) -> void:
	var half_w: float = float(M2Data.m2_base().get("screen_half_width", 7.6))
	## 冰面。
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(half_w * 2.5, 8.0)
	floor.mesh = plane
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.75, 0.82, 0.9)
	floor.material_override = fmat
	add_child(floor)
	## 巨大黑色海盗船船体（背景）。
	var hull := MeshInstance3D.new()
	var hull_box := BoxMesh.new()
	hull_box.size = Vector3(half_w * 0.8, 4.0, 1.0)
	hull.mesh = hull_box
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = Color(0.18, 0.2, 0.24)
	hull.material_override = hmat
	hull.position = Vector3(0.0, 1.4, -3.5)
	add_child(hull)
	## 冰山（灰盒占位，M7 替换最终美术）。
	var ice_mat := StandardMaterial3D.new()
	ice_mat.albedo_color = Color(0.7, 0.78, 0.85)
	for i in 4:
		var ice := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.9, 1.6, 0.9)
		ice.mesh = box
		ice.material_override = ice_mat
		ice.position = Vector3(-half_w + 1.5 + i * (half_w * 0.4), 0.8, -2.0 + (i % 3))
		add_child(ice)
	## 冰柱群（背景装饰，可踩逻辑由 props 管理）。
	var pillar_mat := StandardMaterial3D.new()
	pillar_mat.albedo_color = Color(0.8, 0.86, 0.92)
	for px in [-3.0, 3.0]:
		var pillar := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.radius = 0.2
		cyl.height = 1.4
		pillar.mesh = cyl
		pillar.material_override = pillar_mat
		pillar.position = Vector3(px, 0.7, 1.0)
		add_child(pillar)
