@tool
class_name SVGPath
extends SVGElement

var path_data: String = "":
	set(value):
		path_data = value
		_parse_path_data()
		_update_size()
		queue_redraw()

var _path_points: PackedVector2Array = PackedVector2Array()
var _path_bounds: Rect2 = Rect2()

func _calculate_content_bounds() -> Rect2:
	return _path_bounds

func _draw_content() -> void:
	if _path_points.size() < 2:
		return
	
	var offset = Vector2(stroke_width, stroke_width) - _path_bounds.position
	var adjusted_points = PackedVector2Array()
	for point in _path_points:
		adjusted_points.append(point + offset)
	
	# Draw fill
	if fill_color.a > 0 and adjusted_points.size() > 2:
		draw_colored_polygon(adjusted_points, fill_color)
	
	# Draw stroke
	if stroke_width > 0 and stroke_color.a > 0:
		draw_polyline(adjusted_points, stroke_color, stroke_width, true)

func _parse_path_data() -> void:
	if path_data.is_empty():
		_path_points.clear()
		_path_bounds = Rect2()
		return
	
	# Simplified path parsing - only handles basic commands
	_path_points.clear()
	var current_pos = Vector2.ZERO
	var tokens = _tokenize_path(path_data)
	var i = 0
	
	while i < tokens.size():
		var command = tokens[i]
		i += 1
		
		match command.to_upper():
			"M":  # Move to
				if i + 1 < tokens.size():
					current_pos = Vector2(float(tokens[i]), float(tokens[i + 1]))
					_path_points.append(current_pos)
					i += 2
			"L":  # Line to
				if i + 1 < tokens.size():
					current_pos = Vector2(float(tokens[i]), float(tokens[i + 1]))
					_path_points.append(current_pos)
					i += 2
			"H":  # Horizontal line
				if i < tokens.size():
					current_pos.x = float(tokens[i])
					_path_points.append(current_pos)
					i += 1
			"V":  # Vertical line
				if i < tokens.size():
					current_pos.y = float(tokens[i])
					_path_points.append(current_pos)
					i += 1
			"Z", "z":  # Close path
				if _path_points.size() > 0:
					_path_points.append(_path_points[0])
			_:
				push_warning("Path command not implemented: " + command)
				break
	
	_calculate_path_bounds()

func _tokenize_path(data: String) -> Array[String]:
	# Simple tokenizer - splits on spaces and commas
	var tokens: Array[String] = []
	var current_token = ""
	
	for chr in data:
		if chr in " ,\t\n\r":
			if not current_token.is_empty():
				tokens.append(current_token)
				current_token = ""
		elif chr in "MmLlHhVvCcSsQqTtAaZz":
			if not current_token.is_empty():
				tokens.append(current_token)
			tokens.append(chr)
			current_token = ""
		else:
			current_token += chr
	
	if not current_token.is_empty():
		tokens.append(current_token)
	
	return tokens

func _calculate_path_bounds() -> void:
	if _path_points.is_empty():
		_path_bounds = Rect2()
		return
	
	var min_point = _path_points[0]
	var max_point = _path_points[0]
	
	for point in _path_points:
		min_point.x = min(min_point.x, point.x)
		min_point.y = min(min_point.y, point.y)
		max_point.x = max(max_point.x, point.x)
		max_point.y = max(max_point.y, point.y)
	
	_path_bounds = Rect2(min_point, max_point - min_point)

func set_path_properties(attributes: Dictionary) -> void:
	if "d" in attributes:
		path_data = attributes["d"]
	
	set_common_attributes(attributes)
