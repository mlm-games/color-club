@tool
class_name SVGImage
extends Control

var svg_root: Node2D
var color_registry: Dictionary = {} # Color -> Array[ColorableShape]

signal svg_loaded(colors: Dictionary)

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	var svg_path = GameManager.I.current_svg_path
	if svg_path.is_empty():
		GameManager.log_error("No SVG path was provided to SVGImage.", "SVGImage")
		return
	
	load_svg(svg_path)
	

func load_svg(file_path: String) -> bool:
	_clear_svg_content()
	
	# 1. Import SVG into a raw node tree using the addon
	svg_root = SVGImporter.import_as_nodes(file_path)
	if not is_instance_valid(svg_root):
		GameManager.log_error("SVG Importer failed for: " + file_path, "SVGImage")
		return false
	
	add_child(svg_root)
	
	# 2. Wait for nodes to be ready, then prepare them for the game
	await get_tree().process_frame
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
	
	var shapes = A.find_nodes_by_type(svg_root, ["Polygon2D", "Line2D"])
	
	for shape in shapes:
		if shape is Line2D and not SettingsManager.I.color_strokes:
			# Auto-color the stroke if enabled
			if SettingsManager.I.auto_color_strokes:
				shape.default_color = SettingsManager.I.stroke_color
			continue
		# Attach the interactive component script
		var colorable_script = ColorableShape.new()
		shape.add_child(colorable_script)
		
		# Get the shape's original color from the importer
		var original_color: Color
		if shape is Polygon2D:
			original_color = shape.color
		elif shape is Line2D:
			original_color = shape.default_color
	
		colorable_script.set_original_color(original_color)
			
		# Register the shape in the color registry for the HUD palette
		# Only add non-white, non-transparent colors that need to be colored in.
		if original_color.a > 0.1 and original_color.get_luminance() < 0.99:
			if not color_registry.has(original_color):
				color_registry[original_color] = []
			color_registry[original_color].append(colorable_script)

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
