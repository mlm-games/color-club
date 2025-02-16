extends ColorRect

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
	
