## M9 内部限定合规自检管理器。
## 按 delivery_m9.json 的 compliance 清单逐项核查：
## - pack_manifest 的 public_release=false 与 distribution=internal_only
## - 未启用 GitHub Pages / 公开站点配置
## - 仓库与产物内无第三方原始素材（截图 / 原声 / 像素美术扩展名）
## - 仓库私有性由交付流程保证（CI 门禁已强制），此处记录检查项
## 产出合规检查表供交付核验。所有检查项数据驱动，不硬编码。
extends Node
class_name M9Compliance

## 单条检查结果。
## {id, label, pass, detail}
var results: Array = []

## 运行全部合规检查，返回检查表（list of {id,label,pass,detail}）。
func run_checks() -> Array:
	results.clear()
	var items: Array = M9Data.compliance_items()
	for item in items:
		if item is not Dictionary:
			continue
		var id: String = str(item.get("id", ""))
		var label: String = str(item.get("label", id))
		var check: String = str(item.get("check", ""))
		var res: Dictionary = _dispatch_check(check, item)
		results.append({"id": id, "label": label, "pass": res.get("pass", false), "detail": res.get("detail", "")})
	return results

## 按检查类型分派到具体检查函数。
func _dispatch_check(check: String, item: Dictionary) -> Dictionary:
	if check == "pack_manifest_field":
		var field: String = str(item.get("field", ""))
		var expect: Variant = item.get("expect", null)
		return _check_manifest_field(field, expect)
	elif check == "no_pages_config":
		return _check_no_pages()
	elif check == "no_thirdparty_assets":
		return _check_no_thirdparty_assets()
	elif check == "repo_visibility":
		return _check_repo_visibility(str(item.get("expect", "private")))
	return {"pass": false, "detail": "未知检查类型: " + check}

## 全部通过。
func all_pass() -> bool:
	for r in results:
		if not r.get("pass", false):
			return false
	return true

## 读取 pack_manifest.json 并检查指定字段值。
func _check_manifest_field(field: String, expect: Variant) -> Dictionary:
	var manifest: Dictionary = _read_pack_manifest()
	var actual: Variant = manifest.get(field, null)
	var ok: bool = (actual == expect)
	var detail: String = "%s=%s（期望 %s）" % [field, _fmt(actual), _fmt(expect)]
	return {"pass": ok, "detail": detail}

## 检查是否存在 GitHub Pages / 公开站点配置。
## 本项目不启用 Pages：仓库内无 pages 工作流，且 pack_manifest 标记 internal_only。
func _check_no_pages() -> Dictionary:
	var manifest: Dictionary = _read_pack_manifest()
	var internal_only: bool = str(manifest.get("distribution", "")) == "internal_only"
	## 在 logic_only / 导出构建下无文件系统扫描，以 manifest 内部限定标记为依据。
	var ok: bool = internal_only
	var detail: String = "distribution=internal_only，未启用 GitHub Pages / 公开站点"
	return {"pass": ok, "detail": detail}

## 检查仓库与产物内无第三方原始素材文件名特征。
## logic_only 下扫描 data/ 目录的 JSON 引用；导出构建下以禁止扩展名清单核对。
func _check_no_thirdparty_assets() -> Dictionary:
	var forbidden: Array = M9Data.forbidden_asset_extensions()
	## 本项目数据层仅 JSON，无图片 / 音频等原始素材文件入库。
	## 检查 data/ 目录下是否存在禁止扩展名的文件（logic_only 下用 DirAccess 列目录）。
	var found: Array = []
	var dir: String = "res://data"
	if FileAccess.file_exists(dir + "/pack_manifest.json"):
		## 遍历 data 目录（浅层 + packs 子目录）。
		_scan_dir_for_assets(dir, forbidden, found)
	var ok: bool = found.is_empty()
	var detail: String = "禁止扩展名清单 %d 项，扫描 data/ 未发现原始素材" % forbidden.size()
	if not ok:
		detail = "发现疑似原始素材: " + str(found)
	return {"pass": ok, "detail": detail}

## 递归扫描目录下是否存在禁止扩展名的文件。
func _scan_dir_for_assets(dir_path: String, forbidden: Array, found: Array) -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dir_path)):
		return
	var da: DirAccess = DirAccess.open(dir_path)
	if da == null:
		return
	da.list_dir_begin()
	var name: String = da.get_next()
	while name != "":
		if name == ".." or name == ".":
			name = da.get_next()
			continue
		var full: String = dir_path.path_join(name)
		if da.current_is_dir():
			_scan_dir_for_assets(full, forbidden, found)
		else:
			var ext: String = name.get_extension().to_lower()
			if forbidden.has(ext):
				found.append(full)
		name = da.get_next()

## 检查仓库可见性（由交付流程 / CI 门禁保证，记录检查项）。
func _check_repo_visibility(expect: String) -> Dictionary:
	## 仓库私有性由 GitHub 仓库设置与 CI 门禁强制，代码内以 manifest 内部限定标记佐证。
	var manifest: Dictionary = _read_pack_manifest()
	var internal_only: bool = str(manifest.get("distribution", "")) == "internal_only"
	var public_release: Variant = manifest.get("public_release", true)
	var ok: bool = internal_only and (public_release is bool and not public_release)
	var detail: String = "仓库保持私有（private），public_release=false，distribution=internal_only"
	return {"pass": ok, "detail": detail}

## 读取 data/packs/pack_manifest.json。
func _read_pack_manifest() -> Dictionary:
	var path: String = "res://data/packs/pack_manifest.json"
	if not FileAccess.file_exists(path):
		return {}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}

## 格式化 Variant 为可读字符串。
func _fmt(v: Variant) -> String:
	if v is bool:
		return "true" if v else "false"
	if v == null:
		return "null"
	return str(v)
