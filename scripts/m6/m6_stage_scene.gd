## M6 关卡场景构建器（Stage 5-6 灰盒 + 光照预设）。
## Stage 5 船舱 / 船长室：木条地板、原木横墙、红底金纹地毯、圆舷窗 + 红绒帷幕、
## 雕花拱门、暖金烛光。Stage 6 决战甲板：木舱壁、拱形铁栅门、右上高台（Tinker Bell）、
## 甲板、高对比决战光照。资产沿用灰盒模块化（M7 替换最终美术）。
## 光照参数取自 stage JSON 的 lighting_preset 块。
extends Node3D
class_name M6StageScene

## 构建指定关卡的场景与光照。
func build(stage_id: String, stage_data: Dictionary) -> void:
	clear_scene()
	if M2Data.logic_only:
		return
	if stage_id == "stage_05":
		_build_cabin(stage_data)
	elif stage_id == "stage_06":
		_build_final_deck(stage_data)
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
	var sc: Array = preset.get("sun_color", [1.0, 0.85, 0.6])
	sun.light_color = Color(float(sc[0]), float(sc[1]), float(sc[2]))
	sun.light_energy = float(preset.get("sun_intensity", 1.0))
	sun.transform.basis = Basis.from_euler(Vector3(-PI * 0.35, 0.0, 0.0))
	add_child(sun)
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	var ac: Array = preset.get("ambient", [0.6, 0.5, 0.4])
	env.ambient_light_color = Color(float(ac[0]), float(ac[1]), float(ac[2]))
	env.ambient_light_energy = 0.6
	world_env.environment = env
	add_child(world_env)

## Stage 5 船舱 / 船长室：木条地板、原木墙、红金地毯、舷窗帷幕、拱门。
func _build_cabin(stage_data: Dictionary) -> void:
	var half_w: float = float(M2Data.m2_base().get("screen_half_width", 7.6))
	## 木条地板。
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(half_w * 2.5, 8.0)
	floor.mesh = plane
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.45, 0.3, 0.18)
	floor.material_override = fmat
	add_child(floor)
	## 红底金纹地毯（中轴）。
	var carpet := MeshInstance3D.new()
	var cplane := PlaneMesh.new()
	cplane.size = Vector2(2.2, 8.0)
	carpet.mesh = cplane
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = Color(0.7, 0.18, 0.18)
	carpet.material_override = cmat
	carpet.position = Vector3(0.0, 0.02, 0.0)
	add_child(carpet)
	## 原木横墙（两侧背景）。
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.35, 0.24, 0.14)
	for side in [-1, 1]:
		var wall := MeshInstance3D.new()
		var wbox := BoxMesh.new()
		wbox.size = Vector3(0.3, 3.0, 8.0)
		wall.mesh = wbox
		wall.material_override = wall_mat
		wall.position = Vector3(side * (half_w - 0.2), 1.5, 0.0)
		add_child(wall)
	## 圆舷窗 + 红绒帷幕（两侧墙上）。
	var curtain_mat := StandardMaterial3D.new()
	curtain_mat.albedo_color = Color(0.6, 0.12, 0.12)
	var port_mat := StandardMaterial3D.new()
	port_mat.albedo_color = Color(0.5, 0.6, 0.7)
	for side in [-1, 1]:
		for i in 3:
			var port := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.radius = 0.35
			cyl.height = 0.1
			port.mesh = cyl
			port.material_override = port_mat
			port.position = Vector3(side * (half_w - 0.2), 2.0, -2.0 + i * 2.0)
			port.rotation.y = PI * 0.5
			add_child(port)
			var curtain := MeshInstance3D.new()
			var cbox := BoxMesh.new()
			cbox.size = Vector3(0.2, 1.6, 1.2)
			curtain.mesh = cbox
			curtain.material_override = curtain_mat
			curtain.position = Vector3(side * (half_w - 0.2), 1.4, -2.0 + i * 2.0)
			add_child(curtain)
	## 雕花拱门（中后景）。
	var arch_mat := StandardMaterial3D.new()
	arch_mat.albedo_color = Color(0.5, 0.35, 0.2)
	var arch := MeshInstance3D.new()
	var abox := BoxMesh.new()
	abox.size = Vector3(2.4, 2.6, 0.3)
	arch.mesh = abox
	arch.material_override = arch_mat
	arch.position = Vector3(0.0, 1.3, -3.0)
	add_child(arch)
	## 木桶与烛台装饰。
	var barrel_mat := StandardMaterial3D.new()
	barrel_mat.albedo_color = Color(0.5, 0.32, 0.18)
	for bx in [-3.0, 3.0]:
		var barrel := MeshInstance3D.new()
		var bcyl := CylinderMesh.new()
		bcyl.radius = 0.3
		bcyl.height = 0.6
		barrel.mesh = bcyl
		barrel.material_override = barrel_mat
		barrel.position = Vector3(bx, 0.3, 1.5)
		add_child(barrel)

## Stage 6 决战甲板：木舱壁、拱形铁栅门、右上高台、甲板。
func _build_final_deck(stage_data: Dictionary) -> void:
	var half_w: float = float(M2Data.m2_base().get("screen_half_width", 7.6))
	## 沙色木纹甲板。
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(half_w * 2.5, 8.0)
	floor.mesh = plane
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.55, 0.42, 0.26)
	floor.material_override = fmat
	add_child(floor)
	## 木板舱壁（两侧背景）。
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.38, 0.26, 0.16)
	for side in [-1, 1]:
		var wall := MeshInstance3D.new()
		var wbox := BoxMesh.new()
		wbox.size = Vector3(0.3, 3.2, 8.0)
		wall.mesh = wbox
		wall.material_override = wall_mat
		wall.position = Vector3(side * (half_w - 0.2), 1.6, 0.0)
		add_child(wall)
	## 拱形铁栅门（中后景）。
	var gate_mat := StandardMaterial3D.new()
	gate_mat.albedo_color = Color(0.3, 0.3, 0.32)
	var gate := MeshInstance3D.new()
	var gbox := BoxMesh.new()
	gbox.size = Vector3(2.6, 2.8, 0.3)
	gate.mesh = gbox
	gate.material_override = gate_mat
	gate.position = Vector3(0.0, 1.4, -3.0)
	add_child(gate)
	## 右上高台（Tinker Bell 位置）。
	var platform_mat := StandardMaterial3D.new()
	platform_mat.albedo_color = Color(0.5, 0.34, 0.2)
	var platform := MeshInstance3D.new()
	var pbox := BoxMesh.new()
	pbox.size = Vector3(2.0, 0.3, 1.6)
	platform.mesh = pbox
	platform.material_override = platform_mat
	platform.position = Vector3(4.0, 1.6, -1.0)
	add_child(platform)
	## 木架（后景，鳄鱼登场位置）。
	var rack_mat := StandardMaterial3D.new()
	rack_mat.albedo_color = Color(0.42, 0.28, 0.16)
	var rack := MeshInstance3D.new()
	var rbox := BoxMesh.new()
	rbox.size = Vector3(2.2, 1.4, 0.4)
	rack.mesh = rbox
	rack.material_override = rack_mat
	rack.position = Vector3(-3.5, 0.7, -2.5)
	add_child(rack)
	## 绳网装饰。
	var rope_mat := StandardMaterial3D.new()
	rope_mat.albedo_color = Color(0.6, 0.5, 0.35)
	for i in 4:
		var rope := MeshInstance3D.new()
		var rcyl := CylinderMesh.new()
		rcyl.radius = 0.04
		rcyl.height = 2.0
		rope.mesh = rcyl
		rope.material_override = rope_mat
		rope.position = Vector3(-half_w + 1.0 + i * 0.6, 1.8, -1.5)
		add_child(rope)
