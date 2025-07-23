#@tool
# Main entry point for converting an SVG file into a Godot Node2D scene. To use as autoload
#class_name SVGImporter
extends Node

const PathParser = preload("svg_path_parser.gd")
const Utils = preload("svg_parser_utils.gd")

# Public API
# Takes an SVG file path and returns a root Node2D containing the converted scene.
func import_as_nodes(file_path: String) -> Node2D:
	var parser := XMLParser.new()
	if parser.open(file_path) != OK:
		printerr("SVGImporter Error: Failed to open SVG file: " + file_path)
		return null
	
	var svg_root: Node2D = null
	var node_stack: Array[Node2D] = []
	var style_stack: Array[Dictionary] = [{}] # For inherited styles

	while parser.read() != ERR_FILE_EOF:
		match parser.get_node_type():
			XMLParser.NODE_ELEMENT:
				var tag = parser.get_node_name()
				var attributes = _get_attributes(parser)
				
				# Inherit style from parent and merge with current element's style
				var inherited_style = style_stack.back().duplicate(true)
				var element_style = Utils.extract_styles_from_attributes(attributes)
				inherited_style.merge(element_style, true)
				
				if tag == "svg":
					if svg_root == null: # Only process the root SVG tag
						svg_root = Node2D.new()
						svg_root.name = file_path.get_file().get_basename()
						node_stack.push_back(svg_root)
						style_stack.push_back(inherited_style)
						Utils.apply_svg_root_properties(svg_root, attributes)
				
				elif tag == "g":
					var group = Node2D.new()
					group.name = attributes.get("id", "Group")
					group.transform = Utils.parse_transform(attributes.get("transform", ""))
					
					node_stack.back().add_child(group)
					node_stack.push_back(group)
					style_stack.push_back(inherited_style)
				
				else:
					var element_node = _create_element_node(tag, attributes, inherited_style)
					if is_instance_valid(element_node):
						node_stack.back().add_child(element_node)

			XMLParser.NODE_ELEMENT_END:
				var tag = parser.get_node_name()
				if tag == "svg" or tag == "g":
					if node_stack.size() > 1:
						node_stack.pop_back()
						style_stack.pop_back()
	
	if not is_instance_valid(svg_root):
		printerr("SVGImporter Error: No valid <svg> tag found in file: " + file_path)

	return svg_root

static func _get_attributes(parser: XMLParser) -> Dictionary:
	var attr = {}
	for i in range(parser.get_attribute_count()):
		attr[parser.get_attribute_name(i)] = parser.get_attribute_value(i)
	return attr

static func _create_element_node(tag: String, attributes: Dictionary, style: Dictionary) -> Node2D:
	var points: PackedVector2Array
	var is_closed := false
	
	match tag:
		"rect":
			points = Utils.rect_to_points(attributes)
			is_closed = true
		"circle":
			points = Utils.circle_to_points(attributes)
			is_closed = true
		"ellipse":
			points = Utils.ellipse_to_points(attributes)
			is_closed = true
		"polygon":
			points = Utils.points_string_to_array(attributes.get("points", ""))
			is_closed = true
		"polyline":
			points = Utils.points_string_to_array(attributes.get("points", ""))
		"line":
			points = Utils.line_to_points(attributes)
		"path":
			var path_data = attributes.get("d", "")
			if path_data.is_empty(): return null
			var result = PathParser.parse(path_data)
			points = result.points
			is_closed = result.is_closed
		_:
			return null

	if points.is_empty():
		return null
	
	# Container node to hold the fill and stroke
	var node = Node2D.new()
	node.name = attributes.get("id", tag.capitalize())
	
	var fill_color = Utils.get_style_property(style, "fill")
	var stroke_color = Utils.get_style_property(style, "stroke")
	var stroke_width = Utils.get_style_property(style, "stroke-width")

	# Create Fill Node (Polygon2D)
	if fill_color.a > 0.01:
		var fill_node = Polygon2D.new()
		fill_node.name = "Fill"
		fill_node.polygon = points
		fill_node.color = fill_color
		node.add_child(fill_node)

	# Create Stroke Node (Line2D)
	if stroke_color.a > 0.01 and stroke_width > 0:
		var stroke_node = Line2D.new()
		stroke_node.name = "Stroke"
		stroke_node.points = points
		stroke_node.closed = is_closed
		stroke_node.default_color = stroke_color
		stroke_node.width = stroke_width
		node.add_child(stroke_node)
	
	node.transform = Utils.parse_transform(attributes.get("transform", ""))
	
	return node
