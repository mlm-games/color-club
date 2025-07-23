class_name SettingsManager extends Node

static var I: SettingsManager

func _init() -> void:
	I = self

var color_strokes: bool = false
var auto_color_strokes: bool = true
var stroke_color: Color = Color.BLACK

signal settings_changed

func toggle_stroke_coloring(enabled: bool) -> void:
	color_strokes = enabled
	settings_changed.emit()

func set_auto_stroke_color(color: Color) -> void:
	stroke_color = color
	settings_changed.emit()
