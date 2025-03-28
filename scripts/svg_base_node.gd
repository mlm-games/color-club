@tool
class_name SVGElement extends Control

# Common SVG properties
@export var fill_color: Color = Color.WHITE:
	set(value):
		fill_color = value
		queue_redraw()

@export var stroke_color: Color = Color.BLACK:
	set(value):
		stroke_color = value
		queue_redraw()

@export var stroke_width: float = 0.0:
	set(value):
		stroke_width = value
		_update_control_size()
		queue_redraw()

@export var opacity: float = 1.0:
	set(value):
		opacity = value
		modulate.a = value

var highlighted: bool = false:
	set(value):
		highlighted = value
		queue_redraw()

# Bounds tracking
var _bounds_min: Vector2 = Vector2(INF, INF)
var _bounds_max: Vector2 = Vector2(-INF, -INF)
var _shape_points: PackedVector2Array = []

# Animation properties
@onready var original_scale: Vector2 = scale
var hover_scale: Vector2 = Vector2(1.05, 1.05)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)
	_update_control_size()

func _update_bounds(point: Vector2) -> void:
	_bounds_min.x = min(_bounds_min.x, point.x)
	_bounds_min.y = min(_bounds_min.y, point.y)
	_bounds_max.x = max(_bounds_max.x, point.x)
	_bounds_max.y = max(_bounds_max.y, point.y)
	
func _update_control_size() -> void:
	# To be implemented by child classes
	pass

func _is_point_in_shape(point: Vector2) -> bool:
	# Default implementation - override in subclasses for specific shapes
	if _shape_points.size() > 2:
		return Geometry2D.is_point_in_polygon(point, _shape_points)
	return false

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _is_point_in_shape(get_local_mouse_position()):
			# Click animation
			var click_tween: Tween = create_tween().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT).set_ignore_time_scale()
			click_tween.tween_property(self, "scale", original_scale * 0.95, 0.1)
			click_tween.tween_property(self, "scale", hover_scale, 0.1)
			click_tween.tween_property(self, "scale", original_scale, 0.1)
			
			# Handle highlighting logic
			if highlighted:
				fill_color = HUD.selected_color
				highlighted = false
				HUD.colors_for_image[HUD.selected_color].erase(self)
				HUD.remove_color_and_its_button_if_empty()
			
			get_viewport().set_input_as_handled()

# Method to parse common SVG attributes
func set_common_attributes(attributes: Dictionary) -> void:
	if "fill" in attributes:
		fill_color = Color.html(attributes["fill"])
	if "stroke" in attributes:
		stroke_color = Color.html(attributes["stroke"])
	if "stroke-width" in attributes:
		stroke_width = float(attributes["stroke-width"])
	if "opacity" in attributes:
		opacity = float(attributes["opacity"])
	if "id" in attributes:
		name = attributes["id"]
	if "style" in attributes:
		SVGUtils.apply_css_styles_for_shape(SVGUtils.analyse_style(attributes["style"]), self)

#func _notification(what: int) -> void:
	#if what == NOTIFICATION_RESIZED:
		#_update_control_size()
