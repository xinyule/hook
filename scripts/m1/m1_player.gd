class_name M1Player
extends M1Actor

# M1 player state machine: four-hit combo (fast -> Special, slow -> Heavy),
# grab with auto-throw on the 5th hit, jump attack, wall-lock friendly knockback.

var arena: Node
var input_queue: Array = []
var combo_queued: bool = false
var last_attack_tick: int = -999
var global_tick: int = 0
var grab_hits: int = 0
var grab_target: M1Actor = null
var active_hit: Dictionary = {}
var attack_started: bool = false
var hit_id_counter: int = 0
var hit_enemies: Array = []
var combo_count: int = 0

var move_speed: float = 4.2
var jump_speed: float = 9.0
var base_damage: float = 7.0
var power: float = 1.0
var reach: float = 1.0
var grab_range: float = 0.9
var buffer_frames: int = 3
var combo_window: int = 8
var combo_slow: int = 18
var grab_max: int = 5
var attacks: Dictionary = {}

func setup_player(a: Node) -> void:
    var cfg: Dictionary = M1Data.character("hero_01")
    var bal: Dictionary = M1Data.balance()
    var cmb: Dictionary = M1Data.combat()
    setup("hero_01", cfg, bal, cmb, 0, Color(0.25, 0.75, 0.42))
    arena = a
    move_speed = float(cmb.get("move_speed_mps", 4.2))
    jump_speed = float(cmb.get("jump_speed_mps", 9.0))
    base_damage = float(cmb.get("base_damage", 7.0))
    grab_range = float(cmb.get("grab_range_m", 0.9))
    buffer_frames = int(cmb.get("input_buffer_frames", 3))
    attacks = cmb.get("attack_table", {})
    power = float(cfg.get("power", 1.0))
    reach = float(cfg.get("reach", 1.0))
    var cb: Dictionary = bal.get("combat", {})
    combo_window = int(cb.get("combo_cancel_window_frames", 8))
    combo_slow = int(cb.get("combo_slow_threshold_frames", 18))
    var sp: Dictionary = bal.get("special", {})
    grab_max = int(sp.get("grab_max_hits", 5))

func push_input(action: String) -> void:
    input_queue.append({"action": action, "ttl": buffer_frames})

func _decay_input() -> void:
    var kept: Array = []
    for item in input_queue:
        var ttl: int = int(item.get("ttl", 0)) - 1
        if ttl >= 0:
            item["ttl"] = ttl
            kept.append(item)
    input_queue = kept

func _consume(action: String) -> bool:
    for i in range(input_queue.size()):
        if str(input_queue[i].get("action", "")) == action:
            input_queue.remove_at(i)
            return true
    return false

func current_hitbox() -> AABB:
    var w: float = 1.0 * reach
    var cx: float = position.x + float(facing) * (0.55 * reach)
    return AABB(Vector3(cx - w * 0.5, position.y + 0.25, -0.5), Vector3(w, 1.2, 1.0))

func tick(input: Dictionary, delta: float, enemies: Array) -> void:
    global_tick += 1
    if bool(input.get("attack", false)):
        push_input("attack")
    if bool(input.get("jump", false)):
        push_input("jump")
    _decay_input()
    if hitstop_frames > 0:
        hitstop_frames -= 1
        return
    if invincible_frames > 0:
        invincible_frames -= 1
    if is_dead:
        vx = 0.0
        integrate(delta)
        return
    if is_downed:
        knockdown_frames -= 1
        vx = move_toward(vx, 0.0, 12.0 * delta)
        integrate(delta)
        if knockdown_frames <= 0:
            is_downed = false
            var cb: Dictionary = balance.get("combat", {})
            invincible_frames = int(cb.get("getup_invincible_frames", 10))
            set_state("Idle")
        return
    if hurt_frames > 0:
        hurt_frames -= 1
        vx = move_toward(vx, 0.0, 10.0 * delta)
        integrate(delta)
        if hurt_frames <= 0:
            set_state("Idle")
        return
    _handle_state(input, delta, enemies)
    integrate(delta)

func _handle_state(input: Dictionary, delta: float, enemies: Array) -> void:
    tick_state()
    var left: bool = bool(input.get("left", false))
    var right: bool = bool(input.get("right", false))
    var dir: int = int(right) - int(left)
    match state:
        "Idle", "Walk":
            vx = float(dir) * move_speed
            if dir != 0:
                facing = dir
                set_state("Walk")
            else:
                set_state("Idle")
            if _consume("jump"):
                on_floor = false
                vy = jump_speed
                set_state("Jump")
            elif _consume("attack"):
                _try_start_attack(enemies)
        "Jump":
            vx = float(dir) * move_speed * 0.9
            if dir != 0:
                facing = dir
            if _consume("attack"):
                _begin_attack("JumpAttack")
            elif on_floor:
                set_state("Idle")
        "Attack1", "Attack2", "Attack3", "Special", "Heavy", "JumpAttack", "GrabHit":
            _advance_attack()
        "ComboWait":
            vx = 0.0
            if _consume("attack"):
                var gap: int = global_tick - last_attack_tick
                combo_queued = false
                _begin_attack("Heavy" if gap > combo_slow else "Special")
            elif state_frames >= combo_slow:
                set_state("Idle")
        "Grab":
            vx = 0.0
            _advance_grab()
        "Throw":
            vx = 0.0
            if state_frames >= 10:
                set_state("Idle")
        _:
            set_state("Idle")

func _nearest_enemy(enemies: Array) -> M1Actor:
    var best: M1Actor = null
    var best_d: float = 999.0
    for e in enemies:
        if e == null or e.is_dead:
            continue
        var d: float = absf(e.position.x - position.x)
        if d < best_d:
            best_d = d
            best = e
    return best

func _try_start_attack(enemies: Array) -> void:
    var target: M1Actor = _nearest_enemy(enemies)
    if target != null and absf(target.position.x - position.x) <= grab_range:
        facing = 1 if target.position.x >= position.x else -1
        grab_target = target
        grab_hits = 0
        target.set_state("Grabbed")
        set_state("Grab")
        return
    combo_queued = false
    _begin_attack("Attack1")

func _begin_attack(attack_name: String) -> void:
    var data: Dictionary = attacks.get(attack_name, {})
    if data.is_empty():
        return
    active_hit = data
    hit_id_counter += 1
    hit_enemies.clear()
    attack_started = false
    vx = 0.0
    last_attack_tick = global_tick
    set_state(attack_name)

func _advance_attack() -> void:
    var data: Dictionary = active_hit
    var total: int = int(data.get("total_frames", 8))
    var active_frame: int = int(data.get("active_frame", 3))
    if state_frames == active_frame and not attack_started:
        attack_started = true
        if arena != null:
            arena.register_player_hit(self, data, hit_id_counter)
    if _consume("attack") and state_frames <= active_frame + combo_window:
        combo_queued = true
    if state_frames < total:
        return
    active_hit = {}
    attack_started = false
    var next_name: String = str(data.get("next", ""))
    if state == "JumpAttack":
        combo_queued = false
        if not on_floor:
            set_state("Jump")
        else:
            set_state("Idle")
        return
    if state == "GrabHit":
        combo_queued = false
        if grab_target != null and not grab_target.is_dead:
            set_state("Grab")
        else:
            grab_target = null
            set_state("Idle")
        return
    if next_name == "Attack4":
        if combo_queued:
            combo_queued = false
            var gap: int = global_tick - last_attack_tick
            _begin_attack("Heavy" if gap > combo_slow else "Special")
        else:
            set_state("ComboWait")
        return
    if next_name != "" and combo_queued:
        combo_queued = false
        _begin_attack(next_name)
        return
    combo_queued = false
    set_state("Idle")

func _advance_grab() -> void:
    if grab_target == null or grab_target.is_dead:
        grab_target = null
        set_state("Idle")
        return
    grab_target.position.x = position.x + float(facing) * 0.75
    grab_target.position.y = 0.0
    grab_target.vx = 0.0
    grab_target.set_state("Grabbed")
    if _consume("attack"):
        grab_hits += 1
        if grab_hits >= grab_max:
            _throw_target()
        else:
            _begin_attack("GrabHit")

func _throw_target() -> void:
    var target: M1Actor = grab_target
    if target == null:
        return
    var grab: Dictionary = combat.get("grab", {})
    var dmg: float = base_damage * float(grab.get("throw_damage_mult", 2.5)) * power
    target.take_damage(dmg, 0.0, true, facing)
    if not target.is_dead:
        target.start_throw(facing)
    grab_target = null
    grab_hits = 0
    combo_queued = false
    set_state("Throw")

func reset_player() -> void:
    reset_actor(-3.0)
    input_queue.clear()
    combo_queued = false
    grab_target = null
    grab_hits = 0
    active_hit = {}
    attack_started = false
    hit_enemies.clear()
    combo_count = 0
    state = "Idle"
    state_frames = 0
