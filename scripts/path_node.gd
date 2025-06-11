@tool
class_name SVGPath
extends SVGElement

var path_data: String = "":
	set(value):
		path_data = value
		_parse_path_data()
		_update_size()
		queue_redraw()

# Path parsing state
var _subpaths: Array[PackedVector2Array] = []
var _path_bounds: Rect2 = Rect2()
var _is_closed: bool = false


func _calculate_content_bounds() -> Rect2:
	return _path_bounds

func _draw_content() -> void:
	if _subpaths.is_empty():
		return
	
	var offset = _get_draw_offset()
	
	# Draw fill
	if fill_color.a > 0:
		for subpath in _subpaths:
			if subpath.size() > 2:
				var adjusted_points = PackedVector2Array()
				for point in subpath:
					adjusted_points.append(point + offset)
				draw_colored_polygon(adjusted_points, fill_color)
	
	# Draw stroke
	if stroke_width > 0 and stroke_color.a > 0:
		for subpath in _subpaths:
			if subpath.size() > 1:
				var adjusted_points = PackedVector2Array()
				for point in subpath:
					adjusted_points.append(point + offset)
				draw_polyline(adjusted_points, stroke_color, stroke_width, true)

func _parse_path_data() -> void:
	if path_data.is_empty():
		_subpaths.clear()
		_path_bounds = Rect2()
		return
	
	_subpaths.clear()
	var current_subpath = PackedVector2Array()
	var current_pos = Vector2.ZERO
	var last_control_point = Vector2.ZERO
	var subpath_start = Vector2.ZERO
	var last_command = ""
	
	var tokens = _tokenize_path(path_data)
	var i = 0
	
	while i < tokens.size():
		var command = tokens[i]
		var is_relative = command == command.to_lower()
		var cmd = command.to_upper()
		i += 1
		
		match cmd:
			"M":  # Move to
				if current_subpath.size() > 0:
					_subpaths.append(current_subpath)
					current_subpath = PackedVector2Array()
				
				var point = _get_point(tokens, i, is_relative, current_pos)
				current_pos = point
				subpath_start = point
				current_subpath.append(point)
				i += 2
				
				# Subsequent pairs are implicit line-to commands
				while i + 1 < tokens.size() and _is_number(tokens[i]):
					point = _get_point(tokens, i, is_relative, current_pos)
					current_pos = point
					current_subpath.append(point)
					i += 2
			
			"L":  # Line to
				while i + 1 < tokens.size() and _is_number(tokens[i]):
					var point = _get_point(tokens, i, is_relative, current_pos)
					current_pos = point
					current_subpath.append(point)
					i += 2
			
			"H":  # Horizontal line
				while i < tokens.size() and _is_number(tokens[i]):
					var x = float(tokens[i])
					if is_relative:
						x += current_pos.x
					current_pos.x = x
					current_subpath.append(current_pos)
					i += 1
			
			"V":  # Vertical line
				while i < tokens.size() and _is_number(tokens[i]):
					var y = float(tokens[i])
					if is_relative:
						y += current_pos.y
					current_pos.y = y
					current_subpath.append(current_pos)
					i += 1
			
			"C":  # Cubic Bezier curve
				while i + 5 < tokens.size() and _is_number(tokens[i]):
					var cp1 = _get_point(tokens, i, is_relative, current_pos)
					i += 2
					var cp2 = _get_point(tokens, i, is_relative, current_pos)
					i += 2
					var end = _get_point(tokens, i, is_relative, current_pos)
					i += 2
					
					SVGUtils._add_cubic_bezier(current_subpath, current_pos, cp1, cp2, end)
					last_control_point = cp2
					current_pos = end
			
			"S":  # Smooth cubic Bezier
				while i + 3 < tokens.size() and _is_number(tokens[i]):
					var cp1 = current_pos
					if last_command in ["C", "S"]:
						# Reflect the last control point
						cp1 = current_pos * 2 - last_control_point
					
					var cp2 = _get_point(tokens, i, is_relative, current_pos)
					i += 2
					var end = _get_point(tokens, i, is_relative, current_pos)
					i += 2
					
					SVGUtils._add_cubic_bezier(current_subpath, current_pos, cp1, cp2, end)
					last_control_point = cp2
					current_pos = end
			
			"Q":  # Quadratic Bezier curve
				while i + 3 < tokens.size() and _is_number(tokens[i]):
					var cp = _get_point(tokens, i, is_relative, current_pos)
					i += 2
					var end = _get_point(tokens, i, is_relative, current_pos)
					i += 2
					
					SVGUtils._add_quadratic_bezier(current_subpath, current_pos, cp, end)
					last_control_point = cp
					current_pos = end
			
			"T":  # Smooth quadratic Bezier
				while i + 1 < tokens.size() and _is_number(tokens[i]):
					var cp = current_pos
					if last_command in ["Q", "T"]:
						# Reflect the last control point
						cp = current_pos * 2 - last_control_point
					
					var end = _get_point(tokens, i, is_relative, current_pos)
					i += 2
					
					SVGUtils._add_quadratic_bezier(current_subpath, current_pos, cp, end)
					last_control_point = cp
					current_pos = end
			
			"A":  # Arc
				while i + 6 < tokens.size() and _is_number(tokens[i]):
					var rx = float(tokens[i])
					var ry = float(tokens[i + 1])
					var x_axis_rotation_deg = float(tokens[i + 2])
					var large_arc_flag = int(float(tokens[i + 3])) == 1
					var sweep_flag = int(float(tokens[i + 4])) == 1
					var end = _get_point(tokens, i + 5, is_relative, current_pos)
					i += 7
					
					var arc_points = SVGUtils.tessellate_elliptical_arc(current_pos, rx, ry, 
							x_axis_rotation_deg, large_arc_flag, sweep_flag, end, SVGUtils.CURVE_SEGMENTS)
						
					if arc_points.size() > 1:
						current_subpath.append_array(arc_points.slice(1))
					current_pos = end
			
			"Z", "z":  
				if current_subpath.size() > 0:
					current_subpath.append(subpath_start)
					current_pos = subpath_start
				_is_closed = true
			
			_:
				push_warning("Unknown path command: " + command)
		
		last_command = cmd
	
	# Add the last subpath
	if current_subpath.size() > 0:
		_subpaths.append(current_subpath)
	
	_calculate_path_bounds()

# Helper functions
func _is_number(token: String) -> bool:
	return token.is_valid_float() or token == "-" or token == "."

func _get_point(tokens: Array[String], index: int, is_relative: bool, current_pos: Vector2) -> Vector2:
	if index + 1 >= tokens.size():
		return current_pos
	
	var x = float(tokens[index])
	var y = float(tokens[index + 1])
	
	if is_relative:
		return current_pos + Vector2(x, y)
	return Vector2(x, y)


# Improved tokenizer
func _tokenize_path(data: String) -> Array[String]:
	var tokens: Array[String] = []
	var current_token = ""
	var last_was_command = false
	
	for i in range(data.length()):
		var chr = data[i]
		
		if chr in " ,\t\n\r":
			if not current_token.is_empty():
				tokens.append(current_token)
				current_token = ""
				last_was_command = false
		elif chr in "MmLlHhVvCcSsQqTtAaZz":
			if not current_token.is_empty():
				tokens.append(current_token)
			tokens.append(chr)
			current_token = ""
			last_was_command = true
		elif chr == "-" and not current_token.is_empty() and not last_was_command:
			# Negative number
			tokens.append(current_token)
			current_token = "-"
		elif chr == "." and "." in current_token:
			# New decimal number
			tokens.append(current_token)
			current_token = "."
		else:
			current_token += chr
	
	if not current_token.is_empty():
		tokens.append(current_token)
	
	return tokens

func _calculate_path_bounds() -> void:
	if _subpaths.is_empty():
		_path_bounds = Rect2()
		return
	
	var min_point = Vector2.INF
	var max_point = -Vector2.INF
	
	for subpath in _subpaths:
		for point in subpath:
			min_point.x = min(min_point.x, point.x)
			min_point.y = min(min_point.y, point.y)
			max_point.x = max(max_point.x, point.x)
			max_point.y = max(max_point.y, point.y)
	
	_path_bounds = Rect2(min_point, max_point - min_point)

func set_path_properties(attributes: Dictionary) -> void:
	if "d" in attributes:
		path_data = attributes["d"]
	
	set_common_attributes(attributes)
	apply_svg_transform()

# Improved hit testing for paths
func _has_point(point: Vector2) -> bool:
	# Adjust point for stroke offset
	var test_point = point - _get_draw_offset()
	
	# For stroked paths, check distance to path
	if stroke_width > 0 and stroke_color.a > 0:
		for subpath in _subpaths:
			if _point_near_polyline(test_point, subpath, stroke_width * 0.5):
				return true
	
	# For filled paths, use point-in-polygon test
	if fill_color.a > 0:
		for subpath in _subpaths:
			if _point_in_polygon(test_point, subpath):
				return true
	
	return false

func _point_near_polyline(point: Vector2, polyline: PackedVector2Array, threshold: float) -> bool:
	if polyline.size() < 2:
		return false
	
	for i in range(polyline.size() - 1):
		var dist = _point_to_segment_distance(point, polyline[i], polyline[i + 1])
		if dist <= threshold:
			return true
	
	return false

func _point_to_segment_distance(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab = b - a
	var ap = point - a
	var ab_squared = ab.dot(ab)
	
	if ab_squared == 0:
		return point.distance_to(a)
	
	var t = clamp(ap.dot(ab) / ab_squared, 0.0, 1.0)
	var projection = a + ab * t
	return point.distance_to(projection)

func _point_in_polygon(point: Vector2, polygon: PackedVector2Array) -> bool:
	if polygon.size() < 3:
		return false
	
	var inside = false
	var p1 = polygon[0]
	
	for i in range(1, polygon.size() + 1):
		var p2 = polygon[i % polygon.size()]
		
		if point.y > min(p1.y, p2.y):
			if point.y <= max(p1.y, p2.y):
				if point.x <= max(p1.x, p2.x):
					if p1.y != p2.y:
						var xinters = (point.y - p1.y) * (p2.x - p1.x) / (p2.y - p1.y) + p1.x
						if p1.x == p2.x or point.x <= xinters:
							inside = not inside
		
		p1 = p2
	
	return inside
