extends ColorRect

const ColorPicScene = preload("uid://d23haj46gk4ea")
var pics : Array = []

var tween

func _on_button_pressed() -> void:
	on_play_clickd()
	

func on_play_clickd() -> void:
	tween = get_tree().create_tween()
	tween.tween_property(%PlayButton, "modulate", Color.TRANSPARENT, 0.2)
	%PlayButton.hide()
	populate_pics()

func populate_pics() -> void:
	add_child(ColorPicScene.instantiate())










#region Ideas
#HACK: Have a seperate mode where the user is able to color the images on his own. And share the colored images if needed...
#endregion
