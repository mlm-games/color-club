# Color Extraction Implementation
class_name SVGColorExtractor
extends RefCounted

func extract_from_file(path: String) -> SVGColoringData:
	var file = FileAccess.open(path, FileAccess.READ)
	var content = file.get_as_text()
	return extract_from_string(content)

func extract_from_string(svg_content: String) -> SVGColoringData:
	var data = SVGColoringData.new()
	var parser = XMLParser.new()
	parser.open_buffer(svg_content.to_utf8_buffer())
	
	while parser.read() != ERR_FILE_EOF:
		if parser.get_node_type() == XMLParser.NODE_ELEMENT:
			match parser.get_node_name():
				"path", "rect", "circle", "polygon":
					var area = extract_element_colors(parser)
					if area:
						data.areas[area.area_id] = area
						if area.fill_color != Color.TRANSPARENT:
							data.original_colors[area.area_id] = area.fill_color
							if !data.color_palette.has(area.fill_color):
								data.color_palette.append(area.fill_color)
	
	return data

func extract_element_colors(parser: XMLParser) -> ColorArea:
	var id = parser.get_named_attribute_value("id")
	var path_data = ""
	var fill_color = Color.TRANSPARENT
	var stroke_color = Color.BLACK
	
	# Get path data based on element type
	match parser.get_node_name():
		"path":
			path_data = parser.get_named_attribute_value("d")
		#"rect":
			#path_data = create_rect_path(
				#float(parser.get_named_attribute_value("x")),
				#float(parser.get_named_attribute_value("y")),
				#float(parser.get_named_attribute_value("width")),
				#float(parser.get_named_attribute_value("height"))
			#)
		#"circle":
			#path_data = create_circle_path(
				#float(parser.get_named_attribute_value("cx")),
				#float(parser.get_named_attribute_value("cy")),
				#float(parser.get_named_attribute_value("r"))
			#)
	
	# Extract colors from style attribute
	var style = parser.get_named_attribute_value("style")
	if style:
		var style_dict = parse_style(style)
		if style_dict.has("fill"):
			fill_color = parse_color(style_dict["fill"])
		if style_dict.has("stroke"):
			stroke_color = parse_color(style_dict["stroke"])
	
	# Also check direct fill and stroke attributes
	var fill_attr = parser.get_named_attribute_value("fill")
	var stroke_attr = parser.get_named_attribute_value("stroke")
	
	if fill_attr:
		fill_color = parse_color(fill_attr)
	if stroke_attr:
		stroke_color = parse_color(stroke_attr)
	
	return ColorArea.new(id, path_data, fill_color, stroke_color)

func parse_style(style: String) -> Dictionary:
	var result = {}
	var pairs = style.split(";")
	for pair in pairs:
		var kv = pair.split(":")
		if kv.size() == 2:
			result[kv[0].strip_edges()] = kv[1].strip_edges()
	return result

func parse_color(color_str: String) -> Color:
	if color_str == "none":
		return Color.TRANSPARENT
	elif color_str.begins_with("#"):
		return Color(color_str)
	elif color_str.begins_with("rgb"):
		var values = color_str.substr(4, -1).split(",")
		if values.size() == 3:
			return Color(
				float(values[0]) / 255.0,
				float(values[1]) / 255.0,
				float(values[2]) / 255.0
			)
	return Color.TRANSPARENT

class ColorArea extends Node:
	var id: String
	var path_data: String
	var fill_color: Color
	var stroke_color: Color

	func _init(id, path_data, fill_color, stroke_color) -> void:
		self.id = id
		self.path_data = path_data
		self.fill_color = fill_color
		self.stroke_color = stroke_color
