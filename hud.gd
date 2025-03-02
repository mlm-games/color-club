class_name HUD extends Control

const ColorButtonScene = preload("res://individual_color_button.tscn")

var colors_for_image : Dictionary[Color, Array] = {}:
	set(val):
		colors_for_image = val
		add_colors_to_dict()

var selected_color: Color:
	set(val):
		selected_color = val
		highlight_nodes_to_color()

func add_colors_to_dict() -> void:
	for color in colors_for_image:
		var color_button := ColorButtonScene.instantiate()
		%ColorContainer.add_child(color_button)
		color_button.modulate = color

func highlight_nodes_to_color():
	for obj in colors_for_image[selected_color]:
		obj.highlighted = true
