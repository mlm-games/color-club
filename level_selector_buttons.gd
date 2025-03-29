class_name LevelSelectorButton extends Button

const ColorPicScene : PackedScene = preload("uid://d23haj46gk4ea")

#func _init(img_path: StringName) -> void:
	#icon = load(img_path)
	#

func _ready() -> void:
	expand_icon = false
	pressed.connect(_on_level_selected)

func _on_level_selected() -> void:
	HUD.selected_svg_path = icon.resource_path
	get_tree().change_scene_to_packed(ColorPicScene)
	#get_tree().get_first_node_in_group("HUD")
