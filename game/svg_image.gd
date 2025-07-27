@tool
class_name SVGImage
extends Control

static var I

func _init() -> void:
	if Engine.is_editor_hint():
		return
	
	I = self

var svg_root: Node2D
var color_registry: Dictionary = {} # Color -> Array[ColorableShape]

signal svg_loaded(colors: Dictionary)

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	load_svg_from_content(GameManager.I.current_level.cached_svg_content)

func load_svg_from_content(svg_content: String) -> bool:
	_clear_svg_content()
	
	var temp_path = "user://temp_svg_" + str(Time.get_unix_time_from_system()) + ".svg"
	var file = FileAccess.open(temp_path, FileAccess.WRITE)
	if not file:
		GameManager.log_error("Failed to create temp file", "SVGImage")
		printerr(FileAccess.get_open_error())
		return false
	
	file.store_string(svg_content)
	file.close()
	
	var success = load_svg(temp_path)
	
	DirAccess.remove_absolute(temp_path)
	
	return success

func load_svg(file_path: String) -> bool:
	_clear_svg_content()
	
	svg_root = SVGImporter.import_as_nodes(file_path)
	if not is_instance_valid(svg_root):
		GameManager.log_error("SVG Importer failed for: " + file_path, "SVGImage")
		return false
	
	add_child(svg_root)
	
	_prepare_nodes_for_game()
	
	_finalize_svg_layout()
	svg_loaded.emit(color_registry)
	return true

func get_svg_root() -> Node2D:
	return svg_root

func _clear_svg_content() -> void:
	if is_instance_valid(svg_root):
		svg_root.queue_free()
		svg_root = null
	color_registry.clear()

func _prepare_nodes_for_game() -> void:
	color_registry.clear()
	if not is_instance_valid(svg_root): return
	
	var all_polygons = A.find_nodes_by_type(svg_root, ["Polygon2D"])
	var hidden_shapes: Array[Node] = []
	var invalid_shapes: Array[Node] = []
	
	# Minimum area threshold (adjust as needed)
	var min_area_threshold = SettingsManager.get_setting("gameplay", "min_shape_area_in_px", 50.0)
	var min_dimension_threshold = SettingsManager.get_setting("gameplay", "min_shape_dimension_in_px", 5.0)
	
	# First, filter out invalid shapes
	for shape in all_polygons:
		if not shape.visible or shape.polygon.size() < 3:
			continue
			
		# Check if shape is too thin or small
		if _is_shape_too_thin(shape, min_area_threshold, min_dimension_threshold):
			invalid_shapes.append(shape)
			shape.modulate.a = 0.3 # Make it semi-transparent to indicate it's not colorable
			continue
	
	# Then check for hidden shapes
	if SettingsManager.get_setting("gameplay", "ignore_background_parts_hack"):
		for i in range(all_polygons.size()):
			var shape_to_check: Polygon2D = all_polygons[i]
			if not shape_to_check.visible or shape_to_check.polygon.size() < 3 or shape_to_check in invalid_shapes:
				continue
	
			for j in range(i + 1, all_polygons.size()):
				var occluder_shape = all_polygons[j]
				if not occluder_shape.visible or occluder_shape.polygon.size() < 3 or occluder_shape in invalid_shapes:
					continue
	
				var point_in_occluder_space = occluder_shape.to_local(shape_to_check.global_position)
				
				if Geometry2D.is_point_in_polygon(point_in_occluder_space, occluder_shape.polygon):
					hidden_shapes.append(shape_to_check)
					break
		
		GameManager.log_info("Found and ignored %d hidden shapes." % hidden_shapes.size(), "SVGImage")
	
	GameManager.log_info("Found and ignored %d invalid/thin shapes." % invalid_shapes.size(), "SVGImage")
	
	# Process all shapes
	var shapes = A.find_nodes_by_type(svg_root, ["Polygon2D", "Line2D"])
	
	for shape in shapes:
		# Skip hidden or invalid shapes
		if shape in hidden_shapes:
			shape.visible = false
			continue
		
		if shape in invalid_shapes:
			continue
			
		# Skip strokes if not coloring them
		if shape is Line2D and not SettingsManager.get_setting("gameplay", "color_strokes"):
			if SettingsManager.get_setting("gameplay", "auto_color_strokes"):
				shape.default_color = SettingsManager.get_setting("gameplay", "stroke_color")
			continue
			
		# Additional validation for Line2D
		if shape is Line2D and _is_line_too_thin(shape, min_dimension_threshold):
			shape.modulate.a = 0.3
			continue
		
		var colorable_script = ColorableShape.new()
		shape.add_child(colorable_script)
		
		var original_color: Color
		if shape is Polygon2D:
			original_color = shape.color
		elif shape is Line2D:
			original_color = shape.default_color
	
		colorable_script.set_original_color(original_color)
			
		# Only add non-white, non-transparent colors that need to be colored in.
		if original_color.a > 0.1 and original_color.get_luminance() < 0.99:
			if not color_registry.has(original_color):
				color_registry[original_color] = []
			color_registry[original_color].append(colorable_script)

func _is_shape_too_thin(shape: Polygon2D, min_area: float, min_dimension: float) -> bool:
	var polygon = shape.polygon
	if polygon.size() < 3:
		return true
	
	# Calculate area using shoelace formula
	var area = 0.0
	for i in range(polygon.size()):
		var j = (i + 1) % polygon.size()
		area += polygon[i].x * polygon[j].y
		area -= polygon[j].x * polygon[i].y
	area = abs(area) / 2.0
	
	if area < min_area:
		return true
	
	# Calculate bounding box
	var min_point = polygon[0]
	var max_point = polygon[0]
	for point in polygon:
		min_point.x = min(min_point.x, point.x)
		min_point.y = min(min_point.y, point.y)
		max_point.x = max(max_point.x, point.x)
		max_point.y = max(max_point.y, point.y)
	
	var width = max_point.x - min_point.x
	var height = max_point.y - min_point.y
	
	if width < min_dimension or height < min_dimension:
		return true
	
	var aspect_ratio = max(width / height, height / width)
	if aspect_ratio > 20.0: # Shape is 20x longer in one dimension
		return true
	
	# Calculate the "thinness" of the shape
	# by comparing area to perimeter squared
	var perimeter = 0.0
	for i in range(polygon.size()):
		var j = (i + 1) % polygon.size()
		perimeter += polygon[i].distance_to(polygon[j])
	
	# Isoperimetric quotient (circle = 1, thin shapes approach 0)
	var thinness = (4.0 * PI * area) / (perimeter * perimeter)
	if thinness < 0.01: # Very thin shape
		return true
	
	return false

func _is_line_too_thin(line: Line2D, min_width: float) -> bool:
	if line.width < min_width:
		return true
	
	if line.points.size() < 2:
		return true
		
	var total_length = 0.0
	for i in range(line.points.size() - 1):
		total_length += line.points[i].distance_to(line.points[i + 1])
	
	if total_length < min_width * 2: # Line is too short relative to its width
		return true
	
	return false

func _finalize_svg_layout() -> void:
	if not is_instance_valid(svg_root): return
	
	# Calculate the bounding box of all visible shapes
	var bounds: Rect2
	var first = true
	var shapes = A.find_nodes_by_type(svg_root, ["Polygon2D", "Line2D"])
	
	for shape in shapes:
		if shape is CanvasItem and shape.visible:
			var shape_bounds: Rect2
			
			if shape is Polygon2D and shape.polygon.size() > 0:
				# Calculate bounds from polygon points
				var min_point = shape.polygon[0]
				var max_point = shape.polygon[0]
				for point in shape.polygon:
					min_point.x = min(min_point.x, point.x)
					min_point.y = min(min_point.y, point.y)
					max_point.x = max(max_point.x, point.x)
					max_point.y = max(max_point.y, point.y)
				shape_bounds = Rect2(min_point, max_point - min_point)
			elif shape is Line2D and shape.points.size() > 0:
				# Calculate bounds from line points
				var min_point = shape.points[0]
				var max_point = shape.points[0]
				for point in shape.points:
					min_point.x = min(min_point.x, point.x)
					min_point.y = min(min_point.y, point.y)
					max_point.x = max(max_point.x, point.x)
					max_point.y = max(max_point.y, point.y)
				# Add line width to bounds
				var half_width = shape.width / 2.0
				min_point -= Vector2(half_width, half_width)
				max_point += Vector2(half_width, half_width)
				shape_bounds = Rect2(min_point, max_point - min_point)
			else:
				continue
			
			# Transform the bounds to svg_root space
			var transform_to_root = svg_root.transform.affine_inverse() * shape.get_global_transform()
			shape_bounds = transform_to_root * shape_bounds
			
			if first:
				bounds = shape_bounds
				first = false
			else:
				bounds = bounds.merge(shape_bounds)
				
	if first or bounds.size.x <= 0 or bounds.size.y <= 0:
		GameManager.log_warning("Could not determine SVG bounds. Layout may be incorrect.", "SVGImage")
		bounds = Rect2(0, 0, 512, 512) # Fallback size
		
	var panel_size = get_rect().size
	var scale_factor = min(
		panel_size.x / bounds.size.x,
		panel_size.y / bounds.size.y
	) * 0.6 # 40% margin

	svg_root.scale = Vector2(scale_factor, scale_factor)
	var scaled_size = bounds.size * scale_factor
	svg_root.position = (panel_size - scaled_size) / 2.0 - bounds.position * scale_factor
