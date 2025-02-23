# Specific shape implementations
class_name SVGCircleElement
extends SVGShapeElement

var center_x: float = 0.0
var center_y: float = 0.0
var radius: float = 0.0

func _init(attributes: Dictionary):
	super._init(attributes)
	element_name = "Circle"
	center_x = float(attributes.get("cx", "0"))
	center_y = float(attributes.get("cy", "0"))
	radius = float(attributes.get("r", "0"))

func calculate_local_bounds(include_stroke: bool = false) -> Rect2:
	var bounds = Rect2(center_x - radius, center_y - radius, radius * 2, radius * 2)
	if include_stroke and has_stroke():
		bounds = bounds.grow(stroke_width / 2)
	return bounds
