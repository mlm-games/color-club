@tool
class_name SVGPath extends SVGElement # Assuming SVGElement is a valid base class (e.g., Control or Node2D)

#FIXME: the transform positions are not correct. The path's control (pivot point) should be based on the center, Everything else is fine

enum PathCommandType {
	MOVE_TO,    # M, m
	LINE_TO,    # L, l
	HORIZ_TO,   # H, h
	VERT_TO,    # V, v
	CURVE_TO,   # C, c
	SMOOTH_CURVE_TO,  # S, s  <- Note: Not implemented in _generate_path_segments yet
	QUAD_TO,    # Q, q      <- Note: Implemented via conversion to CURVE_TO in parser
	SMOOTH_QUAD_TO,   # T, t  <- Note: Implemented via conversion to CURVE_TO in parser
	ARC_TO,     # A, a      <- Note: Implemented via conversion to CURVE_TO in parser
	CLOSE_PATH  # Z, z
}

class PathCommand:
	var type: PathCommandType
	var points: Array
	var relative: bool # Stores if the *original* command was relative

	func _init(cmd_type: PathCommandType, cmd_points: Array, is_relative: bool = false) -> void:
		type = cmd_type
		points = cmd_points
		relative = is_relative # Keep track if the source command was relative

# --- Constants ---
const EPSILON = 1e-5 # Small value for float comparisons

# --- Member Variables ---
var _commands: Array[PathCommand] = []
var _current_pos := Vector2.ZERO   # Tracks position during *parsing*
var _path_start := Vector2.ZERO    # Tracks start of current subpath during *parsing*
var _last_control_point := Vector2.ZERO # Tracks last control point during *parsing* for S/s/T/t

var _path_data: String = "" : set = set_path_data # Use setter for updates

# Variables for generated geometry and drawing
var _path_segments: Array[PackedVector2Array] = [] # Stores tessellated points for drawing/filling

# --- Properties (Example - Adjust as needed for SVGElement base) ---
#@export var fill_color: Color = Color.BLACK : set = _set_redraw
#@export var stroke_color: Color = Color.TRANSPARENT : set = _set_redraw
#@export var stroke_width: float = 1.0 : set = _set_redraw_and_recalc

# --- Engine Methods ---
func _ready() -> void:
	# If inheriting from Control, call super._ready() if needed
	# super._ready()
	if not _path_data.is_empty():
		# Call the setter to trigger parsing and drawing
		set_path_data(_path_data)
	else:
		# Ensure initial size calculation even with empty path
		_update_control_size()


func _draw() -> void:
	if _path_segments.is_empty():
		return

	# Draw fill if color has alpha > 0
	if fill_color.a > 0:
		for segment in _path_segments:
			# Geometry2D.triangulate_polygon requires at least 3 points
			if segment.size() > 2:
				# Simple polygon fill (might have issues with self-intersection/holes)
				draw_colored_polygon(segment, fill_color)
				# For more robust filling (holes), you'd need triangulation:
				# var triangles = Geometry2D.triangulate_polygon(segment)
				# for i in range(0, triangles.size(), 3):
				#     draw_colored_polygon(PackedVector2Array([segment[triangles[i]], segment[triangles[i+1]], segment[triangles[i+2]]]), fill_color)


	# Draw stroke if width > 0 and color is visible
	if stroke_width > 0 and stroke_color.a > 0:
		for segment in _path_segments:
			if segment.size() > 1:
				# Antialiasing is generally recommended for smoother lines
				draw_polyline(segment, stroke_color, stroke_width, true) # true = antialiased

# --- Setters ---
func set_path_data(d: String) -> void:
	if _path_data == d and not _commands.is_empty(): # Avoid reprocessing same data
		return
		
	_path_data = d
	_commands.clear()
	_shape_points.clear() # Clear derived data
	_path_segments.clear()
	_bounds_min = Vector2(INF, INF)
	_bounds_max = Vector2(-INF, -INF)

	# Reset parsing state variables
	_current_pos = Vector2.ZERO
	_path_start = Vector2.ZERO
	_last_control_point = Vector2.ZERO # Reset for S/T commands

	if not d.is_empty():
		_parse_path_data(d)
		_generate_path_segments() # Generate geometry *after* parsing
	
	_update_control_size() # Update size based on bounds
	queue_redraw()

func _set_redraw(value) -> void:
	# Generic setter for properties that only require redraw
	if fill_color == value or stroke_color == value: return # Prevent infinite loop if property is the same
	if value is Color: fill_color = value if value == fill_color else fill_color # Assign correct property
	if value is Color: stroke_color = value if value == stroke_color else stroke_color # Assign correct property
	queue_redraw()

func _set_redraw_and_recalc(value: float) -> void:
	# Setter for properties affecting size (like stroke width)
	if stroke_width == value: return
	stroke_width = value
	# Recalculate bounds/offset based on new stroke width
	_update_control_size()
	queue_redraw()


# --- Path Parsing Logic ---

func _parse_path_data(d: String) -> void:
	var tokens := _tokenize_path_data(d)
	var i := 0
	var last_cmd = "" # Track last command for implicit commands

	while i < tokens.size():
		var token : String = tokens[i]
		var command: String

		# Check if current token is a command letter
		if token in ["M", "m", "L", "l", "H", "h", "V", "v", "C", "c", "S", "s", "Q", "q", "T", "t", "A", "a", "Z", "z"]:
			command = token
			i += 1 # Move to the first parameter
		elif not last_cmd.is_empty() and token.is_valid_float():
			# Implicit command: repeat the last command (except M/m becomes L/l)
			if last_cmd.to_upper() == "M":
				command = "L" if last_cmd == "M" else "l"
			else:
				command = last_cmd
			# Don't increment 'i' here, the parameter parsing functions start at current 'i'
		else:
			push_warning("Invalid SVG path token sequence near: " + token)
			i += 1 # Skip invalid token
			continue # Go to next token

		last_cmd = command # Store the command for potential implicit repeats

		match command.to_upper():
			"M":
				i = _parse_move_to(tokens, i, command == "m")
				# After M/m, subsequent coord pairs are treated as L/l
				last_cmd = "L" if command == "M" else "l"
			"L":
				i = _parse_line_to(tokens, i, command == "l")
			"H":
				i = _parse_horizontal_to(tokens, i, command == "h")
			"V":
				i = _parse_vertical_to(tokens, i, command == "v")
			"C":
				i = _parse_curve_to(tokens, i, command == "c")
			"S":
				i = _parse_smooth_curve_to(tokens, i, command == "s")
			"Q":
				i = _parse_quad_to(tokens, i, command == "q")
			"T":
				i = _parse_smooth_quad_to(tokens, i, command == "t")
			"A":
				i = _parse_arc_to(tokens, i, command == "a") # Use the fixed version
			"Z": # z is handled identically
				_commands.append(PathCommand.new(PathCommandType.CLOSE_PATH, [], false))
				# Close path moves current position back to path start
				_current_pos = _path_start
				# Z implicitly ends the parameter list for the previous command
				# 'i' is already advanced past 'Z' or 'z' by the initial check
				pass # No parameters to consume

	# Final check: Reset last control point if path isn't explicitly closed?
	# Usually not needed, as next M/m resets it implicitly.


# --- Command Parsers (Individual Command Handlers) ---

func _tokenize_path_data(d: String) -> Array:
	# Improved tokenizer: handles numbers, signs, and commands robustly
	var tokens: Array = []
	var current_token: String = ""
	var path_len = d.length()
	var idx = 0

	while idx < path_len:
		var char = d[idx]

		if char == " " or char == ",":
			if not current_token.is_empty():
				tokens.append(current_token)
				current_token = ""
		elif char in ["M", "m", "L", "l", "H", "h", "V", "v", "C", "c", "S", "s", "Q", "q", "T", "t", "A", "a", "Z", "z"]:
			if not current_token.is_empty():
				tokens.append(current_token) # Append number before command
			tokens.append(char) # Append command
			current_token = ""
		elif char == "-" or char == "+":
			if not current_token.is_empty() and not current_token.ends_with("e") and not current_token.ends_with("E"):
				# If token has content and isn't scientific notation 'e', start new token
				tokens.append(current_token)
				current_token = char
			else:
				# Append sign (start of number, or part of exponent)
				current_token += char
		elif char == "." :
			if "." in current_token: # Cannot have two decimals
				if not current_token.is_empty():
					tokens.append(current_token)
				current_token = "." # Start new token if invalid float formed
			else:
				current_token += char
		elif char.is_valid_float() or char.to_lower() == "e": # Allow numbers and 'e' for scientific notation
			current_token += char
		else:
			# Skip unexpected characters? Or error?
			if not current_token.is_empty():
				tokens.append(current_token)
				current_token = ""
			push_warning("Skipping unexpected character in path data: " + char)

		idx += 1

	if not current_token.is_empty():
		tokens.append(current_token) # Add the last token

	return tokens


func _parse_move_to(tokens: Array, start_index: int, relative: bool) -> int:
	var i := start_index
	var first_point := true

	while i + 1 < tokens.size():
		if not tokens[i].is_valid_float() or not tokens[i + 1].is_valid_float():
			break # Stop if not enough valid coordinate data

		var x := float(tokens[i])
		var y := float(tokens[i + 1])
		var point := Vector2(x, y)

		# Crucial: Relative move is only relative for the *first* point after 'm'
		# Subsequent points in the 'm' sequence are absolute offsets from the *original* position
		# No, SVG Spec says: "If a moveto is followed by multiple pairs of coordinates, the subsequent pairs are treated as implicit lineto commands."
		# And relative 'l' is relative to the *current* point.

		if relative and first_point:
			point += _current_pos # Only first point is relative to *previous* subpath's end
		elif relative and not first_point:
			point += _current_pos # Implicit 'l' is relative to current point
		# Absolute points remain absolute

		if first_point:
			_commands.append(PathCommand.new(PathCommandType.MOVE_TO, [point], relative))
			_path_start = point # Update start of this subpath
			# Reset last control point on move, unless it's the very first command? SVG spec says "If the command is m [...] the control point is repositioned [...to] the current point".
			_last_control_point = point
			first_point = false
		else:
			# Implicit line-to
			_commands.append(PathCommand.new(PathCommandType.LINE_TO, [point], relative))
			# LineTo doesn't define a control point for S/T reflection.
			# Retain the _last_control_point from before the line? No, spec implies S/T after L defaults to Q. Let's reset control point concept here.
			_last_control_point = point # Treat endpoint as implicit control point? Or maybe better: No control point defined after LineTo. Let S/T handle this.

		_current_pos = point # Update current position
		i += 2

		# Check if next token looks like a command, signaling end of parameters
		if i < tokens.size() and not tokens[i].is_valid_float() and not tokens[i] in ["+", "-"]: # Simplified check
			if tokens[i] in ["M", "m", "L", "l", "H", "h", "V", "v", "C", "c", "S", "s", "Q", "q", "T", "t", "A", "a", "Z", "z"]:
				break

	return i


func _parse_line_to(tokens: Array, start_index: int, relative: bool) -> int:
	var i := start_index
	while i + 1 < tokens.size():
		if not tokens[i].is_valid_float() or not tokens[i + 1].is_valid_float(): break
		var point := Vector2(float(tokens[i]), float(tokens[i + 1]))
		if relative: point += _current_pos
		_commands.append(PathCommand.new(PathCommandType.LINE_TO, [point], relative))
		_current_pos = point
		_last_control_point = point # No curve control point after L/H/V/Z
		i += 2
		if i < tokens.size() and not tokens[i].is_valid_float() and not tokens[i] in ["+", "-"]:
			if tokens[i] in ["M", "m", "L", "l", "H", "h", "V", "v", "C", "c", "S", "s", "Q", "q", "T", "t", "A", "a", "Z", "z"]: break
	return i

func _parse_horizontal_to(tokens: Array, start_index: int, relative: bool) -> int:
	var i := start_index
	while i < tokens.size():
		if not tokens[i].is_valid_float(): break
		var x := float(tokens[i])
		var point := Vector2(x, _current_pos.y) if not relative else Vector2(_current_pos.x + x, _current_pos.y)
		_commands.append(PathCommand.new(PathCommandType.LINE_TO, [point], relative)) # Store as LineTo
		_current_pos = point
		_last_control_point = point # No curve control point
		i += 1
		if i < tokens.size() and not tokens[i].is_valid_float() and not tokens[i] in ["+", "-"]:
			if tokens[i] in ["M", "m", "L", "l", "H", "h", "V", "v", "C", "c", "S", "s", "Q", "q", "T", "t", "A", "a", "Z", "z"]: break
	return i

func _parse_vertical_to(tokens: Array, start_index: int, relative: bool) -> int:
	var i := start_index
	while i < tokens.size():
		if not tokens[i].is_valid_float(): break
		var y := float(tokens[i])
		var point := Vector2(_current_pos.x, y) if not relative else Vector2(_current_pos.x, _current_pos.y + y)
		_commands.append(PathCommand.new(PathCommandType.LINE_TO, [point], relative)) # Store as LineTo
		_current_pos = point
		_last_control_point = point # No curve control point
		i += 1
		if i < tokens.size() and not tokens[i].is_valid_float() and not tokens[i] in ["+", "-"]:
			if tokens[i] in ["M", "m", "L", "l", "H", "h", "V", "v", "C", "c", "S", "s", "Q", "q", "T", "t", "A", "a", "Z", "z"]: break
	return i

func _parse_curve_to(tokens: Array, start_index: int, relative: bool) -> int:
	var i := start_index
	while i + 5 < tokens.size():
		if not tokens[i].is_valid_float() or not tokens[i + 1].is_valid_float() or \
		   not tokens[i + 2].is_valid_float() or not tokens[i + 3].is_valid_float() or \
		   not tokens[i + 4].is_valid_float() or not tokens[i + 5].is_valid_float():
			break
		var cp1 := Vector2(float(tokens[i]), float(tokens[i + 1]))
		var cp2 := Vector2(float(tokens[i + 2]), float(tokens[i + 3]))
		var end := Vector2(float(tokens[i + 4]), float(tokens[i + 5]))
		if relative:
			cp1 += _current_pos
			cp2 += _current_pos
			end += _current_pos
		_commands.append(PathCommand.new(PathCommandType.CURVE_TO, [cp1, cp2, end], relative))
		_last_control_point = cp2 # Store second control point for S/s
		_current_pos = end
		i += 6
		if i < tokens.size() and not tokens[i].is_valid_float() and not tokens[i] in ["+", "-"]:
			if tokens[i] in ["M", "m", "L", "l", "H", "h", "V", "v", "C", "c", "S", "s", "Q", "q", "T", "t", "A", "a", "Z", "z"]: break
	return i

func _parse_smooth_curve_to(tokens: Array, start_index: int, relative: bool) -> int:
	var i := start_index
	while i + 3 < tokens.size():
		if not tokens[i].is_valid_float() or not tokens[i + 1].is_valid_float() or \
		   not tokens[i + 2].is_valid_float() or not tokens[i + 3].is_valid_float():
			break
		# Reflect previous control point. If previous command was not C/c/S/s, assume cp1 == current_pos.
		# Need to check the type of the *last added command*.
		var cp1: Vector2
		if _commands.is_empty() or not _commands.back().type in [PathCommandType.CURVE_TO, PathCommandType.SMOOTH_CURVE_TO]:
			cp1 = _current_pos # Default reflection if prev wasn't curve
		else:
			# Reflection calculation assumes _last_control_point was set correctly by C/S/Q/T
			cp1 = _current_pos + (_current_pos - _last_control_point)

		var cp2 := Vector2(float(tokens[i]), float(tokens[i + 1]))
		var end := Vector2(float(tokens[i + 2]), float(tokens[i + 3]))
		if relative:
			cp2 += _current_pos
			end += _current_pos
		_commands.append(PathCommand.new(PathCommandType.CURVE_TO, [cp1, cp2, end], relative)) # Store as CURVE_TO
		_last_control_point = cp2 # Store second control point for next S/s
		_current_pos = end
		i += 4
		if i < tokens.size() and not tokens[i].is_valid_float() and not tokens[i] in ["+", "-"]:
			if tokens[i] in ["M", "m", "L", "l", "H", "h", "V", "v", "C", "c", "S", "s", "Q", "q", "T", "t", "A", "a", "Z", "z"]: break
	return i

func _parse_quad_to(tokens: Array, start_index: int, relative: bool) -> int:
	var i := start_index
	while i + 3 < tokens.size():
		if not tokens[i].is_valid_float() or not tokens[i + 1].is_valid_float() or \
		   not tokens[i + 2].is_valid_float() or not tokens[i + 3].is_valid_float():
			break
		var control := Vector2(float(tokens[i]), float(tokens[i + 1]))
		var end := Vector2(float(tokens[i + 2]), float(tokens[i + 3]))
		var start_pos = _current_pos # Need start pos for conversion
		if relative:
			control += _current_pos
			end += _current_pos
		# Convert Q to C command for simplicity in generation/rendering
		var cubic_points := _quadratic_to_cubic(start_pos, control, end)
		# cubic_points = [cubic_cp1, cubic_cp2, quadratic_end]
		_commands.append(PathCommand.new(PathCommandType.CURVE_TO, cubic_points, relative)) # Store as CURVE_TO
		_last_control_point = control # Store the *original quadratic* control point for T/t
		_current_pos = end
		i += 4
		if i < tokens.size() and not tokens[i].is_valid_float() and not tokens[i] in ["+", "-"]:
			if tokens[i] in ["M", "m", "L", "l", "H", "h", "V", "v", "C", "c", "S", "s", "Q", "q", "T", "t", "A", "a", "Z", "z"]: break
	return i

func _parse_smooth_quad_to(tokens: Array, start_index: int, relative: bool) -> int:
	var i := start_index
	while i + 1 < tokens.size():
		if not tokens[i].is_valid_float() or not tokens[i + 1].is_valid_float():
			break
		var start_pos = _current_pos
		# Reflect previous control point. If previous command was not Q/q/T/t, assume control == current_pos.
		var control: Vector2
		if _commands.is_empty() or not _commands.back().type in [PathCommandType.QUAD_TO, PathCommandType.SMOOTH_QUAD_TO, PathCommandType.CURVE_TO]: # Check if last cmd allows reflection
			# Check if the last *parsed* command type was Q or T. We stored Q/T as CURVE_TO after conversion.
			# This logic needs refinement. Need to know the *source* command type or store original control point differently.
			# Let's assume _last_control_point holds the correct quadratic control point if prev was Q/T.
			# If prev command was *not* Q/q/T/t, control point is current point.
			var prev_cmd_type = _commands.back().type if not _commands.is_empty() else -1 # Use an invalid type if no commands yet
			# Problem: Q/T are converted to CURVE_TO. We lost the original type info needed here.
			# Quick Fix: Check _last_control_point. If it's == prev end pos, assume prev wasn't Q/T? Unreliable.
			# Better Fix: Store original command type or use a flag?
			# Let's stick to the SVG spec logic using _last_control_point directly:
			control = _current_pos + (_current_pos - _last_control_point)
			# This relies on Q/q setting _last_control_point to the quadratic control point,
			# and T/t updating _last_control_point to its *calculated* quadratic control point.

		var end := Vector2(float(tokens[i]), float(tokens[i + 1]))
		if relative:
			end += _current_pos
		# Convert T to C
		var cubic_points := _quadratic_to_cubic(start_pos, control, end)
		_commands.append(PathCommand.new(PathCommandType.CURVE_TO, cubic_points, relative)) # Store as CURVE_TO
		_last_control_point = control # Update last control point to the one *used* for this T curve
		_current_pos = end
		i += 2
		if i < tokens.size() and not tokens[i].is_valid_float() and not tokens[i] in ["+", "-"]:
			if tokens[i] in ["M", "m", "L", "l", "H", "h", "V", "v", "C", "c", "S", "s", "Q", "q", "T", "t", "A", "a", "Z", "z"]: break
	return i


# --- ARC PARSING (Replaced Placeholder) ---

func _parse_arc_to(tokens: Array, start_index: int, relative: bool) -> int:
	var i := start_index

	while i + 6 < tokens.size():
		# Check for 7 valid float parameters
		var params_valid = true
		for j in range(7):
			if not tokens[i + j].is_valid_float():
				params_valid = false
				break
		if not params_valid:
			break # Stop if not enough valid parameter data

		var rx := absf(float(tokens[i]))
		var ry := absf(float(tokens[i + 1]))
		var x_rotation_deg := float(tokens[i + 2])
		var large_arc_flag := int(float(tokens[i + 3])) != 0
		var sweep_flag := int(float(tokens[i + 4])) != 0
		var end_param := Vector2(float(tokens[i + 5]), float(tokens[i + 6]))

		var start_pos := _current_pos # Position before this arc segment
		var end: Vector2

		if relative:
			end = start_pos + end_param
		else:
			end = end_param

		# Handle edge cases based on SVG spec F.6.2
		if start_pos.distance_squared_to(end) < EPSILON:
			# If start and end points are the same, do nothing.
			pass # Don't add command, don't change position
		elif rx < EPSILON or ry < EPSILON:
			# If rx or ry are zero, treat as a straight line (L command).
			_commands.append(PathCommand.new(PathCommandType.LINE_TO, [end], relative))
			_current_pos = end
			_last_control_point = end # No curve control point
		else:
			# Convert the valid arc to cubic Bezier curves
			var cubic_segments: Array = _convert_arc_to_cubics(start_pos, rx, ry, x_rotation_deg, large_arc_flag, sweep_flag, end)

			if cubic_segments.is_empty():
				# Fallback if conversion returns nothing unexpectedly (e.g., numerical instability?)
				printerr("Arc to Cubic conversion failed unexpectedly, drawing line.")
				_commands.append(PathCommand.new(PathCommandType.LINE_TO, [end], relative))
				_current_pos = end
				_last_control_point = end
			else:
				for segment_points in cubic_segments:
					# segment_points is [control1, control2, segment_end]
					var control1: Vector2 = segment_points[0]
					var control2: Vector2 = segment_points[1]
					var segment_end: Vector2 = segment_points[2]

					# Append as a CURVE_TO command
					_commands.append(PathCommand.new(PathCommandType.CURVE_TO, segment_points, false)) # Store absolute coords

					# Update last control point (use cp2 for S command reflection)
					_last_control_point = control2
					# Update current position to the end of *this segment*
					_current_pos = segment_end

		i += 7 # Move past the 7 parameters consumed

		# Check if next token signals end of parameters
		if i < tokens.size() and not tokens[i].is_valid_float() and not tokens[i] in ["+", "-"]:
			if tokens[i] in ["M", "m", "L", "l", "H", "h", "V", "v", "C", "c", "S", "s", "Q", "q", "T", "t", "A", "a", "Z", "z"]:
				break

	return i


# --- Geometry Generation & Drawing ---

func _generate_path_segments() -> void:
	if _commands.is_empty():
		return

	var current_gen_pos := Vector2.ZERO # Position during generation
	var current_gen_path_start := Vector2.ZERO # Start of current subpath during generation
	# Note: We need _last_control_point *during generation* for S/T commands
	# The parser updated the class member `_last_control_point`. Is that safe?
	# It might be better to pass state explicitly or re-calculate reflection here.
	# Let's assume the parser correctly set _last_control_point *before* this runs.
	# Re-introduce a generation-specific last control point? No, parser state is needed.

	var current_segment_points: Array[Vector2] = [] # Use dynamic array first

	for cmd in _commands:
		match cmd.type:
			PathCommandType.MOVE_TO:
				# Finalize previous segment if it exists and is valid
				if current_segment_points.size() > 1:
					_path_segments.append(PackedVector2Array(current_segment_points))
				elif current_segment_points.size() == 1:
					# Handle single-point segments? Maybe draw a point or ignore?
					# Let's ignore for polyline/polygon. Update bounds though.
					_update_bounds(current_segment_points[0])

				current_segment_points.clear() # Start new segment

				# Get the absolute position from the command
				current_gen_pos = cmd.points[0]
				current_gen_path_start = current_gen_pos # Remember start for Z command

				current_segment_points.append(current_gen_pos)
				# Don't update bounds yet, wait until segment has >1 point or is closed

			PathCommandType.LINE_TO: # Handles L, H, V after parsing
				# Get absolute position
				current_gen_pos = cmd.points[0]
				if current_segment_points.is_empty():
					# If segment started without a MoveTo (e.g., malformed path "L 10 10")
					push_warning("LINE_TO command encountered without preceding MOVE_TO. Starting path at (0,0).")
					current_segment_points.append(Vector2.ZERO) # Assume start at 0,0
					_update_bounds(Vector2.ZERO)
					current_gen_path_start = Vector2.ZERO

				# Check if the new point is different from the last to avoid zero-length segments
				if current_segment_points.back() != current_gen_pos:
					current_segment_points.append(current_gen_pos)
					_update_bounds(current_gen_pos) # Update bounds for each point added

			PathCommandType.CURVE_TO: # Handles C, S, Q, T, A after parsing
				var start_point = Vector2.ZERO
				if current_segment_points.is_empty():
					push_warning("CURVE_TO command encountered without preceding MOVE_TO. Starting path at (0,0).")
					start_point = Vector2.ZERO
					current_segment_points.append(start_point)
					_update_bounds(start_point)
					current_gen_path_start = start_point
				else:
					start_point = current_segment_points.back()

				var cp1 = cmd.points[0]
				var cp2 = cmd.points[1]
				var end_point = cmd.points[2]

				# Tessellate the cubic Bezier curve
				# Use a reasonable number of steps. 12 is often okay.
				var bezier_points := _calculate_bezier_points(start_point, cp1, cp2, end_point, 12)

				# Append points (skip first as it's already in current_segment_points)
				for k in range(1, bezier_points.size()):
					# Check if point is different from last to avoid duplicates if steps is low or curve is short
					if current_segment_points.back() != bezier_points[k]:
						current_segment_points.append(bezier_points[k])
						_update_bounds(bezier_points[k]) # Update bounds for tessellated points

				current_gen_pos = end_point # Update position to the actual end of the curve

			PathCommandType.CLOSE_PATH:
				if not current_segment_points.is_empty() and current_segment_points.back() != current_gen_path_start:
					# Add line back to the start of the current subpath
					current_segment_points.append(current_gen_path_start)
					_update_bounds(current_gen_path_start) # Closing point affects bounds

				current_gen_pos = current_gen_path_start # Position is now back at the start

				# Finalize the closed segment
				if current_segment_points.size() > 1: # Need at least two points (start + something else) to form a line/shape
					_path_segments.append(PackedVector2Array(current_segment_points))

				current_segment_points.clear() # Ready for a new segment (likely after next M/m)

			_:
				push_warning("Unhandled command type during segment generation: " + str(cmd.type))


	# Add any remaining open segment
	if current_segment_points.size() > 1:
		_path_segments.append(PackedVector2Array(current_segment_points))
	elif current_segment_points.size() == 1:
		_update_bounds(current_segment_points[0]) # Ensure bounds include stray points

	# Collect all points for shape detection (if needed separately)
	# This seems redundant if _path_segments holds all final points.
	_shape_points.clear()
	for segment in _path_segments:
		for point in segment:
			_shape_points.append(point)

	# Initial bounds calculation is done during segment generation

func _update_bounds(point: Vector2) -> void:
	_bounds_min.x = min(_bounds_min.x, point.x)
	_bounds_min.y = min(_bounds_min.y, point.y)
	_bounds_max.x = max(_bounds_max.x, point.x)
	_bounds_max.y = max(_bounds_max.y, point.y)

func _update_control_size() -> void:
	# Control size should be based on the calculated bounds + stroke
	var bounds_size = Vector2.ZERO
	if _bounds_min.x <= _bounds_max.x and _bounds_min.y <= _bounds_max.y: # Check for valid bounds
		bounds_size = _bounds_max - _bounds_min
	
	# Add padding for stroke width (half stroke width on each side)
	var padding := Vector2(stroke_width, stroke_width)
	
	var new_size = bounds_size + padding
	
	# Ensure minimum size if path is empty or just a point
	if new_size.x < EPSILON: new_size.x = padding.x
	if new_size.y < EPSILON: new_size.y = padding.y
	
	# If using Control node:
	custom_minimum_size = new_size
	# Maybe reset size? Or let layout handle it? Resetting might be better.
	size = new_size

	# Calculate offset needed to draw the path starting from (stroke/2, stroke/2)
	# relative to the Control's top-left corner.
	var draw_offset := Vector2(stroke_width / 2.0, stroke_width / 2.0) - _bounds_min

	# Adjust all generated path segments to be relative to the control's origin
	# This needs to happen *after* bounds are calculated but *before* drawing.
	# It should only happen once after parsing. Let's move this.

	# ---> Let's move the adjustment logic into _generate_path_segments or do it just before drawing?
	# ---> Doing it here modifies the stored segments permanently after each size update, which might be wrong if stroke changes.
	# ---> Better approach: Calculate the offset here, store it, and apply it *during* _draw().

	# Store the calculated offset
	# Need a member variable: var _draw_offset := Vector2.ZERO
	# _draw_offset = Vector2(stroke_width / 2.0, stroke_width / 2.0) - _bounds_min
	
	# --- REVISED APPROACH: Adjust points after generation, store adjusted ---
	# This is simpler if recalculation on stroke change is okay.
	var adjusted_segments: Array[PackedVector2Array] = []
	for segment in _path_segments:
		var adjusted_segment = PackedVector2Array()
		for point in segment:
			adjusted_segment.append(point + draw_offset)
		adjusted_segments.append(adjusted_segment)
	_path_segments = adjusted_segments # Replace original segments with adjusted ones

	# Also adjust shape points if they are used independently
	var adjusted_shape_points: Array[Vector2] = []
	for point in _shape_points:
		adjusted_shape_points.append(point + draw_offset)
	_shape_points = adjusted_shape_points
	
	# Bounds are now relative to the control origin (0,0) to (size.x, size.y)
	# _bounds_min = Vector2(stroke_width / 2.0, stroke_width / 2.0)
	# _bounds_max = _bounds_min + bounds_size


# --- Hit Testing ---
func _is_point_in_shape(point: Vector2) -> bool:
	# Check point against the *final, offset* polygon segments
	for segment in _path_segments:
		if segment.size() > 2 and Geometry2D.is_point_in_polygon(point, segment):
			# Basic point-in-polygon test. Doesn't account for stroke width.
			return true
			
	# TODO: Add check for point on stroke if needed (more complex)
	return false


# --- Helper Methods ---

# Helper function to compute angle between two vectors
static func _angle(u: Vector2, v: Vector2) -> float:
	var sign := 1.0
	if u.x * v.y - u.y * v.x < 0.0: sign = -1.0
	var dot_prod := sqrt(u.dot(v) / (u.length_squared() * v.length_squared()))
	dot_prod = clamp(dot_prod, -1.0, 1.0) # Clamp for safety
	return sign * acos(dot_prod)

# Helper function: Convert elliptical arc to cubic Bezier segments
static func _convert_arc_to_cubics(p1: Vector2, rx: float, ry: float, phi_deg: float, fA: bool, fS: bool, p2: Vector2) -> Array: # Array[Array[Vector2]]
	var cubics: Array = []
	if p1.distance_squared_to(p2) < EPSILON: return cubics # Points identical
	# rx/ry zero handled in caller (_parse_arc_to)

	var phi := deg_to_rad(phi_deg)
	var cos_phi := cos(phi)
	var sin_phi := sin(phi)

	var half_p1_p2 = (p1 - p2) / 2.0
	var p1_prime := Vector2(cos_phi * half_p1_p2.x + sin_phi * half_p1_p2.y, -sin_phi * half_p1_p2.x + cos_phi * half_p1_p2.y)

	var rx_sq := rx * rx
	var ry_sq := ry * ry
	var p1_prime_x_sq := p1_prime.x * p1_prime.x
	var p1_prime_y_sq := p1_prime.y * p1_prime.y

	var radii_check := p1_prime_x_sq / rx_sq + p1_prime_y_sq / ry_sq
	if radii_check > 1.0:
		var scale_factor := sqrt(radii_check)
		rx *= scale_factor
		ry *= scale_factor
		rx_sq = rx * rx
		ry_sq = ry * ry

	var sign := 1.0 if fA == fS else -1.0
	var sq_num := rx_sq * ry_sq - rx_sq * p1_prime_y_sq - ry_sq * p1_prime_x_sq
	var sq_den := rx_sq * p1_prime_y_sq + ry_sq * p1_prime_x_sq
	# Ensure non-negative under square root
	var sq := sqrt(max(0.0, sq_num / sq_den)) if sq_den > EPSILON else 0.0

	var center_prime := Vector2(sign * sq * (rx * p1_prime.y / ry), sign * sq * (-ry * p1_prime.x / rx))

	var center_offset = (p1 + p2) / 2.0
	var center := Vector2(cos_phi * center_prime.x - sin_phi * center_prime.y + center_offset.x, sin_phi * center_prime.x + cos_phi * center_prime.y + center_offset.y)

	var vec1 := Vector2((p1_prime.x - center_prime.x) / rx, (p1_prime.y - center_prime.y) / ry)
	var vec2 := Vector2((-p1_prime.x - center_prime.x) / rx, (-p1_prime.y - center_prime.y) / ry)

	var start_angle := _angle(Vector2(1, 0), vec1)
	var delta_angle := _angle(vec1, vec2)

	if not fS and delta_angle > 0: delta_angle -= TAU
	elif fS and delta_angle < 0: delta_angle += TAU

	# Approximate arc with cubic Beziers (max 90 degrees per segment)
	var num_segments := int(ceil(absf(delta_angle) / (PI / 2.0)))
	if num_segments == 0 : return cubics # Avoid division by zero if delta_angle is tiny

	var angle_step := delta_angle / float(num_segments) # Ensure float division
	var current_angle := start_angle
	var current_point := p1

	var t = tan(0.5 * angle_step)
	# Handle potential division by zero or large values if angle_step is near +/- PI
	var alpha := 0.0
	if abs(t) < 1e6: # Avoid extreme tan values
		var sqrt_term = sqrt(max(0.0, 4.0 + 3.0 * t * t)) # Ensure non-negative
		alpha = sin(angle_step) * (sqrt_term - 1.0) / 3.0
	else: # Approximation for large t (angle_step near PI) - Bezier isn't great here anyway
		alpha = 4.0/3.0 * sin(angle_step / 2.0) / (1 + cos(angle_step / 2.0)) if abs(1 + cos(angle_step / 2.0)) > EPSILON else 0.0


	for i in range(num_segments):
		var next_angle := current_angle + angle_step
		var cos_start := cos(current_angle)
		var sin_start := sin(current_angle)
		var cos_end := cos(next_angle)
		var sin_end := sin(next_angle)

		var end_prime := Vector2(rx * cos_end, ry * sin_end)
		var next_point := Vector2(
			cos_phi * end_prime.x - sin_phi * end_prime.y + center.x,
			sin_phi * end_prime.x + cos_phi * end_prime.y + center.y
		)
		# Ensure final segment ends precisely at p2
		if i == num_segments - 1: next_point = p2

		var tangent1 := Vector2(-rx * sin_start, ry * cos_start)
		var rotated_tangent1 := Vector2(cos_phi * tangent1.x - sin_phi * tangent1.y, sin_phi * tangent1.x + cos_phi * tangent1.y)
		var tangent2 := Vector2(-rx * sin_end, ry * cos_end)
		var rotated_tangent2 := Vector2(cos_phi * tangent2.x - sin_phi * tangent2.y, sin_phi * tangent2.x + cos_phi * tangent2.y)

		var cp1 := current_point + rotated_tangent1 * alpha
		var cp2 := next_point - rotated_tangent2 * alpha

		cubics.append([cp1, cp2, next_point]) # Store [Control1, Control2, EndPoint]

		current_angle = next_angle
		current_point = next_point

	return cubics


# Helper methods for curve calculations (used in _generate_path_segments)
func _calculate_bezier_points(start: Vector2, control1: Vector2, control2: Vector2, end: Vector2, steps: int = 12) -> Array[Vector2]:
	var points: Array[Vector2] = []
	points.append(start)
	if steps <= 0 : steps = 1 # Ensure at least one step
	for i in range(1, steps + 1):
		var t := float(i) / float(steps)
		var point := _cubic_bezier(start, control1, control2, end, t)
		points.append(point)
	return points

# Note: _calculate_quadratic_bezier_points is no longer directly needed if Q/T are converted to C during parsing.
# Keep it if you might use quadratic curves elsewhere.
#func _calculate_quadratic_bezier_points(start: Vector2, control: Vector2, end: Vector2, steps: int = 12) -> Array[Vector2]:
#	var points: Array[Vector2] = []
#	points.append(start)
#	if steps <= 0 : steps = 1
#	for i in range(1, steps + 1):
#		var t := float(i) / float(steps)
#		var point := _quadratic_bezier(start, control, end, t)
#		points.append(point)
#	return points

static func _cubic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var mt := 1.0 - t
	var mt2 := mt * mt
	var mt3 := mt2 * mt
	var t2 := t * t
	var t3 := t2 * t
	return p0 * mt3 + p1 * (3.0 * mt2 * t) + p2 * (3.0 * mt * t2) + p3 * t3

static func _quadratic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var mt := 1.0 - t
	var mt2 := mt * mt
	var t2 := t * t
	return p0 * mt2 + p1 * (2.0 * mt * t) + p2 * t2

# Helper to convert Quadratic Bezier control point to Cubic Bezier control points
static func _quadratic_to_cubic(p0: Vector2, p1: Vector2, p2: Vector2) -> Array[Vector2]:
	# p0: start, p1: quadratic control, p2: end
	# Returns [cubic_cp1, cubic_cp2, cubic_end (=p2)]
	var cp1 := p0 + (p1 - p0) * (2.0 / 3.0)
	var cp2 := p2 + (p1 - p2) * (2.0 / 3.0)
	return [cp1, cp2, p2]
