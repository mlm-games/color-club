class_name ClickablePanel extends Panel

var fill_color: Color:
	set(val):
		get("theme_override_styles/panel").bg_color = val
	get:
		return get("theme_override_styles/panel").bg_color

var highlighted: bool = false:
	set(val):
		highlighted = val
		if val == true:
			pass
			#TODO: add_shader
			#set_instance_shader_parameter("shader_parameter/use_color_mode", false)
		if val == false:
			pass
			#set_instance_shader_parameter("shader_parameter/use_color_mode", true)
			
		else:
			pass
			#Remove shader

func _ready() -> void:
	gui_input.connect(_on_input_received.bind())
	#material = ShaderMaterial.new()
	#material.shader = load("res://assets/shaders/individual_color_button.gdshader")

@onready var hud : HUD = get_tree().get_first_node_in_group("HUD")
@onready var original_scale = scale
var hover_scale : Vector2 = Vector2(1.05, 1.05)

func _on_input_received(event: InputEvent):
	if event.is_pressed():
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			# Click anim when unbuyable
			var click_tween : Tween = create_tween()
			click_tween.set_trans(Tween.TRANS_QUINT)
			click_tween.set_ease(Tween.EASE_OUT).set_ignore_time_scale()
			click_tween.tween_property(self, "scale", original_scale * 0.95, 0.1)
			click_tween.tween_property(self, "scale", hover_scale, 0.1)
			click_tween.tween_property(self, "scale", original_scale, 0.1)
			
			# FIXME: Play click sound
			#Sound.play_sfx("click")
			
			if highlighted:
				fill_color = hud.selected_color
				highlighted = false
				
