## M9 出招表与操作说明数据接口。
## 从 delivery_m9.json 的 docs 节读取五角色招式表、操作键位说明与备注，
## 提供查询接口供 HUD / 说明界面调用。所有数据来自 data/delivery_m9.json，不硬编码。
extends Node
class_name M9Docs

## 出招表条目列表。
func moves() -> Array:
	return M9Data.moves()

## 按角色 id 查询出招表条目。
func move(hero_id: String) -> Dictionary:
	for m in M9Data.moves():
		if m is Dictionary and str(m.get("hero_id", "")) == hero_id:
			return m
	return {}

## 操作说明条目列表。
func controls() -> Array:
	return M9Data.controls()

## 按操作 id 查询说明条目。
func control(id: String) -> Dictionary:
	for c in M9Data.controls():
		if c is Dictionary and str(c.get("id", "")) == id:
			return c
	return {}

## 说明备注列表。
func notes() -> Array:
	return M9Data.notes()

## 出招表是否覆盖全部五角色。
func covers_all_heroes() -> bool:
	var chars: Array = M2Data.characters().get("characters", [])
	var remaining: Dictionary = {}
	for c in chars:
		if c is Dictionary and c.has("id"):
			remaining[str(c.get("id", ""))] = true
	if remaining.is_empty():
		return false
	for m in M9Data.moves():
		if m is Dictionary:
			var hid: String = str(m.get("hero_id", ""))
			if remaining.has(hid):
				remaining.erase(hid)
	return remaining.is_empty()
