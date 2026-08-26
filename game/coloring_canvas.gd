
extends Control

@onready var svg_image: SVGImage = %SVGImage
@onready var hud: HUD = $HUD

func _ready() -> void:
	var level = GameManager.I.current_level
	if not level:
		GameManager.log_error("No level data provided", "GameSetup")
		get_tree().change_scene_to_file("uid://bnxj7rhwgcg67")
		return
	
	var svg_content = level.load_content()
	if svg_content.is_empty():
		GameManager.log_error("Failed to load SVG content", "GameSetup")
		get_tree().change_scene_to_file("uid://bnxj7rhwgcg67")
		return
	
	if not svg_image.load_svg_from_content(svg_content):
		GameManager.log_error("Failed to parse SVG", "GameSetup")
		get_tree().change_scene_to_file("uid://bnxj7rhwgcg67")
		return
	
	GameManager.I.game_completed_signal.connect(_on_game_completed)

func _on_game_completed() -> void:
	var time_taken = GameManager.I.get_time_taken()
	var elements_colored = GameManager.I.elements_colored
	
	GameManager.log_info("Game completed in %.2f seconds!" % time_taken, "Game")
	GameManager.log_info("Elements colored: %d" % elements_colored, "Game")
	
	_play_completion_animation()

func _play_completion_animation() -> void:
	var root_node := svg_image.get_svg_root()
	if not is_instance_valid(root_node):
		HUD.I._show_win_screen()
		return

	set_process_unhandled_input(false)

	var art_center := _get_art_center(root_node)

	var main_tween = create_tween()
	main_tween.set_parallel(false)

	Node2DPivot.tween_around(
		main_tween,
		root_node,
		art_center,
		Vector2.ONE,
		deg_to_rad(360.0),
		0.8,
		Tween.TRANS_BACK,
		Tween.EASE_IN_OUT
	)

	main_tween.tween_callback(HUD.I.show_win_screen)


func _get_art_center(svg_root_node: Node2D) -> Vector2:
	var half_panel := svg_image.size * 0.5

	if svg_root_node.scale == Vector2.ZERO:
		return Vector2.ZERO

	return (half_panel - svg_root_node.position) / svg_root_node.scale


#region zoom logic

var is_panning: bool = false
var is_moving: bool = false
var pan_start_pos: Vector2
var move_start_pos: Vector2
@onready var camera: Camera2D = %Camera2D

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.is_pressed():
				is_panning = true
				pan_start_pos = event.position
			else:
				is_panning = false
	
	if event is InputEventMouseMotion:
		#print(event)
		if is_panning:
			camera.position -= event.relative / camera.zoom
	
	if event is InputEventMagnifyGesture:
		_handle_zoom_at_point(event.factor, get_global_mouse_position())

	# Zooming with Mouse Wheel (to mouse position)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_handle_zoom_at_point(1.01, event.global_position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_handle_zoom_at_point(0.99, event.global_position)
	
	if event is InputEventMagnifyGesture:
		_handle_zoom_at_point(event.factor, get_global_mouse_position())


func _handle_zoom_at_point(zoom_factor: float, screen_position: Vector2) -> void:
	var viewport_rect := get_viewport_rect()
	
	# Convert screen position to viewport position
	var viewport_position := screen_position - viewport_rect.position
	
	# Get the world position before zoom
	var world_pos_before := camera.get_global_transform().affine_inverse() * viewport_position
	
	# Apply zoom
	var old_zoom := camera.zoom
	var new_zoom := old_zoom * zoom_factor
	new_zoom = new_zoom.clamp(Vector2(0.1, 0.1), Vector2(10.0, 10.0))
	camera.zoom = new_zoom
	
	# Get the world position after zoom
	var world_pos_after = camera.get_global_transform().affine_inverse() * viewport_position
	
	# Adjust camera position to keep the same world point under the mouse
	camera.position += world_pos_before - world_pos_after
	

#endregion
