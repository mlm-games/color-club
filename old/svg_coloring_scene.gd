# Main SVG Coloring Game
class_name SVGColoringGame
extends Node2D

var coloring_data: SVGColoringData
var current_color: Color
var colored_areas: Dictionary = {}  # area_id: Color
var interactive_areas: Dictionary = {}  # area_id: ColoringArea

signal area_colored(area_id: String, color: Color)
signal color_extracted(colors: Array[Color])
signal invalid_coloring(area_id: String)

func load_svg(path: String) -> void:
	var extractor = SVGColorExtractor.new()
	coloring_data = extractor.extract_from_file(path)
	setup_coloring_areas()
	emit_signal("color_extracted", coloring_data.color_palette)

func setup_coloring_areas() -> void:
	for area_id in coloring_data.areas:
		var area_data = coloring_data.areas[area_id]
		var coloring_area = create_coloring_area(area_data)
		interactive_areas[area_id] = coloring_area
		add_child(coloring_area)

func create_coloring_area(area_data: SVGColorExtractor.ColorArea) -> ColoringArea:
	var area = ColoringArea.new()
	area.initialize(area_data)
	#area.area_clicked.connect(_on_area_clicked)
	return area
