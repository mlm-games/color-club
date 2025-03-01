class_name ClickablePanel extends Panel

var fill_color: Color:
	set(val):
		fill_color = val
		get("theme_override_styles/panel").bg_color = fill_color

var highlighted: bool = false:
	set(val):
		highlighted = val
		if val == true:
			#TODO: add_shader
			pass
		else:
			pass
			#Remove shader

func _ready() -> void:
	gui_input.connect(_on_input_received.bind())

@onready var hud : HUD = get_tree().get_first_node_in_group("HUD")
@onready var original_scale = scale
var hover_scale : Vector2 = Vector2(1.1, 1.1)

func _on_input_received(event: InputEvent):
	if event.is_pressed():
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			# Click anim when unbuyable
			var click_tween : Tween = create_tween()
			click_tween.set_trans(Tween.TRANS_CUBIC)
			click_tween.set_ease(Tween.EASE_OUT).set_ignore_time_scale()
			click_tween.tween_property(self, "scale", original_scale * 0.95, 0.1)
			click_tween.tween_property(self, "scale", hover_scale, 0.1)
			
			# FIXME: Play click sound
			#Sound.play_sfx("click")
			
			if highlighted:
				fill_color = hud.selected_color
