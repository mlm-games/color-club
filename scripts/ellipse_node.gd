@tool  # Allows the node to work in the editor
class_name SVGEllipse
extends SVGElement

# SVG Properties
@export var radius_x: float = 10.0:
	set(value):
		radius_x = value
		queue_redraw()

@export var radius_y: float = 10.0:
	set(value):
		radius_y= value
		queue_redraw()

# Optional: Helper method to set all properties at once
func set_ellipse_properties(attributes: Dictionary) -> void:
	if "cx" in attributes:
		position.x = float(attributes["cx"])
	if "cy" in attributes:
		position.y = float(attributes["cy"])
	if "rx" in attributes:
		radius_x = float(attributes["rx"])
	if "ry" in attributes:
		radius_y = float(attributes["ry"])
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
	
	queue_redraw()

func _draw() -> void:
		# Draw fill if color has any opacity
		if fill_color.a > 0:
			#FIXME: Use when this gets merged: https://github.com/godotengine/godot/pull/85080
			#draw_ellipse(Vector2.ZERO, Vector2(radius_x, radius_y), fill_color)
			pass
		
		# Draw stroke if width is greater than 0
		if stroke_width > 0:
				var points := _get_ellipse_points(32)  # 32 points for smooth approximation
				draw_polyline(points, stroke_color, stroke_width, true)
				# Close the ellipse by connecting the last point to the first
				points.append(points[0])
				draw_polyline(points, stroke_color, stroke_width, true)

# Helper function to generate ellipse points
func _get_ellipse_points(point_count: int) -> Array[Vector2]:
		var points: Array[Vector2] = []
		for i in range(point_count):
				var angle := float(i) / point_count * TAU  # TAU = 2 * PI
				var x := radius_x * cos(angle)
				var y := radius_y * sin(angle)
				points.append(Vector2(x, y))
		return points
