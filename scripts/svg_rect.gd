@tool
class_name SVGRect
extends SVGElement

@export var rect_width: float = 10.0:
	set(value):
		rect_width = max(0, value)
		_update_size()
		queue_redraw()

@export var rect_height: float = 10.0:
	set(value):
		rect_height = max(0, value)
		_update_size()
		queue_redraw()

@export var corner_radius_x: float = 0.0:
	set(value):
		corner_radius_x = max(0, value)
		queue_redraw()

@export var corner_radius_y: float = 0.0:
	set(value):
		corner_radius_y = max(0, value)
		queue_redraw()

func _calculate_shape_bounds() -> Rect2:
	return Rect2(0, 0, rect_width, rect_height)

func _draw_content() -> void:
	var draw_offset = _get_draw_offset()
	var shape_rect = Rect2(draw_offset, Vector2(rect_width, rect_height))
	
	# Draw fill first
	if fill_color.a > 0:
		if corner_radius_x > 0 or corner_radius_y > 0:
			_draw_rounded_rect_fill(shape_rect, corner_radius_x, corner_radius_y, fill_color)
		else:
			draw_rect(shape_rect, fill_color)
	
	# Draw stroke
	if stroke_width > 0 and stroke_color.a > 0:
		if corner_radius_x > 0 or corner_radius_y > 0:
			_draw_rounded_rect_stroke_proper(shape_rect, corner_radius_x, corner_radius_y, stroke_color)
		else:
			draw_rect(shape_rect, stroke_color, false, stroke_width)

func _draw_rounded_rect_fill(rect: Rect2, rx: float, ry: float, color: Color) -> void:
	rx = min(rx, rect.size.x * 0.5)
	ry = min(ry, rect.size.y * 0.5)
	
	# Draw center rectangle (vertical)
	draw_rect(Rect2(rect.position.x, rect.position.y + ry, rect.size.x, rect.size.y - 2*ry), color)
	# Draw center rectangle (horizontal)
	draw_rect(Rect2(rect.position.x + rx, rect.position.y, rect.size.x - 2*rx, rect.size.y), color)
	
	# Draw corner circles
	var corners = [
		rect.position + Vector2(rx, ry),
		rect.position + Vector2(rect.size.x - rx, ry),
		rect.position + Vector2(rx, rect.size.y - ry),
		rect.position + Vector2(rect.size.x - rx, rect.size.y - ry)
	]
	
	for corner in corners:
		draw_circle(corner, min(rx, ry), color)

# Fixed rounded rectangle stroke - no overlapping
func _draw_rounded_rect_stroke_proper(rect: Rect2, rx: float, ry: float, color: Color) -> void:
	rx = min(rx, rect.size.x * 0.5)
	ry = min(ry, rect.size.y * 0.5)
	var radius = min(rx, ry)
	
	# Create a continuous path for the rounded rectangle outline
	var points = PackedVector2Array()
	var segments_per_arc = 16  # Number of segments per corner arc
	
	# Start from top-left corner, going clockwise
	
	# Top-left arc (from 180° to 270°)
	var center_tl = rect.position + Vector2(rx, ry)
	for i in range(segments_per_arc + 1):
		var angle = PI + (PI * 0.5) * float(i) / float(segments_per_arc)
		points.append(center_tl + Vector2(cos(angle), sin(angle)) * radius)
	
	# Top edge (already have the start point from arc)
	points.append(Vector2(rect.position.x + rect.size.x - rx, rect.position.y))
	
	# Top-right arc (from 270° to 360°)
	var center_tr = rect.position + Vector2(rect.size.x - rx, ry)
	for i in range(1, segments_per_arc + 1):
		var angle = PI * 1.5 + (PI * 0.5) * float(i) / float(segments_per_arc)
		points.append(center_tr + Vector2(cos(angle), sin(angle)) * radius)
	
	# Right edge
	points.append(Vector2(rect.position.x + rect.size.x, rect.position.y + rect.size.y - ry))
	
	# Bottom-right arc (from 0° to 90°)
	var center_br = rect.position + Vector2(rect.size.x - rx, rect.size.y - ry)
	for i in range(1, segments_per_arc + 1):
		var angle = (PI * 0.5) * float(i) / float(segments_per_arc)
		points.append(center_br + Vector2(cos(angle), sin(angle)) * radius)
	
	# Bottom edge
	points.append(Vector2(rect.position.x + rx, rect.position.y + rect.size.y))
	
	# Bottom-left arc (from 90° to 180°)
	var center_bl = rect.position + Vector2(rx, rect.size.y - ry)
	for i in range(1, segments_per_arc + 1):
		var angle = PI * 0.5 + (PI * 0.5) * float(i) / float(segments_per_arc)
		points.append(center_bl + Vector2(cos(angle), sin(angle)) * radius)
	
	# Left edge (close the path)
	points.append(Vector2(rect.position.x, rect.position.y + ry))
	
	# Close the path by connecting back to start
	if points.size() > 0:
		points.append(points[0])
	
	# Draw the complete outline as one continuous stroke
	if points.size() > 1:
		draw_polyline(points, color, stroke_width, true)

func set_rect_properties(attributes: Dictionary) -> void:
	# Parse dimensions first
	if "width" in attributes:
		rect_width = float(attributes["width"])
	if "height" in attributes:
		rect_height = float(attributes["height"])
	if "rx" in attributes:
		corner_radius_x = float(attributes["rx"])
		if not "ry" in attributes:
			corner_radius_y = corner_radius_x
	if "ry" in attributes:
		corner_radius_y = float(attributes["ry"])
		if not "rx" in attributes:
			corner_radius_x = corner_radius_y
	
	# Store SVG coordinates
	var svg_x = 0.0
	var svg_y = 0.0
	if "x" in attributes:
		svg_x = float(attributes["x"])
	if "y" in attributes:
		svg_y = float(attributes["y"])
	
	# Apply common attributes (this sets has_transform and svg_transform)
	set_common_attributes(attributes)
	
	# Handle positioning based on whether we have transforms
	if has_transform:
		# For transformed elements, we need to handle SVG's transform origin
		# SVG transforms are applied around the element's top-left corner by default
		
		# Set position to SVG coordinates first
		position = Vector2(svg_x, svg_y)
		
		# Apply the transform
		_apply_svg_transform_properly()
	else:
		# For non-transformed elements, use simple positioning
		position = Vector2(svg_x, svg_y)

# Proper transform application for SVG coordinate system
func _apply_svg_transform_properly() -> void:
	if not has_transform:
		return
	
	# Extract transform components
	var transform_origin = svg_transform.origin
	var transform_rotation = svg_transform.get_rotation()
	var transform_scale = svg_transform.get_scale()
	
	# For SVG, transforms are applied around the coordinate system origin,
	# not the element center. We need to account for this.
	
	# Apply scale and rotation around the top-left corner (SVG default)
	if transform_rotation != 0.0 or transform_scale != Vector2.ONE:
		# Set pivot to top-left for SVG-style transforms
		pivot_offset = Vector2.ZERO
		rotation = transform_rotation
		scale = transform_scale
	
	# Apply translation
	position += transform_origin
