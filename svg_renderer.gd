
# Main SVG renderer
extends Node2D

var svg_elements: Dictionary = {}  # Store SVGShapeElement instances
var shape_sprites: Dictionary = {}  # Store Sprite2D instances
var rendering_thread: Thread
var mutex: Mutex = Mutex.new()
var render_at_half_resolution: bool = false
var display_scale: float = 1.0
var rendered_scale: float = 0.0

func _ready() -> void:
	get_tree().get_root().connect("size_changed", window_size
