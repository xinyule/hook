## M3 HUD。
## 每玩家一条 HP 条 + 命数图标；TIME 条；分数；周目计数；玩家指示色。
## 逐帧更新，布局与颜色参数全部取自 hud_m3.json，脚本不硬编码。
extends CanvasLayer
class_name M3Hud

var hud_cfg: Dictionary = {}
var eagle_cfg: Dictionary = {}
var colors: Dictionary = {}

var hp_bars: Array = []          ## 每玩家一个 ProgressBar
var lives_labels: Array = []     ## 每玩家命数文本
var time_bar: ProgressBar = null
var score_label: Label = null
var loop_label: Label = null
var eagle_label: Label = null
var root_panel: Control = null

func _ready() -> void:
	hud_cfg = M3Data.hud_m3().get("hud", {})
	eagle_cfg = M3Data.hud_m3().get("eagle", {})
	colors = M3Data.hud_m3().get("colors", {})
	_build()

## 构建 HUD 控件。
func _build() -> void:
	root_panel = Control.new()
	## CanvasLayer 无固有尺寸，用显式定位 + 尺寸（默认等锚点，避免锚点覆盖警告）。
	root_panel.position = Vector2(0.0, 0.0)
	root_panel.size = Vector2(1280.0, 720.0)
	add_child(root_panel)
	## 玩家 HP 条 + 命数（堆叠在左上角）。
	## 修复：原实现把 stack_start_x=-6.0 直接当像素坐标，HP 条落在屏幕外不可见；
	## 改为像素坐标 + 行距按 100 倍换算，与血条尺寸缩放一致。
	var sx := float(hud_cfg.get("stack_start_x", 20.0))
	var sy := float(hud_cfg.get("stack_start_y", 10.0))
	var row_gap := float(hud_cfg.get("stack_row_gap", 0.28)) * 100.0
	var bar_w := float(hud_cfg.get("hp_bar_width", 2.0))
	var bar_h := float(hud_cfg.get("hp_bar_height", 0.18))
	var gap := float(hud_cfg.get("hp_bar_gap", 0.05))
	for i in 4:
		var row := Control.new()
		row.position = Vector2(sx, sy - i * row_gap)
		root_panel.add_child(row)
		var bar := ProgressBar.new()
		bar.min_value = 0.0
		bar.max_value = 100.0
		bar.value = 100.0
		bar.position = Vector2(0.0, 0.0)
		bar.size = Vector2(bar_w * 100, bar_h * 100)
		bar.tooltip_text = "P%d HP" % (i + 1)
		row.add_child(bar)
		hp_bars.append(bar)
		var lv := Label.new()
		lv.position = Vector2(bar_w * 100 + gap * 100, 0.0)
		lv.add_theme_font_size_override("font_size", int(hud_cfg.get("lives_icon_size", 25)))
		row.add_child(lv)
		lives_labels.append(lv)
	## TIME 条（顶部居中）。
	time_bar = ProgressBar.new()
	time_bar.min_value = 0.0
	time_bar.max_value = 99.0
	time_bar.value = 99.0
	time_bar.position = Vector2(root_panel.size.x * 0.5 - float(hud_cfg.get("time_bar_width", 4.0)) * 50, 10.0)
	time_bar.size = Vector2(float(hud_cfg.get("time_bar_width", 4.0)) * 100, float(hud_cfg.get("time_bar_height", 0.2)) * 100)
	root_panel.add_child(time_bar)
	## 分数（右上）。
	score_label = Label.new()
	score_label.position = Vector2(root_panel.size.x - 200.0, 10.0)
	score_label.add_theme_font_size_override("font_size", int(hud_cfg.get("score_font_size", 20)))
	root_panel.add_child(score_label)
	## 周目（分数下方）。
	loop_label = Label.new()
	loop_label.position = Vector2(root_panel.size.x - 200.0, 35.0)
	loop_label.add_theme_font_size_override("font_size", int(hud_cfg.get("loop_font_size", 16)))
	root_label_color(colors.get("loop", [0.6, 0.8, 1.0]))
	root_panel.add_child(loop_label)
	## 飞鹰警示（顶部居中，TIME 条上方）。
	eagle_label = Label.new()
	eagle_label.position = Vector2(root_panel.size.x * 0.5 - 100.0, 45.0)
	eagle_label.add_theme_font_size_override("font_size", 18)
	eagle_label.text = ""
	root_panel.add_child(eagle_label)

## 设置 Label 颜色（Godot 4 用 modulate）。
func root_label_color(rgb: Array) -> void:
	if loop_label != null:
		loop_label.modulate = _color_from_array(rgb)

## 将 Array[r,g,b] 转为 Color（Godot 4 的 Color 构造函数不接受 Array）。
func _color_from_array(rgb: Array) -> Color:
	if rgb.size() >= 3:
		return Color(float(rgb[0]), float(rgb[1]), float(rgb[2]), 1.0)
	return Color.WHITE

## 逐帧更新。
func update(player_manager: M3PlayerManager, timer: M3Timer, score_node: M3Score, stage_runner: M3StageRunner) -> void:
	## 玩家 HP 条与命数。
	var all: Array = player_manager.all_players()
	for i in hp_bars.size():
		if i < all.size():
			var p: M2Player = all[i]
			var pct: float = float(p.hp) / float(p.max_hp) * 100.0
			hp_bars[i].value = pct
			hp_bars[i].modulate = _color_from_array(colors.get("hp_bar", [0.2, 0.8, 0.3]))
			if pct < 30.0:
				hp_bars[i].modulate = _color_from_array(colors.get("hp_bar_low", [0.9, 0.2, 0.2]))
			var slot: int = player_manager.players.find(p)
			var lv_text: String = ""
			if slot >= 0:
				lv_text = "x%d" % player_manager.lives[slot]
			lives_labels[i].text = lv_text
		else:
			hp_bars[i].value = 0.0
			lives_labels[i].text = ""
	## TIME 条。
	if time_bar != null and timer != null:
		time_bar.value = timer.time_value
		var tpc: float = float(timer.time_value) / float(timer.initial_time)
		time_bar.modulate = _color_from_array(colors.get("time_bar", [0.9, 0.8, 0.2]))
		if tpc < 0.2:
			time_bar.modulate = _color_from_array(colors.get("time_bar_low", [0.9, 0.3, 0.2]))
	## 分数与周目。
	if score_label != null and score_node != null:
		score_label.text = "SCORE %d" % score_node.score
	if loop_label != null and score_node != null:
		loop_label.text = "LOOP %d" % score_node.loop_count
	## 飞鹰警示。
	if eagle_label != null and timer != null:
		if timer.eagle_state == "warning" or timer.eagle_state == "active":
			eagle_label.text = "!! EAGLE PUSH !!"
			eagle_label.modulate = _color_from_array(eagle_cfg.get("warning_color", [0.9, 0.3, 0.2]))
		else:
			eagle_label.text = ""
