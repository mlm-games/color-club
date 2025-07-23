@tool
extends Button

var target_color: Color:
	set(value):
		target_color = value
		set_meta("target_color", value) # Store for HUD to find
		modulate = value

func _ready() -> void:
	custom_minimum_size = Vector2(50, 50)
	
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color.WHITE
	style_normal.border_width_left = 2
	style_normal.border_width_top = 2
	style_normal.border_width_right = 2
	style_normal.border_width_bottom = 2
	style_normal.border_color = Color.BLACK
	style_normal.corner_radius_top_left = 8
	style_normal.corner_radius_top_right = 8
	style_normal.corner_radius_bottom_right = 8
	style_normal.corner_radius_bottom_left = 8
	
	var style_hover = style_normal.duplicate()
	style_hover.border_color = Color.GOLD
	style_hover.border_width_left = 4
	style_hover.border_width_right = 4
	style_hover.border_width_top = 4
	style_hover.border_width_bottom = 4
	
	var style_pressed = style_hover.duplicate()
	style_pressed.border_color = Color.ORANGE_RED
	
	add_theme_stylebox_override("normal", style_normal)
	add_theme_stylebox_override("hover", style_hover)
	add_theme_stylebox_override("pressed", style_pressed)
