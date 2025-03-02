extends Button


func _on_pressed() -> void:
	#Signals.on_new_color_selected.emit(modulate)
	get_tree().get_first_node_in_group("HUD").selected_color = modulate
