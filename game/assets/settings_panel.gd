class_name SettingsPanel extends PanelContainer
#
#@onready var stroke_coloring_check: CheckBox = $VBox/StrokeColoringCheck
#@onready var auto_color_check: CheckBox = $VBox/AutoColorCheck
#@onready var stroke_color_picker: ColorPickerButton = $VBox/StrokeColorPicker
#
#func _ready() -> void:
	#stroke_coloring_check.toggled.connect(_on_stroke_coloring_toggled)
	#auto_color_check.toggled.connect(_on_auto_color_toggled)
	#stroke_color_picker.color_changed.connect(_on_stroke_color_changed)
	#
	##stroke_coloring_check.button_pressed = SettingsManager.color_strokes
	#auto_color_check.button_pressed = SettingsManager.auto_color_strokes
	#stroke_color_picker.color = SettingsManager.stroke_color
	#
	#_update_ui_state()
#
#func _on_stroke_coloring_toggled(pressed: bool) -> void:
	#SettingsManager.I.toggle_stroke_coloring(pressed)
	#_update_ui_state()
#
#func _on_auto_color_toggled(pressed: bool) -> void:
	#SettingsManager.I.auto_color_strokes = pressed
	#_update_ui_state()
#
#func _on_stroke_color_changed(color: Color) -> void:
	#SettingsManager.I.set_auto_stroke_color(color)
#
#func _update_ui_state() -> void:
	#auto_color_check.disabled = SettingsManager.I.color_strokes
	#stroke_color_picker.disabled = SettingsManager.I.color_strokes or not SettingsManager.I.auto_color_strokes
