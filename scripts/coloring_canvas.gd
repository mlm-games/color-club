extends Control

@onready var svg_image: SVGImage = $SVGImage
@onready var hud: HUD = $HUD
@onready var game_manager: GameManager = $GameManager

func _ready() -> void:
	# Validate and load SVG
	var svg_path = HUD.selected_svg_path
	
	var validation = SVGValidator.validate_svg_file(svg_path)
	if not validation.is_valid:
		for error in validation.errors:
			GameManager.log_error(error, "SVG")
		return
	
	# Show warnings
	for warning in validation.warnings:
		GameManager.log_warning(warning, "SVG")
	
	for unsupported in validation.unsupported_features:
		GameManager.log_warning(unsupported, "SVG")
	
	# Start the game
	game_manager.start_game(svg_path)
	
	# Connect signals
	svg_image.element_clicked.connect(_on_element_clicked)
	game_manager.game_completed_signal.connect(_on_game_completed)

func _on_element_clicked(element: SVGElement) -> void:
	GameManager.log_info("Element clicked: " + element.name, "Game")
	game_manager.on_element_colored()

func _on_game_completed(time_taken: float, elements_colored: int) -> void:
	GameManager.log_info("Game completed in %.2f seconds!" % time_taken, "Game")
	GameManager.log_info("Elements colored: %d" % elements_colored, "Game")
