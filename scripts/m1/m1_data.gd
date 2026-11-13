class_name M1Data
extends RefCounted

# Central access to the data-driven M1 configuration. Nothing gameplay-related
# is hard-coded in the logic scripts; every number comes from res://data/.

const ROOT: String = "res://data/"

# When true (headless --selftest), skip building 3D meshes so the dummy
# rendering backend does not emit cleanup noise. Logic stays identical.
static var logic_only: bool = false

static func _read(path: String) -> Dictionary:
    var file: FileAccess = FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_error("[M1Data] cannot open " + path)
        return {}
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    var out: Dictionary = parsed if parsed is Dictionary else {}
    return out

static func balance() -> Dictionary:
    return _read(ROOT + "balance.json")

static func combat() -> Dictionary:
    return _read(ROOT + "combat_m1.json")

static func characters() -> Dictionary:
    return _read(ROOT + "characters.json")

static func enemies() -> Dictionary:
    return _read(ROOT + "enemies.json")

static func names_a() -> Dictionary:
    return _read(ROOT + "packs/internal_reference/names_a.json")

static func character(id: String) -> Dictionary:
    for entry in characters().get("characters", []):
        if entry.get("id", "") == id:
            return entry
    return {}

static func enemy(id: String) -> Dictionary:
    for entry in enemies().get("templates", []):
        if entry.get("id", "") == id:
            return entry
    return {}

static func display_name(id: String) -> String:
    var mapping: Dictionary = names_a().get("map", {})
    return str(mapping.get(id, id))

static func arena_text(key: String) -> String:
    var block: Dictionary = names_a().get("arena_m1", {})
    return str(block.get(key, ""))
