## SVG Path 'd' attribute parser.
class_name SVGImporterPathParser
extends RefCounted

const Utils = preload("svg_parser_utils.gd")

class PathParseResult:
	var points: PackedVector2Array = []
	var is_closed: bool = false

static func parse(path_data: String) -> PathParseResult:
	var result = PathParseResult.new()
	var current_pos := Vector2.ZERO
	var start_pos := Vector2.ZERO
	var last_control := Vector2.ZERO
	var last_cmd := ""
	
	var tokens = _tokenize(path_data)
	var i = 0
	
	while i < tokens.size():
		var cmd = tokens[i]
		
		# Handle implicit commands
		if cmd.is_valid_float():
			cmd = _get_implicit_command(last_cmd)
		else:
			i += 1
		
		var is_relative = cmd == cmd.to_lower()
		var cmd_upper = cmd.to_upper()
		last_cmd = cmd
		
		match cmd_upper:
			"M":
				if i + 2 > tokens.size(): break
				var x = float(tokens[i])
				var y = float(tokens[i + 1])
				current_pos = Vector2(x, y) if not is_relative else current_pos + Vector2(x, y)
				start_pos = current_pos
				result.points.append(current_pos)
				i += 2
				
			"L":
				if i + 2 > tokens.size(): break
				var x = float(tokens[i])
				var y = float(tokens[i + 1])
				current_pos = Vector2(x, y) if not is_relative else current_pos + Vector2(x, y)
				result.points.append(current_pos)
				i += 2
				
			"H":
				if i + 1 > tokens.size(): break
				var x = float(tokens[i])
				current_pos.x = x if not is_relative else current_pos.x + x
				result.points.append(current_pos)
				i += 1
				
			"V":
				if i + 1 > tokens.size(): break
				var y = float(tokens[i])
				current_pos.y = y if not is_relative else current_pos.y + y
				result.points.append(current_pos)
				i += 1
				
			"C":
				if i + 6 > tokens.size(): break
				var cp1 = Vector2(float(tokens[i]), float(tokens[i + 1]))
				var cp2 = Vector2(float(tokens[i + 2]), float(tokens[i + 3]))
				var end = Vector2(float(tokens[i + 4]), float(tokens[i + 5]))
				
				if is_relative:
					cp1 += current_pos
					cp2 += current_pos
					end += current_pos
				
				_add_cubic_bezier(result.points, current_pos, cp1, cp2, end)
				last_control = cp2
				current_pos = end
				i += 6
				
			"S":
				if i + 4 > tokens.size(): break
				var cp1 = current_pos * 2.0 - last_control
				var cp2 = Vector2(float(tokens[i]), float(tokens[i + 1]))
				var end = Vector2(float(tokens[i + 2]), float(tokens[i + 3]))
				
				if is_relative:
					cp2 += current_pos
					end += current_pos
				
				_add_cubic_bezier(result.points, current_pos, cp1, cp2, end)
				last_control = cp2
				current_pos = end
				i += 4
				
			"Q":
				if i + 4 > tokens.size(): break
				var cp = Vector2(float(tokens[i]), float(tokens[i + 1]))
				var end = Vector2(float(tokens[i + 2]), float(tokens[i + 3]))
				
				if is_relative:
					cp += current_pos
					end += current_pos
				
				_add_quadratic_bezier(result.points, current_pos, cp, end)
				last_control = cp
				current_pos = end
				i += 4
				
			"T":
				if i + 2 > tokens.size(): break
				var cp = current_pos * 2.0 - last_control
				var end = Vector2(float(tokens[i]), float(tokens[i + 1]))
				
				if is_relative:
					end += current_pos
				
				_add_quadratic_bezier(result.points, current_pos, cp, end)
				last_control = cp
				current_pos = end
				i += 2
				
			"A":
				if i + 7 > tokens.size(): break
				var rx = float(tokens[i])
				var ry = float(tokens[i + 1])
				var rot = float(tokens[i + 2])
				var large_arc = int(tokens[i + 3]) > 0
				var sweep = int(tokens[i + 4]) > 0
				var end = Vector2(float(tokens[i + 5]), float(tokens[i + 6]))
				
				if is_relative:
					end += current_pos
				
				var arc_points = Utils.tessellate_elliptical_arc(
					current_pos, rx, ry, rot, large_arc, sweep, end)
				result.points.append_array(arc_points)
				current_pos = end
				i += 7
				
			"Z":
				result.points.append(start_pos)
				current_pos = start_pos
				result.is_closed = true
				
			_:
				break
	
	return result

static func _tokenize(data: String) -> Array[String]:
	var regex = RegEx.new()
	regex.compile("([MmLlHhVvCcSsQqTtAaZz])|(-?\\d*\\.?\\d+(?:[eE][-+]?\\d+)?)")
	var results = regex.search_all(data)
	var tokens: Array[String] = []
	for res in results:
		tokens.append(res.get_string())
	return tokens

static func _get_implicit_command(last_cmd: String) -> String:
	if last_cmd.is_empty(): 
		return "L"
	if last_cmd.to_upper() == "M":
		return "l" if last_cmd == "m" else "L"
	return last_cmd

static func _add_cubic_bezier(points: PackedVector2Array, p0: Vector2, p1: Vector2, 
		p2: Vector2, p3: Vector2) -> void:
	var curve = Curve2D.new()
	curve.add_point(p0, Vector2.ZERO, p1 - p0)
	curve.add_point(p3, p2 - p3, Vector2.ZERO)
	points.append_array(curve.tessellate())

static func _add_quadratic_bezier(points: PackedVector2Array, p0: Vector2, p1: Vector2, 
		p2: Vector2) -> void:
	# Convert quadratic to cubic bezier
	var cp1 = p0 + (p1 - p0) * (2.0 / 3.0)
	var cp2 = p2 + (p1 - p2) * (2.0 / 3.0)
	_add_cubic_bezier(points, p0, cp1, cp2, p2)
