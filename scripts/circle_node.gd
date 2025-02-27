@tool  # Allows the node to work in the editor
class_name SVGCircle
extends Node2D

# SVG Properties
@export var radius: float = 10.0:
	set(value):
		radius = value
		queue_redraw()

@export var fill_color: Color = Color.WHITE:
	set(value):
		fill_color = value
		queue_redraw()

@export var stroke_color: Color = Color.BLACK:
	set(value):
		stroke_color = value
		queue_redraw()

@export var stroke_width: float = 0.0:
	set(value):
		stroke_width = value/2
		#TODO: fix to put value instead of value/2
		queue_redraw()

@export var opacity: float = 1.0:
	set(value):
		opacity = value
		modulate.a = value

# Optional: Helper method to set all properties at once
func set_circle_properties(attributes: Dictionary) -> void:
	if "cx" in attributes:
		position.x = float(attributes["cx"])
	if "cy" in attributes:
		position.y = float(attributes["cy"])
	if "r" in attributes:
		radius = float(attributes["r"])
	if "fill" in attributes:
		fill_color = Color.html(attributes["fill"])
	if "stroke" in attributes:
		stroke_color = Color.html(attributes["stroke"])
	if "stroke-width" in attributes:
		stroke_width = float(attributes["stroke-width"])
	if "opacity" in attributes:
		opacity = float(attributes["opacity"])
	if "id" in attributes:
		name = attributes["id"]
	if "style" in attributes:
		SVGUtils.apply_css_styles_for_shape(SVGUtils.analyse_style(attributes["style"]), self)
	
	queue_redraw()

func _draw() -> void:
	# Draw fill if color has any opacity
	if fill_color.a > 0:
		draw_circle(Vector2.ZERO, radius, fill_color)
	
	# Draw stroke if width is greater than 0
	if stroke_width > 0:
		# Use 32 points for smooth circle approximation
		# TAU is equivalent to 2*PI
		draw_arc(
			Vector2.ZERO,  # Center point
			radius,        # Radius
			0,            # Start angle
			TAU,          # End angle (full circle)
			32,           # Number of points
			stroke_color, # Stroke color
			stroke_width, # Line width
			true         # Antialiasing
		)
