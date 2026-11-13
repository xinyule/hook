## M3 数据访问层。
## 在 M2 数据层之上新增关卡、街机规则、会话规则与 HUD 配置的读取入口。
## M2 的 M2Data 保持不变，M3 只做增量数据读取。
extends RefCounted
class_name M3Data

## 与 M2 相同的逻辑层开关，headless 自测时跳过 3D 视觉构建。
static var logic_only: bool = false

static var _arcade: Dictionary = {}
static var _session: Dictionary = {}
static var _hud: Dictionary = {}
static var _stages: Dictionary = {}

static func _read(path: String) -> Dictionary:
	## 导出构建中 ProjectSettings.globalize_path 返回文件系统路径，
	## 但资源实际打包在 pck 内。提取 res:// 部分让 FileAccess 走 pck 解析。
	if path.contains("res://"):
		var idx := path.find("res://")
		if idx > 0:
			path = path.substr(idx)
	if not FileAccess.file_exists(path):
		push_error("[M3Data] missing file: %s" % path)
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("[M3Data] cannot open: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	var out: Dictionary = parsed if parsed is Dictionary else {}
	return out

## 街机规则集（投币续关、周目、TIME 压力）。
static func arcade() -> Dictionary:
	if _arcade.is_empty():
		_arcade = _read("res://data/rules/arcade.json")
	return _arcade

## 会话规则集（可插拔，默认关闭街机规则）。
static func session() -> Dictionary:
	if _session.is_empty():
		_session = _read("res://data/rules/session.json")
	return _session

## HUD 布局与飞鹰视觉参数。
static func hud_m3() -> Dictionary:
	if _hud.is_empty():
		_hud = _read("res://data/hud_m3.json")
	return _hud

## 关卡顺序（LoopManager 周目回环用）。
static func stage_order() -> Array:
	return ["stage_01", "stage_02", "stage_03", "stage_04", "stage_05", "stage_06"]

## 读取单个关卡数据，找不到返回空字典。
static func stage(id: String) -> Dictionary:
	if _stages.has(id):
		return _stages[id]
	var path := "res://data/stages/%s.json" % id
	var data := _read(path)
	_stages[id] = data
	return data

## 取当前生效的规则集（arcade 或 session）。
static func ruleset(name: String = "arcade") -> Dictionary:
	if name == "session":
		return session()
	return arcade()
