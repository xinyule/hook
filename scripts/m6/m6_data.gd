## M6 数据访问层。
## 在 M3/M4/M5 数据层之上新增 Stage 5-6 的 Boss 招式帧表（bosses_m6.json）
## 与场景机关道具配置（props_m6.json）的读取入口。M2/M3/M4/M5 数据层保持不变。
extends RefCounted
class_name M6Data

## 与 M2/M3/M4/M5 相同的逻辑层开关，headless 自测时跳过 3D 视觉构建。
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
		push_error("[M6Data] missing file: %s" % path)
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("[M6Data] cannot open: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	var out: Dictionary = parsed if parsed is Dictionary else {}
	return out

## M6 Boss 数据（bosses_m6.json）。
static func bosses_m6() -> Dictionary:
	if _bosses.is_empty():
		_bosses = _read("res://data/bosses_m6.json")
	return _bosses

## 单个 Boss 配置，找不到返回空字典。
static func boss(id: String) -> Dictionary:
	var all: Dictionary = bosses_m6().get("bosses", {})
	return all.get(id, {})

## Boss 血条布局参数。
static func boss_bar_cfg() -> Dictionary:
	return bosses_m6().get("boss_bar", {})

## M6 场景机关与道具数据（props_m6.json）。
static func props_m6() -> Dictionary:
	if _props.is_empty():
		_props = _read("res://data/props_m6.json")
	return _props

## 运财小兵配置。
static func treasure_carrier_cfg() -> Dictionary:
	return props_m6().get("treasure_carrier", {})

## 炮台配置。
static func cannon_cfg() -> Dictionary:
	return props_m6().get("cannon", {})

## Tinker Bell 配置。
static func tinker_bell_cfg() -> Dictionary:
	return props_m6().get("tinker_bell", {})

## 鳄鱼结局配置。
static func crocodile_cfg() -> Dictionary:
	return props_m6().get("crocodile", {})

## 可击碎物件配置（type -> {hp, score}）。
static func breakables_cfg() -> Dictionary:
	return props_m6().get("breakables", {})

## 单次攻击对可击碎物件的伤害。
static func break_attack_damage() -> int:
	return int(props_m6().get("break_attack_damage", 12))
