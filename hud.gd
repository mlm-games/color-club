class_name HUD extends Control

const ColorButtonScene = preload("uid://dhpkpl2gdud8q")
const WinScreenScene = preload("uid://cevc21alsw44h")

var colors_for_image : Dictionary[Color, Array] = {}:
	set(val):
		colors_for_image = val
		add_colors_to_dict()
var prev_color : Color
var selected_color: Color:
	set(val):
		selected_color = val
		highlight_nodes_to_color()


func add_colors_to_dict() -> void:
	%ColorContainer.get_children().clear()
	for color in colors_for_image:
		var color_button := ColorButtonScene.instantiate()
		%ColorContainer.add_child(color_button)
		color_button.modulate = color

func remove_color_and_its_button_if_empty() -> void:
	if colors_for_image[selected_color].is_empty():
		for child in %ColorContainer.get_children():
			if child.modulate == selected_color:
				%ColorContainer.remove_child(child)
	colors_for_image.erase(selected_color)
	if colors_for_image.is_empty():
		show_completed_overlay()


func highlight_nodes_to_color() -> void:
	for obj:Control in colors_for_image[selected_color]:
		obj.highlighted = true

func show_completed_overlay():
	get_tree().change_scene_to_packed(WinScreenScene)
