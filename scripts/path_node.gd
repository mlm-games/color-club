@tool
class_name SVGPath
extends Node2D

@export var run_test: bool = false:
	set(val):
		run_test = val
		if run_test == true: set_path_data("m 0,0 -0.01,-0.047 c -0.11,-0.006 -0.221,-0.012 -0.333,-0.015 -0.045,-0.003 -0.09,-0.003 -0.138,-0.007 -0.09,-0.003 -0.18,-0.006 -0.27,-0.006 -0.372,-0.01 -0.761,-0.01 -1.159,-0.006 l -0.356,0.009 c -0.058,0 -0.112,0.003 -0.17,0.007 -0.344,0.009 -0.694,0.025 -1.05,0.048 -0.144,0.009 -0.289,0.019 -0.436,0.029 -0.293,0.022 -0.588,0.048 -0.89,0.077 0,0 0.388,-3.399 0.068,-5.733 -0.375,-2.728 -2.257,-5.62 -2.257,-5.62 1.621,-0.158 3.127,-0.209 4.456,-0.158 0,0 0.007,0.015 0.018,0.038 3.158,0.124 5.294,0.833 5.522,2.028 0.003,0.023 0.003,0.108 0.006,0.108 H 3.004 L 5.129,2 C 4.914,0.855 2.943,0.164 0,0")

enum PathCommandType {
	MOVE_TO,    # M, m
	LINE_TO,    # L, l
	HORIZ_TO,   # H, h
	VERT_TO,    # V, v
	CURVE_TO,   # C, c
	SMOOTH_CURVE_TO,  # S, s
	QUAD_TO,    # Q, q #TODO: Crashes
	SMOOTH_QUAD_TO,   # T, t #TODO: CHeck once, if above crashes then this would to
	ARC_TO,     # A, a #TODO: Simple fix, crashes
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

@export var stroke_color := Color.BLACK:
	set(value):
		stroke_color = value
		queue_redraw()

@export var stroke_width := 1.0:
	set(value):
		stroke_width = value
		queue_redraw()

@export var fill_color := Color.TRANSPARENT:
	set(value):
		fill_color = value
		queue_redraw()

var _commands: Array[PathCommand] = []
var _current_pos := Vector2.ZERO
var _path_start := Vector2.ZERO
var _last_control_point := Vector2.ZERO

func set_path_data(d: String) -> void:
	_commands.clear()
	_parse_path_data(d)
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
				i = _parse_quad_to(tokens, i + 1, token == "q") #FIXME
			#"T":
				#i = _parse_smooth_quad_to(tokens, i + 1, token == "t") #FIXME
			#"A":
				#i = _parse_arc_to(tokens, i + 1, token == "a") #FIXME
			"Z", "z":
				_commands.append(PathCommand.new(PathCommandType.CLOSE_PATH, [], false))
				i += 1

func _draw() -> void:
	if _commands.is_empty():
		return
		
	var current_pos := Vector2.ZERO
	var path_start := Vector2.ZERO
	var vertices: PackedVector2Array = []
	
	for cmd in _commands:
		match cmd.type:
			PathCommandType.MOVE_TO:
				if not vertices.is_empty() and fill_color.a > 0:
					draw_colored_polygon(vertices, fill_color)
				vertices.clear()
				current_pos = cmd.points[0]
				path_start = current_pos
				vertices.append(current_pos)
				
			PathCommandType.LINE_TO:
				current_pos = cmd.points[0]
				vertices.append(current_pos)
				if stroke_width > 0:
					draw_line(vertices[-2], vertices[-1], stroke_color, stroke_width)
					
			PathCommandType.HORIZ_TO:
				current_pos.x = cmd.points[0].x
				vertices.append(current_pos)
				if stroke_width > 0:
					draw_line(vertices[-2], vertices[-1], stroke_color, stroke_width)
					
			PathCommandType.VERT_TO:
				current_pos.y = cmd.points[0].y
				vertices.append(current_pos)
				if stroke_width > 0:
					draw_line(vertices[-2], vertices[-1], stroke_color, stroke_width)
					
			PathCommandType.CURVE_TO:
				var points := _calculate_bezier_points(
					current_pos,
					cmd.points[0],
					cmd.points[1],
					cmd.points[2]
				)
				vertices.append_array(points)
				current_pos = cmd.points[2]
				if stroke_width > 0:
					for i in range(1, points.size()):
						draw_line(points[i-1], points[i], stroke_color, stroke_width)
						
			PathCommandType.CLOSE_PATH:
				if vertices.size() > 2:
					vertices.append(path_start)
					if stroke_width > 0:
						draw_line(current_pos, path_start, stroke_color, stroke_width)
					if fill_color.a > 0:
						draw_colored_polygon(vertices, fill_color)
				vertices.clear()
				current_pos = path_start

func _calculate_bezier_points(start: Vector2, control1: Vector2, control2: Vector2, end: Vector2, steps: int = 20) -> Array[Vector2]:
	var points: Array[Vector2] = []
	for i in range(steps + 1):
		var t := float(i) / steps
		var point := _cubic_bezier(start, control1, control2, end, t)
		points.append(point)
	return points

func _cubic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var mt := 1 - t
	var mt2 := mt * mt
	var mt3 := mt2 * mt
	var t2 := t * t
	var t3 := t2 * t
	
	return p0 * mt3 + p1 * (3 * mt2 * t) + p2 * (3 * mt * t2) + p3 * t3

func _tokenize_path_data(d: String) -> Array:
	# Simplified tokenizer, TODO: might want to make this more robust
	var tokens := []
	var current_token := ""
	
	for c in d:
		if c in [" ", ",", "\t", "\n"]:
			if not current_token.is_empty():
				tokens.append(current_token)
				current_token = "" #TODO: Currently nodes with Q or q or A or "a" crash...
		elif c in ["M", "m", "L", "l", "H", "h", "V", "v", "C", "c", "S", "s", "Q", "q", "T", "t", "A", "a", "Z", "z"]:
			if not current_token.is_empty():
				tokens.append(current_token)
			tokens.append(c)
			current_token = ""
		else:
			current_token += c
			
	if not current_token.is_empty():
		tokens.append(current_token)
		
	return tokens

func _parse_move_to(tokens: Array, start_index: int, relative: bool) -> int:
	var i := start_index
	var first_point := true
	
	while i < tokens.size():
		# Check if we have enough tokens for a coordinate pair
		if i + 1 >= tokens.size():
			break
			
		# Try to convert tokens to numbers
		var x :float = float(tokens[i])
		var y : float = float(tokens[i + 1])
		
		var point := Vector2(x, y)
		if relative:
			point += _current_pos
			
		if first_point:
			_commands.append(PathCommand.new(PathCommandType.MOVE_TO, [point], relative))
			first_point = false
		else:
			# Subsequent coordinate pairs are treated as implicit line-to commands
			_commands.append(PathCommand.new(PathCommandType.LINE_TO, [point], relative))
		print("Commands: "); print(_commands)
		_current_pos = point
		if first_point:
			_path_start = _current_pos
			
		i += 2
		
		# Check if next token is a command
		if i < tokens.size() and tokens[i] in ["M", "m", "L", "l", "H", "h", "V", "v", "C", "c", "S", "s", "Q", "q", "T", "t", "A", "a", "Z", "z"]:
			break
			
	return i

func _parse_line_to(tokens: Array, start_index: int, relative: bool) -> int:
	var i := start_index
	
	while i < tokens.size():
		if i + 1 >= tokens.size():
			break
			
		var x : float = float(tokens[i])
		var y : float = float(tokens[i + 1])
		
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
		if i >= tokens.size():
			break
			
		var x : float = float(tokens[i])
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
		if i >= tokens.size():
			break
			
		var y : float = float(tokens[i])
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
	
	while i < tokens.size():
		if i + 5 >= tokens.size():
			break
			
		var control1 := Vector2(float(tokens[i]), float(tokens[i + 1]))
		var control2 := Vector2(float(tokens[i + 2]), float(tokens[i + 3]))
		var end := Vector2(float(tokens[i + 4]), float(tokens[i + 5]))
		
		if relative:
			control1 += _current_pos
			control2 += _current_pos
			end += _current_pos
			
		_commands.append(PathCommand.new(PathCommandType.CURVE_TO, [control1, control2, end], relative))
		_current_pos = end
		_last_control_point = control2
		
		i += 6
		
		if i < tokens.size() and tokens[i] in ["M", "m", "L", "l", "H", "h", "V", "v", "C", "c", "S", "s", "Q", "q", "T", "t", "A", "a", "Z", "z"]:
			break
			
	return i

func _parse_smooth_curve_to(tokens: Array, start_index: int, relative: bool) -> int:
	var i := start_index
	
	while i < tokens.size():
		if i + 3 >= tokens.size():
			break
			
		# Calculate the reflection of the last control point
		var control1 := _current_pos + (_current_pos - _last_control_point)
		var control2 := Vector2(float(tokens[i]), float(tokens[i + 1]))
		var end := Vector2(float(tokens[i + 2]), float(tokens[i + 3]))
		
		if relative:
			control2 += _current_pos
			end += _current_pos
			
		_commands.append(PathCommand.new(PathCommandType.CURVE_TO, [control1, control2, end], relative))
		_current_pos = end
		_last_control_point = control2
		
		i += 4
		
		if i < tokens.size() and tokens[i] in ["M", "m", "L", "l", "H", "h", "V", "v", "C", "c", "S", "s", "Q", "q", "T", "t", "A", "a", "Z", "z"]:
			break
			
	return i

func _parse_quad_to(tokens: Array, start_index: int, relative: bool) -> int:
	var i := start_index
	while i < tokens.size():
		if i + 3 >= tokens.size():
			break
			
		var control := Vector2(float(tokens[i]), float(tokens[i + 1]))
		var end := Vector2(float(tokens[i + 2]), float(tokens[i + 3]))
		
		if relative:
			control += _current_pos
			end += _current_pos
			
		var cubic_points := _quadratic_to_cubic(control, end, _current_pos)
		_commands.append(PathCommand.new(PathCommandType.CURVE_TO, cubic_points, relative))
		_current_pos = end
		_last_control_point = control
		
		i += 4
		
		if i < tokens.size() and tokens[i] in ["M", "m", "L", "l", "H", "h", "V", "v", "C", "c", "S", "s", "Q", "q", "T", "t", "A", "a", "Z", "z"]:
			break
			
	return i


func _parse_smooth_quad_to(tokens: Array, start_index: int, relative: bool) -> int:
	var i := start_index
	
	while i < tokens.size():
		if i + 1 >= tokens.size():
			break
			
		# Calculate the reflection of the last control point
		var control := _current_pos + (_current_pos - _last_control_point)
		var end := Vector2(float(tokens[i]), float(tokens[i + 1]))
		
		if relative:
			end += _current_pos
			
		# Convert quadratic to cubic Bezier
		var control1 := _current_pos + (control - _current_pos) * (2.0/3.0)
		var control2 := end + (control - end) * (2.0/3.0)
		
		_commands.append(PathCommand.new(PathCommandType.CURVE_TO, [control1, control2, end], relative))
		_current_pos = end
		_last_control_point = control
		
		i += 2
		
		if i < tokens.size() and tokens[i] in ["M", "m", "L", "l", "H", "h", "V", "v", "C", "c", "S", "s", "Q", "q", "T", "t", "A", "a", "Z", "z"]:
			break
			
	return i

func _parse_arc_to(tokens: Array, start_index: int, relative: bool) -> int:
	var i := start_index
	
	while i < tokens.size():
		if i + 6 >= tokens.size():
			break
			
		var rx := float(tokens[i])
		var ry := float(tokens[i + 1])
		var x_rotation := float(tokens[i + 2])
		var large_arc := int(tokens[i + 3]) != 0
		var sweep := int(tokens[i + 4]) != 0
		var end := Vector2(float(tokens[i + 5]), float(tokens[i + 6]))
		
		if relative:
			end += _current_pos
			
		# Convert arc to cubic Bezier curves
		var arc_points := _arc_to_bezier(
			_current_pos,
			end,
			rx,
			ry,
			deg_to_rad(x_rotation),
			large_arc,
			sweep
		)
		
		for j in range(0, arc_points.size(), 3):
			_commands.append(PathCommand.new(
				PathCommandType.CURVE_TO,
				[arc_points[j], arc_points[j + 1], arc_points[j + 2]],
				false
			))
			
		_current_pos = end
		
		i += 7
		
		if i < tokens.size() and tokens[i] in ["M", "m", "L", "l", "H", "h", "V", "v", "C", "c", "S", "s", "Q", "q", "T", "t", "A", "a", "Z", "z"]:
			break
			
	return i

func _arc_to_bezier(start: Vector2, end: Vector2, rx: float, ry: float, 
					angle: float, large_arc: bool, sweep: bool) -> Array[Vector2]:
	# Ensure radii are positive
	rx = abs(rx)
	ry = abs(ry)
	
	# If radii are zero, treat as line
	if rx == 0 or ry == 0:
		return [end]
	
	# Convert angle to radians
	var phi := angle
	var cos_phi := cos(phi)
	var sin_phi := sin(phi)
	
	# Step 1: Transform to origin
	var dx := (start.x - end.x) / 2.0
	var dy := (start.y - end.y) / 2.0
	
	# Transform to origin
	var x1_prime := cos_phi * dx + sin_phi * dy
	var y1_prime := -sin_phi * dx + cos_phi * dy
	
	# Step 2: Compute transformed radii
	var rx_sq := rx * rx
	var ry_sq := ry * ry
	var x1_prime_sq := x1_prime * x1_prime
	var y1_prime_sq := y1_prime * y1_prime
	
	# Check if radii are too small, scale them if needed
	var radii_scale := x1_prime_sq / rx_sq + y1_prime_sq / ry_sq
	if radii_scale > 1:
		rx *= sqrt(radii_scale)
		ry *= sqrt(radii_scale)
		rx_sq = rx * rx
		ry_sq = ry * ry
	
	# Step 3: Compute center
	var temp_sign := -1.0 if large_arc == sweep else 1.0
	var sq := maxf(0.0, (rx_sq * ry_sq - rx_sq * y1_prime_sq - ry_sq * x1_prime_sq) / 
					  (rx_sq * y1_prime_sq + ry_sq * x1_prime_sq))
	var coef := temp_sign * sqrt(sq)
	var cx_prime := coef * (rx * y1_prime / ry)
	var cy_prime := coef * (-ry * x1_prime / rx)
	
	# Step 4: Transform back
	var cx := cos_phi * cx_prime - sin_phi * cy_prime + (start.x + end.x) / 2.0
	var cy := sin_phi * cx_prime + cos_phi * cy_prime + (start.y + end.y) / 2.0
	
	# Step 5: Compute angles
	var start_angle := _compute_angle(1.0, 0.0, 
		(x1_prime - cx_prime) / rx, 
		(y1_prime - cy_prime) / ry)
	
	var delta_angle := _compute_angle(
		(x1_prime - cx_prime) / rx, 
		(y1_prime - cy_prime) / ry,
		(-x1_prime - cx_prime) / rx, 
		(-y1_prime - cy_prime) / ry)
	
	if not sweep and delta_angle > 0:
		delta_angle -= TAU
	elif sweep and delta_angle < 0:
		delta_angle += TAU
	
	# Convert to cubic Bézier curves
	var curves: Array[Vector2] = []
	var n_curves := int(ceil(abs(delta_angle) / (PI / 2.0)))
	var angle_step := delta_angle / n_curves
	
	for i in range(n_curves):
		var append_angle := start_angle + i * angle_step
		var next_angle := start_angle + (i + 1) * angle_step
		curves.append_array(_arc_segment_to_bezier(
			cx, cy, rx, ry, append_angle, next_angle, cos_phi, sin_phi
		))
	
	return curves

func _compute_angle(ux: float, uy: float, vx: float, vy: float) -> float:
	var dot := ux * vx + uy * vy
	var len_sq := (ux * ux + uy * uy) * (vx * vx + vy * vy)
	var angle := acos(clamp(dot / sqrt(len_sq), -1.0, 1.0))
	
	if ux * vy - uy * vx < 0:
		angle = -angle
	
	return angle

func _arc_segment_to_bezier(cx: float, cy: float, rx: float, ry: float,
						   start_angle: float, end_angle: float,
						   cos_phi: float, sin_phi: float) -> Array[Vector2]:
	var delta_angle := end_angle - start_angle
	var eta := tan(delta_angle / 4.0) * 4.0 / 3.0
	
	var cos_start := cos(start_angle)
	var sin_start := sin(start_angle)
	var cos_end := cos(end_angle)
	var sin_end := sin(end_angle)
	
	# Calculate endpoints
	var e1x := cx + rx * cos_start
	var e1y := cy + ry * sin_start
	var e2x := cx + rx * cos_end
	var e2y := cy + ry * sin_end
	
	# Calculate control points
	var c1x := e1x - rx * eta * sin_start
	var c1y := e1y + ry * eta * cos_start
	var c2x := e2x + rx * eta * sin_end
	var c2y := e2y - ry * eta * cos_end
	
	# Transform points back
	var result: Array[Vector2] = []
	result.append(_transform_point(e1x, e1y, cos_phi, sin_phi))
	result.append(_transform_point(c1x, c1y, cos_phi, sin_phi))
	result.append(_transform_point(c2x, c2y, cos_phi, sin_phi))
	result.append(_transform_point(e2x, e2y, cos_phi, sin_phi))
	
	return result

func _transform_point(x: float, y: float, cos_phi: float, sin_phi: float) -> Vector2:
	return Vector2(
		cos_phi * x - sin_phi * y,
		sin_phi * x + cos_phi * y
	)

func _quadratic_to_cubic(control: Vector2, end: Vector2, start: Vector2) -> Array:
	var control1 := start + (control - start) * (2.0/3.0)
	var control2 := end + (control - end) * (2.0/3.0)
	return [control1, control2, end]
