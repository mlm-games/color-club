class_name TransformStep
extends RefCounted
enum TransformType { TRANSLATE, ROTATE, SCALE, SET_PIVOT }
var type: TransformType
var x: float
var y: float

func _init(_type: TransformType, _x: float = 0.0, _y: float = 0.0):
	type = _type
	x = _x
	y = _y

# Render cache
var needs_recalculate_bounds: bool = true
var cached_global_bounds: Rect2
var cached_local_bounds: Rect2

# Initialization
func _init(attributes: Dictionary = {}):
	parse_attributes(attributes)

# Hierarchy management
func add_child_element(child: SVGShapeElement) -> void:
	if child and child != self:
		child_elements.append(child)
		child.parent_element = self
		child.invalidate_transform_cache()

func remove_child_element(child: SVGShapeElement) -> void:
	child_elements.erase(child)
	child.parent_element = null
	child.invalidate_transform_cache()

# Styling methods
func has_fill() -> bool:
	return fill_color.a > 0.0

func has_stroke() -> bool:
	return stroke_width > 0.0 and stroke_color.a > 0.0

func adjust_fill_color_hsv(hue_offset: float, saturation_offset: float, value_offset: float) -> void:
	if hue_offset != 0.0 or saturation_offset != 0.0 or value_offset != 0.0:
		var hsv = fill_color.to_hsv()
		var new_h = fmod(hsv.x + hue_offset, 1.0)
		var new_s = clamp(hsv.y + saturation_offset, 0.0, 1.0)
		var new_v = clamp(hsv.z + value_offset, 0.0, 1.0)
		fill_color = Color.from_hsv(new_h, new_s, new_v, fill_color.a)
		invalidate_render_cache()

func adjust_stroke_width(delta: float) -> void:
	stroke_width = max(0.0, stroke_width + delta)
	invalidate_render_cache()

# Transformation methods
func translate(x: float, y: float) -> void:
	transform_steps.append(TransformStep.new(TransformStep.TransformType.TRANSLATE, x, y))
	invalidate_transform_cache()

func rotate(angle_degrees: float) -> void:
	transform_steps.append(TransformStep.new(TransformStep.TransformType.ROTATE, 
		deg_to_rad(angle_degrees)))
	invalidate_transform_cache()

func scale(scale_x: float, scale_y: float) -> void:
	transform_steps.append(TransformStep.new(TransformStep.TransformType.SCALE, scale_x, scale_y))
	invalidate_transform_cache()

func set_pivot(x: float, y: float) -> void:
	transform_steps.append(TransformStep.new(TransformStep.TransformType.SET_PIVOT, x, y))
	pivot_offset_x = x
	pivot_offset_y = y
	invalidate_transform_cache()

func apply_transform(base_transform: Transform2D = Transform2D.IDENTITY) -> Transform2D:
	var transform = base_transform
	if has_initial_transform:
		transform = initial_transform * transform

	var pivot = Vector2.ZERO
	for step in transform_steps:
		match step.type:
			TransformStep.TransformType.TRANSLATE:
				transform = transform.translated(Vector2(step.x, step.y))
			TransformStep.TransformType.ROTATE:
				transform = transform.rotated(step.x)
			TransformStep.TransformType.SCALE:
				transform = transform.scaled(Vector2(step.x, step.y))
			TransformStep.TransformType.SET_PIVOT:
				if pivot != Vector2.ZERO:
					transform = transform.translated(pivot)
				pivot = Vector2(step.x, step.y)
				transform = transform.translated(-pivot)
	
	if pivot != Vector2.ZERO:
		transform = transform.translated(pivot)
	
	transform = transform.translated(Vector2(position_x, position_y))
	return transform

func get_local_transform() -> Transform2D:
	return apply_transform(Transform2D.IDENTITY)

func get_global_transform() -> Transform2D:
	var transform = get_local_transform()
	if parent_element:
		transform = parent_element.get_global_transform() * transform
	return transform

# Virtual methods for subclasses
func calculate_local_bounds(include_stroke: bool = false) -> Rect2:
	push_warning("calculate_local_bounds must be implemented in subclass")
	return Rect2()

func calculate_global_bounds(include_stroke: bool = false) -> Rect2:
	if needs_recalculate_bounds or not cached_global_bounds:
		var local_bounds = calculate_local_bounds(include_stroke)
		var transform = get_global_transform()
		var points = [
			transform * Vector2(local_bounds.position),
			transform * Vector2(local_bounds.position.x + local_bounds.size.x, local_bounds.position.y),
			transform * Vector2(local_bounds.position.x, local_bounds.position.y + local_bounds.size.y),
			transform * Vector2(local_bounds.position.x + local_bounds.size.x, local_bounds.position.y + local_bounds.size.y)
		]
		cached_global_bounds = Rect2(points[0], Vector2.ZERO)
		for point in points:
			cached_global_bounds = cached_global_bounds.expand(point)
		needs_recalculate_bounds = false
	return cached_global_bounds

func hit_test(point: Vector2) -> bool:
	var global_bounds = calculate_global_bounds(true)
	return global_bounds.has_point(point)

func parse_attributes(attributes: Dictionary) -> void:
	fill_color = parse_color(attributes.get("fill", "#FFFFFF"))
	if attributes.has("style"):
		var style = parse_style(attributes["style"])
		if style.has("stroke"):
			stroke_color = parse_color(style["stroke"])
			stroke_width = float(style.get("stroke-width", "1.0"))
			# Parse line caps and joins if needed

func invalidate_transform_cache() -> void:
	needs_recalculate_bounds = true
	for child in child_elements:
		child.invalidate_transform_cache()

func invalidate_render_cache() -> void:
	# Implement render cache invalidation if needed
	pass
