## M4 关卡场景构建器（Stage 1–2 灰盒 + 光照预设）。
## 模块化灰盒资产：地面、栏杆、木桶、海面、枯树、木栅栏等，
## M7 替换最终美术。光照参数取自 stage JSON 的 lighting_preset 块。
extends Node3D
class_name M4StageScene

## 构建指定关卡的场景与光照。
func build(stage_id: String, stage_data: Dictionary) -> void:
	clear_scene()
	if M2Data.logic_only:
		return
	if stage_id == "stage_01":
		_build_dock(stage_data)
	elif stage_id == "stage_02":
		_build_snow(stage_data)
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
	var sc: Array = preset.get("sun_color", [1.0, 0.95, 0.8])
	sun.light_color = Color(float(sc[0]), float(sc[1]), float(sc[2]))
	sun.light_energy = float(preset.get("sun_intensity", 1.0))
	sun.transform.basis = Basis.from_euler(Vector3(-PI * 0.35, 0.0, 0.0))
	add_child(sun)
	## 环境光能量通过 WorldEnvironment 设置（Godot 4 无 AmbientLight 节点）。
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	var ac: Array = preset.get("ambient", [0.5, 0.5, 0.55])
	env.ambient_light_color = Color(float(ac[0]), float(ac[1]), float(ac[2]))
	env.ambient_light_energy = 0.6
	world_env.environment = env
	add_child(world_env)

## Stage 1 海港码头：木板地、绳栏杆、木桶、海面。
func _build_dock(stage_data: Dictionary) -> void:
	var half_w: float = float(M2Data.m2_base().get("screen_half_width", 7.6))
	## 木板地面。
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(half_w * 2.5, 8.0)
	floor.mesh = plane
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.55, 0.42, 0.28)
	floor.material_override = fmat
	add_child(floor)
	## 绳索木栏杆（两侧）。
	var rail_mat := StandardMaterial3D.new()
	rail_mat.albedo_color = Color(0.45, 0.33, 0.22)
	for side in [-1, 1]:
		for i in 4:
			var post := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.12, 1.4, 0.12)
			post.mesh = box
			post.material_override = rail_mat
			post.position = Vector3(side * (half_w - 0.5), 0.7, -1.5 + i * 1.0)
			add_child(post)
	## 木桶（装饰）。
	var barrel_mat := StandardMaterial3D.new()
	barrel_mat.albedo_color = Color(0.6, 0.4, 0.25)
	for bx in [-3.0, 3.0]:
		var barrel := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.radius = 0.4
		cyl.height = 0.9
		barrel.mesh = cyl
		barrel.material_override = barrel_mat
		barrel.position = Vector3(bx, 0.45, 1.0)
		add_child(barrel)
	## 海面（半透明蓝面，远层）。
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

## Stage 2 雪原枯树林：雪地、枯树、木栅栏。
func _build_snow(stage_data: Dictionary) -> void:
	var half_w: float = float(M2Data.m2_base().get("screen_half_width", 7.6))
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(half_w * 2.5, 8.0)
	floor.mesh = plane
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.85, 0.88, 0.92)
	floor.material_override = fmat
	add_child(floor)
	## 枯树群。
	var tree_mat := StandardMaterial3D.new()
	tree_mat.albedo_color = Color(0.35, 0.28, 0.22)
	for i in 5:
		var tree := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.18, 2.6, 0.18)
		tree.mesh = box
		tree.material_override = tree_mat
		tree.position = Vector3(-half_w + 1.5 + i * (half_w * 0.45), 1.3, -1.5 + (i % 3))
		add_child(tree)
	## 木栅栏。
	var fence_mat := StandardMaterial3D.new()
	fence_mat.albedo_color = Color(0.5, 0.4, 0.3)
	for side in [-1, 1]:
		var fence := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.1, 1.0, 4.0)
		fence.mesh = box
		fence.material_override = fence_mat
		fence.position = Vector3(side * (half_w - 0.4), 0.5, 0.0)
		add_child(fence)
