## M7 风格化视觉升级器。
## 把 M2Actor 的灰盒胶囊视觉替换为手绘 Toon 风格的块状模型
## （头 / 躯干 / 双臂 / 双腿 BoxMesh 分块 + 角色专属配色 + 背面外扩描边）。
## 复用 M2 战斗核心不改：只替换 _visual 节点树，逻辑层零改动。
## 所有数值来自 data/visual_m7.json，不硬编码。
extends Node
class_name M7Visual

## 已升级标记的属性名（挂在 actor 上做幂等判断）。
const UPGRADE_FLAG := "_m7_upgraded"

## 升级指定角色 / 敌人 / Boss 的视觉。幂等：已升级直接返回。
## logic_only（headless 自测）下只做标记与规划，不构建网格。
func upgrade_actor(actor: M2Actor) -> bool:
	if actor == null or not is_instance_valid(actor):
		return false
	if actor.get_meta(UPGRADE_FLAG, false):
		return true
	actor.set_meta(UPGRADE_FLAG, true)
	if M7Data.logic_only:
		return true
	_build_stylized(actor)
	return true

## 规划风格化分块（不创建网格，logic_only 下也可调用，供自测断言）。
## 返回分块字典数组：{type, size, pos, color, outline}。
func plan_parts(actor: M2Actor) -> Array:
	var id := actor.actor_id
	if id.is_empty():
		## 兜底：Boss 等未设 actor_id 时按 boss_id 查调色板。
		var bid = actor.get("boss_id")
		id = str(bid) if bid != null else ""
	var pal := M7Data.palette(id)
	var layout: Dictionary = M7Data.style().get("part_layout", {})
	var primary := _c(pal.get("primary", Color.WHITE))
	var secondary := _c(pal.get("secondary", Color.WHITE))
	var accent := _c(pal.get("accent", Color.WHITE))
	var skin := _c(pal.get("skin", Color.WHITE))
	var torso_y := float(layout.get("torso_y", 0.85))
	var head_y := float(layout.get("head_y", 1.35))
	var arm_y := float(layout.get("arm_y", 0.95))
	var leg_y := float(layout.get("leg_y", 0.3))
	var torso_size := _v3(layout.get("torso_size", Vector3(0.5, 0.55, 0.3)))
	var head_size := _v3(layout.get("head_size", Vector3(0.3, 0.3, 0.3)))
	var arm_size := _v3(layout.get("arm_size", Vector3(0.14, 0.45, 0.14)))
	var leg_size := _v3(layout.get("leg_size", Vector3(0.16, 0.5, 0.16)))
	var parts: Array = []
	parts.append({"type": "box", "size": torso_size, "pos": Vector3(0.0, torso_y, 0.0), "color": primary, "outline": true})
	parts.append({"type": "box", "size": head_size, "pos": Vector3(0.0, head_y, 0.0), "color": skin, "outline": true})
	parts.append({"type": "box", "size": arm_size, "pos": Vector3(-0.32, arm_y, 0.0), "color": secondary, "outline": true})
	parts.append({"type": "box", "size": arm_size, "pos": Vector3(0.32, arm_y, 0.0), "color": secondary, "outline": true})
	parts.append({"type": "box", "size": leg_size, "pos": Vector3(-0.14, leg_y, 0.0), "color": accent, "outline": true})
	parts.append({"type": "box", "size": leg_size, "pos": Vector3(0.14, leg_y, 0.0), "color": accent, "outline": true})
	return parts

## 构建风格化模型并替换 actor._visual。
func _build_stylized(actor: M2Actor) -> void:
	## 拆除 M2 的灰盒视觉。
	if actor._visual != null and is_instance_valid(actor._visual):
		actor._visual.queue_free()
	var style := M7Data.style()
	var outline_scale := float(style.get("outline_scale", 1.06))
	var outline_color := _c(style.get("outline_color", Color(0.1, 0.1, 0.12)))
	var vis := Node3D.new()
	var parts := plan_parts(actor)
	## 躯干必须位于 child(0)：M2Enemy 变体配色依赖 _visual.get_child(0)。
	## 躯干同时设置 material 与 material_override，兼容 (body.material as StandardMaterial3D)。
	var torso_mat := StandardMaterial3D.new()
	var palette_id := actor.actor_id
	if palette_id.is_empty():
		var bid = actor.get("boss_id")
		palette_id = str(bid) if bid != null else ""
	torso_mat.albedo_color = _c(M7Data.palette(palette_id).get("primary", Color.WHITE))
	var torso := MeshInstance3D.new()
	torso.mesh = BoxMesh.new()
	torso.mesh.size = _v3(parts[0].get("size", Vector3(0.5, 0.55, 0.3)))
	torso.position = parts[0].get("pos", Vector3.ZERO)
	torso.material = torso_mat
	torso.material_override = torso_mat
	vis.add_child(torso)
	## 其余分块（头 / 臂 / 腿）+ 各自描边。
	for i in range(1, parts.size()):
		var part: Dictionary = parts[i]
		var mesh_inst := MeshInstance3D.new()
		mesh_inst.mesh = BoxMesh.new()
		mesh_inst.mesh.size = _v3(part.get("size", Vector3.ONE))
		mesh_inst.position = _v3(part.get("pos", Vector3.ZERO))
		var mat := StandardMaterial3D.new()
		mat.albedo_color = _c(part.get("color", Color.WHITE))
		mesh_inst.material_override = mat
		vis.add_child(mesh_inst)
		if part.get("outline", true):
			var outline := MeshInstance3D.new()
			outline.mesh = BoxMesh.new()
			outline.mesh.size = _v3(part.get("size", Vector3.ONE)) * outline_scale
			outline.position = _v3(part.get("pos", Vector3.ZERO))
			var omat := StandardMaterial3D.new()
			omat.albedo_color = outline_color
			## 背面外扩描边：关闭剔除（CULL_MODE_DISABLED = 0），渲染背面形成轮廓。
			omat.cull_mode = 0
			outline.material_override = omat
			vis.add_child(outline)
	## 朝向标记（替代 M2 的顶部球体，位于头部前方）。
	var marker := MeshInstance3D.new()
	marker.mesh = BoxMesh.new()
	marker.mesh.size = Vector3(0.1, 0.1, 0.06)
	marker.position = Vector3(0.0, float(M7Data.style().get("part_layout", {}).get("head_y", 1.35)), 0.2)
	var mmat := StandardMaterial3D.new()
	mmat.albedo_color = outline_color
	marker.material_override = mmat
	vis.add_child(marker)
	## 先 add_child 再挂载，避免 Godot 4 未入树设坐标警告。
	actor.add_child(vis)
	actor._visual = vis

## 数组 / 字典取值辅助（容错）。
static func _c(arr) -> Color:
	if arr is Array and arr.size() >= 3:
		return Color(float(arr[0]), float(arr[1]), float(arr[2]), float(arr[3]) if arr.size() >= 4 else 1.0)
	return Color.WHITE

static func _v3(v) -> Vector3:
	if v is Vector3:
		return v
	if v is Array and v.size() >= 3:
		return Vector3(float(v[0]), float(v[1]), float(v[2]))
	return Vector3.ONE
