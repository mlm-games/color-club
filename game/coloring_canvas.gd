
extends Control

@onready var svg_image: SVGImage = $SVGImage
@onready var hud: HUD = $HUD

func _ready() -> void:
	var svg_path = GameManager.I.current_svg_path
	if svg_path.is_empty():
		GameManager.log_error("No SVG path was provided to the coloring scene.", "GameSetup")
		get_tree().change_scene_to_file("uid://bnxj7rhwgcg67")
		return

	GameManager.I.start_game()
	
	GameManager.I.game_completed_signal.connect(_on_game_completed)

func _on_game_completed() -> void:
	var time_taken = GameManager.I.get_time_taken()
	var elements_colored = GameManager.I.elements_colored
	
	GameManager.log_info("Game completed in %.2f seconds!" % time_taken, "Game")
	GameManager.log_info("Elements colored: %d" % elements_colored, "Game")
	
	_play_completion_animation()

func _play_completion_animation() -> void:
	#TODO: Can't rotate or scale from center instead of top left for node2ds, control nodes is not an option -> transform doesn't work properly...
	var root_node = svg_image #.get_svg_root()
	svg_image.pivot_offset = svg_image.size/2
	if not is_instance_valid(root_node):
		HUD.I._show_win_screen()
		return
	
	set_process_unhandled_input(false)
	
	var main_tween = create_tween()
	main_tween.set_parallel(false)
	
	main_tween.tween_property(root_node, "scale", root_node.scale * 1.1, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	main_tween.tween_property(root_node, "scale", root_node.scale, 0.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	
	var colorable_shapes = A.find_nodes_with_script(root_node, "uid://dnfuu7hosi1en")
	
	main_tween.tween_callback(_create_wiggle_animations.bind(colorable_shapes))
	
	main_tween.tween_interval(1.5)
	
	main_tween.tween_property(root_node, "rotation", root_node.rotation + deg_to_rad(360), 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
	
	main_tween.tween_callback(HUD.I.show_win_screen)

func _create_wiggle_animations(shapes: Array) -> void:
	for i in range(shapes.size()):
		var shape_script = shapes[i]
		var shape_parent = shape_script.get_parent()
		if not is_instance_valid(shape_parent):
			continue
		
		var wiggle_tween = create_tween()
		wiggle_tween.set_loops(2)
		
		var delay = i * 0.05
		wiggle_tween.tween_interval(delay)
		
		var original_rotation = shape_parent.rotation
		
		wiggle_tween.tween_property(shape_parent, "rotation", original_rotation + deg_to_rad(5), 0.1).set_trans(Tween.TRANS_SINE)
		wiggle_tween.tween_property(shape_parent, "rotation", original_rotation - deg_to_rad(5), 0.2).set_trans(Tween.TRANS_SINE)
		wiggle_tween.tween_property(shape_parent, "rotation", original_rotation, 0.1).set_trans(Tween.TRANS_SINE)
		
		var scale_tween = create_tween()
		scale_tween.tween_interval(delay)
		scale_tween.tween_property(shape_parent, "scale", shape_parent.scale * 1.05, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		scale_tween.tween_property(shape_parent, "scale", shape_parent.scale, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
