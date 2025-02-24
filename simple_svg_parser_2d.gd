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
	
#One of many svg regexs online
var regex_dict : Dictionary[StringName, RegEx] = {
"viewbox": RegEx.create_from_string("^\\s*(" + NUM_PATTERN + ")\\s+(" + NUM_PATTERN + ")\\s+(" + NUM_PATTERN + ")\\s+(" + NUM_PATTERN + ")\\s*$"),
"alpha": RegEx.create_from_string("^\\s*(" + NUM_PATTERN + "%?)\\s*$"),
"value": RegEx.create_from_string("^\\s*(" + NUM_PATTERN + ")\\s*$"),
"path": RegEx.create_from_string("^\\s*(?:" + PATH_PATTERN + "\\s*)*$"),
"path_split": RegEx.create_from_string(PATH_PATTERN),
"num": RegEx.create_from_string("(" + NUM_PATTERN + ")"),
"point": RegEx.create_from_string("(" + NUM_PATTERN + ANY_SEP + NUM_PATTERN + ")"),
"quad": RegEx.create_from_string("(" + NUM_PATTERN + ANY_SEP + NUM_PATTERN + ANY_SEP + NUM_PATTERN + ANY_SEP + NUM_PATTERN + ")"),
"cube": RegEx.create_from_string("(" + NUM_PATTERN + ANY_SEP + NUM_PATTERN + ANY_SEP + NUM_PATTERN + ANY_SEP + NUM_PATTERN + ANY_SEP + NUM_PATTERN + ANY_SEP + NUM_PATTERN + ")"),
"arc": RegEx.create_from_string("(" + POSITIVE_NUM_PATTERN + ANY_SEP + POSITIVE_NUM_PATTERN + ANY_SEP + NUM_PATTERN + ANY_SEP + "[01]" + ANY_SEP + "[01]" + ANY_SEP + NUM_PATTERN + ANY_SEP + NUM_PATTERN + ")"),
"transform": RegEx.create_from_string("^\\s*(?:" + TRANSFORM_PATTERN + "\\s*)*$"),
"transform_split": RegEx.create_from_string(TRANSFORM_PATTERN),
"points": RegEx.create_from_string("^\\s*(?:" + POINT_PATTERN + "\\s*)*$"),
"style": RegEx.create_from_string(STYLE_PATTERN),
"styles": RegEx.create_from_string("^[\\s;]*" + STYLE_PATTERN + "(?:\\s*;[\\s;]*" + STYLE_PATTERN + ")*[\\s;]*$"),
"linejoin": RegEx.create_from_string("^\\s*(" + LINEJOIN_PATTERN + ")\\s*$"),
"linecap": RegEx.create_from_string("^\\s*(" + LINECAP_PATTERN + ")\\s*$"),
"color": RegEx.create_from_string("^\\s*(" + COLOR_PATTERN + ")\\s*$"),
"url": RegEx.create_from_string("^\\s*" + URL_PATTERN + "\\s*$"),
"paint": RegEx.create_from_string("^\\s*(" + PAINT_PATTERN + ")\\s*$"),
"double_period": RegEx.create_from_string("\\d+\\.\\d+(\\.)\\d+"),
"trim_whitespace": RegEx.create_from_string(r"^\s+|\s+$"),
}

const POSITIVE_NUM_PATTERN: String = "(?:\\+?(?:[0-9]*\\.)?[0-9]+(?:e[+\\-]?[0-9]+)?(?![0-9]))"
const NUM_PATTERN: String = "(?:[+\\-]?(?:[0-9]*\\.)?[0-9]+(?:e[+\\-]?[0-9]+)?(?![0-9]))"
const ANY_SEP: String = ")[^0-9+\\-\\.]*("
const SEP_PATTERN: String = "(?:[\\s]*(?:[\\s]|(?:,[\\s]*)))"
const OPTIONAL_SEP_PATTERN: String = "(?:[\\s]*(?:(?:,[\\s]*)?))"
const NEXT_NUM_PATTERN: String = "(?:(?:[+\\-]|(?:" + SEP_PATTERN + "[+\\-]?))(?:[0-9]*\\.)?[0-9]+(?:e[+\\-]?[0-9]+)?(?![0-9]))"
const POINT_PATTERN: String = "(?:" + NUM_PATTERN + NEXT_NUM_PATTERN + ")"
const NEXT_POINT_PATTERN: String = "(?:" + NEXT_NUM_PATTERN + NEXT_NUM_PATTERN + ")"
const QUAD_PATTERN: String = "(?:" + NUM_PATTERN + NEXT_NUM_PATTERN + NEXT_NUM_PATTERN + NEXT_NUM_PATTERN + ")"
const NEXT_QUAD_PATTERN: String = "(?:" + NEXT_NUM_PATTERN + NEXT_NUM_PATTERN + NEXT_NUM_PATTERN + NEXT_NUM_PATTERN + ")"
const CUBE_PATTERN: String = "(?:" + NUM_PATTERN + NEXT_NUM_PATTERN + NEXT_NUM_PATTERN + NEXT_NUM_PATTERN + NEXT_NUM_PATTERN + NEXT_NUM_PATTERN + ")"
const NEXT_CUBE_PATTERN: String = "(?:" + NEXT_NUM_PATTERN + NEXT_NUM_PATTERN + NEXT_NUM_PATTERN + NEXT_NUM_PATTERN + NEXT_NUM_PATTERN + NEXT_NUM_PATTERN + ")"
const ARC_PATTERN: String = "(?:" + POSITIVE_NUM_PATTERN + SEP_PATTERN + POSITIVE_NUM_PATTERN + NEXT_NUM_PATTERN + SEP_PATTERN + "[01]" + OPTIONAL_SEP_PATTERN + "[01]" + NEXT_NUM_PATTERN + NEXT_NUM_PATTERN + ")"
const PATH_PATTERN: String = "(?:(?:[Aa][\\s]*" + ARC_PATTERN + "(?:" + SEP_PATTERN + ARC_PATTERN + ")*)|(?:[Cc][\\s]*" + CUBE_PATTERN + "(?:" + NEXT_CUBE_PATTERN + ")*)|(?:[HVhv][\\s]*" + NUM_PATTERN + "(?:" + NEXT_NUM_PATTERN + ")*)|(?:[LMTlmt][\\s]*" + POINT_PATTERN + "(?:" + NEXT_POINT_PATTERN + ")*)|(?:[QSqs][\\s]*" + QUAD_PATTERN + "(?:" + NEXT_QUAD_PATTERN + ")*)|(?:[Zz]))"
const TRANSFORM_PATTERN: String = "(?:(?:[Mm][Aa][Tt][Rr][Ii][Xx]\\s*\\(\\s*(" + NUM_PATTERN + ")(" + NEXT_NUM_PATTERN + ")(" + NEXT_NUM_PATTERN + ")(" + NEXT_NUM_PATTERN + ")(" + NEXT_NUM_PATTERN + ")(" + NEXT_NUM_PATTERN + ")\\s*\\))|(?:[Tt][Rr][Aa][Nn][Ss][Ll][Aa][Tt][Ee]\\s*\\(\\s*(" + NUM_PATTERN + ")(" + NEXT_NUM_PATTERN + ")?\\s*\\))|(?:[Ss][Cc][Aa][Ll][Ee]\\s*\\(\\s*(" + NUM_PATTERN + ")(" + NEXT_NUM_PATTERN + ")?\\s*\\))|(?:[Rr][Oo][Tt][Aa][Tt][Ee]\\s*\\(\\s*(" + NUM_PATTERN + ")(" + NEXT_NUM_PATTERN + "(" + NEXT_NUM_PATTERN + ")?)?\\s*\\))|(?:[Rr][Oo][Tt][Aa][Tt][Ee]\\s*\\(\\s*(" + NUM_PATTERN + ")(" + NEXT_NUM_PATTERN + "(" + NEXT_NUM_PATTERN + ")?)?\\s*\\))|(?:[Ss][Kk][Ee][Ww][Xx]\\s*\\(\\s*(" + NUM_PATTERN + ")\\s*\\))|(?:[Ss][Kk][Ee][Ww][Yy]\\s*\\(\\s*(" + NUM_PATTERN + ")\\s*\\)))"
const STYLE_PATTERN: String = "(?:([\\-A-Za-z]+)\\s*\\:\\s*([^;\\s](?:\\s*[^;\\s])*))"
const LINEJOIN_PATTERN: String = "(?:" + \
"(?:[Aa][Rr][Cc][Ss])|" + \
"(?:[Bb][Ee][Vv][Ee][Ll])|" + \
"(?:[Mm][Ii][Tt][Ee][Rr])|" + \
"(?:[Mm][Ii][Tt][Ee][Rr]-[Cc][Ll][Ii][Pp])|" + \
"(?:[Rr][Oo][Uu][Nn][Dd]))"
const LINECAP_PATTERN: String = "(?:" + \
"(?:[Bb][Uu][Tt][Tt])|" + \
"(?:[Rr][Oo][Uu][Nn][Dd])|" + \
"(?:[Ss][Qq][Uu][Aa][Rr][Ee]))"
const COLOR_KEYWORD_PATTERN: String = "(?:" + \
"(?:[Aa][Ll][Ii][Cc][Ee][Bb][Ll][Uu][Ee])|" + \
"(?:[Aa][Nn][Tt][Ii][Qq][Uu][Ee][Ww][Hh][Ii][Tt][Ee])|" + \
"(?:[Aa][Qq][Uu][Aa])|" + \
"(?:[Aa][Qq][Uu][Aa][Mm][Aa][Rr][Ii][Nn][Ee])|" + \
"(?:[Aa][Zz][Uu][Rr][Ee])|" + \
"(?:[Bb][Ee][Ii][Gg][Ee])|" + \
"(?:[Bb][Ii][Ss][Qq][Uu][Ee])|" + \
"(?:[Bb][Ll][Aa][Cc][Kk])|" + \
"(?:[Bb][Ll][Aa][Nn][Cc][Hh][Ee][Dd][Aa][Ll][Mm][Oo][Nn][Dd])|" + \
"(?:[Bb][Ll][Uu][Ee])|" + \
"(?:[Bb][Ll][Uu][Ee][Vv][Ii][Oo][Ll][Ee][Tt])|" + \
"(?:[Bb][Rr][Oo][Ww][Nn])|" + \
"(?:[Bb][Uu][Rr][Ll][Yy][Ww][Oo][Oo][Dd])|" + \
"(?:[Cc][Aa][Dd][Ee][Tt][Bb][Ll][Uu][Ee])|" + \
"(?:[Cc][Hh][Aa][Rr][Tt][Rr][Ee][Uu][Ss][Ee])|" + \
"(?:[Cc][Hh][Oo][Cc][Oo][Ll][Aa][Tt][Ee])|" + \
"(?:[Cc][Oo][Rr][Aa][Ll])|" + \
"(?:[Cc][Oo][Rr][Nn][Ff][Ll][Oo][Ww][Ee][Rr][Bb][Ll][Uu][Ee])|" + \
"(?:[Cc][Oo][Rr][Nn][Ss][Ii][Ll][Kk])|" + \
"(?:[Cc][Rr][Ii][Mm][Ss][Oo][Nn])|" + \
"(?:[Cc][Yy][Aa][Nn])|" + \
"(?:[Dd][Aa][Rr][Kk][Bb][Ll][Uu][Ee])|" + \
"(?:[Dd][Aa][Rr][Kk][Cc][Yy][Aa][Nn])|" + \
"(?:[Dd][Aa][Rr][Kk][Gg][Oo][Ll][Dd][Ee][Nn][Rr][Oo][Dd])|" + \
"(?:[Dd][Aa][Rr][Kk][Gg][Rr][Aa][Yy])|" + \
"(?:[Dd][Aa][Rr][Kk][Gg][Rr][Ee][Ee][Nn])|" + \
"(?:[Dd][Aa][Rr][Kk][Gg][Rr][Ee][Yy])|" + \
"(?:[Dd][Aa][Rr][Kk][Kk][Hh][Aa][Kk][Ii])|" + \
"(?:[Dd][Aa][Rr][Kk][Oo][Ll][Ii][Vv][Ee][Gg][Rr][Ee][Ee][Nn])|" + \
"(?:[Dd][Aa][Rr][Kk][Oo][Rr][Aa][Nn][Gg][Ee])|" + \
"(?:[Dd][Aa][Rr][Kk][Oo][Rr][Cc][Hh][Ii][Dd])|" + \
"(?:[Dd][Aa][Rr][Kk][Rr][Ee][Dd])|" + \
"(?:[Dd][Aa][Rr][Kk][Ss][Aa][Ll][Mm][Oo][Nn])|" + \
"(?:[Dd][Aa][Rr][Kk][Ss][Ee][Aa][Gg][Rr][Ee][Ee][Nn])|" + \
"(?:[Dd][Aa][Rr][Kk][Ss][Ll][Aa][Tt][Ee][Bb][Ll][Uu][Ee])|" + \
"(?:[Dd][Aa][Rr][Kk][Ss][Ll][Aa][Tt][Ee][Gg][Rr][Aa][Yy])|" + \
"(?:[Dd][Aa][Rr][Kk][Ss][Ll][Aa][Tt][Ee][Gg][Rr][Ee][Yy])|" + \
"(?:[Dd][Aa][Rr][Kk][Tt][Uu][Rr][Qq][Uu][Oo][Ii][Ss][Ee])|" + \
"(?:[Dd][Aa][Rr][Kk][Vv][Ii][Oo][Ll][Ee][Tt])|" + \
"(?:[Dd][Ee][Ee][Pp][Pp][Ii][Nn][Kk])|" + \
"(?:[Dd][Ee][Ee][Pp][Ss][Kk][Yy][Bb][Ll][Uu][Ee])|" + \
"(?:[Dd][Ii][Mm][Gg][Rr][Aa][Yy])|" + \
"(?:[Dd][Ii][Mm][Gg][Rr][Ee][Yy])|" + \
"(?:[Dd][Oo][Dd][Gg][Ee][Rr][Bb][Ll][Uu][Ee])|" + \
"(?:[Ff][Ii][Rr][Ee][Bb][Rr][Ii][Cc][Kk])|" + \
"(?:[Ff][Ll][Oo][Rr][Aa][Ll][Ww][Hh][Ii][Tt][Ee])|" + \
"(?:[Ff][Oo][Rr][Ee][Ss][Tt][Gg][Rr][Ee][Ee][Nn])|" + \
"(?:[Ff][Uu][Cc][Hh][Ss][Ii][Aa])|" + \
"(?:[Gg][Aa][Ii][Nn][Ss][Bb][Oo][Rr][Oo])|" + \
"(?:[Gg][Hh][Oo][Ss][Tt][Ww][Hh][Ii][Tt][Ee])|" + \
"(?:[Gg][Oo][Ll][Dd])|" + \
"(?:[Gg][Oo][Ll][Dd][Ee][Nn][Rr][Oo][Dd])|" + \
"(?:[Gg][Rr][Aa][Yy])|" + \
"(?:[Gg][Rr][Ee][Ee][Nn])|" + \
"(?:[Gg][Rr][Ee][Ee][Nn][Yy][Ee][Ll][Ll][Oo][Ww])|" + \
"(?:[Gg][Rr][Ee][Yy])|" + \
"(?:[Hh][Oo][Nn][Ee][Yy][Dd][Ee][Ww])|" + \
"(?:[Hh][Oo][Tt][Pp][Ii][Nn][Kk])|" + \
"(?:[Ii][Nn][Dd][Ii][Aa][Nn][Rr][Ee][Dd])|" + \
"(?:[Ii][Nn][Dd][Ii][Gg][Oo])|" + \
"(?:[Ii][Vv][Oo][Rr][Yy])|" + \
"(?:[Kk][Hh][Aa][Kk][Ii])|" + \
"(?:[Ll][Aa][Vv][Ee][Nn][Dd][Ee][Rr])|" + \
"(?:[Ll][Aa][Vv][Ee][Nn][Dd][Ee][Rr][Bb][Ll][Uu][Ss][Hh])|" + \
"(?:[Ll][Aa][Ww][Nn][Gg][Rr][Ee][Ee][Nn])|" + \
"(?:[Ll][Ee][Mm][Oo][Nn][Cc][Hh][Ii][Ff][Ff][Oo][Nn])|" + \
"(?:[Ll][Ii][Gg][Hh][Tt][Bb][Ll][Uu][Ee])|" + \
"(?:[Ll][Ii][Gg][Hh][Tt][Cc][Oo][Rr][Aa][Ll])|" + \
"(?:[Ll][Ii][Gg][Hh][Tt][Cc][Yy][Aa][Nn])|" + \
"(?:[Ll][Ii][Gg][Hh][Tt][Gg][Oo][Ll][Dd][Ee][Nn][Rr][Oo][Dd][Yy][Ee][Ll][Ll][Oo][Ww])|" + \
"(?:[Ll][Ii][Gg][Hh][Tt][Gg][Rr][Aa][Yy])|" + \
"(?:[Ll][Ii][Gg][Hh][Tt][Gg][Rr][Ee][Ee][Nn])|" + \
"(?:[Ll][Ii][Gg][Hh][Tt][Gg][Rr][Ee][Yy])|" + \
"(?:[Ll][Ii][Gg][Hh][Tt][Pp][Ii][Nn][Kk])|" + \
"(?:[Ll][Ii][Gg][Hh][Tt][Ss][Aa][Ll][Mm][Oo][Nn])|" + \
"(?:[Ll][Ii][Gg][Hh][Tt][Ss][Ee][Aa][Gg][Rr][Ee][Ee][Nn])|" + \
"(?:[Ll][Ii][Gg][Hh][Tt][Ss][Kk][Yy][Bb][Ll][Uu][Ee])|" + \
"(?:[Ll][Ii][Gg][Hh][Tt][Ss][Ll][Aa][Tt][Ee][Gg][Rr][Aa][Yy])|" + \
"(?:[Ll][Ii][Gg][Hh][Tt][Ss][Ll][Aa][Tt][Ee][Gg][Rr][Ee][Yy])|" + \
"(?:[Ll][Ii][Gg][Hh][Tt][Ss][Tt][Ee][Ee][Ll][Bb][Ll][Uu][Ee])|" + \
"(?:[Ll][Ii][Gg][Hh][Tt][Yy][Ee][Ll][Ll][Oo][Ww])|" + \
"(?:[Ll][Ii][Mm][Ee])|" + \
"(?:[Ll][Ii][Mm][Ee][Gg][Rr][Ee][Ee][Nn])|" + \
"(?:[Ll][Ii][Nn][Ee][Nn])|" + \
"(?:[Mm][Aa][Gg][Ee][Nn][Tt][Aa])|" + \
"(?:[Mm][Aa][Rr][Oo][Oo][Nn])|" + \
"(?:[Mm][Ee][Dd][Ii][Uu][Mm][Aa][Qq][Uu][Aa][Mm][Aa][Rr][Ii][Nn][Ee])|" + \
"(?:[Mm][Ee][Dd][Ii][Uu][Mm][Bb][Ll][Uu][Ee])|" + \
"(?:[Mm][Ee][Dd][Ii][Uu][Mm][Oo][Rr][Cc][Hh][Ii][Dd])|" + \
"(?:[Mm][Ee][Dd][Ii][Uu][Mm][Pp][Uu][Rr][Pp][Ll][Ee])|" + \
"(?:[Mm][Ee][Dd][Ii][Uu][Mm][Ss][Ee][Aa][Gg][Rr][Ee][Ee][Nn])|" + \
"(?:[Mm][Ee][Dd][Ii][Uu][Mm][Ss][Ll][Aa][Tt][Ee][Bb][Ll][Uu][Ee])|" + \
"(?:[Mm][Ee][Dd][Ii][Uu][Mm][Ss][Pp][Rr][Ii][Nn][Gg][Gg][Rr][Ee][Ee][Nn])|" + \
"(?:[Mm][Ee][Dd][Ii][Uu][Mm][Tt][Uu][Rr][Qq][Uu][Oo][Ii][Ss][Ee])|" + \
"(?:[Mm][Ee][Dd][Ii][Uu][Mm][Vv][Ii][Oo][Ll][Ee][Tt][Rr][Ee][Dd])|" + \
"(?:[Mm][Ii][Dd][Nn][Ii][Gg][Hh][Tt][Bb][Ll][Uu][Ee])|" + \
"(?:[Mm][Ii][Nn][Tt][Cc][Rr][Ee][Aa][Mm])|" + \
"(?:[Mm][Ii][Ss][Tt][Yy][Rr][Oo][Ss][Ee])|" + \
"(?:[Mm][Oo][Cc][Cc][Aa][Ss][Ii][Nn])|" + \
"(?:[Nn][Aa][Vv][Aa][Jj][Oo][Ww][Hh][Ii][Tt][Ee])|" + \
"(?:[Nn][Aa][Vv][Yy])|" + \
"(?:[Oo][Ll][Dd][Ll][Aa][Cc][Ee])|" + \
"(?:[Oo][Ll][Ii][Vv][Ee])|" + \
"(?:[Oo][Ll][Ii][Vv][Ee][Dd][Rr][Aa][Bb])|" + \
"(?:[Oo][Rr][Aa][Nn][Gg][Ee])|" + \
"(?:[Oo][Rr][Aa][Nn][Gg][Ee][Rr][Ee][Dd])|" + \
"(?:[Oo][Rr][Cc][Hh][Ii][Dd])|" + \
"(?:[Pp][Aa][Ll][Ee][Gg][Oo][Ll][Dd][Ee][Nn][Rr][Oo][Dd])|" + \
"(?:[Pp][Aa][Ll][Ee][Gg][Rr][Ee][Ee][Nn])|" + \
"(?:[Pp][Aa][Ll][Ee][Tt][Uu][Rr][Qq][Uu][Oo][Ii][Ss][Ee])|" + \
"(?:[Pp][Aa][Ll][Ee][Vv][Ii][Oo][Ll][Ee][Tt][Rr][Ee][Dd])|" + \
"(?:[Pp][Aa][Pp][Aa][Yy][Aa][Ww][Hh][Ii][Pp])|" + \
"(?:[Pp][Ee][Aa][Cc][Hh][Pp][Uu][Ff][Ff])|" + \
"(?:[Pp][Ee][Rr][Uu])|" + \
"(?:[Pp][Ii][Nn][Kk])|" + \
"(?:[Pp][Ll][Uu][Mm])|" + \
"(?:[Pp][Oo][Ww][Dd][Ee][Rr][Bb][Ll][Uu][Ee])|" + \
"(?:[Pp][Uu][Rr][Pp][Ll][Ee])|" + \
"(?:[Rr][Ee][Dd])|" + \
"(?:[Rr][Oo][Ss][Yy][Bb][Rr][Oo][Ww][Nn])|" + \
"(?:[Rr][Oo][Yy][Aa][Ll][Bb][Ll][Uu][Ee])|" + \
"(?:[Ss][Aa][Dd][Dd][Ll][Ee][Bb][Rr][Oo][Ww][Nn])|" + \
"(?:[Ss][Aa][Ll][Mm][Oo][Nn])|" + \
"(?:[Ss][Aa][Nn][Dd][Yy][Bb][Rr][Oo][Ww][Nn])|" + \
"(?:[Ss][Ee][Aa][Gg][Rr][Ee][Ee][Nn])|" + \
"(?:[Ss][Ee][Aa][Ss][Hh][Ee][Ll][Ll])|" + \
"(?:[Ss][Ii][Ee][Nn][Nn][Aa])|" + \
"(?:[Ss][Ii][Ll][Vv][Ee][Rr])|" + \
"(?:[Ss][Kk][Yy][Bb][Ll][Uu][Ee])|" + \
"(?:[Ss][Ll][Aa][Tt][Ee][Bb][Ll][Uu][Ee])|" + \
"(?:[Ss][Ll][Aa][Tt][Ee][Gg][Rr][Aa][Yy])|" + \
"(?:[Ss][Ll][Aa][Tt][Ee][Gg][Rr][Ee][Yy])|" + \
"(?:[Ss][Nn][Oo][Ww])|" + \
"(?:[Ss][Pp][Rr][Ii][Nn][Gg][Gg][Rr][Ee][Ee][Nn])|" + \
"(?:[Ss][Tt][Ee][Ee][Ll][Bb][Ll][Uu][Ee])|" + \
"(?:[Tt][Aa][Nn])|" + \
"(?:[Tt][Ee][Aa][Ll])|" + \
"(?:[Tt][Hh][Ii][Ss][Tt][Ll][Ee])|" + \
"(?:[Tt][Oo][Mm][Aa][Tt][Oo])|" + \
"(?:[Tt][Uu][Rr][Qq][Uu][Oo][Ii][Ss][Ee])|" + \
"(?:[Vv][Ii][Oo][Ll][Ee][Tt])|" + \
"(?:[Ww][Hh][Ee][Aa][Tt])|" + \
"(?:[Ww][Hh][Ii][Tt][Ee])|" + \
"(?:[Ww][Hh][Ii][Tt][Ee][Ss][Mm][Oo][Kk][Ee])|" + \
"(?:[Yy][Ee][Ll][Ll][Oo][Ww])|" + \
"(?:[Yy][Ee][Ll][Ll][Oo][Ww][Gg][Rr][Ee][Ee][Nn])|" + \
"(?:[Tt][Rr][Aa][Nn][Ss][Pp][Aa][Rr][Ee][Nn][Tt]))"
const COLOR_PATTERN: String = "(?:" + COLOR_KEYWORD_PATTERN + "|(?:#[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f](?:[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f])?)|(?:[Rr][Gg][Bb]\\s*\\(\\s*" + NUM_PATTERN + "%?\\s*,\\s*" + NUM_PATTERN + "%?\\s*,\\s*" + NUM_PATTERN + "%?\\s*\\))|(?:[Rr][Gg][Bb][Aa]\\s*\\(\\s*" + NUM_PATTERN + "%?\\s*,\\s*" + NUM_PATTERN + "%?\\s*,\\s*" + NUM_PATTERN + "%?\\s*,\\s*" + NUM_PATTERN + "%?\\s*\\)))"
const URL_PATTERN: String = "(?:[Uu][Rr][Ll]\\s*\\(\\s*(?:#([^\\)]*)|'#([^']*)'|\"#([^\"]*)\")\\s*\\))"
const PAINT_PATTERN: String = "(?:(?:[Nn][Oo][Nn][Ee])|" + COLOR_PATTERN + "|" + URL_PATTERN + ")"
