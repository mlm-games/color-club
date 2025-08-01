class_name GameManager
extends Node

static var I : GameManager

func _init() -> void:
	I = self

# Game state
var current_level: LevelData = null
var game_started: bool = false
var start_time: float = 0.0

static var selected_color: Color = Color.TRANSPARENT:
	set(value):
		if selected_color != value:
			selected_color = value
			HUD.I._on_color_selected(value)

# Statistics
var elements_colored: int = 0
var total_colorable_elements: int = 0
var unique_colors_completed: int = 0
var total_unique_colors: int = 0

signal game_started_signal
signal game_completed_signal
signal progress_updated(progress: float)

func start_game() -> void:
	game_started = true
	start_time = Time.get_unix_time_from_system()
	elements_colored = 0
	unique_colors_completed = 0
	total_colorable_elements = HUD.I.get_total_colorable_elements()
	total_unique_colors = HUD.I.color_registry.size()
	
	game_started_signal.emit()
	progress_updated.emit(0.0)
	log_info("Game started with SVG: " + str(current_level), "Game")
	log_info("Total colorable elements: " + str(total_colorable_elements), "Game")
	log_info("Total unique colors: " + str(total_unique_colors), "Game")

func register_element_colored() -> void:
	if game_started:
		elements_colored += 1
		var progress = float(elements_colored) / float(total_colorable_elements) if total_colorable_elements > 0 else 1.0
		progress_updated.emit(progress)
		
		log_info("Element colored. Progress: %d/%d" % [elements_colored, total_colorable_elements], "Game")
		
		_check_game_completion()

func register_color_completed() -> void:
	if game_started:
		unique_colors_completed += 1
		log_info("Color completed. Colors done: %d/%d" % [unique_colors_completed, total_unique_colors], "Game")


func get_time_taken() -> float:
	if start_time > 0:
		return Time.get_unix_time_from_system() - start_time
	return 0.0

func _check_game_completion() -> void:
	# Check against the source of truth from the HUD's registry.
	if HUD.I.get_remaining_colors() == 0:
		game_completed_signal.emit()
		game_started = false
		log_info("Game Completed!", "Game")

# --- Logging Utilities ---
static func log_warning(message: String, category: String = "General") -> void:
	if OS.is_debug_build():
		print_rich("[color=yellow][WARNING][/color] [", category, "] ", message)

static func log_error(message: String, category: String = "General") -> void:
	print_rich("[color=red][ERROR][/color] [", category, "] ", message)

static func log_info(message: String, category: String = "General") -> void:
	if OS.is_debug_build():
		print_rich("[color=cyan][INFO][/color] [", category, "] ", message)
