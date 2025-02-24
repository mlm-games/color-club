@tool

## Used from https://github.com/pixelriot/SVG2Godot/blob/c70cfee4a2a396a795326b567d01f977c81c42c7/SVGParser.gd

class_name SVGParser extends Node2D

var file_path = "res://map01.svg" #"res://assets/art/test1.svg"
@export var use_path2d = false #true to deploy Path2D for vector paths

var current_node : Node

var xml_data = XMLParser.new()
const MAX_WIDTH = 7.0

@export var run: bool = false:
	set(val):
		run = val
		if val == true: 
			run_call.emit()
		else: 
			for i in get_children():
				i.queue_free()
signal run_call

func _ready() -> void:
	run_call.connect(_run)


func _run() -> void:
	if xml_data.open(file_path) != OK:
		print("Error opening file: ", file_path)
		return
	current_node = self
	
	#clear tree
	for c in get_children():
		c.queue_free()
	
	parse()

"""
Loop through all nodes and create the respective element.
"""
func parse() -> void:
	print("start parsing ...")
	
	while xml_data.read() == OK:
		if not xml_data.get_node_type() in [XMLParser.NODE_ELEMENT, XMLParser.NODE_ELEMENT_END]:
			continue
		elif xml_data.get_node_name() == "g":
			if xml_data.get_node_type() == XMLParser.NODE_ELEMENT:
				process_group(xml_data)
			elif xml_data.get_node_type() == XMLParser.NODE_ELEMENT_END:
				current_node = current_node.get_parent()
		#elif xml_data.get_node_name() == "rect":
			#process_svg_rectangle(xml_data)
		elif xml_data.get_node_name() == "polygon":
			process_svg_polygon(xml_data)
		elif xml_data.get_node_name() == "path":
			process_svg_path(xml_data)
	print("... end parsing")




func process_group(element:XMLParser) -> void:
	var new_group = Node2D.new()
	new_group.name = element.get_named_attribute_value("id")
	new_group.transform = get_svg_transform(element)
	current_node.add_child(new_group)
	new_group.set_meta("_edit_group_", true)
	current_node = new_group
	print("group " + new_group.name + " created")


#func process_svg_rectangle(element:XMLParser) -> void:
	#var new_rect = ColorRect.new()
	#new_rect.name = element.get_named_attribute_value("id")
	#current_node.add_child(new_rect)
	#
	##transform
	#var x = float(element.get_named_attribute_value("x"))
	#var y = float(element.get_named_attribute_value("y"))
	#var width = float(element.get_named_attribute_value("width"))
	#var height = float(element.get_named_attribute_value("height"))
	#var transform = get_svg_transform(element)
	#new_rect.position = Vector2((x), (y))
	#new_rect.size = Vector2(width, height)
	#new_rect.position = transform * new_rect.position
	#new_rect.size.x *= transform[0][0] 
	#new_rect.size.y *= transform[1][1]
	##style
	#var style = get_svg_style(element)
	#if style.has("fill"):
		#new_rect.color = Color(style["fill"])
	#if style.has("fill-opacity"):
		#new_rect.color.a = float(style["fill-opacity"])
		#
	#print("-rect ", new_rect.name, " created")


func process_svg_polygon(element:XMLParser) -> void:
	var points : PackedVector2Array
	var points_split = element.get_named_attribute_value("d").split(" ", false)
	for i in points_split:
		var values = i.split_floats(",", false)
		points.append(Vector2(values[0], values[1]))
		await get_tree().create_timer(0.5).timeout
	points.append(points[0])

	#create closed line
	var new_line = Line2D.new()
	new_line.name = element.get_named_attribute_value("id")
	new_line.transform = get_svg_transform(element)
	current_node.add_child(new_line)
	new_line.points = points
	
	
	#style
	var style = get_svg_style(element)
	if style.has("fill"):
		new_line.default_color = Color(style["fill"])
	if style.has("stroke-width"):
		new_line.width = float(style["stroke-width"])

	print("-line ", new_line.name, " created")


func process_svg_path(element:XMLParser) -> void:
	print("Processing path with d=", element.get_named_attribute_value("d"))
	
	var element_string = element.get_named_attribute_value("d")
	for symbol in ["m", "M", "v", "V", "h", "H", "l", "L", "c", "C", "s", "S", "z", "Z"]:
		element_string = element_string.replacen(symbol, " " + symbol + " ")
	element_string = element_string.replacen(",", " ")
	
	print("Processed element string:", element_string)
	
	#split element string into multiple arrays
	var element_string_array = element_string.split(" ", false)
	var string_arrays = []
	var string_array : PackedStringArray
	
	for a in element_string_array:
		if a in ["m", "M"]:
			if string_array.size() > 0:
				string_arrays.append(string_array)
			string_array = PackedStringArray()
		string_array.append(a)
	
	if string_array.size() > 0:
		string_arrays.append(string_array)
		
	print("Number of path segments:", string_arrays.size())
	for arr in string_arrays:
		print("Path segment:", arr)
	
	#convert into Line2Ds
	var string_array_count = -1
	for current_array in string_arrays:
		var cursor = Vector2.ZERO
		var points : PackedVector2Array
		var curve = Curve2D.new()
		string_array_count += 1
		
		for i in current_array.size()-1:
			match current_array[i]:
				"m":
					while current_array.size() > i + 2 and current_array[i+1].is_valid_float():
						cursor += Vector2(float(current_array[i+1]), float(current_array[i+2]))
						points.append(cursor)
						i += 2
				"M":
					while current_array.size() > i + 2 and current_array[i+1].is_valid_float():
						cursor = Vector2(float(current_array[i+1]), float(current_array[i+2]))
						points.append(cursor)
						
						curve.add_point(Vector2(float(current_array[i+1]), float(current_array[i+2])))
						
						i += 2
				"v":
					while current_array[i+1].is_valid_float():
						cursor.y += float(current_array[i+1])
						points.append(cursor)
						i += 1
				"V":
					while current_array[i+1].is_valid_float():
						cursor.y = float(current_array[i+1])
						points.append(cursor)
						i += 1
				"h":
					while current_array[i+1].is_valid_float():
						cursor.x += float(current_array[i+1])
						points.append(cursor)
						i += 1
				"H":
					while current_array[i+1].is_valid_float():
						cursor.x = float(current_array[i+1])
						points.append(cursor)
						i += 1
				"l":
					while current_array.size() > i + 2 and current_array[i+1].is_valid_float():
						cursor += Vector2(float(current_array[i+1]), float(current_array[i+2]))
						points.append(cursor)
						i += 2
				"L":
					while current_array.size() > i + 2 and current_array[i+1].is_valid_float():
						cursor = Vector2(float(current_array[i+1]), float(current_array[i+2]))
						points.append(cursor)
						i += 2
				#simpify Bezier curves with straight line
				"c": 
					while current_array.size() > i + 6 and current_array[i+1].is_valid_float():
						cursor += Vector2(float(current_array[i+5]), float(current_array[i+6]))
						points.append(cursor)
						i += 6
				"C":
					while current_array.size() > i + 6 and current_array[i+1].is_valid_float():
						var controll_point_in = Vector2(float(current_array[i+5]), float(current_array[i+6])) - cursor
						cursor = Vector2(float(current_array[i+5]), float(current_array[i+6]))
						points.append(cursor)
						curve.add_point(	cursor,
											-cursor + Vector2(float(current_array[i+3]), float(current_array[i+4])),
											cursor - Vector2(float(current_array[i+3]), float(current_array[i+4]))
										)
						i += 6
				"s":
					while current_array.size() > i + 4 and current_array[i+1].is_valid_float():
						cursor += Vector2(float(current_array[i+3]), float(current_array[i+4]))
						points.append(cursor)
						i += 4
				"S":
					while current_array.size() > i + 4 and current_array[i+1].is_valid_float():
						cursor = Vector2(float(current_array[i+3]), float(current_array[i+4]))
						points.append(cursor)
						i += 4
		
		if use_path2d and curve.get_point_count() > 1:
			create_path2d(	element.get_named_attribute_value("id") + "_" + str(string_array_count), 
							current_node, 
							curve, 
							get_svg_transform(element), 
							get_svg_style(element))
		
		elif string_array[string_array.size()-1].to_upper() == "Z": #closed polygon
			create_polygon2d(	element.get_named_attribute_value("id") + "_" + str(string_array_count), 
								current_node, 
								points, 
								get_svg_transform(element), 
								get_svg_style(element))
		else:
			create_line2d(	element.get_named_attribute_value("id") + "_" + str(string_array_count), 
							current_node, 
							points, 
							get_svg_transform(element), 
							get_svg_style(element))


func create_path2d(	name:String, 
					parent:Node, 
					curve:Curve2D, 
					transform:Transform2D, 
					style:Dictionary) -> void:
	var new_path = Path2D.new()
	new_path.name = name
	new_path.transform = transform
	parent.add_child(new_path)
	new_path.curve = curve
	
	#style
	if style.has("stroke"):
		new_path.modulate = Color(style["stroke"])
#	if style.has("stroke-width"):
#		new_path.width = float(style["stroke-width"])


func create_line2d(	name:String, 
					parent:Node, 
					points:PackedVector2Array, 
					transform:Transform2D, 
					style:Dictionary) -> void:
	var new_line = Line2D.new()
	new_line.name = name
	new_line.transform = transform
	parent.add_child(new_line)
	new_line.points = points
	await get_tree().create_timer(0.5).timeout
	
	#style
	if style.has("stroke"):
		new_line.default_color = Color(style["stroke"])
	if style.has("stroke-width"):
		#var line = Line2D.new() 
		new_line.width = float(style["stroke-width"])
		#new_path.add_child(line)
		#
		## Sample points along curve
		#var curve_points = []
		#var step = 0.1
		#for i in range(0, 1.0, step):
			#points.append(curve.interpolate(i))
		#line.points = points


func create_polygon2d(	name:String, 
						parent:Node, 
						points:PackedVector2Array, 
						transform:Transform2D, 
						style:Dictionary) -> void:
	var new_poly
	#style
	if style.has("fill") and style["fill"] != "none":
		#create base
		new_poly = Polygon2D.new()
		new_poly.name = name
		parent.add_child(new_poly)

		new_poly.transform = transform
		new_poly.polygon = points
		new_poly.color = Color(style["fill"])
	
	if style.has("stroke") and style["stroke"] != "none":
		#create outline
		var new_outline = Line2D.new()
		new_outline.name = name + "_stroke"
		if new_poly:
			new_poly.add_child(new_outline)
		else:
			parent.add_child(new_outline)
			new_outline.transform = transform

		points.append(points[0])
		new_outline.points = points
		
		new_outline.default_color = Color(style["stroke"])
		if style.has("stroke-width"):
			new_outline.width = float(style["stroke-width"])


static func get_svg_transform(element: XMLParser) -> Transform2D:
	var transform = Transform2D.IDENTITY
	
	if !element.has_attribute("transform"):
		return transform
		
	var svg_transform = element.get_named_attribute_value("transform")
	
	# Split multiple transformations if present
	var transforms = svg_transform.split(")")
	
	for t in transforms:
		t = t.strip_edges()
		if t.is_empty():
			continue
			
		if t.begins_with("translate"):
			var values = _get_transform_values(t)
			if values.size() == 1:
				transform *= Transform2D.IDENTITY.translated(Vector2(values[0], 0))
			elif values.size() == 2:
				transform *= Transform2D.IDENTITY.translated(Vector2(values[0], values[1]))
				
		elif t.begins_with("scale"):
			var values = _get_transform_values(t)
			if values.size() == 1:
				transform *= Transform2D.IDENTITY.scaled(Vector2(values[0], values[0]))
			elif values.size() == 2:
				transform *= Transform2D.IDENTITY.scaled(Vector2(values[0], values[1]))
				
		elif t.begins_with("rotate"):
			var values = _get_transform_values(t)
			if values.size() >= 1:
				var angle = values[0] * (PI / 180.0)
				if values.size() == 3:
					var pivot = Vector2(values[1], values[2])
					transform *= Transform2D().translated(-pivot).rotated(angle).translated(pivot)
				else:
					transform *= Transform2D().rotated(angle)
					
		elif t.begins_with("matrix"):
			var values = _get_transform_values(t)
			if values.size() == 6:
				transform *= Transform2D(Vector2(values[0], values[1]),
									  Vector2(values[2], values[3]),
									  Vector2(values[4], values[5]))
									  
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
		
	if element.has_attribute("style"):
		var svg_style = element.get_named_attribute_value("style")
		svg_style = svg_style.replacen(":", "\":\"")
		svg_style = svg_style.replacen(";", "\",\"")
		svg_style = "{\"" + svg_style + "\"}"
		style = JSON.parse_string(svg_style)
	return style
