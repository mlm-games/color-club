# Extension to SVGPath for advanced features
extends SVGPath

# Marker support for paths
var marker_start: String = ""
var marker_mid: String = ""
var marker_end: String = ""

# Dash array for stroke
var stroke_dasharray: Array[float] = []
var stroke_dashoffset: float = 0.0

# Path effects
var path_length: float = -1.0  # -1 means auto-calculate

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
	
	# Draw stroke with dash support
	if stroke_width > 0 and stroke_color.a > 0:
		for subpath in _subpaths:
			if subpath.size() > 1:
				if stroke_dasharray.is_empty():
					# Regular stroke
					var adjusted_points = PackedVector2Array()
					for point in subpath:
						adjusted_points.append(point + offset)
					draw_polyline(adjusted_points, stroke_color, stroke_width, true)
				else:
					# Dashed stroke
					_draw_dashed_polyline(subpath, offset, stroke_color, stroke_width, 
										 stroke_dasharray, stroke_dashoffset)

func _draw_dashed_polyline(points: PackedVector2Array, offset: Vector2, color: Color, 
						  width: float, dash_array: Array[float], dash_offset: float) -> void:
	if points.size() < 2 or dash_array.is_empty():
		return
	
	var total_length = 0.0
	var segments = []
	
	# Calculate segment lengths
	for i in range(points.size() - 1):
		var length = points[i].distance_to(points[i + 1])
		segments.append({
			"start": points[i],
			"end": points[i + 1],
			"length": length
		})
		total_length += length
	
	# Draw dashed segments
	var current_offset = fmod(dash_offset, _get_dash_pattern_length(dash_array))
	var dash_index = 0
	var is_gap = false
	
	for segment in segments:
		var segment_start = 0.0
		var segment_length = segment.length
		
		while segment_start < segment_length:
			var dash_length = dash_array[dash_index % dash_array.size()]
			var remaining_in_segment = segment_length - segment_start
			var dash_end = min(segment_start + dash_length - current_offset, segment_length)
			
			if dash_end > segment_start and not is_gap:
				# Draw this dash
				var t1 = segment_start / segment_length
				var t2 = dash_end / segment_length
				var p1 = segment.start.lerp(segment.end, t1) + offset
				var p2 = segment.start.lerp(segment.end, t2) + offset
				draw_line(p1, p2, color, width, true)
			
			segment_start = dash_end
			current_offset = 0.0
			
			if dash_end >= segment_start + dash_length - current_offset:
				dash_index += 1
				is_gap = not is_gap

func _get_dash_pattern_length(dash_array: Array[float]) -> float:
	var total = 0.0
	for dash in dash_array:
		total += dash
	return total

# Calculate actual path length
func calculate_path_length() -> float:
	var total_length = 0.0
	
	for subpath in _subpaths:
		for i in range(subpath.size() - 1):
			total_length += subpath[i].distance_to(subpath[i + 1])
	
	return total_length

# Get point at specific length along path
func get_point_at_length(length: float) -> Vector2:
	if _subpaths.is_empty():
		return Vector2.ZERO
	
	var current_length = 0.0
	
	for subpath in _subpaths:
		for i in range(subpath.size() - 1):
			var segment_length = subpath[i].distance_to(subpath[i + 1])
			
			if current_length + segment_length >= length:
				var t = (length - current_length) / segment_length
				return subpath[i].lerp(subpath[i + 1], t)
			
			current_length += segment_length
	
	# Return last point if length exceeds path
	return _subpaths[-1][-1]

# Get tangent at specific length along path
func get_tangent_at_length(length: float) -> Vector2:
	if _subpaths.is_empty():
		return Vector2.RIGHT
	
	var current_length = 0.0
	
	for subpath in _subpaths:
		for i in range(subpath.size() - 1):
			var segment_length = subpath[i].distance_to(subpath[i + 1])
			
			if current_length + segment_length >= length:
				return (subpath[i + 1] - subpath[i]).normalized()
			
			current_length += segment_length
	
	# Return last tangent if length exceeds path
	if _subpaths[-1].size() >= 2:
		return (_subpaths[-1][-1] - _subpaths[-1][-2]).normalized()
	
	return Vector2.RIGHT

# Extended attribute parsing
func set_path_properties_extended(attributes: Dictionary) -> void:
	set_path_properties(attributes)
	
	# Parse stroke dash array
	if "stroke-dasharray" in attributes:
		stroke_dasharray = _parse_dash_array(attributes["stroke-dasharray"])
	
	if "stroke-dashoffset" in attributes:
		stroke_dashoffset = float(attributes["stroke-dashoffset"])
	
	# Parse markers
	if "marker-start" in attributes:
		marker_start = attributes["marker-start"]
	if "marker-mid" in attributes:
		marker_mid = attributes["marker-mid"]
	if "marker-end" in attributes:
		marker_end = attributes["marker-end"]
	
	if "pathLength" in attributes:
		path_length = float(attributes["pathLength"])

func _parse_dash_array(dash_string: String) -> Array[float]:
	var result: Array[float] = []
	var parts = dash_string.split(",")
	
	for part in parts:
		part = part.strip_edges()
		if part.is_valid_float():
			result.append(float(part))
	
	# If odd number of values, repeat the pattern
	if result.size() % 2 == 1:
		var original_size = result.size()
		for i in range(original_size):
			result.append(result[i])
	
	return result
