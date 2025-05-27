class_name GameManager
extends Node

static var instance: GameManager

# Game state
var current_svg_path: String = ""
var game_started: bool = false
var start_time: float = 0.0

# Statistics
var elements_colored: int = 0
var total_elements: int = 0

signal game_started_signal
signal game_completed_signal(time_taken: float, elements_colored: int)

func _ready() -> void:
	instance = self

func start_game(svg_path: String) -> void:
	current_svg_path = svg_path
	HUD.selected_svg_path = svg_path
	game_started = true
	start_time = Time.get_unix_time_from_datetime_dict(Time.get_time_dict_from_system())
	elements_colored = 0
	
	game_started_signal.emit()

func on_element_colored() -> void:
	if game_started:
		elements_colored += 1
		_check_game_completion()

func _check_game_completion() -> void:
	if HUD.colors_for_image.is_empty():
		var end_time = Time.get_unix_time_from_datetime_dict(Time.get_time_dict_from_system())
		var time_taken = end_time - start_time
		game_completed_signal.emit(time_taken, elements_colored)
		game_started = false

static func log_warning(message: String, category: String = "General") -> void:
	if OS.is_debug_build():
		print_rich("[color=yellow][WARNING][/color] [", category, "] ", message)

static func log_error(message: String, category: String = "General") -> void:
	print_rich("[color=red][ERROR][/color] [", category, "] ", message)

static func log_info(message: String, category: String = "General") -> void:
	if OS.is_debug_build():
		print_rich("[color=cyan][INFO][/color] [", category, "] ", message)
