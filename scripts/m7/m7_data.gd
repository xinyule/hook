## M7 数据访问层。
## 读取 M7 表现层数据：风格化视觉调色板（visual_m7.json）、
## 粒子特效与六关天气（vfx_m7.json）、程序化音频参数（audio_m7.json）。
## M2-M6 数据层保持不变。
extends RefCounted
class_name M7Data

## 与 M2-M6 相同的逻辑层开关，headless 自测时跳过 3D 视觉与音频构建。
static var logic_only: bool = false

static var _visual: Dictionary = {}
static var _vfx: Dictionary = {}
static var _audio: Dictionary = {}

static func _read(path: String) -> Dictionary:
	## 导出构建中 ProjectSettings.globalize_path 返回文件系统路径，
	## 但资源实际打包在 pck 内。提取 res:// 部分让 FileAccess 走 pck 解析。
	if path.contains("res://"):
		var idx := path.find("res://")
		if idx > 0:
			path = path.substr(idx)
	if not FileAccess.file_exists(path):
		push_error("[M7Data] missing file: %s" % path)
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("[M7Data] cannot open: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	var out: Dictionary = parsed if parsed is Dictionary else {}
	return out

## 风格化视觉数据（visual_m7.json）。
static func visual() -> Dictionary:
	if _visual.is_empty():
		_visual = _read("res://data/visual_m7.json")
	return _visual

## VFX 与天气数据（vfx_m7.json）。
static func vfx() -> Dictionary:
	if _vfx.is_empty():
		_vfx = _read("res://data/vfx_m7.json")
	return _vfx

## 音频数据（audio_m7.json）。
static func audio() -> Dictionary:
	if _audio.is_empty():
		_audio = _read("res://data/audio_m7.json")
	return _audio

## Toon 风格参数（描边缩放 / 描边色 / 分块布局）。
static func style() -> Dictionary:
	return visual().get("style", {})

## 指定角色 / 敌人 / Boss 的调色板，找不到返回空字典。
static func palette(id: String) -> Dictionary:
	return visual().get("palettes", {}).get(id, {})

## UI 对齐参数。
static func ui() -> Dictionary:
	return visual().get("ui", {})

## 命中火花配置（heavy 为真取重击档）。
static func hit_spark(heavy: bool) -> Dictionary:
	var hs: Dictionary = vfx().get("hit_spark", {})
	return hs.get("heavy" if heavy else "light", {})

## 爆炸 VFX 配置。
static func explosion() -> Dictionary:
	return vfx().get("explosion", {})

## 财宝爆裂 VFX 配置。
static func treasure_burst() -> Dictionary:
	return vfx().get("treasure_burst", {})

## 指定关卡的天气配置，找不到返回空字典。
static func weather(stage_id: String) -> Dictionary:
	return vfx().get("weather", {}).get(stage_id, {})

## 指定名称的 SFX 参数，找不到返回空字典。
static func sfx(name: String) -> Dictionary:
	return audio().get("sfx", {}).get(name, {})

## BGM 全局参数（速度 / 单音时长 / 循环）。
static func bgm_meta() -> Dictionary:
	return audio().get("bgm", {})

## 指定关卡的 BGM 音符表（notes 为 [音名, 拍数] 数组）。
static func bgm_stage(stage_id: String) -> Dictionary:
	return audio().get("bgm", {}).get("stages", {}).get(stage_id, {})
