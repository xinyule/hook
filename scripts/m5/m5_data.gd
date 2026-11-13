## M5 数据访问层。
## 在 M3/M4 数据层之上新增 Stage 3-4 的 Boss 招式帧表（bosses_m5.json）
## 与场景机关道具配置（props_m5.json）的读取入口。M2/M3/M4 数据层保持不变。
extends RefCounted
class_name M5Data

## 与 M2/M3/M4 相同的逻辑层开关，headless 自测时跳过 3D 视觉构建。
static var logic_only: bool = false

static var _bosses: Dictionary = {}
static var _props: Dictionary = {}

static func _read(path: String) -> Dictionary:
	## 导出构建中 ProjectSettings.globalize_path 返回文件系统路径，
	## 但资源实际打包在 pck 内。提取 res:// 部分让 FileAccess 走 pck 解析。
	if path.contains("res://"):
		var idx := path.find("res://")
		if idx > 0:
			path = path.substr(idx)
	if not FileAccess.file_exists(path):
		push_error("[M5Data] missing file: %s" % path)
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("[M5Data] cannot open: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	var out: Dictionary = parsed if parsed is Dictionary else {}
	return out

## M5 Boss 数据（bosses_m5.json）。
static func bosses_m5() -> Dictionary:
	if _bosses.is_empty():
		_bosses = _read("res://data/bosses_m5.json")
	return _bosses

## 单个 Boss 配置，找不到返回空字典。
static func boss(id: String) -> Dictionary:
	var all: Dictionary = bosses_m5().get("bosses", {})
	return all.get(id, {})

## Boss 是否为假 Hook（无血条 NPC）。
static func is_fake_boss(id: String) -> bool:
	return bool(boss(id).get("is_fake", false))

## 假 Hook 数量按人数配置。
static func fake_hook_count(player_count: int) -> int:
	var table: Dictionary = boss("boss_03").get("count_by_players", {})
	var key := str(maxi(player_count, 1))
	if table.has(key):
		return int(table[key])
	return int(table.get("1", 2))

## Boss 血条布局参数。
static func boss_bar_cfg() -> Dictionary:
	return bosses_m5().get("boss_bar", {})

## M5 场景机关与道具数据（props_m5.json）。
static func props_m5() -> Dictionary:
	if _props.is_empty():
		_props = _read("res://data/props_m5.json")
	return _props

## 假 Hook 投掷互投配置。
static func fake_hook_cfg() -> Dictionary:
	return props_m5().get("fake_hook", {})

## 彩绘大罐配置。
static func painted_jar_cfg() -> Dictionary:
	return props_m5().get("painted_jar", {})

## 长矛配置。
static func spear_cfg() -> Dictionary:
	return props_m5().get("spear", {})

## 冰柱配置。
static func ice_pillar_cfg() -> Dictionary:
	return props_m5().get("ice_pillar", {})

## 企鹅配置。
static func penguin_cfg() -> Dictionary:
	return props_m5().get("penguin", {})

## 冰面反跳配置。
static func ice_surface_cfg() -> Dictionary:
	return props_m5().get("ice_surface", {})

## 单次攻击对可击碎物件的伤害。
static func break_attack_damage() -> int:
	return int(props_m5().get("break_attack_damage", 12))
