@tool
class_name SVGElement
extends Control

# Core SVG properties
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

# Transform properties
var svg_transform: Transform2D = Transform2D.IDENTITY
var has_transform: bool = false
var svg_id: String = ""

# SVG coordinate properties
var svg_x: float = 0.0
var svg_y: float = 0.0

# Bounds for proper sizing
var _content_bounds: Rect2 = Rect2()

func _ready() -> void:
	# Ensure we can receive input
	mouse_filter = Control.MOUSE_FILTER_PASS
	_update_size()

# Apply SVG transform properly according to Godot 4.4
func apply_svg_transform() -> void:
	if not has_transform:
		# No transform, just apply position
		position = Vector2(svg_x, svg_y)
		return
	
	# In Godot 4.4, we need to be careful about transform order
	# SVG transforms are applied in the order they appear, from right to left
	# when written as matrices
	
	# Reset to base position first
	position = Vector2.ZERO
	rotation = 0.0
	scale = Vector2.ONE
	
	# Create a compound transform that includes position
	var compound_transform = Transform2D.IDENTITY
	compound_transform.origin = Vector2(svg_x, svg_y)
	compound_transform = svg_transform * compound_transform
	
	# Extract the final position, rotation, and scale
	position = compound_transform.origin
	rotation = compound_transform.get_rotation()
	scale = compound_transform.get_scale()
	
	# For proper rotation/scale, we need to set the pivot
	# SVG rotates around (0,0) by default, not the element center
	pivot_offset = Vector2.ZERO

# Virtual methods to be overridden
func _calculate_content_bounds() -> Rect2:
	push_warning("SVGElement._calculate_content_bounds() not implemented in " + get_class())
	return Rect2()

func _draw_content() -> void:
	push_warning("SVGElement._draw_content() not implemented in " + get_class())

func _update_size() -> void:
	_content_bounds = _calculate_content_bounds()
	
	# Account for stroke in size calculation
	var total_size = _content_bounds.size + Vector2(stroke_width * 2, stroke_width * 2)
	
	custom_minimum_size = total_size
	size = total_size

func _draw() -> void:
	# Apply clipping to prevent drawing outside bounds
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	
	if highlighted:
		_draw_highlight()
	
	_draw_content()

func _draw_highlight() -> void:
	var highlight_rect = Rect2(Vector2.ZERO, size)
	draw_rect(highlight_rect, Color.YELLOW, false, 3.0)

# Get the drawing offset to account for stroke
func _get_draw_offset() -> Vector2:
	return Vector2(stroke_width, stroke_width)

# Common attribute parsing
func set_common_attributes(attributes: Dictionary) -> void:
	if "id" in attributes:
		svg_id = attributes["id"]
		name = svg_id
	
	# Store position attributes for later use
	if "x" in attributes:
		svg_x = float(attributes["x"])
	if "y" in attributes:
		svg_y = float(attributes["y"])
	
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
			if stroke_width == 0.0:
				stroke_width = 1.0
	
	if "stroke-width" in attributes:
		stroke_width = float(attributes["stroke-width"])
	
	if "opacity" in attributes:
		opacity = float(attributes["opacity"])
	
	if "style" in attributes:
		_apply_style_string(attributes["style"])
	
	if "transform" in attributes:
		has_transform = true
		svg_transform = SVGUtils.parse_transform(attributes["transform"])

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
				else:
					stroke_color = SVGUtils.parse_color(stroke_val)
					if stroke_width == 0.0:
						stroke_width = 1.0
			"stroke-width":
				stroke_width = float(styles[property])
			"opacity":
				opacity = float(styles[property])

# Improved hit testing
func _has_point(point: Vector2) -> bool:
	# Transform the point to local space
	var local_point = point
	
	# Check if point is within content bounds
	var content_rect = Rect2(_get_draw_offset(), _content_bounds.size)
	return content_rect.has_point(local_point)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if _has_point(mouse_event.position):
				accept_event()  # Prevent event propagation
				get_viewport().set_input_as_handled()
				# Emit signal through parent
				if get_parent() and get_parent().has_signal("element_clicked"):
					get_parent().emit_signal("element_clicked", self)
