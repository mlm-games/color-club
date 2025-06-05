@tool
class_name SVGGroup
extends Control

var svg_transform: Transform2D = Transform2D.IDENTITY
var has_transform: bool = false
var svg_id: String = ""

# Group-specific transform accumulation
var accumulated_transform: Transform2D = Transform2D.IDENTITY

func _ready() -> void:
	# Groups pass through mouse events to children
	mouse_filter = Control.MOUSE_FILTER_PASS

func apply_group_transform() -> void:
	if not has_transform:
		return
	
	# For groups, we need to handle transform accumulation differently
	# Groups affect all their children
	position = svg_transform.origin
	rotation = svg_transform.get_rotation()
	scale = svg_transform.get_scale()
	
	# Set pivot to origin for SVG-compliant transforms
	pivot_offset = Vector2.ZERO

func set_group_attributes(attributes: Dictionary) -> void:
	if "id" in attributes:
		svg_id = attributes["id"]
		name = svg_id
	
	if "transform" in attributes:
		has_transform = true
		svg_transform = SVGUtils.parse_transform(attributes["transform"])
		apply_group_transform()
	
	if "opacity" in attributes:
		modulate.a = float(attributes["opacity"])
	
	if "style" in attributes:
		_apply_style_string(attributes["style"])

func _apply_style_string(style_string: String) -> void:
	var styles = SVGUtils.parse_style_string(style_string)
	for property in styles:
		match property:
			"opacity":
				modulate.a = float(styles[property])
			"display":
				if styles[property] == "none":
					visible = false

# Pass accumulated transform to children
func get_accumulated_transform() -> Transform2D:
	if has_transform:
		return accumulated_transform * svg_transform
	return accumulated_transform

func set_accumulated_transform(parent_transform: Transform2D) -> void:
	accumulated_transform = parent_transform
	if has_transform:
		accumulated_transform = accumulated_transform * svg_transform
