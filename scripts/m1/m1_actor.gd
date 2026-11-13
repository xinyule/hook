class_name M1Actor
extends Node3D

# Base for player and enemies. 3D visuals, but position is integrated by hand
# on a locked plane (z = 0) so frame advance is fully deterministic.

var cfg: Dictionary = {}
var balance: Dictionary = {}
var combat: Dictionary = {}
var actor_id: String = ""
var actor_name: String = ""
var team: int = 0

var max_hp: float = 100.0
var hp: float = 100.0
var facing: int = 1
var state: String = "Idle"
var state_frames: int = 0
var hitstop_frames: int = 0
var hurt_frames: int = 0
var knockdown_frames: int = 0
var invincible_frames: int = 0

var on_floor: bool = true
var is_dead: bool = false
var is_downed: bool = false
var is_thrown: bool = false
var throw_bounces: int = 0

var vx: float = 0.0
var vy: float = 0.0
var half_width: float = 7.6

var mesh_inst: MeshInstance3D
var name_label: Label3D

func setup(p_id: String, p_cfg: Dictionary, p_bal: Dictionary, p_combat: Dictionary, p_team: int, body_color: Color) -> void:
    actor_id = p_id
    cfg = p_cfg
    balance = p_bal
    combat = p_combat
    team = p_team
    actor_name = M1Data.display_name(p_id)
    max_hp = float(cfg.get("hp", 100))
    hp = max_hp
    half_width = float(p_combat.get("screen_half_width_m", 7.6))
    _build_visual(body_color)

func _build_visual(body_color: Color) -> void:
    if M1Data.logic_only:
        return
    mesh_inst = MeshInstance3D.new()
    var capsule: CapsuleMesh = CapsuleMesh.new()
    capsule.radius = 0.34
    capsule.height = 1.7
    mesh_inst.mesh = capsule
    mesh_inst.position = Vector3(0, 0.85, 0)
    var mat: StandardMaterial3D = StandardMaterial3D.new()
    mat.albedo_color = body_color
    mat.roughness = 0.85
    mesh_inst.material_override = mat
    add_child(mesh_inst)

    name_label = Label3D.new()
    name_label.text = actor_name
    name_label.position = Vector3(0, 2.15, 0)
    name_label.font_size = 28
    add_child(name_label)

func set_state(next: String) -> void:
    if state == next:
        return
    state = next
    state_frames = 0

func tick_state() -> void:
    state_frames += 1

func integrate(delta: float) -> void:
    position.x += vx * delta
    if not on_floor:
        vy -= float(combat.get("gravity_mps2", 26.0)) * delta
        position.y += vy * delta
        if position.y <= 0.0:
            position.y = 0.0
            vy = 0.0
            on_floor = true
            if is_thrown:
                _finish_throw()
    if position.x >= half_width or position.x <= -half_width:
        position.x = clampf(position.x, -half_width, half_width)
        on_wall_hit()
    position.z = 0.0
    if mesh_inst != null:
        mesh_inst.scale.x = float(facing)
        mesh_inst.rotation.z = (PI * 0.5) if is_downed else 0.0

func on_wall_hit() -> void:
    # Overridden by the enemy to bounce a thrown body once (wall-lock tactic).
    pass

func _finish_throw() -> void:
    is_thrown = false
    throw_bounces = 0
    is_downed = true
    var cb: Dictionary = balance.get("combat", {})
    knockdown_frames = int(cb.get("knockdown_frames", 40))
    set_state("Knockdown")

func hurtbox() -> AABB:
    return AABB(Vector3(position.x - 0.35, position.y + 0.05, -0.35), Vector3(0.7, 1.65, 0.7))

func take_damage(amount: float, knockback: float, heavy: bool, from_facing: int) -> void:
    if is_dead or invincible_frames > 0:
        return
    hp = maxf(0.0, hp - amount)
    vx = knockback * float(from_facing)
    var cb: Dictionary = balance.get("combat", {})
    if hp <= 0.0:
        is_dead = true
        is_downed = true
        is_thrown = false
        vx = 0.0
        set_state("Death")
        return
    if heavy:
        hurt_frames = int(cb.get("hurt_heavy_frames", 24))
        is_downed = true
        knockdown_frames = int(cb.get("knockdown_frames", 40))
        set_state("Knockdown")
    else:
        hurt_frames = int(cb.get("hurt_light_frames", 12))
        set_state("Hurt")

func start_throw(dir: int) -> void:
    var grab: Dictionary = combat.get("grab", {})
    is_thrown = true
    is_downed = false
    throw_bounces = 0
    vx = float(grab.get("throw_vx_mps", 7.0)) * float(dir)
    vy = float(grab.get("throw_vy_mps", 6.0))
    on_floor = false
    set_state("Thrown")

func reset_actor(x: float) -> void:
    position = Vector3(x, 0.0, 0.0)
    vx = 0.0
    vy = 0.0
    hp = max_hp
    facing = 1
    on_floor = true
    is_dead = false
    is_downed = false
    is_thrown = false
    throw_bounces = 0
    hitstop_frames = 0
    hurt_frames = 0
    knockdown_frames = 0
    invincible_frames = 0
    state = "Idle"
    state_frames = 0
    visible = true
