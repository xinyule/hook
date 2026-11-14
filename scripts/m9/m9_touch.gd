## M9 安卓虚拟按键层。
## 仅在 Android 平台显示：左侧左右移动，右侧攻击 / 跳跃 / 必杀。
## 通过 Input.set_action_pressed / set_action_released 模拟 P1 按键，
## 与 M3PlayerManager.read_inputs() 无缝兼容。
## 美观协调：半透明深色圆角按钮、亮色描边与文字、按下高亮，
## 布局在中下部两侧，不遮挡顶部 HUD。
class_name M9Touch
extends CanvasLayer

## 按钮配置：{label, actions, cx, cy}
var _buttons: Array = []

## 初始化。仅安卓平台生效，其他平台直接退出。
func _ready() -> void:
	if not OS.has_feature("android"):
		queue_free()
		return
	layer = 10
	_build()

## 构建虚拟按键布局。
func _build() -> void:
	## 左侧移动区。
	_add_button("左", ["m3_p1_left"], 150.0, 540.0)
	_add_button("右", ["m3_p1_right"], 262.0, 540.0)
	## 右侧动作区。
	_add_button("攻击", ["m3_p1_a"], 958.0, 540.0)
	_add_button("跳跃", ["m3_p1_b"], 1086.0, 452.0)
	## 必杀（同时按 a+b）。
	_add_button("必杀", ["m3_p1_a", "m3_p1_b"], 958.0, 364.0, true)

## 添加一个虚拟按钮。
## actions 为需要同时按下的动作列表；ultimate 为 true 时按下/释放整个列表。
func _add_button(label: String, actions: Array, cx: float, cy: float, ultimate: bool = false) -> void:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(112.0, 112.0)
	btn.position = Vector2(cx - 56.0, cy - 56.0)
	## Button 默认文字居中，无需显式设置 align。
	## 半透明深色圆角底 + 亮色描边，与游戏画面协调。
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.10, 0.72)
	style.border_color_top_left = Color(0.55, 0.62, 0.75, 0.9)
	style.border_color_top_right = Color(0.55, 0.62, 0.75, 0.9)
	style.border_color_bottom_left = Color(0.42, 0.48, 0.60, 0.9)
	style.border_color_bottom_right = Color(0.42, 0.48, 0.60, 0.9)
	style.corner_radius_top_left = 28
	style.corner_radius_top_right = 28
	style.corner_radius_bottom_left = 28
	style.corner_radius_bottom_right = 28
	style.content_margin_left = 6.0
	style.content_margin_right = 6.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	btn.style = style
	## 文字颜色与字号。
	btn.add_theme_font_size_override("font_size", 26)
	btn.add_theme_color_override("font_color", Color(0.95, 0.96, 1.0, 0.95))
	btn.add_theme_color_override("font_focus_color", Color(1.0, 0.95, 0.6, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.96, 0.75, 1.0))
	## 按下时高亮。
	var pressed_style := StyleBoxFlat.new()
	pressed_style.bg_color = Color(0.22, 0.30, 0.52, 0.85)
	pressed_style.border_color_top_left = Color(0.75, 0.82, 1.0, 1.0)
	pressed_style.border_color_top_right = Color(0.75, 0.82, 1.0, 1.0)
	pressed_style.border_color_bottom_left = Color(0.55, 0.65, 0.90, 1.0)
	pressed_style.border_color_bottom_right = Color(0.55, 0.65, 0.90, 1.0)
	pressed_style.corner_radius_top_left = 28
	pressed_style.corner_radius_top_right = 28
	pressed_style.corner_radius_bottom_left = 28
	pressed_style.corner_radius_bottom_right = 28
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("pressed", pressed_style)
	## 信号连接：按下模拟按键按下，释放模拟按键释放。
	var pressed_actions: Array = actions
	btn.pressed.connect(_on_pressed.bind(pressed_actions))
	btn.released.connect(_on_released.bind(pressed_actions))
	add_child(btn)
	_buttons.append({"btn": btn, "actions": actions})

## 按钮按下：模拟动作按下（Godot 4 用 set_action_value 模拟，call 动态调用绕过静态解析）。
func _on_pressed(actions: Array) -> void:
	for a in actions:
		Input.call("set_action_value", StringName(str(a)), 1.0)

## 按钮释放：模拟动作释放。
func _on_released(actions: Array) -> void:
	for a in actions:
		Input.call("set_action_value", StringName(str(a)), 0.0)
