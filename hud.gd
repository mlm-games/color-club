class_name HUD extends Control

const ColorButtonScene = preload("uid://dhpkpl2gdud8q")
const WinScreenScene = preload("uid://cevc21alsw44h")

static var colors_for_image : Dictionary[Color, Array] = {}#:
	#set(val):
		#add_colors_to_dict.call_deferred()

static var color_container : Control

var prev_color : Color
static var selected_color: Color:
	set(val):
		selected_color = val
		highlight_nodes_to_color()

func _ready() -> void:
	
	color_container = %ColorContainer
	
	#HACK:Temp condition	
	await get_tree().create_timer(0.1).timeout
	add_colors_to_dict()

static func add_colors_to_dict() -> void:
	color_container.get_children().clear()
	for color in colors_for_image:
		var color_button := ColorButtonScene.instantiate()
		color_container.add_child(color_button)
		color_button.modulate = color

static func remove_color_and_its_button_if_empty() -> void:
	if OS.is_debug_build():
		print(HUD.colors_for_image)
	if colors_for_image[selected_color].is_empty():
		for child in color_container.get_children():
			if child.modulate == selected_color:
				color_container.remove_child(child)
		colors_for_image.erase(selected_color)
	if colors_for_image.is_empty():
		show_completed_overlay()


static func highlight_nodes_to_color() -> void:
	print(colors_for_image)
	for obj:Control in colors_for_image[selected_color]:
		obj.highlighted = true

static func show_completed_overlay() -> void:
	pass
	#get_tree().change_scene_to_packed(WinScreenScene)
