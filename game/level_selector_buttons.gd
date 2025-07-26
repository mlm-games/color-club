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
	var level_data = get_meta("level_data") as LevelData
	if not level_data:
		GameManager.log_error("Level button has no level data.", "UI")
		return
	
	GameManager.I.current_level = level_data
	
	var pulse_tween = create_tween()
	pulse_tween.tween_property(self, "scale", Vector2(0.9, 0.9), 0.1)
	pulse_tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.1)
	pulse_tween.tween_callback(func():
		get_tree().change_scene_to_packed(ColorPicScene)
	)

func _on_level_button_hover(button: Button, is_hovering: bool) -> void:
	var hover_tween = create_tween()
	
	if is_hovering:
		hover_tween.parallel().tween_property(button, "scale", Vector2(1.1, 1.1), 0.2).set_trans(Tween.TRANS_QUAD)
		hover_tween.parallel().tween_property(button, "rotation", deg_to_rad(5), 0.2)
	else:
		hover_tween.parallel().tween_property(button, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_QUAD)
		hover_tween.parallel().tween_property(button, "rotation", 0.0, 0.2)
