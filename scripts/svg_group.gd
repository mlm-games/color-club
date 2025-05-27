@tool
class_name SVGGroup
extends Control

var svg_transform: Transform2D = Transform2D.IDENTITY:
	set(value):
		svg_transform = value
		_apply_transform()

var svg_id: String = ""

func _ready() -> void:
	# Groups are transparent containers
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _apply_transform() -> void:
	# Apply transform using Control properties
	if svg_transform != Transform2D.IDENTITY:
		var transform_origin = svg_transform.origin
		var transform_rotation = svg_transform.get_rotation()
		var transform_scale = svg_transform.get_scale()
		
		# Apply to Control properties
		position += transform_origin
		rotation = transform_rotation
		scale = transform_scale
		
		# Set pivot to center for proper rotation
		pivot_offset = size * 0.5

func set_group_attributes(attributes: Dictionary) -> void:
	if "id" in attributes:
		svg_id = attributes["id"]
		name = svg_id
	
	if "transform" in attributes:
		svg_transform = SVGUtils.parse_transform(attributes["transform"])
	
	# Groups can have opacity
	if "opacity" in attributes:
		modulate.a = float(attributes["opacity"])
	
	# Groups can have style
	if "style" in attributes:
		_apply_style_string(attributes["style"])

func _apply_style_string(style_string: String) -> void:
	var styles = SVGUtils.parse_style_string(style_string)
	for property in styles:
		match property:
			"opacity":
				modulate.a = float(styles[property])
			_:
				push_warning("Unimplemented group style property: " + property)
