## M2 基础角色类。
## 扩展 M1 的状态机骨架，新增：格挡状态、倒地追击计数、
## 命中停顿分级（轻/重/必杀）、屏幕震动与粒子钩子。
## 所有数值从 data/*.json 读取，不在脚本中硬编码。
extends Node3D
class_name M2Actor

## ---- 数据缓存 ----
var cfg: Dictionary = {}
var balance: Dictionary = {}
var combat: Dictionary = {}
var m2: Dictionary = {}
var ai: Dictionary = {}

## ---- 生命与状态 ----
var max_hp: int = 100
var hp: int = 100
var facing: int = 1                  ## 1=右 -1=左
var state: String = "idle"
var state_frames: int = 0
var hitstop_frames: int = 0          ## 命中停顿剩余帧（受分级控制）
var hurt_frames: int = 0
var knockdown_frames: int = 0
var invincible_frames: int = 0
var on_floor: bool = true
var is_dead: bool = false
var is_downed: bool = false
var is_thrown: bool = false
var throw_bounces: int = 0

## ---- 移动 ----
var vx: float = 0.0
var vy: float = 0.0
var half_width: float = 0.3

## ---- M2 新增：格挡 / 倒地追击 / 必杀 ----
var is_blocking: bool = false
var block_frames: int = 0
var downed_hits: int = 0             ## 当前倒地目标已被连击数
var downed_refresh: int = 0          ## 倒地连击刷新计时
var is_ulting: bool = false
var ultimate_frames: int = 0
var is_wall_jumping: bool = false
var wall_jump_bounces: int = 0

## ---- 视觉 ----
var _visual: Node3D = null
var _hit_id: int = 0
var hit_id_counter: int = 0          ## 全局命中 id 生成（子类共用）

## 角色配置 id（玩家用角色 id，敌人用模板 id）。
var actor_id: String = ""

func setup(id: String, hp_override: int = 0) -> void:
	actor_id = id
	cfg = M2Data.character(id)
	if cfg.is_empty():
		cfg = M2Data.enemy(id)
	m2 = M2Data.character_moves(id)
	balance = M2Data.balance()
	combat = M2Data.combat()
	ai = cfg.get("ai", {})
	var base := M2Data.m2_base()
	max_hp = hp_override if hp_override > 0 else int(cfg.get("hp", 100))
	hp = max_hp
	half_width = float(cfg.get("half_width", base.get("actor_half_width", 0.3)))
	if not M2Data.logic_only:
		_build_visual()

## 构建 3D 视觉占位（胶囊 + 朝向标记）。
func _build_visual() -> void:
	_visual = Node3D.new()
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = half_width
	cap.height = float(cfg.get("visual_height", 1.6))
	body.mesh = cap
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(cfg.get("color", Color.WHITE))
	body.material_override = mat
	_visual.add_child(body)
	var marker := MeshInstance3D.new()
	var cone := SphereMesh.new()
	cone.radius = half_width * 0.6
	cone.height = 0.3
	marker.mesh = cone
	var mmat := StandardMaterial3D.new()
	mmat.albedo_color = Color(0.2, 0.2, 0.2)
	marker.material_override = mmat
	marker.position.z = float(cfg.get("visual_height", 1.6)) * 0.5 + 0.15
	_visual.add_child(marker)
	add_child(_visual)

## 设置状态并重置帧计数。
func set_state(new_state: String) -> void:
	if state == new_state:
		return
	state = new_state
	state_frames = 0

## 每帧推进状态帧计数。
func tick_state() -> void:
	if hitstop_frames > 0:
		hitstop_frames -= 1
		return
	state_frames += 1
	if hurt_frames > 0:
		hurt_frames -= 1
	if knockdown_frames > 0:
		knockdown_frames -= 1
		if knockdown_frames == 0 and is_downed:
			is_downed = false
	if invincible_frames > 0:
		invincible_frames -= 1
	if block_frames > 0:
		block_frames -= 1
		if block_frames == 0:
			is_blocking = false
	if is_ulting:
		ultimate_frames -= 1
		if ultimate_frames <= 0:
			is_ulting = false
	if is_wall_jumping:
		if wall_jump_bounces <= 0 and on_floor:
			is_wall_jumping = false

## 平面位移积分（z 锁定为 0，2.5D 判定）。
func integrate(dt: float) -> void:
	if hitstop_frames > 0:
		return
	var pos := global_position
	pos.x += vx * dt
	pos.y += vy * dt
	if not on_floor:
		vy -= float(M2Data.m2_base().get("gravity", 26.0)) * dt
	if pos.y <= 0.0:
		pos.y = 0.0
		vy = 0.0
		if not on_floor:
			on_floor = true
	global_position = pos

## 撞墙回调：反弹、清速、墙跳触发。
func on_wall_hit() -> void:
	vx = 0.0
	if is_wall_jumping:
		wall_jump_bounces -= 1
		if wall_jump_bounces <= 0:
			is_wall_jumping = false
			vx = -facing * float(M2Data.m2_base().get("move_speed_mps", 4.2))

## 完成一次投掷（落地或撞墙后）。
func _finish_throw() -> void:
	is_thrown = false
	throw_bounces = 0
	vx = 0.0
	vy = 0.0
	set_state("hurt")
	hurt_frames = int(combat.get("hurt_lock", 12))

## 受击盒（2D 平面矩形）。
func hurtbox() -> Rect2:
	var w := half_width * 2.0
	var h := float(cfg.get("hurt_depth", 0.6))
	return Rect2(global_position.x - w * 0.5, global_position.y - h * 0.5, w, h)

## 攻击盒（根据当前招式帧生成）。
func hitbox(active: bool) -> Rect2:
	if not active:
		return Rect2()
	var table: Dictionary = m2.get("attack_table", {})
	var atk: Dictionary = table.get(state, {})
	var range := float(atk.get("reach_m", m2.get("reach_m", 0.8)))
	var depth := float(atk.get("depth_m", 0.6))
	var x := global_position.x + facing * (half_width + range * 0.5)
	var y := global_position.y - depth * 0.5
	return Rect2(x - range * 0.5, y, range, depth)

## 受伤处理。返回是否成功受伤（被格挡/无敌则返回 false）。
func take_damage(dmg: int, src_facing: int, knockback: float, hit_id: int) -> bool:
	if invincible_frames > 0 or is_dead:
		return false
	## 格挡判定：面朝攻击者且处于格挡状态。
	if is_blocking and facing == -src_facing:
		var blk := M2Data.block_cfg()
		var reduced := int(dmg * float(blk.get("damage_multiplier", 0.2)))
		hp -= reduced
		knockback *= float(blk.get("knockback_multiplier", 0.3))
		_on_block_fx()
		return false
	## 命中去重：同一招式对同一目标只生效一次。
	if M2Data.hitbox_cfg().get("hit_dedup", true) and hit_id == _hit_id:
		return false
	_hit_id = hit_id
	hp -= dmg
	hurt_frames = int(combat.get("hurt_lock", 12))
	invincible_frames = int(combat.get("invincible_frames", 0))
	## 命中停顿分级。
	var hs := M2Data.hitstop_cfg()
	var tier := "light"
	if dmg >= 25:
		tier = "heavy"
	if is_ulting or src_facing == 0:
		tier = "ultimate"
	hitstop_frames = int(hs.get(tier, hs.get("light", 4)))
	## 击退。
	vx = src_facing * knockback
	if knockback > 1.5:
		is_downed = true
		knockdown_frames = int(combat.get("knockdown_frames", 30))
	if hp <= 0:
		hp = 0
		is_dead = true
	set_state("hurt")
	return true

## 格挡视觉反馈钩子（由 arena 填充屏幕特效）。
func _on_block_fx() -> void:
	pass

## 开始被投掷：进入投掷状态并设置初速。
func start_throw(dir: int) -> void:
	is_thrown = true
	throw_bounces = 0
	vx = dir * 6.0
	vy = 4.0
	on_floor = false
	set_state("thrown")
	invincible_frames = int(combat.get("throw_invincible", 10))

## 重置角色到初始状态。
func reset_actor() -> void:
	hp = max_hp
	state = "idle"
	state_frames = 0
	hitstop_frames = 0
	hurt_frames = 0
	knockdown_frames = 0
	invincible_frames = 0
	on_floor = true
	is_dead = false
	is_downed = false
	is_thrown = false
	is_blocking = false
	is_ulting = false
	vx = 0.0
	vy = 0.0
	global_position = Vector3(_spawn_x, 0.0, 0.0)

var _spawn_x: float = 0.0
func set_spawn(x: float) -> void:
	_spawn_x = x
