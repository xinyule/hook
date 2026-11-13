extends Node3D

# M1 arena: builds a 3D greybox corridor, drives one deterministic 60 Hz
# simulation tick, resolves hits, and runs a headless self-test when the
# game is launched with `-- --selftest`.

const PlayerScript = preload("res://scripts/m1/m1_player.gd")
const EnemyScript = preload("res://scripts/m1/m1_enemy.gd")

var player: M1Player
var enemies: Array = []
var camera: Camera3D
var hud_label: Label
var combat: Dictionary = {}
var balance: Dictionary = {}
var half_width: float = 7.6
var selftest: bool = false
var frame_count: int = 0

func _ready() -> void:
    _ensure_input_actions()
    combat = M1Data.combat()
    balance = M1Data.balance()
    half_width = float(combat.get("screen_half_width_m", 7.6))
    var user_args: PackedStringArray = OS.get_cmdline_user_args()
    selftest = user_args.has("--selftest") or OS.get_cmdline_args().has("--selftest")
    M1Data.logic_only = selftest
    _build_world()
    _spawn_actors()
    _build_hud()
    if selftest:
        run_selftest()

func _ensure_input_actions() -> void:
    var defs: Dictionary = {
        "p1_left": [KEY_A, KEY_LEFT],
        "p1_right": [KEY_D, KEY_RIGHT],
        "p1_attack": [KEY_J],
        "p1_jump": [KEY_K],
        "p1_restart": [KEY_R],
    }
    for action in defs:
        if not InputMap.has_action(action):
            InputMap.add_action(action, 0.2)
        for keycode in defs[action]:
            var ev := InputEventKey.new()
            ev.physical_keycode = int(keycode)
            InputMap.action_add_event(action, ev)

func _box(parent: Node, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
    var inst := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    inst.mesh = mesh
    inst.position = pos
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.9
    inst.material_override = mat
    parent.add_child(inst)
    return inst

func _build_world() -> void:
    var world := Node3D.new()
    world.name = "World"
    add_child(world)

    if not M1Data.logic_only:
        var we := WorldEnvironment.new()
        var env := Environment.new()
        env.background_mode = Environment.BG_COLOR
        env.background_color = Color(0.10, 0.14, 0.20)
        env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
        env.ambient_light_color = Color(0.65, 0.70, 0.80)
        env.ambient_light_energy = 0.9
        we.environment = env
        world.add_child(we)

        var light := DirectionalLight3D.new()
        light.rotation_degrees = Vector3(-35, -30, 0)
        light.light_energy = 1.2
        world.add_child(light)

        _box(world, Vector3(half_width * 2.0 + 2.0, 0.3, 4.0), Vector3(0, -0.15, 0), Color(0.32, 0.28, 0.24))
        for side in [-1.0, 1.0]:
            _box(world, Vector3(0.4, 3.0, 4.0), Vector3(side * (half_width + 0.2), 1.5, 0), Color(0.45, 0.30, 0.22))
        # A few background pillars make the 3D depth readable.
        for i in range(5):
            var x: float = -6.0 + float(i) * 3.0
            _box(world, Vector3(0.35, 2.4, 0.35), Vector3(x, 1.2, -1.6), Color(0.22, 0.26, 0.33))

    camera = Camera3D.new()
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = 9.0
    camera.position = Vector3(0, 3.2, 12.0)
    camera.rotation_degrees = Vector3(-8, 0, 0)
    world.add_child(camera)

func _spawn_actors() -> void:
    player = PlayerScript.new()
    player.name = "Player"
    add_child(player)
    player.setup_player(self)
    player.position = Vector3(-3.0, 0, 0)

    var variants: Array = ["white_blue", "blue_white", "green_red"]
    var xs: Array = [2.0, 4.0, 6.0]
    for i in range(3):
        var enemy = EnemyScript.new()
        enemy.name = "Grunt%d" % (i + 1)
        add_child(enemy)
        enemy.setup_enemy(player, str(variants[i]))
        enemy.position = Vector3(float(xs[i]), 0, 0)
        enemies.append(enemy)

func _build_hud() -> void:
    var layer := CanvasLayer.new()
    layer.name = "HUD"
    add_child(layer)
    hud_label = Label.new()
    hud_label.position = Vector2(20, 16)
    hud_label.add_theme_font_size_override("font_size", 20)
    hud_label.modulate = Color(0.95, 0.97, 1.0)
    layer.add_child(hud_label)

func _physics_process(delta: float) -> void:
    if selftest:
        return
    if Input.is_action_just_pressed("p1_restart"):
        _reset()
        return
    if Input.is_action_just_pressed("ui_cancel"):
        get_tree().quit()
        return
    var input: Dictionary = {
        "left": Input.is_action_pressed("p1_left"),
        "right": Input.is_action_pressed("p1_right"),
        "attack": Input.is_action_just_pressed("p1_attack"),
        "jump": Input.is_action_just_pressed("p1_jump"),
    }
    simulate_tick(input, delta)

func simulate_tick(input: Dictionary, delta: float) -> void:
    frame_count += 1
    player.tick(input, delta, enemies)
    for enemy in enemies:
        enemy.tick(delta)
    _update_camera()
    _update_hud()

func register_player_hit(p: M1Player, data: Dictionary, hit_id: int) -> void:
    var hitbox: AABB = p.current_hitbox()
    for enemy in enemies:
        if enemy.is_dead or enemy.state == "Grabbed":
            continue
        if p.hit_enemies.has(enemy.get_instance_id()):
            continue
        if not hitbox.intersects(enemy.hurtbox()):
            continue
        p.hit_enemies.append(enemy.get_instance_id())
        var dmg: float = p.base_damage * float(data.get("damage_mult", 1.0)) * p.power
        var heavy: bool = bool(data.get("heavy", false))
        enemy.take_damage(dmg, float(data.get("knockback_m", 0.6)), heavy, p.facing)
        var cb: Dictionary = balance.get("combat", {})
        var key: String = "hitstop_heavy_frames" if heavy else "hitstop_light_frames"
        var hs: int = int(cb.get(key, 4))
        p.hitstop_frames = hs
        enemy.hitstop_frames = hs
        p.combo_count += 1

func _update_camera() -> void:
    var target_x: float = clampf(player.position.x, -half_width + 4.0, half_width - 4.0)
    camera.position.x = lerpf(camera.position.x, target_x, 0.12)

func _update_hud() -> void:
    var alive: int = 0
    for enemy in enemies:
        if not enemy.is_dead:
            alive += 1
    hud_label.text = "%s | HP %d/%d | state=%s | combo=%d | enemies=%d\n%s" % [
        player.actor_name, int(player.hp), int(player.max_hp), player.state,
        player.combo_count, alive, M1Data.arena_text("hint")
    ]

func _reset() -> void:
    player.reset_player()
    for i in range(enemies.size()):
        enemies[i].reset_enemy(2.0 + float(i) * 2.0)

# ---------------------------------------------------------------- selftest

func _step(input: Dictionary, times: int) -> void:
    for i in range(times):
        simulate_tick(input, 1.0 / 60.0)

func _check(cond: bool, label: String, results: Array) -> bool:
    results.append(("PASS " if cond else "FAIL ") + label)
    return cond

func run_selftest() -> void:
    var results: Array = []
    var ok: bool = true
    var idle: Dictionary = {"left": false, "right": false, "attack": false, "jump": false}

    # 1. Frame table and core rules come from data, not code.
    var table: Dictionary = combat.get("attack_table", {})
    var expected: Dictionary = {
        "Attack1": 8, "Attack2": 9, "Attack3": 10, "Special": 16,
        "Heavy": 22, "JumpAttack": 12, "GrabHit": 9
    }
    for key in expected:
        var present: bool = table.has(key) and int(table[key].get("total_frames", 0)) == int(expected[key])
        ok = _check(present, "frame_table." + str(key) + "=" + str(expected[key]), results) and ok
    var grab_cfg: Dictionary = combat.get("grab", {})
    ok = _check(int(grab_cfg.get("max_hits", 0)) == 5, "grab.max_hits=5", results) and ok
    ok = _check(int(balance.get("combat", {}).get("combo_cancel_window_frames", 0)) == 8, "combo_window=8f", results) and ok

    # 2. A single attack advances and returns to Idle.
    _reset()
    player._begin_attack("Attack1")
    _step(idle, 9)
    ok = _check(player.state == "Idle", "attack_state_returns_idle", results) and ok

    # 3. Four-hit fast combo ends in Special; slow 4th input ends in Heavy.
    _reset()
    player._begin_attack("Attack1")
    player.combo_queued = true
    _step(idle, 9)
    ok = _check(player.state == "Attack2", "combo.Attack1->Attack2", results) and ok
    player.combo_queued = true
    _step(idle, 10)
    ok = _check(player.state == "Attack3", "combo.Attack2->Attack3", results) and ok
    player.combo_queued = true
    _step(idle, 11)
    ok = _check(player.state == "Special", "combo.fast_4th=Special", results) and ok

    _reset()
    player._begin_attack("Attack3")
    _step(idle, 11)
    ok = _check(player.state == "ComboWait", "combo.slow_wait_state", results) and ok
    _step(idle, 12)
    player.push_input("attack")
    _step(idle, 1)
    ok = _check(player.state == "Heavy", "combo.slow_4th=Heavy", results) and ok

    # 4. Grab: 5th hit automatically throws the target.
    _reset()
    var target: M1Actor = enemies[0]
    target.position.x = player.position.x + 0.5
    player.push_input("attack")
    _step(idle, 1)
    ok = _check(player.state == "Grab", "grab.enters_on_close_attack", results) and ok
    for i in range(4):
        player.push_input("attack")
        _step(idle, 10)
    ok = _check(player.grab_hits == 4, "grab.4_hits_counted", results) and ok
    player.push_input("attack")
    _step(idle, 1)
    ok = _check(player.state == "Throw", "grab.5th_auto_throw", results) and ok
    ok = _check(target.is_thrown or target.is_dead, "grab.target_launched", results) and ok

    # 5. Jump attack.
    _reset()
    player.push_input("jump")
    _step(idle, 1)
    ok = _check(player.state == "Jump", "jump.enters", results) and ok
    player.push_input("attack")
    _step(idle, 1)
    ok = _check(player.state == "JumpAttack", "jump.attack=JumpAttack", results) and ok

    # 6. grunt dies in 3 light hits (data: hp 20, base_damage 7).
    _reset()
    var victim: M1Actor = enemies[0]
    for i in range(3):
        victim.take_damage(player.base_damage, 0.0, false, 1)
    ok = _check(victim.is_dead, "grunt.3_hits_kill", results) and ok

    # 7. Solid screen boundary: no penetration, still reachable for wall-lock.
    _reset()
    var wall_enemy: M1Actor = enemies[0]
    wall_enemy.position.x = half_width - 0.1
    wall_enemy.vx = 12.0
    for i in range(10):
        wall_enemy.integrate(1.0 / 60.0)
    ok = _check(wall_enemy.position.x <= half_width + 0.001, "wall.no_penetration", results) and ok
    player.position.x = wall_enemy.position.x - 0.6
    player.facing = 1
    ok = _check(player.current_hitbox().intersects(wall_enemy.hurtbox()), "wall.lock_hitbox_reachable", results) and ok

    # 8. 120 deterministic ticks with mixed input, no crash / no state leak.
    _reset()
    var before: int = frame_count
    for i in range(120):
        var input: Dictionary = idle.duplicate()
        input["right"] = (i % 2 == 0)
        input["attack"] = (i % 17 == 0)
        input["jump"] = (i % 31 == 0)
        simulate_tick(input, 1.0 / 60.0)
    ok = _check(frame_count - before == 120, "smoke.120_ticks", results) and ok
    ok = _check(player.position.x <= half_width and player.position.x >= -half_width, "smoke.player_in_bounds", results) and ok

    var all_ok: bool = true
    for line in results:
        if str(line).begins_with("FAIL"):
            all_ok = false
    print("=== M1 SELFTEST ===")
    for line in results:
        print("  ", line)
    print("SELFTEST PASS" if all_ok else "SELFTEST FAIL")
    get_tree().quit(0 if all_ok else 1)
