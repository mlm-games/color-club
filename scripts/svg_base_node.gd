@tool
class_name SVGElement
extends Control

# Core SVG properties that all elements share
@export var fill_color: Color = Color.WHITE:
	set(value):
		fill_color = value
		queue_redraw()

@export var stroke_color: Color = Color.TRANSPARENT:
	set(value):
		stroke_color = value
		queue_redraw()

@export var stroke_width: float = 0.0:
	set(value):
		stroke_width = value
		_update_size()
		queue_redraw()

@export var opacity: float = 1.0:
	set(value):
		opacity = clamp(value, 0.0, 1.0)
		modulate.a = opacity

@export var highlighted: bool = false:
	set(value):
		highlighted = value
		queue_redraw()

# Transform and positioning
var svg_transform: Transform2D = Transform2D.IDENTITY
var has_transform: bool = false
var svg_id: String = ""

# Bounds for proper sizing
var _shape_bounds: Rect2 = Rect2()

func _ready() -> void:
	_update_size()

# Only apply transforms if they exist
func _apply_svg_transform() -> void:
	if not has_transform:
		return
	
	# Extract transform components
	var transform_origin = svg_transform.origin
	var transform_rotation = svg_transform.get_rotation()
	var transform_scale = svg_transform.get_scale()
	
	# Apply rotation and scale around center
	if transform_rotation != 0.0 or transform_scale != Vector2.ONE:
		pivot_offset = size * 0.5
		rotation = transform_rotation
		scale = transform_scale
	
	# Apply translation
	if transform_origin != Vector2.ZERO:
		position += transform_origin

# Virtual methods to be overridden by subclasses
func _calculate_shape_bounds() -> Rect2:
	push_warning("SVGElement._calculate_shape_bounds() not implemented in " + get_class())
	return Rect2()

func _draw_content() -> void:
	push_warning("SVGElement._draw_content() not implemented in " + get_class())

func _update_size() -> void:
	_shape_bounds = _calculate_shape_bounds()
	
	# The control size should accommodate both the shape and the stroke
	var stroke_padding = stroke_width * 0.5
	var total_size = _shape_bounds.size + Vector2(stroke_width, stroke_width)
	
	custom_minimum_size = total_size
	size = total_size

func _draw() -> void:
	if highlighted:
		_draw_highlight()
	
	_draw_content()

func _draw_highlight() -> void:
	var highlight_rect = Rect2(Vector2.ZERO, size)
	draw_rect(highlight_rect, Color.YELLOW, false, 2.0)

# Get the drawing offset to center the shape within the control
func _get_draw_offset() -> Vector2:
	return Vector2(stroke_width * 0.5, stroke_width * 0.5)

# Common attribute parsing
func set_common_attributes(attributes: Dictionary) -> void:
	if "id" in attributes:
		svg_id = attributes["id"]
		name = svg_id
	
	if "fill" in attributes:
		var fill_val = attributes["fill"].strip_edges().to_lower()
		if fill_val == "none":
			fill_color = Color.TRANSPARENT
		else:
			fill_color = SVGUtils.parse_color(fill_val)
	
	if "stroke" in attributes:
		var stroke_val = attributes["stroke"].strip_edges().to_lower()
		if stroke_val == "none":
			stroke_color = Color.TRANSPARENT
		else:
			stroke_color = SVGUtils.parse_color(stroke_val)
			# If stroke is specified but no width, default to 1
			if stroke_width == 0.0:
				stroke_width = 1.0
	
	if "stroke-width" in attributes:
		stroke_width = float(attributes["stroke-width"])
	
	if "opacity" in attributes:
		opacity = float(attributes["opacity"])
	
	if "style" in attributes:
		_apply_style_string(attributes["style"])
	
	# Only handle transform if it exists
	if "transform" in attributes:
		has_transform = true
		svg_transform = SVGUtils.parse_transform(attributes["transform"])
	
	# Make sure the element can receive mouse input
	mouse_filter = Control.MOUSE_FILTER_PASS

func _apply_style_string(style_string: String) -> void:
	var styles = SVGUtils.parse_style_string(style_string)
	for property in styles:
		match property:
			"fill":
				var fill_val = styles[property].to_lower()
				fill_color = Color.TRANSPARENT if fill_val == "none" else SVGUtils.parse_color(fill_val)
			"stroke":
				var stroke_val = styles[property].to_lower()
				if stroke_val == "none":
					stroke_color = Color.TRANSPARENT
					stroke_width = 0.0
				else:
					stroke_color = SVGUtils.parse_color(stroke_val)
					if stroke_width == 0.0:
						stroke_width = 1.0
			"stroke-width":
				stroke_width = float(styles[property])
			"opacity":
				opacity = float(styles[property])
			_:
				push_warning("Unimplemented CSS property: " + property)

func contains_point(point: Vector2) -> bool:
	var offset = _get_draw_offset()
	var shape_rect = Rect2(offset, _shape_bounds.size)
	return shape_rect.has_point(point)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if contains_point(mouse_event.position):
				_on_clicked()

func _on_clicked() -> void:
	if get_parent().has_signal("element_clicked"):
		get_parent().emit_signal("element_clicked", self)
