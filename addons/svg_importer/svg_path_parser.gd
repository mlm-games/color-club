## Robust SVG Path 'd' attribute parser.
class_name SVGImporterPathParser
extends RefCounted

const Utils = preload("svg_parser_utils.gd")

class PathParseResult:
	var points: PackedVector2Array = []
	var is_closed: bool = false

class PathState:
	var subpaths: Array[PackedVector2Array] = []
	var current_subpath: PackedVector2Array = []
	var current_pos := Vector2.ZERO
	var subpath_start := Vector2.ZERO
	var last_control_point := Vector2.ZERO
	var last_command := ""

static func parse(path_data: String) -> PathParseResult:
	var state = PathState.new()
	var tokens = _tokenize(path_data)
	var i = 0
	
	var result = PathParseResult.new()
	
	while i < tokens.size():
		var command = tokens[i]
		
		if command.is_valid_float():
			command = _get_implicit_command(state.last_command)
		else:
			i += 1
		
		var is_relative = command == command.to_lower()
		var cmd_upper = command.to_upper()
		state.last_command = command
		
		var consumed = _execute_command(cmd_upper, is_relative, tokens, i, state)
		if consumed == 0 and not cmd_upper in ["Z"]:
			printerr("SVG Path Parser: Parsing stopped due to invalid command sequence for '", command, "'")
			break
		i += consumed

	if not state.current_subpath.is_empty():
		state.subpaths.push_back(state.current_subpath)

	# Combine all subpaths into a single polyline for drawing, but keep structure for fill/close logic
	for subpath in state.subpaths:
		result.points.append_array(subpath)
	
	# A path is considered closed if its last command was Z
	if state.last_command.to_upper() == "Z":
		result.is_closed = true

	return result

static func _execute_command(cmd: String, is_rel: bool, tokens: Array, index: int, state: PathState) -> int:
	var params_per_cmd = {"M":2, "L":2, "H":1, "V":1, "C":6, "S":4, "Q":4, "T":2, "A":7, "Z":0}
	if not cmd in params_per_cmd: return 0
	
	var count = params_per_cmd[cmd]
	var consumed = 0

	while index + count <= tokens.size() or (count == 0 and cmd == "Z"):
		var params: Array[float] = []
		for j in range(count):
			if not tokens[index + j].is_valid_float(): return consumed
			params.append(float(tokens[index + j]))

		match cmd:
			"M":
				if not state.current_subpath.is_empty():
					state.subpaths.push_back(state.current_subpath)
				state.current_subpath = PackedVector2Array()
				
				state.current_pos = _get_point(params, 0, is_rel, state.current_pos if consumed > 0 else Vector2.ZERO)
				state.current_subpath.append(state.current_pos)
				state.subpath_start = state.current_pos
				state.last_command = "l" if is_rel else "L" # Implicit LineTo
			"L":
				state.current_pos = _get_point(params, 0, is_rel, state.current_pos)
				state.current_subpath.append(state.current_pos)
			"H":
				state.current_pos.x = params[0] + (state.current_pos.x if is_rel else 0)
				state.current_subpath.append(state.current_pos)
			"V":
				state.current_pos.y = params[0] + (state.current_pos.y if is_rel else 0)
				state.current_subpath.append(state.current_pos)
			"C":
				var p1 = _get_point(params, 0, is_rel, state.current_pos)
				var p2 = _get_point(params, 2, is_rel, state.current_pos)
				var p3 = _get_point(params, 4, is_rel, state.current_pos)
				_tessellate_cubic_bezier(state.current_subpath, state.current_pos, p1, p2, p3)
				state.last_control_point = p2
				state.current_pos = p3
			"S":
				var p1 = state.current_pos * 2.0 - state.last_control_point if state.last_command.to_upper() in ["C", "S"] else state.current_pos
				var p2 = _get_point(params, 0, is_rel, state.current_pos)
				var p3 = _get_point(params, 2, is_rel, state.current_pos)
				_tessellate_cubic_bezier(state.current_subpath, state.current_pos, p1, p2, p3)
				state.last_control_point = p2
				state.current_pos = p3
			"Q":
				var p1 = _get_point(params, 0, is_rel, state.current_pos)
				var p2 = _get_point(params, 2, is_rel, state.current_pos)
				_tessellate_quadratic_bezier(state.current_subpath, state.current_pos, p1, p2)
				state.last_control_point = p1
				state.current_pos = p2
			"T":
				var p1 = state.current_pos * 2.0 - state.last_control_point if state.last_command.to_upper() in ["Q", "T"] else state.current_pos
				var p2 = _get_point(params, 0, is_rel, state.current_pos)
				_tessellate_quadratic_bezier(state.current_subpath, state.current_pos, p1, p2)
				state.last_control_point = p1
				state.current_pos = p2
			"A":
				var p_end = _get_point(params, 5, is_rel, state.current_pos)
				var arc_points = Utils.tessellate_elliptical_arc(
					state.current_pos, params[0], params[1], params[2],
					params[3] > 0.5, params[4] > 0.5, p_end
				)
				if arc_points.size() > 1:
					state.current_subpath.append_array(arc_points.slice(1))
				state.current_pos = p_end
			"Z":
				if not state.current_subpath.is_empty():
					state.current_subpath.append(state.subpath_start)
					state.current_pos = state.subpath_start
				return 0 # Z consumes no params
		
		consumed += count
		index += count
		
		if not cmd in ["M", "L", "C", "S", "Q", "T", "H", "V"]: break
			
	return consumed

static func _tessellate_cubic_bezier(points: PackedVector2Array, p0, p1, p2, p3):
	var curve = Curve2D.new()
	curve.add_point(p0, Vector2.ZERO, p1 - p0)
	curve.add_point(p3, p2 - p3, Vector2.ZERO)
	points.append_array(curve.tessellate())

static func _tessellate_quadratic_bezier(points: PackedVector2Array, p0, p1, p2):
	var cp1 = p0 + (p1 - p0) * (2.0 / 3.0)
	var cp2 = p2 + (p1 - p2) * (2.0 / 3.0)
	_tessellate_cubic_bezier(points, p0, cp1, cp2, p2)

static func _get_point(params: Array, offset: int, is_rel: bool, current: Vector2) -> Vector2:
	var p = Vector2(params[offset], params[offset+1])
	return current + p if is_rel else p

static func _get_implicit_command(last_cmd: String) -> String:
	if last_cmd.is_empty(): return "L" # Should not happen, but safe fallback
	if last_cmd.to_upper() == "M":
		return "l" if last_cmd.to_lower() == last_cmd else "L"
	return last_cmd

static func _tokenize(data: String) -> Array[String]:
	var regex = RegEx.new()
	regex.compile("([MmLlHhVvCcSsQqTtAaZz])|(-?\\d*\\.?\\d+(?:[eE][-+]?\\d+)?)")
	var results = regex.search_all(data)
	var tokens: Array[String] = []
	for res in results:
		tokens.append(res.get_string())
	return tokens
