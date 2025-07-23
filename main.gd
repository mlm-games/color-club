extends Control

const ART_FOLDER := "res://assets/art/"
const LevelButtonsScene := preload("uid://df6stj0kgo1jl")

@onready var play_button: Button = %PlayButton
@onready var pic_container: GridContainer = %PicContainer
@onready var title_label: RichTextLabel = %TitleLabel
@onready var level_select_container: Control = %LevelSelectContainer

var local_pics: PackedStringArray = []
var button_hover_tweens: Dictionary = {}

func _ready() -> void:
	title_label.theme_type_variation = "TitleLabel"
	play_button.theme_type_variation = "PlayButton"
	play_button.grab_focus()
	play_button.pivot_offset = play_button.size/2
	
	_animate_title_entrance()
	
	var dir = DirAccess.open(ART_FOLDER)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".svg"):
				local_pics.append(file_name)
			file_name = dir.get_next()
	else:
		GameManager.log_error("Could not open art folder: " + ART_FOLDER, "Main")
	
	populate_pics()
	
	level_select_container.modulate.a = 0.0
	level_select_container.visible = false


func _animate_title_entrance() -> void:
	title_label.modulate.a = 0.0
	title_label.position.y -= 50
	
	var title_tween := create_tween()
	title_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	title_tween.parallel().tween_property(title_label, "modulate:a", 1.0, 0.8)
	title_tween.parallel().tween_property(title_label, "position:y", title_label.position.y + 50, 0.8)
	
	play_button.scale = Vector2(0, 0)
	title_tween.tween_property(play_button, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK)

func on_play_clicked() -> void:
	play_button.pivot_offset = play_button.size/2
	var tween := create_tween()
	
	tween.parallel().tween_property(play_button, "rotation", deg_to_rad(360), 0.5)
	tween.parallel().tween_property(play_button, "scale", Vector2.ZERO, 0.5).set_trans(Tween.TRANS_BACK)
	tween.parallel().tween_property(play_button, "modulate:a", 0.0, 0.3)
	
	# Level select with stagger animation
	tween.tween_callback(func():
		play_button.visible = false
		level_select_container.visible = true
	)
	tween.tween_property(level_select_container, "modulate:a", 1.0, 0.3)
	
	tween.tween_callback(_animate_level_buttons_entrance)

func _animate_level_buttons_entrance() -> void:
	var delay = 0.0
	for child in pic_container.get_children():
		if child is Button:
			child.scale = Vector2.ZERO
			child.modulate.a = 0.0
			
			var button_tween = create_tween()
			button_tween.tween_interval(delay)
			button_tween.parallel().tween_property(child, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK)
			button_tween.parallel().tween_property(child, "modulate:a", 1.0, 0.3)
			
			delay += 0.05

func populate_pics() -> void:
	for pic_path: StringName in local_pics:
		var pic_button := LevelButtonsScene.instantiate()
		var full_path = ART_FOLDER + pic_path
		pic_button.icon = load(full_path)
		pic_button.set_meta("svg_path", full_path)
		
		pic_button.mouse_entered.connect(_on_level_button_hover.bind(pic_button, true))
		pic_button.mouse_exited.connect(_on_level_button_hover.bind(pic_button, false))
		
		pic_container.add_child(pic_button)

func _on_level_button_hover(button: Button, is_hovering: bool) -> void:
	if button in button_hover_tweens:
		button_hover_tweens[button].kill()
	
	var hover_tween = create_tween()
	button_hover_tweens[button] = hover_tween
	
	if is_hovering:
		hover_tween.parallel().tween_property(button, "scale", Vector2(1.1, 1.1), 0.2).set_trans(Tween.TRANS_QUAD)
		hover_tween.parallel().tween_property(button, "rotation", deg_to_rad(5), 0.2)
	else:
		hover_tween.parallel().tween_property(button, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_QUAD)
		hover_tween.parallel().tween_property(button, "rotation", 0.0, 0.2)

func _on_play_button_pressed() -> void:
	on_play_clicked()
