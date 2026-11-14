## M9 数据访问层。
## 读取 M9 打包与内部交付数据（delivery_m9.json）：
## 性能达标阈值、内部限定合规检查项、出招表与操作说明。
## M2-M8 数据层保持不变。
extends RefCounted
class_name M9Data

## 与 M2-M8 相同的逻辑层开关。
static var logic_only: bool = false

static var _delivery: Dictionary = {}
static var _quality: Dictionary = {}

static func _read(path: String) -> Dictionary:
	## 导出构建中 ProjectSettings.globalize_path 返回文件系统路径，
	## 但资源实际打包在 pck 内。提取 res:// 部分让 FileAccess 走 pck 解析。
	if path.contains("res://"):
		var idx := path.find("res://")
		if idx > 0:
			path = path.substr(idx)
	if not FileAccess.file_exists(path):
		push_error("[M9Data] missing file: %s" % path)
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("[M9Data] cannot open: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	var out: Dictionary = parsed if parsed is Dictionary else {}
	return out

## delivery_m9.json 全量数据。
static func delivery() -> Dictionary:
	if _delivery.is_empty():
		_delivery = _read("res://data/delivery_m9.json")
	return _delivery

## 性能达标阈值。
static func performance() -> Dictionary:
	return delivery().get("performance", {})

## 目标帧率。
static func target_fps() -> int:
	return int(performance().get("target_fps", 60))

## 单帧预算（毫秒）。
static func frame_budget_ms() -> float:
	return float(performance().get("frame_budget_ms", 16.67))

## 同屏实体上限。
static func max_entities() -> int:
	return int(performance().get("max_entities_onscreen", 12))

## 内存预算（MB）。
static func memory_budget_mb() -> int:
	return int(performance().get("memory_budget_mb", 2048))

## 内部限定合规检查项列表。
static func compliance_items() -> Array:
	return delivery().get("compliance", {}).get("items", [])

## 禁止入库的第三方原始素材扩展名。
static func forbidden_asset_extensions() -> Array:
	return delivery().get("compliance", {}).get("forbidden_asset_extensions", [])

## 出招表条目。
static func moves() -> Array:
	return delivery().get("docs", {}).get("moves", [])

## 操作说明条目。
static func controls() -> Array:
	return delivery().get("docs", {}).get("controls", [])

## 说明备注。
static func notes() -> Array:
	return delivery().get("docs", {}).get("notes", [])

## 交付产物清单。
static func artifacts() -> Array:
	return delivery().get("delivery", {}).get("artifacts", [])

## 目标版本号。
static func version_target() -> String:
	return str(delivery().get("delivery", {}).get("version_target", "1.0.0"))

## 画质分级数据（quality_m9.json）全量。
static func quality() -> Dictionary:
	if _quality.is_empty():
		_quality = _read("res://data/quality_m9.json")
	return _quality

## 画质档位列表（低/中/高）。
static func quality_tiers() -> Dictionary:
	return quality().get("tiers", {})

## 默认画质档。
static func quality_default_tier() -> String:
	return str(quality().get("default_tier", "medium"))
