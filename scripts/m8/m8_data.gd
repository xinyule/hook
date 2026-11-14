## M8 数据访问层。
## 读取 M8 平衡与完整度数据（balance_m8.json）：难度三档、角色调优、
## 辅助选项、贪分 / PK、成就定义、练习模式、最高分约定。
## M2-M7 数据层保持不变。
extends RefCounted
class_name M8Data

## 与 M2-M7 相同的逻辑层开关。
static var logic_only: bool = false

static var _balance: Dictionary = {}

static func _read(path: String) -> Dictionary:
	## 导出构建中 ProjectSettings.globalize_path 返回文件系统路径，
	## 但资源实际打包在 pck 内。提取 res:// 部分让 FileAccess 走 pck 解析。
	if path.contains("res://"):
		var idx := path.find("res://")
		if idx > 0:
			path = path.substr(idx)
	if not FileAccess.file_exists(path):
		push_error("[M8Data] missing file: %s" % path)
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("[M8Data] cannot open: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	var out: Dictionary = parsed if parsed is Dictionary else {}
	return out

## balance_m8.json 全量数据。
static func balance() -> Dictionary:
	if _balance.is_empty():
		_balance = _read("res://data/balance_m8.json")
	return _balance

## 难度三档配置。
static func difficulties() -> Dictionary:
	return balance().get("difficulties", {})

## 指定难度档配置，找不到返回空字典。
static func difficulty(name: String) -> Dictionary:
	return difficulties().get(name, {})

## 角色调优表。
static func character_tuning() -> Dictionary:
	return balance().get("character_tuning", {})

## 指定角色调优，找不到返回空字典。
static func tuning(hero_id: String) -> Dictionary:
	return character_tuning().get(hero_id, {})

## RUFIO 补强条目。
static func rufio_buff() -> Dictionary:
	return balance().get("rufio_buff", {})

## 辅助选项。
static func assists() -> Dictionary:
	return balance().get("assists", {})

## 指定辅助项，找不到返回空字典。
static func assist(name: String) -> Dictionary:
	return assists().get(name, {})

## 贪分 / PK 规则。
static func scoring() -> Dictionary:
	return balance().get("scoring", {})

## 成就定义列表。
static func achievements() -> Array:
	return balance().get("achievements", [])

## 练习模式参数。
static func practice() -> Dictionary:
	return balance().get("practice", {})

## 最高分约定。
static func highscore_meta() -> Dictionary:
	return balance().get("highscore", {})
