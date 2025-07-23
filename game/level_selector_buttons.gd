class_name LevelSelectorButton
extends Button

const ColorPicScene: PackedScene = preload("uid://bmgl20mx1bn0g")

var base_style: StyleBoxFlat
var hover_style: StyleBoxFlat
var pressed_style: StyleBoxFlat

func _ready() -> void:
	theme_type_variation = "LevelButton"
	expand_icon = true
	pressed.connect(_on_level_selected)
	
	pivot_offset = size/2
	
	pressed.connect(GlobalAudioExports.I.play_ui_sound.bind(GlobalAudioExports.Sound.Click))
	mouse_entered.connect(GlobalAudioExports.I.play_ui_sound.bind(GlobalAudioExports.Sound.Hover))

func _on_level_selected() -> void:
	var svg_path = get_meta("svg_path", "")
	if svg_path.is_empty():
		GameManager.log_error("Level button has no SVG path assigned.", "UI")
		return
	
	var pulse_tween = create_tween()
	pulse_tween.tween_property(self, "scale", Vector2(0.9, 0.9), 0.1)
	pulse_tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.1)
	pulse_tween.tween_callback(func():
		GameManager.I.current_svg_path = svg_path
		get_tree().change_scene_to_packed(ColorPicScene)
	)
