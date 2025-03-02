class_name HUD extends Control

const ColorButtonScene = preload("res://individual_color_button.tscn")

var colors_for_image : Dictionary[Color, Array] = {}:
	set(val):
		colors_for_image = val
		add_colors_to_dict()
var prev_color : Color
var selected_color: Color:
	set(val):
		selected_color = val
		highlight_nodes_to_color()

func _ready() -> void:
	Signals.on_new_color_selected.connect(reset_nodes_highlighting)

func add_colors_to_dict() -> void:
	for color in colors_for_image:
		var color_button := ColorButtonScene.instantiate()
		%ColorContainer.add_child(color_button)
		color_button.modulate = color

func reset_nodes_highlighting() -> void:
	for color:Color in colors_for_image:
		for obj:Control in colors_for_image[color]:
			obj.highlighting = false

func highlight_nodes_to_color() -> void:
	for obj:Control in colors_for_image[selected_color]:
		obj.highlighted = true
