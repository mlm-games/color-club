@tool
class_name SVGUtils
extends RefCounted

# For curve tessellation
const CURVE_SEGMENTS = 32
const BEZIER_TOLERANCE = 0.5

# Color parsing with better error handling
static func parse_color(color_string: String) -> Color:
	color_string = color_string.strip_edges().to_lower()
	
	if color_string.begins_with("#"):
		return Color.html(color_string)
	elif color_string.begins_with("rgb"):
		return _parse_rgb_color(color_string)
	else:
		# Named colors
		return _parse_named_color(color_string)

static func _parse_rgb_color(rgb_string: String) -> Color:
	# Simple RGB parsing: rgb(255, 0, 0) or rgb(100%, 0%, 0%)
	var regex = RegEx.new()
	regex.compile(r"rgb\s*\(\s*([^,]+)\s*,\s*([^,]+)\s*,\s*([^)]+)\s*\)")
	var result = regex.search(rgb_string)
	
	if result:
		var r_str = result.get_string(1).strip_edges()
		var g_str = result.get_string(2).strip_edges()
		var b_str = result.get_string(3).strip_edges()
		
		var r: float
		var g: float
		var b: float
		
		if r_str.ends_with("%"):
			r = float(r_str.substr(0, r_str.length() - 1)) / 100.0
			g = float(g_str.substr(0, g_str.length() - 1)) / 100.0
			b = float(b_str.substr(0, b_str.length() - 1)) / 100.0
		else:
			r = float(r_str) / 255.0
			g = float(g_str) / 255.0
			b = float(b_str) / 255.0
		
		return Color(r, g, b)
	
	push_warning("Failed to parse RGB color: " + rgb_string)
	return Color.WHITE

static func _parse_named_color(color_name: String) -> Color:
	match color_name:
		"red": return Color.RED
		"green": return Color.GREEN
		"blue": return Color.BLUE
		"black": return Color.BLACK
		"white": return Color.WHITE
		"transparent": return Color.TRANSPARENT
		"yellow": return Color.YELLOW
		"cyan": return Color.CYAN
		"magenta": return Color.MAGENTA
		"orange": return Color.ORANGE
		"purple": return Color.PURPLE
		"brown": return Color(0.6, 0.3, 0.1)
		"gray", "grey": return Color.GRAY
		"darkgray", "darkgrey": return Color.DIM_GRAY
		"lightgray", "lightgrey": return Color.LIGHT_GRAY
		_:
			push_warning("Unknown color name: " + color_name)
			return Color.WHITE

# Improved style string parsing
static func parse_style_string(style_string: String) -> Dictionary:
	var result = {}
	if style_string.is_empty():
		return result
	
	var declarations = style_string.split(";")
	for declaration in declarations:
		declaration = declaration.strip_edges()
		if declaration.is_empty():
			continue
		
		var colon_pos = declaration.find(":")
		if colon_pos > 0:
			var property = declaration.substr(0, colon_pos).strip_edges().to_lower()
			var value = declaration.substr(colon_pos + 1).strip_edges()
			result[property] = value
	
	return result

# Improved transform parsing
# Improved transform parsing with better rotation handling
static func parse_transform(transform_string: String) -> Transform2D:
	if transform_string.is_empty():
		return Transform2D.IDENTITY
	
	var result_transform = Transform2D.IDENTITY
	
	# Parse multiple transform functions
	var regex = RegEx.new()
	regex.compile(r"(\w+)\s*\([^)]*\)")
	var matches = regex.search_all(transform_string)
	
	for match in matches:
		var full_match = match.get_string(0)
		var func_name = match.get_string(1).to_lower()
		
		# Extract parameters
		var params_start = full_match.find("(")
		var params_end = full_match.rfind(")")
		var params_str = full_match.substr(params_start + 1, params_end - params_start - 1)
		var params = _parse_transform_params(params_str)
		
		var func_transform = _parse_single_transform(func_name, params)
		# Apply transforms in order (left-multiply)
		result_transform = func_transform * result_transform
	
	return result_transform

static func _parse_transform_params(params_str: String) -> Array[float]:
	var params: Array[float] = []
	if params_str.is_empty():
		return params
	
	# Replace commas with spaces and split
	var cleaned = params_str.replace(",", " ")
	var parts = cleaned.split(" ", false)  # false = don't allow empty strings
	
	for part in parts:
		part = part.strip_edges()
		if not part.is_empty() and part.is_valid_float():
			params.append(float(part))
	
	return params

static func _parse_single_transform(func_name: String, params: Array[float]) -> Transform2D:
	match func_name:
		"translate":
			var tx = params[0] if params.size() > 0 else 0.0
			var ty = params[1] if params.size() > 1 else 0.0
			return Transform2D(0.0, Vector2(tx, ty))
		
		"scale":
			var sx = params[0] if params.size() > 0 else 1.0
			var sy = params[1] if params.size() > 1 else sx
			return Transform2D.IDENTITY.scaled(Vector2(sx, sy))
		
		"rotate":
			var angle_deg = params[0] if params.size() > 0 else 0.0
			var angle_rad = deg_to_rad(angle_deg)
			
			if params.size() >= 3:
				# Rotate around point (cx, cy)
				var cx = params[1]
				var cy = params[2]
				var center = Vector2(cx, cy)
				
				# Create compound transform: translate to origin, rotate, translate back
				var t1 = Transform2D(0.0, -center)
				var r = Transform2D(angle_rad, Vector2.ZERO)
				var t2 = Transform2D(0.0, center)
				
				return t2 * r * t1
			else:
				# Rotate around origin
				return Transform2D(angle_rad, Vector2.ZERO)
		
		"skewx":
			var angle_deg = params[0] if params.size() > 0 else 0.0
			var angle_rad = deg_to_rad(angle_deg)
			return Transform2D(Vector2(1, 0), Vector2(tan(angle_rad), 1), Vector2.ZERO)
		
		"skewy":
			var angle_deg = params[0] if params.size() > 0 else 0.0
			var angle_rad = deg_to_rad(angle_deg)
			return Transform2D(Vector2(1, tan(angle_rad)), Vector2(0, 1), Vector2.ZERO)
		
		"matrix":
			if params.size() >= 6:
				return Transform2D(
					Vector2(params[0], params[1]),
					Vector2(params[2], params[3]),
					Vector2(params[4], params[5])
				)
			else:
				push_warning("Invalid matrix transform parameters")
				return Transform2D.IDENTITY
		
		_:
			push_warning("Unsupported transform function: " + func_name)
			return Transform2D.IDENTITY



# Element factory with proper error handling
static func create_svg_element(tag_name: String, attributes: Dictionary) -> SVGElement:
	var element: SVGElement = null
	
	match tag_name:
		"rect":
			element = SVGRect.new()
			element.set_rect_properties(attributes)
		"circle":
			element = SVGCircle.new()
			element.set_circle_properties(attributes)
		"ellipse":
			element = SVGEllipse.new()
			element.set_ellipse_properties(attributes)
		"path":
			element = SVGPath.new()
			element.set_path_properties(attributes)
		"line":
			element = SVGLine.new()
			element.set_line_properties(attributes)
		"polyline":
			element = SVGPolyline.new()
			element.set_polyline_properties(attributes)
		"polygon":
			element = SVGPolygon.new()
			element.set_polygon_properties(attributes)
		"text":
			push_warning("SVG <text> element not implemented")
			return null
		"image":
			push_warning("SVG <image> element not implemented")
			return null
		_:
			push_warning("Unknown SVG element: " + tag_name)
			return null
	
	return element



# Dimension parsing with unit support
static func parse_dimension(value: String) -> float:
	if value.is_empty():
		return 0.0
	
	value = value.strip_edges().to_lower()
	
	# Remove common units (simplified conversion)
	if value.ends_with("px"):
		return float(value.substr(0, value.length() - 2))
	elif value.ends_with("pt"):
		return float(value.substr(0, value.length() - 2)) * 1.333  # pt to px approximation
	elif value.ends_with("mm"):
		return float(value.substr(0, value.length() - 2)) * 3.779  # mm to px approximation
	elif value.ends_with("cm"):
		return float(value.substr(0, value.length() - 2)) * 37.79  # cm to px approximation
	elif value.ends_with("%"):
		push_warning("Percentage dimensions not supported: " + value)
		return 0.0
	else:
		return float(value)

static func tessellate_elliptical_arc(p1: Vector2, rx_in: float, ry_in: float, phi_deg: float, fA: bool, fS: bool, p2: Vector2, num_segments_hint: int) -> PackedVector2Array:
	var phi = deg_to_rad(phi_deg)
	var cos_phi = cos(phi)
	var sin_phi = sin(phi)

	# Ensure radii are positive
	var rx = abs(rx_in)
	var ry = abs(ry_in)

	# Step 1: Compute (x1', y1')
	var p1_prime = Vector2(
		cos_phi * (p1.x - p2.x) / 2.0 + sin_phi * (p1.y - p2.y) / 2.0,
		-sin_phi * (p1.x - p2.x) / 2.0 + cos_phi * (p1.y - p2.y) / 2.0
	)

	# Ensure radii are large enough (F.6.6)
	var lambda_sq = (p1_prime.x * p1_prime.x) / (rx * rx) + (p1_prime.y * p1_prime.y) / (ry * ry)
	if lambda_sq > 1.0:
		var lambda = sqrt(lambda_sq)
		rx *= lambda
		ry *= lambda

	var rx_sq = rx * rx
	var ry_sq = ry * ry
	var p1p_sq = p1_prime.x * p1_prime.x
	var p1p_y_sq = p1_prime.y * p1_prime.y

	# Step 2: Compute (cx', cy')
	var num = rx_sq * ry_sq - rx_sq * p1p_y_sq - ry_sq * p1p_sq
	if num < 0: num = 0 # Handle precision errors
	var den = rx_sq * p1p_y_sq + ry_sq * p1p_sq
	var sign = -1.0 if fA == fS else 1.0
	var c_factor = sign * sqrt(num / den)

	var c_prime = Vector2(
		c_factor * (rx * p1_prime.y / ry),
		c_factor * -(ry * p1_prime.x / rx)
	)

	# Step 3: Compute (cx, cy)
	var p1_p2_mid = (p1 + p2) / 2.0
	var center = Vector2(
		cos_phi * c_prime.x - sin_phi * c_prime.y + p1_p2_mid.x,
		sin_phi * c_prime.x + cos_phi * c_prime.y + p1_p2_mid.y
	)

	# Step 4: Compute start_angle and delta_angle
	var v1 = Vector2((p1_prime.x - c_prime.x) / rx, (p1_prime.y - c_prime.y) / ry)
	var v2 = Vector2((-p1_prime.x - c_prime.x) / rx, (-p1_prime.y - c_prime.y) / ry)

	var start_angle = Vector2.RIGHT.angle_to(v1) # Angle from (1,0) to v1
	var delta_angle = v1.angle_to(v2)           # Signed angle from v1 to v2

	# Correct delta_angle based on sweep_flag (fS)
	if not fS and delta_angle > 0: # sweep-flag is 0 (counter-clockwise) and angle is positive
		delta_angle -= TAU       # We need to go the long way around counter-clockwise
	elif fS and delta_angle < 0: # sweep-flag is 1 (clockwise) and angle is negative
		delta_angle += TAU       # We need to go the long way around clockwise

	# Adaptive segmentation based on angle sweep
	# A good heuristic is ~4-8 segments per 90 degrees (PI/2 radians)
	var num_segments = ceil(abs(delta_angle) / (PI / 8.0))
	if num_segments < 2: num_segments = 2
	if num_segments > 64: num_segments = 64 # Cap max segments for performance

	var points := PackedVector2Array()
	points.append(p1) # Start with the first point

	for i in range(1, int(num_segments) + 1):
		var t = float(i) / float(num_segments)
		var angle = start_angle + delta_angle * t
		
		# Point on unrotated, untranslated ellipse
		var ellipse_point = Vector2(rx * cos(angle), ry * sin(angle))
		
		# Apply rotation and translate to center
		var final_point = Vector2(
			cos_phi * ellipse_point.x - sin_phi * ellipse_point.y + center.x,
			sin_phi * ellipse_point.x + cos_phi * ellipse_point.y + center.y
		)
		points.append(final_point)

	return points

# Cubic Bezier curve tessellation
static func _add_cubic_bezier(points: PackedVector2Array, p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2) -> void:
	# Adaptive subdivision based on curvature
	var segments = _calculate_bezier_segments(p0, p1, p2, p3)
	
	for i in range(1, segments + 1):
		var t = float(i) / float(segments)
		var point = _cubic_bezier_point(p0, p1, p2, p3, t)
		points.append(point)

static func _cubic_bezier_point(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var u = 1.0 - t
	var tt = t * t
	var uu = u * u
	var uuu = uu * u
	var ttt = tt * t
	
	var point = uuu * p0
	point += 3 * uu * t * p1
	point += 3 * u * tt * p2
	point += ttt * p3
	
	return point

# Quadratic Bezier curve tessellation
static func _add_quadratic_bezier(points: PackedVector2Array, p0: Vector2, p1: Vector2, p2: Vector2) -> void:
	# Convert to cubic for consistency
	var cp1 = p0 + 2.0/3.0 * (p1 - p0)
	var cp2 = p2 + 2.0/3.0 * (p1 - p2)
	_add_cubic_bezier(points, p0, cp1, cp2, p2)

# Adaptive subdivision for curves
static func _calculate_bezier_segments(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2) -> int:
	# Estimate curve length
	var chord = p0.distance_to(p3)
	var control_net = p0.distance_to(p1) + p1.distance_to(p2) + p2.distance_to(p3)
	
	if chord < 0.001:
		return 1
	
	# More segments for curvier paths
	var curviness = (control_net - chord) / chord
	return clamp(int(curviness * CURVE_SEGMENTS), 4, CURVE_SEGMENTS * 2)
