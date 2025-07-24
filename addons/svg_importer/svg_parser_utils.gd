## Utility functions for parsing SVG attributes and converting shapes.
class_name SVGImporterUtils
extends RefCounted

const COLOR_MAP = {
	"black": Color.BLACK, "white": Color.WHITE, "red": Color.RED,
	"green": Color.GREEN, "blue": Color.BLUE, "yellow": Color.YELLOW,
	"cyan": Color.CYAN, "magenta": Color.MAGENTA, "gray": Color.GRAY,
	"transparent": Color.TRANSPARENT, "grey": Color.GRAY
}

# --- Property Parsers ---

static func parse_color(color_string: String) -> Color:
	var s = color_string.strip_edges().to_lower()
	if s == "none": return Color.TRANSPARENT
	if s in COLOR_MAP: return COLOR_MAP[s]
	if s.begins_with("#"): return Color.html(s)
	if s.begins_with("rgb"):
		var values_str = s.trim_prefix("rgb(").trim_suffix(")")
		var values = values_str.split(",", false)
		if values.size() == 3:
			var r = float(values[0].strip_edges()) / 255.0
			var g = float(values[1].strip_edges()) / 255.0
			var b = float(values[2].strip_edges()) / 255.0
			return Color(r, g, b)
	return Color.BLACK

static func parse_dimension(value_str: String) -> float:
	var regex = RegEx.new()
	regex.compile("(-?\\d*\\.?\\d+)")
	var result = regex.search(value_str)
	return float(result.get_string()) if result else 0.0

static func extract_styles_from_attributes(attributes: Dictionary) -> Dictionary:
	var style = {}
	if "style" in attributes:
		style.merge(parse_style_string(attributes["style"]), true)
	
	for key in ["fill", "stroke", "stroke-width", "opacity", "fill-opacity", "stroke-opacity"]:
		if key in attributes:
			style[key] = attributes[key]
	return style

static func get_style_property(style: Dictionary, prop: String) -> Variant:
	var value = style.get(prop, null)
	if value == null:
		# Default SVG values
		match prop:
			"fill": return Color.BLACK
			"stroke": return Color.TRANSPARENT
			"stroke-width": return 1.0
			"opacity": return 1.0
			"fill-opacity": return 1.0
			"stroke-opacity": return 1.0
		return null

	match prop:
		"fill", "stroke": return parse_color(value)
		"stroke-width": return parse_dimension(value)
		"opacity", "fill-opacity", "stroke-opacity": return clamp(float(value), 0.0, 1.0)
		_: return value

static func parse_style_string(style_str: String) -> Dictionary:
	var styles = {}
	for item in style_str.split(";", false):
		var parts = item.split(":", false)
		if parts.size() == 2:
			styles[parts[0].strip_edges()] = parts[1].strip_edges()
	return styles

static func parse_transform(transform_str: String) -> Transform2D:
	var final_transform = Transform2D.IDENTITY
	var func_regex = RegEx.new()
	func_regex.compile("(\\w+)\\s*\\(([^)]*)\\)")
	var num_regex = RegEx.new()
	num_regex.compile("(-?\\d*\\.?\\d+)")
	transform_str.reverse()
	for match in func_regex.search_all(transform_str):
		var type = match.get_string(1).to_lower()
		var params_str = match.get_string(2)
		var params: Array[float] = []
		for num_match in num_regex.search_all(params_str):
			params.append(float(num_match.get_string()))
		
		var t = Transform2D.IDENTITY
		if params.is_empty() and type != "rotate": continue

		match type:
			"translate":
				t = Transform2D(0.0, Vector2(params[0], params[1] if params.size() > 1 else 0.0))
			"scale":
				t = Transform2D.IDENTITY.scaled(Vector2(params[0], params[1] if params.size() > 1 else params[0]))
			"rotate":
				var angle_rad = deg_to_rad(params[0] if not params.is_empty() else 0.0)
				if params.size() >= 3:
					var center = Vector2(params[1], params[2])
					t = Transform2D(0.0, center) * Transform2D(angle_rad, Vector2.ZERO) * Transform2D(0.0, -center)
				else:
					t = Transform2D(angle_rad, Vector2.ZERO)
			"matrix":
				if params.size() >= 6:
					t = Transform2D(Vector2(params[0], params[1]), Vector2(params[2], params[3]), Vector2(params[4], params[5]))

		final_transform = final_transform * t
	return final_transform

# --- Root SVG Properties ---
static func apply_svg_root_properties(root_node: Node2D, attributes: Dictionary) -> void:
	var width = parse_dimension(attributes.get("width", "100"))
	var height = parse_dimension(attributes.get("height", "100"))
	var viewbox: Rect2
	
	if "viewBox" in attributes:
		var vb_parts: Array[float] = []
		var num_regex = RegEx.new()
		num_regex.compile("(-?\\d*\\.?\\d+)")
		for match in num_regex.search_all(attributes.get("viewBox")):
			vb_parts.append(float(match.get_string()))
		
		if vb_parts.size() == 4:
			viewbox = Rect2(vb_parts[0], vb_parts[1], vb_parts[2], vb_parts[3])
	
	if viewbox.size.x > 0 and viewbox.size.y > 0:
		var scale_x = width / viewbox.size.x
		var scale_y = height / viewbox.size.y
		root_node.scale = Vector2(scale_x, scale_y)
		root_node.position = -viewbox.position * root_node.scale

# --- Shape to Points Conversion ---
static func rect_to_points(attr: Dictionary) -> PackedVector2Array:
	var x = parse_dimension(attr.get("x", "0"))
	var y = parse_dimension(attr.get("y", "0"))
	var w = parse_dimension(attr.get("width", "0"))
	var h = parse_dimension(attr.get("height", "0"))
	# Note: rx/ry for rounded rects would require path conversion.
	return [Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)]

static func rect_to_path_string(x: float, y: float, w: float, h: float, rx: float, ry: float) -> String:
	if rx == 0 and ry == 0:
		return "M %f %f L %f %f L %f %f L %f %f Z" % [x, y, x+w, y, x+w, y+h, x, y+h]
	
	if rx == 0: rx = ry
	if ry == 0: ry = rx
	rx = min(rx, w / 2.0)
	ry = min(ry, h / 2.0)
	
	var path = "M %f %f " % [x + rx, y]  # Move to start
	path += "L %f %f " % [x + w - rx, y]  # Top edge
	path += "A %f %f 0 0 1 %f %f " % [rx, ry, x + w, y + ry]  # Top-right
	path += "L %f %f " % [x + w, y + h - ry]  # Right edge
	path += "A %f %f 0 0 1 %f %f " % [rx, ry, x + w - rx, y + h]  # Bottom-right
	path += "L %f %f " % [x + rx, y + h]  # Bottom edge
	path += "A %f %f 0 0 1 %f %f " % [rx, ry, x, y + h - ry]  # Bottom-left
	path += "L %f %f " % [x, y + ry]  # Left edge
	path += "A %f %f 0 0 1 %f %f " % [rx, ry, x + rx, y]  # Top-left
	path += "Z"  # Close path
	
	return path

static func circle_to_points(attr: Dictionary) -> PackedVector2Array:
	var cx = parse_dimension(attr.get("cx", "0"))
	var cy = parse_dimension(attr.get("cy", "0"))
	var r = parse_dimension(attr.get("r", "0"))
	return ellipse_to_points({"cx":str(cx), "cy":str(cy), "rx":str(r), "ry":str(r)})

static func ellipse_to_points(attr: Dictionary) -> PackedVector2Array:
	var cx = parse_dimension(attr.get("cx", "0"))
	var cy = parse_dimension(attr.get("cy", "0"))
	var rx = parse_dimension(attr.get("rx", "0"))
	var ry = parse_dimension(attr.get("ry", "0"))
	
	var points: PackedVector2Array
	var segments = 32
	for i in range(segments):
		var angle = TAU * i / segments
		points.append(Vector2(cx + cos(angle) * rx, cy + sin(angle) * ry))
	return points

static func line_to_points(attr: Dictionary) -> PackedVector2Array:
	var x1 = parse_dimension(attr.get("x1", "0"))
	var y1 = parse_dimension(attr.get("y1", "0"))
	var x2 = parse_dimension(attr.get("x2", "0"))
	var y2 = parse_dimension(attr.get("y2", "0"))
	return [Vector2(x1, y1), Vector2(x2, y2)]
	
static func points_string_to_array(points_str: String) -> PackedVector2Array:
	var points: PackedVector2Array
	var numbers: Array[float] = []
	var num_regex = RegEx.new()
	num_regex.compile("(-?\\d*\\.?\\d+)")
	for match in num_regex.search_all(points_str):
		numbers.append(float(match.get_string()))

	for i in range(0, numbers.size(), 2):
		if i + 1 < numbers.size():
			points.append(Vector2(numbers[i], numbers[i+1]))
	return points
	
# --- Arc Tessellation (from Curved Lines 2D / GodSVG) ---
static func tessellate_elliptical_arc(p1: Vector2, rx: float, ry: float, phi_deg: float, fA: bool, fS: bool, p2: Vector2) -> PackedVector2Array:
	if p1.is_equal_approx(p2) or rx <= 0 or ry <= 0: return [p2]

	var phi = deg_to_rad(phi_deg)
	var cos_phi = cos(phi); var sin_phi = sin(phi)

	var p1_prime = Vector2(
		cos_phi * (p1.x - p2.x) / 2.0 + sin_phi * (p1.y - p2.y) / 2.0,
		-sin_phi * (p1.x - p2.x) / 2.0 + cos_phi * (p1.y - p2.y) / 2.0
	)

	var lambda_sq = (p1_prime.x * p1_prime.x) / (rx * rx) + (p1_prime.y * p1_prime.y) / (ry * ry)
	if lambda_sq > 1.0:
		var lambda = sqrt(lambda_sq)
		rx *= lambda; ry *= lambda

	var rx_sq = rx*rx; var ry_sq = ry*ry
	var p1p_x_sq = p1_prime.x*p1_prime.x; var p1p_y_sq = p1_prime.y*p1_prime.y
	
	var num = rx_sq * ry_sq - rx_sq * p1p_y_sq - ry_sq * p1p_x_sq
	if num < 0: num = 0
	var den = rx_sq * p1p_y_sq + ry_sq * p1p_x_sq
	var sign = -1.0 if fA == fS else 1.0
	var c_factor = sign * sqrt(num / den)

	var c_prime = Vector2(c_factor * (rx * p1_prime.y / ry), c_factor * -(ry * p1_prime.x / rx))
	var center = Vector2(
		cos_phi * c_prime.x - sin_phi * c_prime.y + (p1.x + p2.x) / 2.0,
		sin_phi * c_prime.x + cos_phi * c_prime.y + (p1.y + p2.y) / 2.0
	)

	var v1 = Vector2((p1_prime.x - c_prime.x) / rx, (p1_prime.y - c_prime.y) / ry)
	var v2 = Vector2((-p1_prime.x - c_prime.x) / rx, (-p1_prime.y - c_prime.y) / ry)
	var start_angle = Vector2.RIGHT.angle_to(v1)
	var delta_angle = v1.angle_to(v2)

	if not fS and delta_angle > 0: delta_angle -= TAU
	elif fS and delta_angle < 0: delta_angle += TAU

	var num_segments = clamp(ceil(abs(delta_angle) / deg_to_rad(5.0)), 4, 64)
	var points := PackedVector2Array()

	for i in range(1, int(num_segments) + 1):
		var t = float(i) / float(num_segments)
		var angle = start_angle + delta_angle * t
		var ellipse_point = Vector2(rx * cos(angle), ry * sin(angle))
		var final_point = Vector2(
			cos_phi * ellipse_point.x - sin_phi * ellipse_point.y + center.x,
			sin_phi * ellipse_point.x + cos_phi * ellipse_point.y + center.y
		)
		points.append(final_point)
	return points
