# Base class for all SVG shape elements
class_name SVGShapeElement
extends RefCounted

# Hierarchy properties
var parent_element: SVGShapeElement = null
var child_elements: Array[SVGShapeElement] = []
var layers: Array = []  # For layer references
var nodes: Array = []   # For node references

# Basic properties
var element_name: String = "Shape"
var is_visible: bool = true
var sort_order: float = 0.0

# Styling properties
var fill_color: Color = Color.TRANSPARENT:
	set(value):
		fill_color = value
		invalidate_render_cache()
var stroke_color: Color = Color.TRANSPARENT:
	set(value):
		stroke_color = value
		invalidate_render_cache()
var stroke_width: float = 0.0:
	set(value):
		stroke_width = value
		invalidate_render_cache()

enum LineCapStyle { NONE, SQUARE, ROUND }
enum LineJoinStyle { MITER, ROUND, BEVEL }

var stroke_line_cap: LineCapStyle = LineCapStyle.NONE:
	set(value):
		stroke_line_cap = value
		invalidate_render_cache()
var stroke_line_join: LineJoinStyle = LineJoinStyle.MITER:
	set(value):
		stroke_line_join = value
		invalidate_render_cache()

# Transformation properties
var position_x: float = 0.0
var position_y: float = 0.0
var pivot_offset_x: float = 0.0
var pivot_offset_y: float = 0.0
var has_initial_transform: bool = false
var initial_transform: Transform2D = Transform2D.IDENTITY:
	set(value):
		initial_transform = value
		has_initial_transform = (value != Transform2D.IDENTITY)
		invalidate_transform_cache()

var transform_steps: Array[TransformStep] = []
