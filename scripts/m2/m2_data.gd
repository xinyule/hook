## M2 数据访问层。
## 在 M1 的基础上新增 combat_m2.json 读取，
## 为五角色招式表、必杀技、判定打磨参数提供统一入口。
extends RefCounted
class_name M2Data

## 与 M1 相同的逻辑层开关，headless 自测时跳过 3D 视觉构建。
static var logic_only: bool = false

static var _balance: Dictionary = {}
static var _combat: Dictionary = {}
static var _combat_m2: Dictionary = {}
static var _characters: Dictionary = {}
static var _enemies: Dictionary = {}
static var _names_a: Dictionary = {}

static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("[M2Data] missing file: %s" % path)
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("[M2Data] cannot open: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	var out: Dictionary = parsed if parsed is Dictionary else {}
	return out

static func balance() -> Dictionary:
	if _balance.is_empty():
		_balance = _read(ProjectSettings.globalize_path("res://data/balance.json"))
	return _balance

static func combat() -> Dictionary:
	if _combat.is_empty():
		_combat = _read(ProjectSettings.globalize_path("res://data/combat_m1.json"))
	return _combat

static func combat_m2() -> Dictionary:
	if _combat_m2.is_empty():
		_combat_m2 = _read(ProjectSettings.globalize_path("res://data/combat_m2.json"))
	return _combat_m2

static func characters() -> Dictionary:
	if _characters.is_empty():
		_characters = _read(ProjectSettings.globalize_path("res://data/characters.json"))
	return _characters

static func enemies() -> Dictionary:
	if _enemies.is_empty():
		_enemies = _read(ProjectSettings.globalize_path("res://data/enemies.json"))
	return _enemies

static func names_a() -> Dictionary:
	if _names_a.is_empty():
		_names_a = _read(ProjectSettings.globalize_path("res://data/packs/internal_reference/names_a.json"))
	return _names_a

## 取单个角色定义，找不到返回空字典。
static func character(id: String) -> Dictionary:
	var list: Array = characters().get("characters", [])
	for c in list:
		if c.get("id", "") == id:
			return c
	return {}

## 取单个敌人模板，找不到返回空字典。
static func enemy(id: String) -> Dictionary:
	var list: Array = enemies().get("templates", [])
	for e in list:
		if e.get("id", "") == id:
			return e
	return {}

## 角色招式表（来自 combat_m2.json character_moves）。
static func character_moves(id: String) -> Dictionary:
	var cm: Dictionary = combat_m2().get("character_moves", {})
	return cm.get(id, {})

## M2 基础物理参数（速度、重力、抓取范围等）。
static func m2_base() -> Dictionary:
	return combat_m2().get("base", {})

## 必杀技配置。
static func ultimate() -> Dictionary:
	return combat_m2().get("ultimate", {})

## 落地必杀配置。
static func landing_ultimate() -> Dictionary:
	return combat_m2().get("landing_ultimate", {})

## 墙跳配置。
static func wall_jump() -> Dictionary:
	return combat_m2().get("wall_jump", {})

## 空投配置。
static func air_throw() -> Dictionary:
	return combat_m2().get("air_throw", {})

## 背投配置。
static func back_throw() -> Dictionary:
	return combat_m2().get("back_throw", {})

## 倒地追击配置。
static func downed_chase() -> Dictionary:
	return combat_m2().get("downed_chase", {})

## 抓取配置。
static func grab() -> Dictionary:
	return combat_m2().get("grab", {})

## 判定打磨参数。
static func hitbox_cfg() -> Dictionary:
	return combat_m2().get("hitbox", {})

static func hitstop_cfg() -> Dictionary:
	return combat_m2().get("hitstop", {})

static func vfx_cfg() -> Dictionary:
	return combat_m2().get("vfx", {})

static func friendly_fire_cfg() -> Dictionary:
	return combat_m2().get("friendly_fire", {})

static func block_cfg() -> Dictionary:
	return combat_m2().get("block", {})

## 显示名：优先 A 包对照名，否则用 characters.json 的 name。
static func display_name(id: String) -> String:
	var nm: Dictionary = names_a().get("map", {})
	if nm.has(id):
		return nm[id]
	var c: Dictionary = character(id)
	return c.get("name", id)
