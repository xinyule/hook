class_name M1Enemy
extends M1Actor

# M1 grunt: fast, fragile dagger soldier. Three colour variants share behaviour.

var ai: Dictionary = {}
var player: M1Actor
var attack_done: bool = false
var hit_id_counter: int = 0
var variant_id: String = "white_blue"

func setup_enemy(p: M1Actor, variant: String) -> void:
    var cfg: Dictionary = M1Data.enemy("grunt")
    var bal: Dictionary = M1Data.balance()
    var cmb: Dictionary = M1Data.combat()
    var colors: Dictionary = cmb.get("variant_colors", {})
    var rgb: Array = colors.get(variant, [0.9, 0.9, 0.9])
    var col := Color(float(rgb[0]), float(rgb[1]), float(rgb[2]))
    setup("grunt", cfg, bal, cmb, 1, col)
    player = p
    ai = cmb.get("enemy_grunt", {})
    variant_id = variant
    set_state("Approach")

func on_wall_hit() -> void:
    if not is_thrown:
        return
    var grab: Dictionary = combat.get("grab", {})
    var max_bounce: int = int(grab.get("wall_bounce_count", 1))
    if throw_bounces >= max_bounce:
        vx = 0.0
        return
    throw_bounces += 1
    vx = -vx * 0.7
    facing = -facing

func tick(delta: float) -> void:
    if hitstop_frames > 0:
        hitstop_frames -= 1
        return
    if invincible_frames > 0:
        invincible_frames -= 1
    if is_dead:
        vx = 0.0
        integrate(delta)
        return
    if is_thrown:
        integrate(delta)
        return
    if is_downed:
        knockdown_frames -= 1
        vx = move_toward(vx, 0.0, 12.0 * delta)
        integrate(delta)
        if knockdown_frames <= 0:
            is_downed = false
            invincible_frames = 10
            set_state("Approach")
        return
    if hurt_frames > 0:
        hurt_frames -= 1
        vx = move_toward(vx, 0.0, 10.0 * delta)
        integrate(delta)
        if hurt_frames <= 0:
            set_state("Approach")
        return
    if state == "Grabbed":
        vx = 0.0
        integrate(delta)
        return
    _ai_tick(delta)
    integrate(delta)

func _ai_tick(delta: float) -> void:
    tick_state()
    var dx: float = player.position.x - position.x
    var dist: float = absf(dx)
    var speed: float = float(ai.get("speed_mps", 2.2))
    var attack_range: float = float(ai.get("attack_range_m", 0.9))
    match state:
        "Approach":
            if dist > attack_range and not player.is_dead:
                facing = 1 if dx > 0 else -1
                vx = float(facing) * speed
            else:
                vx = 0.0
                attack_done = false
                set_state("Windup")
        "Windup":
            vx = 0.0
            if state_frames >= int(ai.get("windup_frames", 6)):
                attack_done = false
                set_state("EnemyAttack")
        "EnemyAttack":
            vx = 0.0
            if not attack_done and state_frames >= 1:
                attack_done = true
                hit_id_counter += 1
                if dist <= attack_range + 0.2 and not player.is_dead:
                    player.take_damage(float(ai.get("damage", 5)), float(ai.get("knockback_m", 0.8)), false, facing)
                    player.hitstop_frames = 4
                    hitstop_frames = 4
            if state_frames >= int(ai.get("attack_frames", 4)):
                set_state("Recover")
        "Recover":
            vx = -float(facing) * speed * 0.4
            if state_frames >= int(ai.get("recover_frames", 20)):
                set_state("Approach")
        _:
            set_state("Approach")

func reset_enemy(x: float) -> void:
    reset_actor(x)
    attack_done = false
    state = "Approach"
    state_frames = 0
