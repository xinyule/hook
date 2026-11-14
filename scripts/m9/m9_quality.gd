## M9 画质分级管理器。
## 三档画质（低/中/高）：渲染分辨率缩放、特效粒子倍率、天气粒子倍率、描边开关。
## 用户可在游戏内切换，选择持久化到 user://，Windows / Web / 安卓三端一致生效。
## 表现层（M7Vfx / M7Visual）通过静态实例按档位取值；未挂载时走默认高配，
## 保证 M2-M8 沙盒场景独立运行不受影响。
## 所有数值来自 data/quality_m9.json，不硬编码。
extends Node
class_name M9Quality

## 全局单例引用（供表现层按档位取值）。
static var instance: M9Quality = null

## 当前画质档。
var current_tier: String = "medium"
var _cfg: Dictionary = {}

## 初始化：加载配置、读取已保存档位、应用渲染分辨率缩放。
func _ready() -> void:
	instance = self
	_cfg = M9Data.quality()
	load_saved()
	apply_render_scale()

## 当前档配置。
func tier_cfg() -> Dictionary:
	return _cfg.get("tiers", {}).get(current_tier, {})

## 切换画质档（无效档名保持原档），返回是否成功。
func set_tier(name: String) -> bool:
	if not _cfg.get("tiers", {}).has(name):
		return false
	current_tier = name
	save()
	apply_render_scale()
	return true

## 渲染分辨率缩放（低 0.6 / 中 0.8 / 高 1.0）。
func render_scale() -> float:
	return float(tier_cfg().get("render_scale", 1.0))

## 特效粒子数量倍率（低 0.3 / 中 0.6 / 高 1.0）。
func vfx_particles_mult() -> float:
	return float(tier_cfg().get("vfx_particles_mult", 1.0))

## 天气粒子数量倍率（低 0 / 中 0.5 / 高 1.0）。
func weather_particles_mult() -> float:
	return float(tier_cfg().get("weather_particles_mult", 1.0))

## 是否启用描边（低配关闭，省一半绘制调用）。
func outlines_enabled() -> bool:
	return bool(tier_cfg().get("outlines", true))

## 应用渲染分辨率缩放：按基础分辨率 × 缩放调整视口尺寸（三端通用，运行时即时生效）。
func apply_render_scale() -> void:
	if M9Data.logic_only:
		return
	var base_w := int(_cfg.get("render", {}).get("base_width", 1280))
	var base_h := int(_cfg.get("render", {}).get("base_height", 720))
	var scale := render_scale()
	var w := maxi(320, int(base_w * scale))
	var h := maxi(180, int(base_h * scale))
	ProjectSettings.set_setting("display/window/size/viewport_width", w)
	ProjectSettings.set_setting("display/window/size/viewport_height", h)

## 持久化路径。
func _persist_path() -> String:
	return str(_cfg.get("persist_path", "user://hook3d_quality.json"))

## 从磁盘加载已保存档位（无记录或非法档用默认档）。
func load_saved() -> void:
	var path := _persist_path()
	if M9Data.logic_only or not FileAccess.file_exists(path):
		current_tier = M9Data.quality_default_tier()
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		current_tier = M9Data.quality_default_tier()
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary and _cfg.get("tiers", {}).has(str(parsed.get("tier", ""))):
		current_tier = str(parsed.get("tier", M9Data.quality_default_tier()))
	else:
		current_tier = M9Data.quality_default_tier()

## 保存当前档位。
func save() -> void:
	if M9Data.logic_only:
		return
	var path := _persist_path()
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"tier": current_tier}))
