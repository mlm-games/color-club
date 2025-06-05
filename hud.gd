class_name HUD
extends Control

# Scenes
const ColorButtonScene = preload("uid://dhpkpl2gdud8q")
const WinScreenScene = preload("uid://cevc21alsw44h")

# Static references
static var instance: HUD
static var selected_svg_path: String = ""
static var colors_for_image: Dictionary = {}
static var color_container: Control

static var selected_color: Color = Color.TRANSPARENT:
	set(value):
		print("HUD: Setting selected color to: ", value)
		selected_color = value
		if instance:
			instance._on_color_selected(value)

func _on_color_button_pressed(color: Color) -> void:
	print("Color button pressed: ", color)
	selected_color = color

func _on_color_selected(color: Color) -> void:
	print("Color selected: ", color)
	_highlight_elements_with_color(color)

func _highlight_elements_with_color(color: Color) -> void:
	_clear_all_highlights()
	
	print("Highlighting elements with color: ", color)
	print("Available colors: ", colors_for_image.keys())
	
	if color in colors_for_image:
		print("Found ", colors_for_image[color].size(), " elements with this color")
		for element in colors_for_image[color]:
			if is_instance_valid(element):
				element.highlighted = true
				print("Highlighted element: ", element.name)
	else:
		print("No elements found with color: ", color)


func _ready() -> void:
	instance = self
	color_container = %ColorContainer
	
	# Connect to SVG image signals
	var svg_image : SVGImage = get_node("../SVGImage")
	if svg_image:
		svg_image.svg_loaded.connect(_on_svg_loaded)

func _on_svg_loaded(colors: Dictionary) -> void:
	colors_for_image = colors
	_update_color_buttons()

func _update_color_buttons() -> void:
	# Clear existing buttons
	for child in color_container.get_children():
		child.queue_free()
	
	# Create new buttons
	for color in colors_for_image:
		if color == Color.WHITE or color == Color.TRANSPARENT:
			continue  # Skip white and transparent
		
		var button = ColorButtonScene.instantiate()
		color_container.add_child(button)
		button.modulate = color
		button.pressed.connect(_on_color_button_pressed.bind(color))

func _clear_all_highlights() -> void:
	for color in colors_for_image:
		for element in colors_for_image[color]:
			if is_instance_valid(element):
				element.highlighted = false

static func remove_color_if_empty(color: Color) -> void:
	if color in colors_for_image and colors_for_image[color].is_empty():
		colors_for_image.erase(color)
		if instance:
			instance._remove_color_button(color)
		
		# Check if game is complete
		if colors_for_image.is_empty():
			_show_win_screen()

static func _remove_color_button(color: Color) -> void:
	for child in color_container.get_children():
		if child.modulate.is_equal_approx(color):
			child.queue_free()
			break

static func _show_win_screen() -> void:
	if instance:
		Utils.game_tree.change_scene_to_packed(WinScreenScene)

# Debug function
func _on_debug_button_pressed() -> void:
	print("Colors remaining: ", colors_for_image.keys())
	for color in colors_for_image:
		print("  ", color, ": ", colors_for_image[color].size(), " elements")
