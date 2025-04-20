@tool
class_name SVGRect extends SVGElement

# Rectangle properties
@export var width: float = 10.0:
	set(value):
		width = value
		_update_control_size()
		queue_redraw()

@export var height: float = 10.0:
	set(value):
		height = value
		_update_control_size()
		queue_redraw()

@export var corner_radius_x: float = 0.0:
	set(value):
		corner_radius_x = value
		queue_redraw()

@export var corner_radius_y: float = 0.0:
	set(value):
		corner_radius_y = value
		queue_redraw()

func _ready() -> void:
	super._ready()
	_update_shape_points()

func set_rect_properties(attributes: Dictionary) -> void:
	set_common_attributes(attributes)
	
	if "x" in attributes:
		position.x = float(attributes["x"])
	if "y" in attributes:
		position.y = float(attributes["y"])
	if "width" in attributes:
		width = float(attributes["width"])
	if "height" in attributes:
		height = float(attributes["height"])
	if "rx" in attributes:
		corner_radius_x = float(attributes["rx"])
		if not "ry" in attributes:
			corner_radius_y = corner_radius_x  # Default behavior per SVG spec
	if "ry" in attributes:
		corner_radius_y = float(attributes["ry"])
		if not "rx" in attributes:
			corner_radius_x = corner_radius_y  # Default behavior per SVG spec
	
	_update_control_size()
	_update_shape_points()
	queue_redraw()

func _update_control_size() -> void:
	var total_width := width + stroke_width * 2
	var total_height := height + stroke_width * 2
	custom_minimum_size = Vector2(total_width, total_height)
	size = custom_minimum_size
	
	# Update bounds
	_bounds_min = Vector2.ZERO
	_bounds_max = Vector2(width, height)

func _update_shape_points() -> void:
	_shape_points.clear()
	
	# Create a polygon approximation of the rectangle for hit detection
	if corner_radius_x > 0 or corner_radius_y > 0:
		# For rounded rectangles we use a simplified polygon
		var rx := minf(corner_radius_x, width/2)
		var ry := minf(corner_radius_y, height/2)
		
		# Add points in clockwise order
		_shape_points.append(Vector2(rx, 0))
		_shape_points.append(Vector2(width - rx, 0))
		_shape_points.append(Vector2(width, ry))
		_shape_points.append(Vector2(width, height - ry))
		_shape_points.append(Vector2(width - rx, height))
		_shape_points.append(Vector2(rx, height))
		_shape_points.append(Vector2(0, height - ry))
		_shape_points.append(Vector2(0, ry))
	else:
		# Simple rectangle
		_shape_points.append(Vector2(0, 0))
		_shape_points.append(Vector2(width, 0))
		_shape_points.append(Vector2(width, height))
		_shape_points.append(Vector2(0, height))

func _draw() -> void:
	# Account for stroke width in drawing
	var offset := Vector2(stroke_width, stroke_width)
	var draw_width := width
	var draw_height := height
	
	# Draw fill
	if fill_color.a > 0:
		if corner_radius_x > 0 or corner_radius_y > 0:
			# Use rounded rectangle
			var rx := minf(corner_radius_x, width/2)
			var ry := minf(corner_radius_y, height/2)
			draw_rounded_rect(Rect2(offset, Vector2(draw_width, draw_height)), 
							 rx, ry, fill_color)
		else:
			# Simple rectangle
			draw_rect(Rect2(offset, Vector2(draw_width, draw_height)), 
					 fill_color, true)
	
	# Draw stroke
	if stroke_width > 0:
		if corner_radius_x > 0 or corner_radius_y > 0:
			# Rounded rectangle stroke
			var rx := minf(corner_radius_x, width/2)
			var ry := minf(corner_radius_y, height/2)
			draw_rounded_rect(Rect2(offset, Vector2(draw_width, draw_height)), 
							 rx, ry, stroke_color, false, stroke_width)
		else:
			# Simple rectangle stroke
			draw_rect(Rect2(offset, Vector2(draw_width, draw_height)), 
					 stroke_color, false, stroke_width)

func _is_point_in_shape(point: Vector2) -> bool:
	# For non-rounded rectangles, simple bounds check is enough
	if corner_radius_x == 0 and corner_radius_y == 0:
		var offset := Vector2(stroke_width, stroke_width)
		var rect := Rect2(offset, Vector2(width, height))
		return rect.has_point(point)
	
	# For rounded rectangles, use the polygon approximation
	return Geometry2D.is_point_in_polygon(point, _shape_points)

# Helper function to draw rounded rectangles
func draw_rounded_rect(rect: Rect2, radius_x: float, radius_y: float, 
					  color: Color, filled: bool = true, line_width: float = 1.0) -> void:
	# Ensure radii aren't too large
	radius_x = min(radius_x, rect.size.x / 2)
	radius_y = min(radius_y, rect.size.y / 2)
	
	if filled:
		# Draw center rectangle
		draw_rect(Rect2(rect.position.x + radius_x, rect.position.y, 
					   rect.size.x - 2 * radius_x, rect.size.y), color, true)
		
		# Draw left and right rectangles
		draw_rect(Rect2(rect.position.x, rect.position.y + radius_y,
					   radius_x, rect.size.y - 2 * radius_y), color, true)
		draw_rect(Rect2(rect.position.x + rect.size.x - radius_x, rect.position.y + radius_y,
					   radius_x, rect.size.y - 2 * radius_y), color, true)
		
		# Draw the four corner arcs
		draw_circle_arc(Vector2(rect.position.x + radius_x, rect.position.y + radius_y), 
						radius_x, radius_y, PI, 1.5 * PI, color, true)
		draw_circle_arc(Vector2(rect.position.x + rect.size.x - radius_x, rect.position.y + radius_y), 
						radius_x, radius_y, 1.5 * PI, TAU, color, true)
		draw_circle_arc(Vector2(rect.position.x + radius_x, rect.position.y + rect.size.y - radius_y), 
						radius_x, radius_y, 0.5 * PI, PI, color, true)
		draw_circle_arc(Vector2(rect.position.x + rect.size.x - radius_x, rect.position.y + rect.size.y - radius_y), 
						radius_x, radius_y, 0, 0.5 * PI, color, true)
	else:
		# Draw horizontal lines
		draw_line(Vector2(rect.position.x + radius_x, rect.position.y), 
				 Vector2(rect.position.x + rect.size.x - radius_x, rect.position.y), 
				 color, line_width)
		draw_line(Vector2(rect.position.x + radius_x, rect.position.y + rect.size.y), 
				 Vector2(rect.position.x + rect.size.x - radius_x, rect.position.y + rect.size.y), 
				 color, line_width)
		
		# Draw vertical lines
		draw_line(Vector2(rect.position.x, rect.position.y + radius_y), 
				 Vector2(rect.position.x, rect.position.y + rect.size.y - radius_y), 
				 color, line_width)
		draw_line(Vector2(rect.position.x + rect.size.x, rect.position.y + radius_y), 
				 Vector2(rect.position.x + rect.size.x, rect.position.y + rect.size.y - radius_y), 
				 color, line_width)
		
		# Draw the four corner arcs
		draw_circle_arc(Vector2(rect.position.x + radius_x, rect.position.y + radius_y), 
						radius_x, radius_y, PI, 1.5 * PI, color, false, line_width)
		draw_circle_arc(Vector2(rect.position.x + rect.size.x - radius_x, rect.position.y + radius_y), 
						radius_x, radius_y, 1.5 * PI, TAU, color, false, line_width)
		draw_circle_arc(Vector2(rect.position.x + radius_x, rect.position.y + rect.size.y - radius_y), 
						radius_x, radius_y, 0.5 * PI, PI, color, false, line_width)
		draw_circle_arc(Vector2(rect.position.x + rect.size.x - radius_x, rect.position.y + rect.size.y - radius_y), 
						radius_x, radius_y, 0, 0.5 * PI, color, false, line_width)

# Helper function to draw elliptical arcs
func draw_circle_arc(center: Vector2, radius_x: float, radius_y: float, 
					angle_from: float, angle_to: float, color: Color, 
					filled: bool = false, line_width: float = 1.0) -> void:
	var nb_points := 32
	var points_arc := PackedVector2Array()
	
	if filled:
		points_arc.append(center)
	
	for i in range(nb_points + 1):
		var angle_point := angle_from + i * (angle_to - angle_from) / nb_points
		points_arc.append(center + Vector2(
			cos(angle_point) * radius_x,
			sin(angle_point) * radius_y
		))
	
	if filled:
		draw_colored_polygon(points_arc, color)
	else:
		for i in range(1, points_arc.size()):
			draw_line(points_arc[i-1], points_arc[i], color, line_width)
