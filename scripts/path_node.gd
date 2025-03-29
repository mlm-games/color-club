@tool
class_name SVGPath extends SVGElement

#FIXME: the transform positions are not correct. The path's control (pivot point) should be based on the center, Everything else is fine

enum PathCommandType {
	MOVE_TO,    # M, m
	LINE_TO,    # L, l
	HORIZ_TO,   # H, h
	VERT_TO,    # V, v
	CURVE_TO,   # C, c
	SMOOTH_CURVE_TO,  # S, s
	QUAD_TO,    # Q, q
	SMOOTH_QUAD_TO,   # T, t
	ARC_TO,     # A, a
	CLOSE_PATH  # Z, z
}

class PathCommand:
	var type: PathCommandType
	var points: Array[Vector2]
	var relative: bool
	
	func _init(cmd_type: PathCommandType, cmd_points: Array[Vector2], is_relative: bool = false) -> void:
		type = cmd_type
		points = cmd_points
		relative = is_relative

var _commands: Array[PathCommand] = []
var _current_pos := Vector2.ZERO
var _path_start := Vector2.ZERO
var _last_control_point := Vector2.ZERO
var _path_data: String = ""
var _path_segments: Array[PackedVector2Array] = []

func _ready() -> void:
	super._ready()
	if not _path_data.is_empty():
		set_path_data(_path_data)

func set_path_data(d: String) -> void:
	_path_data = d
	_commands.clear()
	_shape_points.clear()
	_path_segments.clear()
	_bounds_min = Vector2(INF, INF)
	_bounds_max = Vector2(-INF, -INF)
	
	# Reset tracking variables
	_current_pos = Vector2.ZERO
	_path_start = Vector2.ZERO
	_last_control_point = Vector2.ZERO
	
	_parse_path_data(d)
	_generate_path_segments()
	_update_control_size()
	queue_redraw()

func _parse_path_data(d: String) -> void:
	var tokens := _tokenize_path_data(d)
	var i := 0
	
	while i < tokens.size():
		var token : String = tokens[i]
		match token.to_upper():
			"M":
				i = _parse_move_to(tokens, i + 1, token == "m")
			"L":
				i = _parse_line_to(tokens, i + 1, token == "l")
			"H":
				i = _parse_horizontal_to(tokens, i + 1, token == "h")
			"V":
				i = _parse_vertical_to(tokens, i + 1, token == "v")
			"C":
				i = _parse_curve_to(tokens, i + 1, token == "c")
			"S":
				i = _parse_smooth_curve_to(tokens, i + 1, token == "s")
			"Q":
				i = _parse_quad_to(tokens, i + 1, token == "q")
			"T":
				i = _parse_smooth_quad_to(tokens, i + 1, token == "t")
			"A":
				i = _parse_arc_to(tokens, i + 1, token == "a")
			"Z", "z":
				_commands.append(PathCommand.new(PathCommandType.CLOSE_PATH, [], false))
				i += 1
			_:
				# Skip invalid tokens
				push_warning("Invalid SVG path command: " + token)
				i += 1

func _generate_path_segments() -> void:
	if _commands.is_empty():
		return
		
	var current_pos := Vector2.ZERO
	var path_start := Vector2.ZERO
	var current_segment: PackedVector2Array = []
	
	for cmd in _commands:
		match cmd.type:
			PathCommandType.MOVE_TO:
				if not current_segment.is_empty():
					_path_segments.append(current_segment)
					current_segment = PackedVector2Array()
				
				current_pos = cmd.points[0]
				path_start = current_pos
				current_segment.append(current_pos)
				_update_bounds(current_pos)
				
			PathCommandType.LINE_TO:
				current_pos = cmd.points[0]
				current_segment.append(current_pos)
				_update_bounds(current_pos)
				
			PathCommandType.HORIZ_TO:
				current_pos.x = cmd.points[0].x
				current_segment.append(current_pos)
				_update_bounds(current_pos)
				
			PathCommandType.VERT_TO:
				current_pos.y = cmd.points[0].y
				current_segment.append(current_pos)
				_update_bounds(current_pos)
				
			PathCommandType.CURVE_TO:
				var bezier_points = _calculate_bezier_points(
					current_pos,
					cmd.points[0],
					cmd.points[1],
					cmd.points[2]
				)
				
				# Skip first point as it's the same as current_pos
				for i in range(1, bezier_points.size()):
					current_segment.append(bezier_points[i])
					_update_bounds(bezier_points[i])
				
				current_pos = cmd.points[2]
				
			PathCommandType.SMOOTH_CURVE_TO:
				var control1 = _current_pos + (_current_pos - _last_control_point)
				var bezier_points = _calculate_bezier_points(
					current_pos,
					control1,
					cmd.points[0],
					cmd.points[1]
				)
				
				# Skip first point as it's the same as current_pos
				for i in range(1, bezier_points.size()):
					current_segment.append(bezier_points[i])
					_update_bounds(bezier_points[i])
				
				current_pos = cmd.points[1]
				
			PathCommandType.QUAD_TO:
				# Convert quadratic to cubic bezier
				var bezier_points = _calculate_quadratic_bezier_points(
					current_pos,
					cmd.points[0],
					cmd.points[1]
				)
				
				# Skip first point as it's the same as current_pos
				for i in range(1, bezier_points.size()):
					current_segment.append(bezier_points[i])
					_update_bounds(bezier_points[i])
				
				current_pos = cmd.points[1]
				
			PathCommandType.SMOOTH_QUAD_TO:
				var control = current_pos + (current_pos - _last_control_point)
				var bezier_points = _calculate_quadratic_bezier_points(
					current_pos,
					control,
					cmd.points[0]
				)
				
				# Skip first point as it's the same as current_pos
				for i in range(1, bezier_points.size()):
					current_segment.append(bezier_points[i])
					_update_bounds(bezier_points[i])
				
				current_pos = cmd.points[0]
				
			PathCommandType.CLOSE_PATH:
				if current_pos != path_start:
					current_segment.append(path_start)
					_update_bounds(path_start)
				current_pos = path_start
				
				# Complete the segment
				if current_segment.size() > 1:
					_path_segments.append(current_segment)
					current_segment = PackedVector2Array()
	
	# Add any remaining segment
	if current_segment.size() > 1:
		_path_segments.append(current_segment)
	
	# Collect all points for shape detection
	for segment in _path_segments:
		for point in segment:
			_shape_points.append(point)

func _update_control_size() -> void:
	# Add padding for stroke width
	var padding = Vector2(stroke_width, stroke_width) * 2
	
	# If we have valid bounds
	if _bounds_min.x != INF and _bounds_min.y != INF:
		custom_minimum_size = (_bounds_max - _bounds_min) + padding
		size = custom_minimum_size
		
		# Store the offset for drawing
		var offset = Vector2(stroke_width, stroke_width) - _bounds_min
		
		# Adjust all path segments to be relative to new position
		for i in range(_path_segments.size()):
			var segment = _path_segments[i]
			var adjusted_segment = PackedVector2Array()
			
			for point in segment:
				adjusted_segment.append(point + offset)
			
			_path_segments[i] = adjusted_segment
			
		# Also adjust shape points for hit detection
		for i in range(_shape_points.size()):
			_shape_points[i] += offset
	else:
		# Fallback if no points were processed
		custom_minimum_size = Vector2(10, 10)
		size = custom_minimum_size

func _draw() -> void:
	if _path_segments.is_empty():
		return
		
	# Draw fill if color has alpha
	if fill_color.a > 0:
		for segment in _path_segments:
			if segment.size() > 2:
				draw_colored_polygon(segment, fill_color)
	
	# Draw stroke if width > 0
	if stroke_width > 0:
		for segment in _path_segments:
			if segment.size() > 1:
				draw_polyline(segment, stroke_color, stroke_width, true)

func _is_point_in_shape(point: Vector2) -> bool:
	# For each closed segment, check if point is inside
	for segment in _path_segments:
		if segment.size() > 2 and Geometry2D.is_point_in_polygon(point, segment):
			return true
	return false

# Path parsing helper methods
func _tokenize_path_data(d: String) -> Array:
	# Normalize the path data by adding spaces around commands and commas
	var normalized = d.replace(",", " ")
	for cmd in ["M", "m", "L", "l", "H", "h", "V", "v", "C", "c", "S", "s", "Q", "q", "T", "t", "A", "a", "Z", "z"]:
		normalized = normalized.replace(cmd, " " + cmd + " ")
	
	# Split by whitespace and filter out empty strings
	var tokens = []
	for token in normalized.split(" ", false):
		var trimmed = token.strip_edges()
		if not trimmed.is_empty():
			tokens.append(trimmed)
	
	return tokens

func _parse_move_to(tokens: Array, start_index: int, relative: bool) -> int:
	var i := start_index
	var first_point := true
	
	while i + 1 < tokens.size():
		# Try to parse x,y coordinates
		if not tokens[i].is_valid_float() or not tokens[i + 1].is_valid_float():
			break
			
		var x := float(tokens[i])
		var y := float(tokens[i + 1])
		
		var point := Vector2(x, y)
		if relative:
			point += _current_pos
			
		if first_point:
			_commands.append(PathCommand.new(PathCommandType.MOVE_TO, [point], relative))
			_path_start = point
			first_point = false
		else:
			# Subsequent coordinates are implicit line-to commands
			_commands.append(PathCommand.new(PathCommandType.LINE_TO, [point], relative))
			
		_current_pos = point
		i += 2
		
		# Check if next token is a command
		if i < tokens.size() and tokens[i] in ["M", "m", "L", "l", "H", "h", "V", "v", "C", "c", "S", "s", "Q", "q", "T", "t", "A", "a", "Z", "z"]:
			break
			
	return i

func _parse_line_to(tokens: Array, start_index: int, relative: bool) -> int:
	var i := start_index
	
	while i + 1 < tokens.size():
		if not tokens[i].is_valid_float() or not tokens[i + 1].is_valid_float():
			break
			
		var x := float(tokens[i])
		var y := float(tokens[i + 1])
		
		var point := Vector2(x, y)
		if relative:
			point += _current_pos
			
		_commands.append(PathCommand.new(PathCommandType.LINE_TO, [point], relative))
		_current_pos = point
		i += 2
		
		if i < tokens.size() and tokens[i] in ["M", "m", "L", "l", "H", "h", "V", "v", "C", "c", "S", "s", "Q", "q", "T", "t", "A", "a", "Z", "z"]:
			break
			
	return i

func _parse_horizontal_to(tokens: Array, start_index: int, relative: bool) -> int:
	var i := start_index
	
	while i < tokens.size():
		if not tokens[i].is_valid_float():
			break
			
		var x := float(tokens[i])
		var point := Vector2.ZERO
		
		if relative:
			point = Vector2(_current_pos.x + x, _current_pos.y)
		else:
			point = Vector2(x, _current_pos.y)
			
		_commands.append(PathCommand.new(PathCommandType.HORIZ_TO, [point], relative))
		_current_pos = point
		i += 1
		
		if i < tokens.size() and tokens[i] in ["M", "m", "L", "l", "H", "h", "V", "v", "C", "c", "S", "s", "Q", "q", "T", "t", "A", "a", "Z", "z"]:
			break
			
	return i

func _parse_vertical_to(tokens: Array, start_index: int, relative: bool) -> int:
	var i := start_index
	
	while i < tokens.size():
		if not tokens[i].is_valid_float():
			break
			
		var y := float(tokens[i])
		var point := Vector2.ZERO
		
		if relative:
			point = Vector2(_current_pos.x, _current_pos.y + y)
		else:
			point = Vector2(_current_pos.x, y)
			
		_commands.append(PathCommand.new(PathCommandType.VERT_TO, [point], relative))
		_current_pos = point
		i += 1
		
		if i < tokens.size() and tokens[i] in ["M", "m", "L", "l", "H", "h", "V", "v", "C", "c", "S", "s", "Q", "q", "T", "t", "A", "a", "Z", "z"]:
			break
			
	return i

func _parse_curve_to(tokens: Array, start_index: int, relative: bool) -> int:
	var i := start_index
	
	while i + 5 < tokens.size():
		# We need 6 values for a cubic bezier curve
		if not tokens[i].is_valid_float() or not tokens[i + 1].is_valid_float() or \
		   not tokens[i + 2].is_valid_float() or not tokens[i + 3].is_valid_float() or \
		   not tokens[i + 4].is_valid_float() or not tokens[i + 5].is_valid_float():
			break
			
		var control1 := Vector2(float(tokens[i]), float(tokens[i + 1]))
		var control2 := Vector2(float(tokens[i + 2]), float(tokens[i + 3]))
		var end := Vector2(float(tokens[i + 4]), float(tokens[i + 5]))
		
		if relative:
			control1 += _current_pos
			control2 += _current_pos
			end += _current_pos
			
		_commands.append(PathCommand.new(PathCommandType.CURVE_TO, [control1, control2, end], relative))
		_last_control_point = control2
		_current_pos = end
		i += 6
		
		if i < tokens.size() and tokens[i] in ["M", "m", "L", "l", "H", "h", "V", "v", "C", "c", "S", "s", "Q", "q", "T", "t", "A", "a", "Z", "z"]:
			break
			
	return i

func _parse_smooth_curve_to(tokens: Array, start_index: int, relative: bool) -> int:
	var i := start_index
	
	while i + 3 < tokens.size():
		# We need 4 values for a smooth cubic bezier curve
		if not tokens[i].is_valid_float() or not tokens[i + 1].is_valid_float() or \
		   not tokens[i + 2].is_valid_float() or not tokens[i + 3].is_valid_float():
			break
			
		# Calculate the reflection of the last control point
		var control1 := _current_pos * 2 - _last_control_point
		var control2 := Vector2(float(tokens[i]), float(tokens[i + 1]))
		var end := Vector2(float(tokens[i + 2]), float(tokens[i + 3]))
		
		if relative:
			control2 += _current_pos
			end += _current_pos
			
		_commands.append(PathCommand.new(PathCommandType.CURVE_TO, [control1, control2, end], relative))
		_last_control_point = control2
		_current_pos = end
		i += 4
		
		if i < tokens.size() and tokens[i] in ["M", "m", "L", "l", "H", "h", "V", "v", "C", "c", "S", "s", "Q", "q", "T", "t", "A", "a", "Z", "z"]:
			break
			
	return i

func _parse_quad_to(tokens: Array, start_index: int, relative: bool) -> int:
	var i := start_index
	
	while i + 3 < tokens.size():
		# We need 4 values for a quadratic bezier curve
		if not tokens[i].is_valid_float() or not tokens[i + 1].is_valid_float() or \
		   not tokens[i + 2].is_valid_float() or not tokens[i + 3].is_valid_float():
			break
			
		var control := Vector2(float(tokens[i]), float(tokens[i + 1]))
		var end := Vector2(float(tokens[i + 2]), float(tokens[i + 3]))
		
		if relative:
			control += _current_pos
			end += _current_pos
			
		# Convert to cubic to reuse existing curve code
		var cubic_points := _quadratic_to_cubic(_current_pos, control, end)
		_commands.append(PathCommand.new(PathCommandType.CURVE_TO, cubic_points, false))
		
		_last_control_point = control
		_current_pos = end
		i += 4
		
		if i < tokens.size() and tokens[i] in ["M", "m", "L", "l", "H", "h", "V", "v", "C", "c", "S", "s", "Q", "q", "T", "t", "A", "a", "Z", "z"]:
			break
			
	return i

func _parse_smooth_quad_to(tokens: Array, start_index: int, relative: bool) -> int:
	var i := start_index
	
	while i + 1 < tokens.size():
		# We need 2 values for a smooth quadratic bezier curve
		if not tokens[i].is_valid_float() or not tokens[i + 1].is_valid_float():
			break
			
		# Calculate the reflection of the last control point
		var control := _current_pos * 2 - _last_control_point
		var end := Vector2(float(tokens[i]), float(tokens[i + 1]))
		
		if relative:
			end += _current_pos
			
		# Convert to cubic
		var cubic_points := _quadratic_to_cubic(_current_pos, control, end)
		_commands.append(PathCommand.new(PathCommandType.CURVE_TO, cubic_points, false))
		
		_last_control_point = control
		_current_pos = end
		i += 2
		
		if i < tokens.size() and tokens[i] in ["M", "m", "L", "l", "H", "h", "V", "v", "C", "c", "S", "s", "Q", "q", "T", "t", "A", "a", "Z", "z"]:
			break
			
	return i

func _parse_arc_to(tokens: Array, start_index: int, relative: bool) -> int:
	var i := start_index
	
	while i + 6 < tokens.size():
		# We need 7 values for an elliptical arc
		if not tokens[i].is_valid_float() or not tokens[i + 1].is_valid_float() or \
		   not tokens[i + 2].is_valid_float() or not tokens[i + 3].is_valid_float() or \
		   not tokens[i + 4].is_valid_float() or not tokens[i + 5].is_valid_float() or \
		   not tokens[i + 6].is_valid_float():
			break
			
		var rx := absf(float(tokens[i]))
		var ry := absf(float(tokens[i + 1]))
		var x_rotation := float(tokens[i + 2])
		var large_arc := int(float(tokens[i + 3])) != 0
		var sweep := int(float(tokens[i + 4])) != 0
		var end := Vector2(float(tokens[i + 5]), float(tokens[i + 6]))
		
		if relative:
			end += _current_pos
		
		# For simplicity, we'll just create a line for now
		# A proper implementation would convert the arc to bezier curves
		push_warning("Arc commands are not fully implemented - using line approximation")
		_commands.append(PathCommand.new(PathCommandType.LINE_TO, [end], false))
		
		_current_pos = end
		i += 7
		
		if i < tokens.size() and tokens[i] in ["M", "m", "L", "l", "H", "h", "V", "v", "C", "c", "S", "s", "Q", "q", "T", "t", "A", "a", "Z", "z"]:
			break
			
	return i

# Helper methods for curve calculations
func _calculate_bezier_points(start: Vector2, control1: Vector2, control2: Vector2, end: Vector2, steps: int = 12) -> Array[Vector2]:
	var points: Array[Vector2] = []
	points.append(start)
	
	for i in range(1, steps + 1):
		var t := float(i) / steps
		var point := _cubic_bezier(start, control1, control2, end, t)
		points.append(point)
		
	return points

func _calculate_quadratic_bezier_points(start: Vector2, control: Vector2, end: Vector2, steps: int = 12) -> Array[Vector2]:
	var points: Array[Vector2] = []
	points.append(start)
	
	for i in range(1, steps + 1):
		var t := float(i) / steps
		var point := _quadratic_bezier(start, control, end, t)
		points.append(point)
		
	return points

func _cubic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var mt := 1.0 - t
	var mt2 := mt * mt
	var mt3 := mt2 * mt
	var t2 := t * t
	var t3 := t2 * t
	
	return p0 * mt3 + p1 * (3.0 * mt2 * t) + p2 * (3.0 * mt * t2) + p3 * t3

func _quadratic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var mt := 1.0 - t
	var mt2 := mt * mt
	var t2 := t * t
	
	return p0 * mt2 + p1 * (2.0 * mt * t) + p2 * t2

func _quadratic_to_cubic(p0: Vector2, p1: Vector2, p2: Vector2) -> Array[Vector2]:
	var result: Array[Vector2] = []
	
	# Convert quadratic control point to two cubic control points
	var cp1 := p0 + (p1 - p0) * (2.0/3.0)
	var cp2 := p2 + (p1 - p2) * (2.0/3.0)
	
	result.append(cp1)
	result.append(cp2)
	result.append(p2)
	
	return result
