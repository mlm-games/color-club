@tool
extends Button

var target_color: Color:
	set(value):
		target_color = value
		modulate = value
		print("Color button created with color: ", value)

func _ready() -> void:
	# Style the button
	custom_minimum_size = Vector2(40, 40)
	flat = false
	
	# Add border for better visibility
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color.WHITE
	style_normal.border_width_left = 2
	style_normal.border_width_right = 2
	style_normal.border_width_top = 2
	style_normal.border_width_bottom = 2
	style_normal.border_color = Color.BLACK
	style_normal.corner_radius_top_left = 4
	style_normal.corner_radius_top_right = 4
	style_normal.corner_radius_bottom_left = 4
	style_normal.corner_radius_bottom_right = 4
	
	var style_hover = style_normal.duplicate()
	style_hover.border_color = Color.YELLOW
	style_hover.border_width_left = 3
	style_hover.border_width_right = 3
	style_hover.border_width_top = 3
	style_hover.border_width_bottom = 3
	
	var style_pressed = style_normal.duplicate()
	style_pressed.border_color = Color.RED
	
	add_theme_stylebox_override("normal", style_normal)
	add_theme_stylebox_override("hover", style_hover)
	add_theme_stylebox_override("pressed", style_pressed)
	
	# Connect the pressed signal
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)

func _on_pressed() -> void:
	print("Button pressed with target color: ", target_color)
	HUD.selected_color = target_color
