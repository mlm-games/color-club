extends Button


func _on_pressed() -> void:
	#Signals.on_new_color_selected.emit(modulate)
	HUD.selected_color = modulate
