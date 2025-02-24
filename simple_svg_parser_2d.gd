@tool
class_name SimpleSVGParser extends EditorScript

var file_path = "res://assets/art/test1.svg"
var xml_data = XMLParser.new()
var root_node: Node
var current_node: Node

func _run() -> void:
	if xml_data.open(file_path) != OK:
		print("Error opening file: ", file_path)
		return
	root_node = self.get_scene()
	current_node = root_node
	
	# Clear existing nodes
	for c in root_node.get_children():
		c.queue_free()
	
	parse_svg()

func parse_svg() -> void:
	print("Starting SVG parse...")
	
	while xml_data.read() == OK:
		if not xml_data.get_node_type() in [XMLParser.NODE_ELEMENT, XMLParser.NODE_ELEMENT_END]:
			continue
			
		match xml_data.get_node_name():
			"g":
				if xml_data.get_node_type() == XMLParser.NODE_ELEMENT:
					create_group()
				elif xml_data.get_node_type() == XMLParser.NODE_ELEMENT_END:
					current_node = current_node.get_parent()
			"path":
				if xml_data.get_node_type() == XMLParser.NODE_ELEMENT:
					create_path()
	
	print("SVG parsing complete")

func create_group() -> void:
	var group = Node2D.new()
	group.name = xml_data.get_named_attribute_value_safe("id")
	group.transform = get_svg_transform(xml_data)
	current_node.add_child(group)
	group.owner = root_node
	group.set_meta("_edit_group_", true)
	current_node = group

func create_path() -> void:
	var path_data = xml_data.get_named_attribute_value_safe("d")
	var style = get_svg_style(xml_data)
	var transform = get_svg_transform(xml_data)
	var points = parse_path_data(path_data)
	
	if points.size() < 2:
		return
		
	var is_closed = path_data.to_upper().contains("Z")
	create_shape(points, is_closed, style, transform)

func parse_path_data(data: String) -> PackedVector2Array:
	var points = PackedVector2Array()
	var cursor = Vector2.ZERO
	
	# Clean up the data
	for cmd in ["M", "L", "H", "V", "Z"]:
		data = data.replacen(cmd, " " + cmd + " ")
		data = data.replacen(cmd.to_lower(), " " + cmd.to_lower() + " ")
	data = data.replacen(",", " ")
	
	var tokens = data.split(" ", false)
	var i = 0
	
	while i < tokens.size():
		var token = tokens[i]
		match token:
			"M", "m":
				if i + 2 < tokens.size() and tokens[i + 1].is_valid_float() and tokens[i + 2].is_valid_float():
					var point = Vector2(float(tokens[i + 1]), float(tokens[i + 2]))
					if token == "m":
						point += cursor
					cursor = point
					points.append(cursor)
					i += 3
				else:
					i += 1
			
			"L", "l":
				if i + 2 < tokens.size() and tokens[i + 1].is_valid_float() and tokens[i + 2].is_valid_float():
					var point = Vector2(float(tokens[i + 1]), float(tokens[i + 2]))
					if token == "l":
						point += cursor
					cursor = point
					points.append(cursor)
					i += 3
				else:
					i += 1
			
			"Z", "z":
				if points.size() > 0:
					points.append(points[0])  # Close the path
				i += 1
			
			_:
				i += 1
	
	return points

func create_shape(points: PackedVector2Array, is_closed: bool, style: Dictionary, transform: Transform2D) -> void:
	var root = Node2D.new()
	root.name = xml_data.get_named_attribute_value_safe("id") + "_0"
	root.transform = transform
	current_node.add_child(root)
	root.owner = root_node
	
	# Create fill if specified
	if style.has("fill") and style["fill"] != "none":
		var polygon = Polygon2D.new()
		polygon.polygon = points
		polygon.color = Color(style["fill"])
		root.add_child(polygon)
		polygon.owner = root_node
	
	# Create stroke if specified
	if style.has("stroke") and style["stroke"] != "none":
		var outline = Line2D.new()
		outline.points = points
		outline.default_color = Color(style["stroke"])
		if style.has("stroke-width"):
			outline.width = float(style["stroke-width"])
		root.add_child(outline)
		outline.owner = root_node

static func get_svg_transform(element: XMLParser) -> Transform2D:
	if !element.has_attribute("transform"):
		return Transform2D.IDENTITY
		
	var transform = Transform2D.IDENTITY
	var transform_str = element.get_named_attribute_value("transform")
	
	# Split multiple transformations
	var transforms = transform_str.split(")")
	
	for t in transforms:
		t = t.strip_edges()
		if t.is_empty():
			continue
			
		if t.begins_with("translate"):
			var values = _get_transform_values(t)
			if values.size() >= 2:
				transform = transform.translated(Vector2(values[0], values[1]))
		
		elif t.begins_with("scale"):
			var values = _get_transform_values(t)
			if values.size() >= 1:
				var scale = Vector2(values[0], values[0])
				if values.size() >= 2:
					scale.y = values[1]
				transform = transform.scaled(scale)
		
		elif t.begins_with("rotate"):
			var values = _get_transform_values(t)
			if values.size() >= 1:
				transform = transform.rotated(deg_to_rad(values[0]))
	
	return transform

static func _get_transform_values(transform_str: String) -> Array:
	var value_str = transform_str.split("(")[1].strip_edges()
	return value_str.split(",", false)

static func get_svg_style(element:XMLParser) -> Dictionary:
	var style : Dictionary = {}
	var style_flags : Array[StringName] = ["fill", "stroke", "stroke-width", "stop-color", "fill-opacity", "stroke-opacity", "stop-opacity", "stroke-miterlimit", "stroke-linejoin", "stroke-linecap"]
	# Check direct attributes first
	for attribute in style_flags:
		if element.has_attribute(attribute):
			style[attribute] = element.get_named_attribute_value_safe(attribute)
			
	# Check style attribute
	if element.has_attribute("style"):
		var svg_style = element.get_named_attribute_value("style")
		svg_style = svg_style.replacen(":", "\":\"")
		svg_style = svg_style.replacen(";", "\",\"")
		svg_style = "{\"" + svg_style + "\"}"
		var parsed_style = JSON.parse_string(svg_style)
		if parsed_style:
			style.merge(parsed_style)
	
	return style
